import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/pinned_caution_card.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/screens/result/sections/starts_from_card.dart';
import 'package:beoba/src/screens/result/sections/today_card.dart';
import 'package:domain_data/domain_data.dart' show Caution, DeadlineKind;
import 'package:engines/engines.dart' show KstDate;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 전세·월세 보증금 — **네 번째 분야.**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const domainId = 'deposit_return';

  /// 전입신고 2024-03-11 · 확정일자 같은 날 · 계약은 끝났다.
  const answers = <String, Object?>{
    'q_still_living': 'yes',
    'q_move_in_reported': KstDate(2024, 3, 11),
    'q_fixed_date': 'same_day',
    'q_lease_ended': KstDate(2026, 6, 30),
  };

  Future<ProviderContainer> openResult(
    WidgetTester tester, {
    Map<String, Object?> seed = answers,
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(container, domainId, answers: seed);
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();
    return container;
  }

  group('★ 기한이 아니라 「언제부터」다', () {
    testWidgets('날짜가 「그 다음 날」로 나온다', (tester) async {
      await openResult(tester);

      // 전입신고 3월 11일 → **그 다음 날** 3월 12일. 조문이 직접 정한 것이라
      // 민법 제157조 초일불산입과는 다른 층이다(DECISIONS 135번).
      expect(find.byType(StartsFromCard), findsOneWidget);
      expectScreenText(tester, '2024년 3월 12일부터');
      expectScreenText(tester, '제삼자에 대한 효력');
    });

    testWidgets('D-day 도 「오늘 할 일」도 아니다', (tester) async {
      final container = await openResult(tester);

      // 「오늘 할 일」이 세는 것은 지나면 잃는 날뿐이다.
      expect(container.read(dueDeadlinesProvider(domainId)), isEmpty);
      expect(container.read(startsFromProvider(domainId)), isNotEmpty);
      for (final result in container.read(startsFromProvider(domainId))) {
        expect(result.kind, DeadlineKind.startsFrom);
      }

      final today = tester
          .widget<TodayCard>(find.byType(TodayCard))
          .deadlines;
      expect(today, isEmpty);
      // 「부터」이지 「까지」가 아니다. D-day 는 붙지 않는다.
      expectNoScreenText(tester, 'D-');
      expectNoScreenText(tester, '일 남음');
    });

    testWidgets('확정일자를 나중에 받으면 그날이 기준이다', (tester) async {
      await openResult(
        tester,
        seed: const {
          'q_still_living': 'yes',
          'q_move_in_reported': KstDate(2024, 3, 11),
          'q_fixed_date': 'later',
          'q_fixed_date_on': KstDate(2024, 6, 1),
          'q_lease_ended': KstDate(2026, 6, 30),
        },
      );

      // 대항요건은 이미 갖췄으니 셋 중 늦은 날은 확정일자 그날이다.
      expectScreenText(tester, '2024년 6월 1일부터');
    });
  });

  group('★ 이사 경고', () {
    testWidgets('멈춤 카드로 뜨고 조문 둘이 나란하다', (tester) async {
      await openResult(tester);

      expect(find.byType(PinnedCautionCard), findsWidgets);
      expectScreenText(tester, '짐을 빼거나 전입신고를 옮기기 전에 확인하세요');
      // 조문 둘 — 잃는 쪽과 지키는 쪽.
      expectScreenText(tester, '주택임대차보호법 제3조 제1항');
      expectScreenText(tester, '주택임대차보호법 제3조의3 제5항');
    });

    testWidgets('권유하지 않는다', (tester) async {
      final container = await pumpApp(tester);
      final caution = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .cautions
          .firstWhere((c) => c.id == 'ct_before_moving');
      final ours = '${caution.condition} ${caution.consequence}';

      for (final banned in const ['이사 가지 마', '등기부터', '신청하세요']) {
        expect(ours.contains(banned), isFalse, reason: '「$banned」가 있습니다');
      }
    });
  });

  group('단정하지 않는다', () {
    testWidgets('우리 말에 금지 표현이 없다', (tester) async {
      final container = await pumpApp(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);

      final ours = <String>[
        for (final caution in domain.cautions)
          '${caution.condition} ${caution.consequence}',
        for (final deadline in domain.deadlines)
          '${deadline.label} ${deadline.whatIsThis}',
        for (final procedure in domain.procedures)
          '${procedure.label} ${procedure.whatIsThis} ${procedure.detail ?? ''}',
      ].join(' ');

      for (final banned in const [
        '받을 수 있어요',
        '돌려받',
        '대항력이 있습니다',
        '이사 가지 마',
      ]) {
        expect(ours.contains(banned), isFalse, reason: '「$banned」가 있습니다');
      }
    });
  });

  group('비용 — 못 찾은 것은 안 낸다', () {
    testWidgets('송달료만 내고 인지는 없다고 말한다', (tester) async {
      final container = await openResult(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);

      expect(domain.costs.map((c) => c.id), ['cost_service_fee']);
      // 송달료 3회 × 당사자 2인 × 5,500원.
      expect(
        container.read(costResultProvider(domainId)).total,
        33000, // not-a-legal-number: 3회 × 2인 × 5,500
      );
      // 「전부」인 것처럼 쓰지 않는다.
      expect(
        domain.costs.single.verification.openPart,
        contains('인지액'),
      );
      final procedure = domain.procedures
          .firstWhere((p) => p.id == 'proc_lease_registration');
      expect(procedure.caution, contains('전부가 아닐 수 있어요'));
    });
  });

  group('관할 — 표가 들어왔다', () {
    testWidgets('집 주소를 적으면 법원 이름이 나온다', (tester) async {
      await openResult(
        tester,
        seed: const {
          'q_still_living': 'yes',
          'q_move_in_reported': KstDate(2024, 3, 11),
          'q_fixed_date': 'same_day',
          'q_lease_ended': KstDate(2026, 6, 30),
          'q_house_area': '포천시',
        },
      );

      // **조문이 셋 다 허용한다.** 시·군법원이 지방법원을 밀어내지 않는다.
      await tester.ensureVisible(find.text(JurisdictionCard.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(JurisdictionCard.title));
      await tester.pumpAndSettle();

      expectScreenText(tester, '포천시법원');
      expectScreenText(tester, '의정부지방법원');
    });

    testWidgets('비워 두면 이름을 짓지 않는다', (tester) async {
      final container = await openResult(tester);

      for (final result in container.read(jurisdictionResultsProvider(domainId))) {
        expect(result.court, isNull);
      }
    });

    testWidgets('인천은 소송에서 비고 시·군법원에서는 나온다', (tester) async {
      // [별표 1]에는 인천지방법원이 있는데 [별표 3]에 관할구역이 없다.
      // 넘겨짚지 않는다.
      await openResult(
        tester,
        seed: const {
          'q_still_living': 'yes',
          'q_move_in_reported': KstDate(2024, 3, 11),
          'q_fixed_date': 'same_day',
          'q_lease_ended': KstDate(2026, 6, 30),
          'q_house_area': '인천광역시 강화군',
        },
      );

      await tester.ensureVisible(find.text(JurisdictionCard.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(JurisdictionCard.title));
      await tester.pumpAndSettle();

      expectScreenText(tester, '강화군법원');
      expectNoScreenText(tester, '인천지방법원');
    });
  });

  group('소액임차인 — 지역·시점에 안 걸리는 것만 낸다', () {
    Caution cautionOf(ProviderContainer container, String id) => container
        .read(domainBundleProvider)
        .requireValue
        .byId(domainId)
        .cautions
        .firstWhere((c) => c.id == id);

    testWidgets('★ 「경매신청의 등기 전에」가 따로 선다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit_timing');

      // 제8조 제1항은 문장이 둘이고 **뒷문장이 시점을 정한다.** 앞문장만 읽으면
      // 「보증금이 적으면 먼저 받는다」로 끝난다.
      expect(card.legalBasis!.text, contains('경매신청의 등기 전에'));
      expect(card.consequence, contains('등기 뒤에 갖춘 요건으로는'));
      // 대항요건 조문이 칩으로 따라붙는다.
      expect(card.alsoBasis.single.article, '제3조 제1항');
    });

    testWidgets('권유하지 않는다', (tester) async {
      final container = await openResult(tester);
      for (final id in const [
        'ct_small_deposit_timing',
        'ct_small_deposit_basis_date',
        'ct_small_deposit_cap',
        'ct_small_deposit_share',
      ]) {
        final card = cautionOf(container, id);
        final ours = '${card.condition} ${card.consequence}';
        for (final banned in const ['하세요', '받습니다', '못 받아요']) {
          expect(ours.contains(banned), isFalse, reason: '$id 에 「$banned」');
        }
      }
    });

    testWidgets('집값의 절반이 천장이라는 것을 낸다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit_cap');

      expect(card.consequence, contains('2분의 1'));
      // 법 단서와 시행령이 같은 말을 두 자리에서 한다. 둘 다 싣는다.
      expect(card.legalBasis!.article, '제8조 제3항');
      expect(card.alsoBasis.single.article, '제10조 제2항');
    });

    testWidgets('★ 여럿이면 제3항과 제4항을 함께 낸다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit_share');

      // 제4항만 빠지면 「나는 따로 계약했으니 따로 받겠지」로 읽힌다.
      expect(card.consequence, contains('한 사람으로 보아'));
      expect(card.alsoBasis.single.text, contains('가정공동생활'));
    });

    testWidgets('★ 기준일은 오늘이 아니라 담보가 잡힌 날이다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit_basis_date');

      expect(card.verification.appliesFrom, const KstDate(2023, 2, 21));
      expect(card.legalBasis!.article, '부칙(제33254호) 제2조');
      // 부칙은 **담보권자마다** 따로 보라고 적었다.
      expect(card.consequence, contains('담보를 잡은 사람마다 따로'));
      expect(card.consequence, isNot(contains('가장 이른')));
    });

    testWidgets('★ 넷을 묻지 않고 다 낸다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit');

      expect(card.variants.map((v) => v.key), ['1호', '2호', '3호', '4호']);
      // **구분은 조문의 말 그대로다.** 줄이면 우리가 만든 구분이 된다.
      expect(
        card.variants[1].label,
        contains('「수도권정비계획법」에 따른 과밀억제권역(서울특별시는 제외한다)'),
      );
      // 지역을 새로 묻지 않는다 — 질문은 여섯 그대로다.
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);
      expect(domain.intake, hasLength(6));
    });

    testWidgets('★ 제11조와 제10조 제1항을 짝으로 낸다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit');

      // 자격만 내면 얼마를 받는지 모르고, 금액만 내면 해당하는지를 모른다.
      const pairs = [
        ('1억6,500만원', '5,500만원'),
        ('1억4,500만원', '4,800만원'),
        ('8,500만원', '2,800만원'),
        ('7,500만원', '2,500만원'),
      ];
      for (final (index, (eligible, priority)) in pairs.indexed) {
        final detail = card.variants[index].detail;
        expect(detail, contains(eligible));
        expect(detail, contains(priority));
      }
      // 조문 둘이 근거 칩으로 함께 붙는다.
      expect(card.alsoBasis.map((b) => b.article), ['제10조 제1항', '제11조']);
    });

    testWidgets('★ 구분이 두 조문에 글자 하나까지 같게 들어 있다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit');

      // 두 벌로 적으면 한쪽만 고치는 사고가 나도 아무도 못 잡는다.
      // label 을 조문 원문 그대로 두었으니 **양쪽에 그대로 들어 있어야 한다.**
      for (final variant in card.variants) {
        for (final basis in card.alsoBasis) {
          expect(
            basis.text,
            contains(variant.label),
            reason: '${variant.key} 이 ${basis.article} 에 그대로 없습니다',
          );
        }
      }
    });

    testWidgets('★ 금액 카드 머리에 기준일이 박혀 있다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_small_deposit');

      expect(card.consequence, contains('2023년 2월 21일 이후에 담보'));
      expect(card.verification.appliesFrom, const KstDate(2023, 2, 21));
      expect(card.verification.openPart, contains('이전 담보물권 기준 금액'));
    });

    testWidgets('넷이 화면에 실제로 그려진다', (tester) async {
      await openResult(tester);

      await tester.ensureVisible(find.text('보증금이 적으면 먼저 받나요?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('보증금이 적으면 먼저 받나요?'));
      await tester.pumpAndSettle();

      for (final amount in const ['5,500만원', '4,800만원', '2,800만원', '2,500만원']) {
        expectScreenText(tester, amount);
      }
    });

    testWidgets('과밀억제권역 목록이 조문 그대로 실린다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_overconcentration_area');

      // 제외구역이 문언 안에 들어 있어야 본인이 자기 칸을 찾을 수 있다.
      final text = card.legalBasis!.text;
      expect(text, contains('남양주시(호평동'));
      expect(text, contains('시흥시[반월특수지역'));
      expect(text, contains('강화군, 옹진군'));
      // 안 쓰는 란은 전사하지 않았다.
      expect(text, isNot(contains('성장관리권역')));
      expect(text, isNot(contains('자연보전권역')));
    });
  });
}
