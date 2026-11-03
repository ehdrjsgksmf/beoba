import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/detected/detected_screen.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/result/sections/pinned_caution_card.dart';
import 'package:beoba/src/screens/result/sections/cost_section.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:domain_data/domain_data.dart'
    show AlertDisplay, Caution, QuestionType;
import 'package:engines/engines.dart'
    show JurisdictionResult, VerificationStatus;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 빚 갚기가 어려울 때 — **채무자 흐름의 마지막 칸.**
///
/// 이 분야는 감정이 제일 무겁다. 위기 경보가 여기서 제일 많이 걸린다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const domainId = 'debt_relief';
  const answers = <String, Object?>{'q_creditor_count': 5};

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

  /// 이 분야가 화면에 내는 **우리 말** 전부.
  String oursOf(ProviderContainer container) {
    final domain =
        container.read(domainBundleProvider).requireValue.byId(domainId);
    return [
      for (final caution in domain.cautions)
        '${caution.question} ${caution.condition} ${caution.consequence}',
      for (final procedure in domain.procedures)
        '${procedure.label} ${procedure.whatIsThis} ${procedure.detail ?? ''} '
            '${procedure.caution ?? ''}',
      for (final question in domain.intake)
        '${question.text} ${question.whyAsk}',
    ].join(' ');
  }

  group('★ 위기 경보가 분야보다 먼저다', () {
    testWidgets('죽고 싶다고 적으면 위기 화면이 덮는다', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byType(TextField).first,
        '빚이 너무 많아서 갚을 수가 없어요. 죽고 싶습니다',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();

      // 분야는 걸렸지만(「빚이 너무」·「갚을 수가 없」) 그것보다 먼저다.
      expect(find.text(DetectedScreen.title), findsNothing);
      expectScreenText(tester, '109');
    });

    testWidgets('걸릴 낱말이 없으면 확인 카드로 온다', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byType(TextField).first,
        '빚이 너무 많아서 갚을 수가 없어요',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();

      expect(find.text(DetectedScreen.title), findsOneWidget);
      expectScreenText(tester, '빚 갚기가 어려울 때');
    });
  });

  group('★ 면책되지 않는 것을 먼저 말한다', () {
    testWidgets('멈춤 카드로 뜨고 다섯이 앞에 나온다', (tester) async {
      await openResult(tester);

      expect(find.byType(PinnedCautionCard), findsWidgets);
      expectScreenText(tester, '면책을 받아도 없어지지 않는 것이 있어요');
      // 세금 · 벌금 · 고의 손해 · 임금과 퇴직금 · 양육비.
      for (final kept in const ['세금', '벌금', '임금과 퇴직금', '양육비']) {
        expectScreenText(tester, kept);
      }
    });

    testWidgets('아홉 호는 접힘 안 원문에만 있다', (tester) async {
      final container = await openResult(tester);
      final caution = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .cautions
          .firstWhere((c) => c.id == 'ct_not_discharged');

      expect(caution.display, AlertDisplay.stop);
      // 원문에는 아홉이 다 있다.
      expect(caution.legalBasis!.text, contains('7. 채무자가 악의로'));
      // 우리 말에는 다섯만.
      expect(caution.consequence, isNot(contains('임치금')));
    });
  });

  group('★ 원칙과 예외의 어순', () {
    testWidgets('허가가 원칙이라는 말이 먼저 나온다', (tester) async {
      final container = await openResult(tester);
      final caution = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .cautions
          .firstWhere((c) => c.id == 'ct_discharge_principle');

      // 조건절이 먼저 그려진다. 거기에 「허가하여야 한다」가 있다.
      expect(caution.condition, contains('허가하여야 한다'));

      final ours = caution.consequence;
      // 「허가가 원칙」이 「도박」보다 앞이다.
      expect(ours.indexOf('허가가 원칙'), lessThan(ours.indexOf('도박')));
    });

    testWidgets('제1항과 제2항이 함께 나온다', (tester) async {
      await openResult(tester);
      expectScreenText(tester, '채무자 회생 및 파산에 관한 법률 제564조 제1항');
      expectScreenText(tester, '채무자 회생 및 파산에 관한 법률 제564조 제2항');
      // 정하는 것은 법원이다.
      expectScreenText(tester, '정하는 것은 법원이에요');
    });
  });

  group('우리 말에 없어야 하는 것', () {
    testWidgets('단정도 권유도 실무 이야기도 없다', (tester) async {
      final container = await pumpApp(tester);
      final ours = oursOf(container);

      for (final banned in const [
        '없어져요',
        '하세요',
        '나아요',
        '신용점수',
        '불이익',
        '얼마나 되세요',
      ]) {
        expect(ours.contains(banned), isFalse, reason: '「$banned」가 있습니다');
      }
    });

    testWidgets('금액을 묻지 않는다 — 숫자만 보여준다', (tester) async {
      final container = await pumpApp(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);

      // 묻는 것은 셋뿐이고 **금액을 묻는 칸은 하나도 없다.**
      expect(
        domain.intake.map((q) => q.id),
        ['q_creditor_count', 'q_my_area', 'q_my_city'],
      );
      expect(
        domain.intake.map((q) => q.type),
        isNot(contains(QuestionType.money)),
      );
      // 15억/10억은 조문 그대로 보여준다.
      final amount = domain.cautions
          .firstWhere((c) => c.id == 'ct_eligible_amount');
      expect(amount.consequence, contains('15억원'));
      expect(amount.consequence, contains('10억원'));
    });
  });

  group('비용 — 채권자 수로 늘어난다', () {
    testWidgets('개인회생 10회 + 5 × 8회', (tester) async {
      final container = await openResult(tester);
      final scenarios = container.read(costScenariosProvider(domainId));
      final byId = {for (final s in scenarios) s.id: s};

      // 송달료 (10 + 5×8) × 5,500 = 275,000. 인지 30,000 을 더해 305,000.
      expect(byId['cs_rehabilitation']!.result.total, 305000);
      // 파산은 (10 + 5×4) × 5,500 = 165,000. 인지는 근거를 못 찾아 안 낸다.
      expect(byId['cs_bankruptcy']!.result.total, 165000);
      // 면책은 (10 + 5×3) × 5,500 = 137,500.
      expect(byId['cs_discharge']!.result.total, 137500);
    });

    testWidgets('파산 인지는 안 낸다 — 근거를 못 찾았다', (tester) async {
      final container = await openResult(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);

      final bankruptcy =
          domain.procedures.firstWhere((p) => p.id == 'proc_bankruptcy');
      expect(bankruptcy.caution, contains('전부가 아닐 수 있어요'));
      expect(bankruptcy.verification.openPart, contains('본인 파산 신청 인지액'));
      // 인지대 줄은 개인회생 갈래에만 붙는다.
      expect(domain.costs.firstWhere((c) => c.id == 'cost_stamp_fee').showIf, isNotNull);
    });

    testWidgets('★ 예납 항목이 넷인데 둘만 세지 않는다', (tester) async {
      final container = await openResult(tester);
      final line = container
          .read(costScenariosProvider(domainId))
          .firstWhere((s) => s.id == 'cs_rehabilitation')
          .result
          .lineById('cost_officer_fee');

      // 규칙 제87조 제1항이 예납 항목을 넷으로 못박는다. 3호가 회생위원 보수다.
      expect(line, isNotNull);
      expect(line!.amountKnown, isFalse);
      // 0원으로 세지 않는다 — 0원이라고 쓰면 「안 든다」가 된다.
      expect(line.amount, 0);
      expect(line.verification, VerificationStatus.needsCheck);
      expect(line.openPart, contains('확정액 아님'));
      // 합계는 인지 3만 + 송달료 27만5천 그대로다.
      expect(
        container
            .read(costScenariosProvider(domainId))
            .firstWhere((s) => s.id == 'cs_rehabilitation')
            .result
            .total,
        305000,
      );
    });

    testWidgets('화면에 0원이 아니라 모른다고 쓴다', (tester) async {
      await openResult(tester);
      await tester.ensureVisible(find.text(CostCard.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CostCard.title));
      await tester.pumpAndSettle();

      expectScreenText(tester, '회생위원 보수');
      expectScreenText(tester, CostSection.amountUnknown);
    });

    testWidgets('★ 누구에게 붙는지를 우리가 판정하지 않는다', (tester) async {
      final container = await openResult(tester);
      final card = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .cautions
          .firstWhere((c) => c.id == 'ct_rehab_officer');

      // 제9조의6 제1항은 「위촉되어 있는 회생법원에서는」이 앞에 붙는다.
      // 「영업으로 버시면 반드시 붙습니다」로 쓰면 틀린다.
      expect(card.condition, contains('위촉돼 있으면'));
      expect(card.consequence, isNot(contains('반드시')));
      expect(card.consequence, contains('정하는 것은 법원이에요'));
      // 법원 직원이면 보수가 없다는 항을 함께 낸다. 빼면 「무조건 붙는다」다.
      expect(card.alsoBasis.single.text, contains('보수를 지급하지 아니하는'));
    });

    testWidgets('비용 카드 아래에 소송구조가 붙는다', (tester) async {
      final container = await openResult(tester);
      expect(find.text(CostCard.title), findsOneWidget);
      expect(container.read(legalAidProvider(domainId)), isNotNull);
    });
  });

  group('파산 예규 — 단서가 오해를 막는다', () {
    Caution cautionOf(ProviderContainer container, String id) => container
        .read(domainBundleProvider)
        .requireValue
        .byId(domainId)
        .cautions
        .firstWhere((c) => c.id == id);

    testWidgets('★ 면책까지 가면 통보가 가지 않는다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_registration_notice');

      // 제566조 카드가 「다 없어지지는 않는다」이면 이쪽은 「끝까지 가면
      // 남지 않는다」다. 겁만 주고 끝내지 않는다.
      expect(card.legalBasis!.text, contains('한하여 통보한다'));
      expect(card.consequence, contains('통보가 가지 않는다'));
      // 조문에 없는 말은 안 쓴다.
      for (final banned in const ['신용점수', '불이익', '기각']) {
        expect(card.consequence.contains(banned), isFalse, reason: banned);
      }
    });

    testWidgets('★ 통보가 둘이라는 것을 감추지 않는다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_registration_notice');

      // 제6조만 내면 「아무 데도 통보 안 간다」로 읽힌다. 제5조는 반대로
      // **면책까지 가야** 간다.
      expect(card.alsoBasis.single.article, '제5조 제1항');
      expect(card.consequence, contains('한국신용정보원'));
      // 그 뒤에 무엇이 되는지는 이 예규에 없다. 거기서 멈춘다.
      expect(card.consequence, contains('적혀 있지 않아요'));
    });

    testWidgets('★ 예납금 자리를 비워 두지 않는다', (tester) async {
      final container = await openResult(tester);
      final card = cautionOf(container, 'ct_bankruptcy_deposit');

      // 「비용 카드에 인지대와 송달료뿐」이 「그게 전부」라는 뜻이 아니다.
      expect(card.consequence, contains('500만원을 넘을 수 없다'));
      expect(card.verification.openPart, contains('예납금 액수'));
      // 상한을 금액처럼 내면 「500만원이 든다」로 읽힌다.
      expect(card.consequence, isNot(contains('500만원이 들어')));
      expect(container.read(costResultProvider(domainId)).lines
          .map((l) => l.id), isNot(contains('cost_deposit')));
      // 파산관재인을 두는 쪽으로 가는 조문이 함께 붙는다.
      expect(card.alsoBasis.single.article, '제2조의3');
    });

    testWidgets('★ 법원의 처리기간은 기한이 아니다', (tester) async {
      final container = await openResult(tester);
      final procedure = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .procedures
          .firstWhere((p) => p.id == 'proc_bankruptcy');

      expect(procedure.courtTerms.map((t) => t.id),
          ['cterm_declare', 'cterm_hearing', 'cterm_discharge']);
      // Deadline 이 아니다 — 세는 것도 D-day 도 없다.
      expect(container.read(dueDeadlinesProvider(domainId)), isEmpty);
      for (final term in procedure.courtTerms) {
        expect(term.within, isNot(contains('D-')));
      }
    });

    testWidgets('★ 예납을 안 하면 14일 규칙이 안 걸린다', (tester) async {
      final container = await openResult(tester);
      final term = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .procedures
          .firstWhere((p) => p.id == 'proc_bankruptcy')
          .courtTerms
          .firstWhere((t) => t.id == 'cterm_discharge');

      // 눈금만 보여주면 「가만히 있어도 굴러간다」로 읽힌다.
      expect(term.exceptWhen, contains('절차비용을 예납하지 않은 때'));
      // 다섯 호를 다 낸다. 골라 내면 그건 우리가 고른 것이다.
      expect(term.exceptWhen, hasLength(5));
      expect(term.legalBasis!.text, contains('5. 기타 특별한 사정이 있는 경우'));
    });

    testWidgets('사건부호가 송달료 산식으로 이어진다', (tester) async {
      final container = await openResult(tester);
      final cost = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .costs
          .firstWhere((c) => c.id == 'cost_service_fee');

      // [별표 1]은 「하단」·「하면」이라고만 적는다. 그 부호가 무엇인지는
      // 예규 제2조 제2항에 있다.
      final chip =
          cost.alsoBasis.firstWhere((b) => b.article == '제2조 제2항');
      expect(chip.text, contains('하단'));
      expect(chip.text, contains('하면'));
    });
  });

  group('관할 — 이름을 낸다. 다만 표에 없는 지역은 비운다', () {
    Future<List<JurisdictionResult>> venue(
      WidgetTester tester,
      Map<String, Object?> where,
    ) async {
      final container = await openResult(tester, extra: where);
      return container.read(jurisdictionResultsProvider(domainId));
    }

    testWidgets('[별표 10]이 이름을 낸다', (tester) async {
      // 시·도 한 줄로 적힌 행이다. 시·군으로 풀지 않았다.
      expect((await venue(tester, {'q_my_area': '충청남도'})).single.court,
          '대전회생법원');
      expect((await venue(tester, {'q_my_area': '서울특별시'})).single.court,
          '서울회생법원');
    });

    testWidgets('★ 경기도는 시·군을 더 물어야 갈린다', (tester) async {
      // 19곳은 수원회생법원이고 12곳은 어느 회생법원에도 안 적혀 있다.
      final suwon = await venue(
        tester,
        {'q_my_area': '경기도', 'q_my_city': '수원시'},
      );
      expect(suwon.single.court, '수원회생법원');

      final uijeongbu = await venue(
        tester,
        {'q_my_area': '경기도', 'q_my_city': '의정부시'},
      );
      expect(uijeongbu.single.court, isNull);
    });

    testWidgets('★ 표에 없는 지역은 이름을 안 낸다', (tester) async {
      for (final area in const ['인천광역시', '강원특별자치도']) {
        expect((await venue(tester, {'q_my_area': area})).single.court, isNull,
            reason: area);
      }
    });

    testWidgets('아직 안 고르셨으면 억지로 내지 않는다', (tester) async {
      expect((await venue(tester, const {})).single.court, isNull);
    });
  });

  group('★ 「…에도 신청할 수 있다」는 한 곳을 더 여는 조문이다', () {
    Future<List<Caution>> extrasFor(
      WidgetTester tester,
      String area,
    ) async {
      final container = await openResult(tester, extra: {'q_my_area': area});
      return container.read(jurisdictionGuideProvider(domainId))!.branches;
    }

    testWidgets('걸린 지역에만 한 줄이 뜬다', (tester) async {
      expect((await extrasFor(tester, '충청북도')).map((b) => b.id),
          ['jg_extra_daejeon']);
      expect((await extrasFor(tester, '경상남도')).map((b) => b.id),
          ['jg_extra_busan']);
      expect((await extrasFor(tester, '제주특별자치도')).map((b) => b.id),
          ['jg_extra_gwangju']);
    });

    testWidgets('안 걸린 지역에는 아무 줄도 안 나온다', (tester) async {
      // 「없습니다」라고 쓰지 않는다. 줄이 없으면 없는 것이다.
      expect(await extrasFor(tester, '충청남도'), isEmpty);
      expectNoScreenText(tester, '없습니다');
    });

    testWidgets('「내야 합니다」가 아니라 「에도」다', (tester) async {
      for (final area in const ['충청북도', '경상남도', '제주특별자치도']) {
        final branch = (await extrasFor(tester, area)).single;
        expect(branch.consequence, contains('에도 낼 수 있어요'));
        expect(branch.consequence, isNot(contains('내야')));
      }
    });

    testWidgets('★ 강원은 파산·개인회생에만 걸린다', (tester) async {
      final branch = (await extrasFor(tester, '강원특별자치도')).single;
      expect(branch.id, 'jg_extra_gangneung');
      expect(branch.consequence, contains('춘천지방법원 강릉지원'));
      // 조문에 회생·간이회생이 빠져 있다. 넓게 옮기지 않는다.
      expect(branch.consequence, contains('회생과 간이회생은'));
      expect(branch.legalBasis!.text, contains('파산선고 또는 개인회생절차개시'));
    });
  });

  test('못 내는 지역을 openPart 에 적어 둔다', () async {
    final container = await bootstrappedContainer();
    final guide = container
        .read(domainBundleProvider)
        .requireValue
        .byId(domainId)
        .jurisdictionGuide;

    expect(guide!.verification.openPart, contains('회생법원이 없는 지역'));
    // 「회생법원이 없으면 지방법원 본원」이라는 규정은 원문을 못 봤다.
    expect(guide.lookupNote, isNot(contains('지방법원')));
  });
}
