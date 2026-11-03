import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/pinned_caution_card.dart';
import 'package:domain_data/domain_data.dart'
    show AlertDisplay, Caution, QuestionType;
import 'package:engines/engines.dart' show KstDate, SafetyFilter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 갑자기 나가라고 했을 때 — **여섯 번째 분야.**
///
/// 이 분야에서 우리가 하는 일은 하나다 — **3개월을 놓치지 않게 하는 것.**
/// 정당한지 아닌지는 노동위원회가 판정한다(근로기준법 제30조 제1항).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const domainId = 'unfair_dismissal';

  /// 8월 15일에 들었고, 5명 이상, 서면은 못 받았고, 돌아가고 싶지 않다.
  const answers = <String, Object?>{
    'q_dismissal_date': KstDate(2026, 8, 15),
    'q_workplace_size': 'five_or_more',
    'q_written_notice': 'no',
    'q_want_return': 'no',
  };

  Future<ProviderContainer> openResult(
    WidgetTester tester, {
    Map<String, Object?> extra = const {},
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(container, domainId, answers: {...answers, ...extra});
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();
    return container;
  }

  Caution cautionOf(ProviderContainer container, String id) => container
      .read(domainBundleProvider)
      .requireValue
      .byId(domainId)
      .cautions
      .firstWhere((c) => c.id == id);

  group('★ 우리가 하는 일은 3개월 하나다', () {
    testWidgets('맨 위가 3개월 기한이다', (tester) async {
      final container = await openResult(tester);
      final due = container.read(dueDeadlinesProvider(domainId));

      expect(due.first.id, 'dl_relief_request');
      // 8월 15일 + 3개월 = 11월 15일인데 일요일이라 다음 날로 밀린다
      // (민법 제161조). 정답지가 보는 값은 밀기 전이다.
      expectScreenText(tester, '2026년 11월 16일');
    });

    testWidgets('재촉하지 않는다', (tester) async {
      final container = await openResult(tester);
      final deadline = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .deadlines
          .firstWhere((d) => d.id == 'dl_relief_request');

      for (final banned in const ['빨리', '서두르', '늦기 전에']) {
        expect(
          '${deadline.label} ${deadline.whatIsThis} ${deadline.appearsWhen}'
              .contains(banned),
          isFalse,
          reason: banned,
        );
      }
    });

    testWidgets('★ 기산점을 우리가 확정하지 않는다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_two_dates');

      // 조문은 「부당해고등이 있었던 날」이라고만 적었다.
      expect(card.consequence, contains('저희가 정하지 않아요'));
      expect(card.consequence, contains('그쪽부터 세는 것이 안전'));
      expect(card.verification.openPart, contains('기산점'));
      // 날짜를 하나 더 묻지 않는다. 지역 질문이 붙어 다섯이지만 날짜는 하나다.
      final intake =
          container.read(domainBundleProvider).requireValue.byId(domainId).intake;
      expect(intake.where((q) => q.type == QuestionType.date), hasLength(1));
    });
  });

  group('★ 판정하지 않는다', () {
    testWidgets('우리 말에 판정하는 문장이 없다', (tester) async {
      final container = await pumpApp(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);

      final ours = <String>[
        for (final caution in domain.cautions)
          '${caution.question} ${caution.condition} ${caution.consequence}',
        for (final deadline in domain.deadlines)
          '${deadline.label} ${deadline.whatIsThis} ${deadline.appearsWhen}',
        for (final procedure in domain.procedures)
          '${procedure.label} ${procedure.whatIsThis} ${procedure.detail ?? ''}',
        for (final question in domain.intake)
          '${question.text} ${question.whyAsk}',
      ].join(' ');

      for (final banned in const [
        '부당해고입니다',
        '부당해고예요',
        '무효입니다',
        '이길 수 있',
        '승소',
        '사장이 잘못',
        '위법입니다',
        '고소하세요',
        '하세요',
      ]) {
        expect(ours.contains(banned), isFalse, reason: '「$banned」가 있습니다');
      }
      // 걸림망이 코드에도 있다. 문자열 검사만으로 두지 않는다.
      expect(SafetyFilter.isSafe(ours), isTrue);
    });

    testWidgets('「부당한 것 같나요」류 질문이 없다', (tester) async {
      final container = await pumpApp(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);

      expect(
        domain.intake.map((q) => q.id),
        ['q_dismissal_date', 'q_workplace_size', 'q_written_notice',
         'q_want_return', 'q_workplace_area'],
      );
      for (final question in domain.intake) {
        expect(question.text, isNot(contains('부당')));
        expect(question.text, isNot(contains('억울')));
      }
    });
  });

  group('★ 돌아가기 싫어도 소용없는 게 아니다', () {
    testWidgets('제30조 제3항과 제4항이 함께 나온다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_no_return_needed');

      expect(card.legalBasis!.article, '제30조 제3항');
      // 제4항이 「계약 끝나서 소용없다」로 포기하는 자리를 막는다.
      expect(card.alsoBasis.single.text, contains('근로계약기간의 만료, 정년의 도래'));
      // 금액은 우리가 계산 못 한다.
      expect(card.consequence, contains('알지 못해요'));
    });

    testWidgets('돌아가고 싶다고 답하면 안 나온다. 답을 안 하면 나온다', (tester) async {
      final shown = await openResult(tester);
      expect(
        shown.read(cautionsProvider(domainId)).map((c) => c.id),
        contains('ct_no_return_needed'),
      );

      final wants = await openResult(tester, extra: {'q_want_return': 'yes'});
      expect(
        wants.read(cautionsProvider(domainId)).map((c) => c.id),
        isNot(contains('ct_no_return_needed')),
      );
    });
  });

  group('★ 5명이 안 되면 멈춘다', () {
    testWidgets('「적용이 안 됩니다」라고 쓰지 않는다', (tester) async {
      final container =
          await openResult(tester, extra: {'q_workplace_size': 'four_or_fewer'});
      final card = cautionOf(container, 'ct_small_workplace');

      expect(card.display, AlertDisplay.stop);
      expect(find.byType(PinnedCautionCard), findsWidgets);
      // **못 하는 것 하나에 되는 것 둘을 같이 놓는다.**
      expect(card.consequence, contains('구제신청은 이 법이 적용되지 않아요'));
      expect(card.consequence, contains('다만 이 둘은 그대로 걸려요'));
      expect(card.consequence, isNot(contains('보호가 없')));
      // [별표 1] 원문이 칩으로 붙는다.
      expect(card.alsoBasis.map((b) => b.article), contains('[별표 1]'));

      // 구제신청 기한은 4명 이하에는 안 붙는다. 예고와 보호기간은 붙는다.
      expect(container.read(dueDeadlinesProvider(domainId)), isEmpty);
      final shown = container.read(cautionsProvider(domainId)).map((c) => c.id);
      expect(shown, containsAll(['ct_advance_notice', 'ct_protected_period']));
      expect(shown, isNot(contains('ct_no_written_notice')));
    });

    testWidgets('★ 인원은 사장이 세는 것이 아니다', (tester) async {
      final container =
          await openResult(tester, extra: {'q_workplace_size': 'unknown'});
      final card = cautionOf(container, 'ct_headcount');

      // 「잘 모르겠어요」에도 낸다. 시행령 계산으로 뒤집히는 자리다.
      expect(
        container.read(cautionsProvider(domainId)).map((c) => c.id),
        contains('ct_headcount'),
      );
      expect(card.legalBasis!.text, contains('동거하는 친족인 근로자'));
      // 대신 세어 주지 않는다.
      expect(card.consequence, contains('세어 드리지는 않아요'));
    });
  });

  group('★ 상대에게 부과되는 것을 우리 돈으로 쓰지 않는다', () {
    testWidgets('「사용자에게」가 문장에 있다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_enforcement_fine');

      expect(card.condition, contains('사용자에게'));
      expect(card.consequence, contains('근로자에게 오는 돈이 아니'));
      // 「3천만원 받는다」로 읽히면 안 된다.
      expect(card.consequence, isNot(contains('3천만원을 받')));
    });
  });

  group('★ 늘려주지 않는 날짜 둘', () {
    testWidgets('재심 10일 · 소송 15일에 불변기간 근거가 붙는다', (tester) async {
      final container = await openResult(tester);
      final deadlines = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .deadlines;

      final reexamine = deadlines.firstWhere((d) => d.id == 'dl_reexamine');
      final suit = deadlines.firstWhere((d) => d.id == 'dl_admin_suit');

      expect(reexamine.alsoBasis.last.text, contains('불변기간'));
      expect(suit.alsoBasis.last.text, contains('불변기간'));
      // 낱말은 화면에 안 쓴다. 뜻만 검수 메모에 있다.
      expect(reexamine.whatIsThis, isNot(contains('불변기간')));
      expect(suit.whatIsThis, isNot(contains('불변기간')));
    });

    testWidgets('아직 안 일어난 일이라 「이런 때에」로 나온다', (tester) async {
      final container = await openResult(tester);
      final hints = container.read(deadlineHintsProvider(domainId)).join(' ');

      // 결정서·판정서를 아직 안 받았으니 날짜가 안 잡힌다. 빈 화면 대신
      // 「언제 생기는지」를 말한다.
      expect(hints, contains('10일'));
      expect(hints, contains('15일'));
      expect(container.read(dueDeadlinesProvider(domainId)), hasLength(1));
    });
  });

  group('★ 관할 기준이 사는 곳이 아니라 사업장이다', () {
    Future<String?> commissionFor(WidgetTester tester, String area) async {
      final container = await openResult(tester, extra: {'q_workplace_area': area});
      return container.read(jurisdictionResultsProvider(domainId)).single.court;
    }

    testWidgets('일하던 시·도를 고르면 이름이 나온다', (tester) async {
      expect(await commissionFor(tester, '서울특별시'), '서울지방노동위원회');
      expect(await commissionFor(tester, '경기도'), '경기지방노동위원회');
      // 인천은 여기서 단독이다. 법원 별표들에서 열려 있던 자리가 여기엔 없다.
      expect(await commissionFor(tester, '인천광역시'), '인천지방노동위원회');
    });

    testWidgets('★ 이름과 위치가 어긋나는 두 곳은 위치를 같이 낸다', (tester) async {
      // 이름만 보고 찾아가면 헤맨다.
      expect(await commissionFor(tester, '충청남도'), contains('대전에 있어요'));
      expect(await commissionFor(tester, '경상북도'), contains('대구에 있어요'));
    });

    testWidgets('★ 판본이 다른 이름도 걸린다', (tester) async {
      // 노동위 [별표 1]은 「전남광주통합특별시」라고 적는데 선택지에는 없다.
      // regions.json 의 별칭이 잇는다.
      expect(await commissionFor(tester, '광주광역시'), '전남지방노동위원회');
      expect(await commissionFor(tester, '전라남도'), '전남지방노동위원회');
    });

    testWidgets('안 고르면 이름을 짓지 않는다', (tester) async {
      final container = await openResult(tester);
      expect(
        container.read(jurisdictionResultsProvider(domainId)).single.court,
        isNull,
      );
    });
  });

  group('★ 부당해고등은 다섯이다', () {
    testWidgets('감봉·전직으로 오셔도 같은 3개월이다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_other_punishments');

      expect(card.legalBasis!.text, contains('해고, 휴직, 정직, 전직, 감봉'));
      expect(card.consequence, contains('같은 3개월'));
    });

    testWidgets('★ 이행강제금은 넷으로 갈리고 줄마다 「사용자에게」다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_enforcement_fine');

      expect(card.variants.map((v) => v.key),
          ['해고', '휴직·정직', '전직·감봉', '그 밖의 징벌']);
      for (final variant in card.variants) {
        expect(variant.detail, startsWith('사용자에게'));
      }
      // 확정액이 아니라 범위다.
      expect(card.variants.first.detail, contains('500만원 이상 3,000만원 이하'));
      expect(card.alsoBasis.map((b) => b.article), contains('[별표 3]'));
    });
  });

  group('관할 — 기준만 낸다', () {
    test('지방노동위원회 이름을 내지 않는다', () async {
      final container = await bootstrappedContainer();
      final guide = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .jurisdictionGuide;

      expect(guide!.basis.single.article, '제3조 제2항');
      // 표가 왔다. 더 이상 열려 있지 않다.
      expect(guide.verification.openPart, isNull);
    });
  });
}
