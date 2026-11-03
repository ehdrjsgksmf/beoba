import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/not_ready_view.dart';
import 'package:beoba/src/screens/result/sections/cost_section.dart';
import 'package:beoba/src/screens/result/sections/deadline_section.dart';
import 'package:beoba/src/screens/result/sections/document_section.dart';
import 'package:beoba/src/screens/result/sections/jurisdiction_section.dart';
import 'package:beoba/src/screens/result/sections/procedure_section.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/screens/result/result_screen.dart';
import 'package:beoba/src/widgets/layer_block.dart';
import 'package:engines/engines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openResult(
    WidgetTester tester, {
    Map<String, Object?> answers = completeAnswers,
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(container, kDebtRecoveryDomainId, answers: answers);
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return container;
  }

  /// 접힌 카드를 펴서 그 안을 본다. 항목별 내역·서류·관할은 여기 있다.
  Future<void> openCard(WidgetTester tester, String title) async {
    final finder = find.text(title);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('readiness 가 red 면 결과를 만들지 않는다', () {
    testWidgets('부실한 결과 대신 빠진 정보를 알려준다', (tester) async {
      final container = await openResult(
        tester,
        answers: const {'q_claim_type': 'loan'},
      );

      expect(
        container.read(interviewStateProvider(kDebtRecoveryDomainId)).readiness,
        Readiness.red,
      );

      expect(find.byType(NotReadyView), findsOneWidget);
      expect(find.text(NotReadyView.title), findsOneWidget);

      // 기한·비용을 절반만 아는 채로 늘어놓지 않는다.
      expect(find.byType(DeadlineSection), findsNothing);
      expect(find.byType(CostSection), findsNothing);
    });

    testWidgets('빠진 항목마다 되돌아갈 질문 링크가 붙는다', (tester) async {
      await openResult(tester, answers: const {'q_claim_type': 'loan'});

      expect(find.byType(RedBlockView), findsWidgets);
      expect(find.text(RedBlockView.action), findsWidgets);
    });

    testWidgets('링크를 누르면 그 질문으로 돌아간다', (tester) async {
      await openResult(tester, answers: const {'q_claim_type': 'loan'});

      await tester.tap(find.text(RedBlockView.action).first);
      await tester.pumpAndSettle();

      expect(find.byType(NotReadyView), findsNothing);
      // 인터뷰 화면으로 넘어갔다.
      expect(find.byType(ResultScreen), findsNothing);
    });
  });

  group('결과 — 엔진 4종', () {
    testWidgets('접힌 카드 안은 펴야 보인다', (tester) async {
      // 급한 사람은 갈래별 합계만 보고 나간다. 다 펼쳐 놓으면 둘 다 잃는다.
      await openResult(tester);

      expect(find.byType(CostSection), findsNothing);
      expect(find.byType(DocumentSection), findsNothing);
      expect(find.byType(JurisdictionSection), findsNothing);
      expect(find.byType(ProcedureSection), findsNothing);
      expect(find.text(ResultScreen.detail), findsOneWidget);
    });

    testWidgets('펴면 그 카드의 것이 다 있다', (tester) async {
      await openResult(tester);

      await openCard(tester, CostCard.title);
      expect(find.byType(CostSection), findsOneWidget);

      await openCard(tester, DocumentCard.title);
      expect(find.byType(DocumentSection), findsOneWidget);

      await openCard(tester, JurisdictionCard.title);
      expect(find.byType(JurisdictionSection), findsOneWidget);

      await openCard(tester, ProcedureCard.title);
      expect(find.byType(ProcedureSection), findsOneWidget);
    });

    testWidgets('판단하지 않는다는 고지가 머리에 붙는다', (tester) async {
      await openResult(tester);
      expect(find.text(ResultScreen.disclaimer), findsOneWidget);
    });

    testWidgets('갈래는 둘이고, 찾은 것만 이름을 낸다', (tester) async {
      // **표가 들어왔다**([별표 3]·[별표 7]). 이름을 낼 수 있게 됐지만
      // 갈래를 우리가 고르지는 않는다 — 둘을 나란히 낸다(DECISIONS 139번).
      final container = await openResult(tester);
      await openCard(tester, JurisdictionCard.title);

      final results =
          container.read(jurisdictionResultsProvider(kDebtRecoveryDomainId));
      expect(results, hasLength(2));

      final byLabel = {for (final r in results) r.label: r};
      // 서울특별시 종로구 — 소송이면 서울중앙지방법원.
      expect(byLabel['그 밖의 소송이면']!.court, '서울중앙지방법원');
      // 서울에는 시·군법원이 없다. **없는 것을 지어내지 않는다.**
      expect(byLabel['지급명령·조정·소액사건이면']!.court, isNull);
    });

    testWidgets('금액은 포매터를 거쳐 나온다', (tester) async {
      await openResult(tester);

      // 청구액 5,000만원 · 소송 · 종이 → 인지대 230,000 + 송달료 165,000
      expect(find.text('395,000원'), findsWidgets);
    });

    testWidgets('갈래마다 따로 낸다 — 하나의 숫자로 내지 않는다', (tester) async {
      final container = await openResult(tester);
      final scenarios =
          container.read(costScenariosProvider(kDebtRecoveryDomainId));

      // 어느 절차를 밟을지 묻는 질문이 없다. 그래서 한 벌만 계산하면 소장·종이
      // 금액이 모든 사람에게 나간다 — 지급명령·전자소송의 11배다.
      expect(scenarios, hasLength(6));

      final totals = {
        for (final s in scenarios) '${s.label} ${s.option}': s.result.total,
      };
      expect(totals, {
        '지급명령으로 하면 종이로 낼 때': 89000, // 인지 23,000 + 송달 66,000
        '지급명령으로 하면 전자소송으로 낼 때': 86700, // 인지 20,700 + 송달 66,000
        // 민사조정은 인지가 지급명령과 같은 1/10 인데 **전자 감액 뒤에 100원을
        // 버린다**(민사조정규칙 제3조 제2항). 송달료는 민사조정사건(머) 5회다.
        '민사조정으로 하면 종이로 낼 때': 78000, // 인지 23,000 + 송달 55,000
        '민사조정으로 하면 전자소송으로 낼 때': 75700, // 인지 20,700 + 송달 55,000
        '소송으로 하면 종이로 낼 때': 395000, // 인지 230,000 + 송달 165,000
        '소송으로 하면 전자소송으로 낼 때': 372000, // 인지 207,000 + 송달 165,000
      });

      // 네 숫자가 **화면에** 있어야 한다. 계산만 맞고 안 보이면 없는 것과 같다.
      for (final total in totals.values) {
        expect(find.text(formatWon(total)), findsWidgets, reason: '$total원');
      }
      // 가정이라는 사실을 말한다. 사용자가 고른 것이 아니다.
      expect(scenarios.every((s) => s.isAssumption), isTrue);
    });

    testWidgets('못 쓰는 절차의 금액은 내밀지 않는다', (tester) async {
      // 민사소송법 제462조 단서 — 「공시송달 외의 방법으로 송달할 수 있는
      // 경우에 한한다」. 상대 주소를 아예 모르면 지급명령을 쓸 수 없다.
      // **밟을 수 없는 절차의 비용을 계산해 보여주면 그 절차를 권하는 것이 된다.**
      final container = await openResult(
        tester,
        answers: {...completeAnswers, 'q_debtor_address_known': 'no'},
      );
      final scenarios =
          container.read(costScenariosProvider(kDebtRecoveryDomainId));

      final ids = scenarios.map((s) => s.id);
      expect(ids, isNot(contains('cs_payment_order_paper')));
      expect(ids, isNot(contains('cs_payment_order_efiling')));
      // 민사조정도 같다. 다만 근거 조문이 다르다 — 민사조정규칙 제2조의2 다.
      expect(ids, isNot(contains('cs_mediation_paper')));
      expect(ids, isNot(contains('cs_mediation_efiling')));
      // 소송 갈래는 그대로 남는다.
      expect(ids, contains('cs_lawsuit_paper'));

      // 절차 목록에서도 빠진다.
      final procedures =
          container.read(proceduresProvider(kDebtRecoveryDomainId)).map((p) => p.id);
      expect(procedures, isNot(contains('proc_payment_order')));
      expect(procedures, isNot(contains('proc_mediation')));
    });

    testWidgets('앞칸을 밟아도 인지를 두 번 내지 않는다', (tester) async {
      // 사다리 앞칸을 시도할 값어치를 만드는 사실이다. 근거가 함께 붙는다.
      await openResult(tester);
      await openCard(tester, ProcedureCard.title);

      expect(find.textContaining('인지를 두 번 내지 않아요'), findsOneWidget);
      expect(find.text('민사소송 등 인지법 제7조 제3항'), findsWidgets);
      expect(find.text('민사조정법 제36조 제2항'), findsWidgets);
    });

    testWidgets('사라진 절차가 왜 없는지 말한다', (tester) async {
      // 조용히 사라지면 사용자는 왜 없는지 모른다.
      final container = await openResult(
        tester,
        answers: {...completeAnswers, 'q_debtor_address_known': 'no'},
      );

      expect(
        container.read(cautionsProvider(kDebtRecoveryDomainId)).map((c) => c.id),
        contains('ct_payment_order_needs_address'),
      );
      expect(find.text('상대방 주소를 모르시나요?'), findsOneWidget);
    });

    testWidgets('예전 주소만 알면 지급명령은 남는다', (tester) async {
      // 그 주소로 보내 볼 수는 있다. 실패했을 때 어떻게 되는지까지는
      // 우리가 판단하지 않는다.
      final container = await openResult(
        tester,
        answers: {...completeAnswers, 'q_debtor_address_known': 'partial'},
      );

      final ids = container
          .read(costScenariosProvider(kDebtRecoveryDomainId))
          .map((s) => s.id);
      expect(ids, contains('cs_payment_order_paper'));
      expect(ids, contains('cs_mediation_paper'));
    });

    testWidgets('소액사건은 갈래가 아니라 소가로 갈린다', (tester) async {
      // 사용자가 고르는 것이 아니다. 제소한 때의 소송목적의 값으로 정해진다.
      // 인지대는 소액이든 아니든 같은 산식이고 **달라지는 것은 송달료 회차뿐**이다.
      // 경계는 「초과하지 아니하는」 이라 3,000만원 **정각은 소액**이다.
      final container = await openResult(
        tester,
        answers: {
          ...completeAnswers,
          'q_amount': 30000000, // not-a-legal-number: 테스트 입력값
        },
      );
      final byId = {
        for (final s in container.read(costScenariosProvider(kDebtRecoveryDomainId)))
          s.id: s,
      };

      // 2명 × 10회 × 5,500원. 소송 15회였다면 165,000원이다.
      expect(
        byId['cs_lawsuit_paper']!.result.lineById('cost_service_fee')!.amount,
        110000,
      );
      // 지급명령은 소가와 무관하게 독촉사건 6회 그대로다.
      expect(
        byId['cs_payment_order_paper']!
            .result
            .lineById('cost_service_fee')!
            .amount,
        66000,
      );
    });

    testWidgets('전자소송이어도 송달료는 안 줄어든다', (tester) async {
      // 전자독촉사건(차전)도 독촉사건(차)과 같은 6회다. 깎이는 것은 인지대뿐이다.
      // 「전자면 다 싸겠지」로 고치는 사람이 나온다. 그래서 잠가 둔다.
      final container = await openResult(tester);
      final byId = {
        for (final s in container.read(costScenariosProvider(kDebtRecoveryDomainId)))
          s.id: s,
      };

      int fee(String id) =>
          byId[id]!.result.lineById('cost_service_fee')!.amount;

      expect(fee('cs_payment_order_efiling'), fee('cs_payment_order_paper'));
      expect(fee('cs_lawsuit_efiling'), fee('cs_lawsuit_paper'));
    });

    testWidgets('안내 금액은 법정 최저액 아래로 내려가지 않는다', (tester) async {
      // 인지법 제16조 뒤에는 끝수 준용이 없어 조문대로면 900원이다. 그대로
      // 안내했다가 법원이 1,000원을 요구하면 **보정 명령**이 온다. 100원 더 내는
      // 쪽이 낫다. 조문 해석(amount)과 안전 여유(guidedAmount)는 다른 층이다.
      final container = await openResult(
        tester,
        answers: {
          ...completeAnswers,
          'q_amount': 100000, // not-a-legal-number: 테스트 입력값
        },
      );
      final scenario = container
          .read(costScenariosProvider(kDebtRecoveryDomainId))
          .firstWhere((s) => s.id == 'cs_lawsuit_efiling');
      final stamp = scenario.result.lineById('cost_stamp_fee')!;

      expect(stamp.amount, 900, reason: '조문대로의 값은 건드리지 않는다');
      expect(stamp.guidedAmount, 1000, reason: '화면에 낼 값');
      expect(scenario.result.total, 110900);
      expect(scenario.result.guidedTotal, 111000);

      // 화면에는 올린 값이 나간다.
      expect(find.text(formatWon(111000)), findsWidgets);
      expect(find.text(formatWon(110900)), findsNothing);
    });

    testWidgets('송달료가 줄째로 사라지지 않는다', (tester) async {
      final container = await openResult(tester);
      final scenarios =
          container.read(costScenariosProvider(kDebtRecoveryDomainId));

      // 절차를 아무도 안 채우면 `perUnit` 계산식이 회수를 못 찾아 **줄 자체가
      // 빠진다.** 빠진 줄은 화면에 자리조차 남기지 않아 사용자는 송달료라는 것이
      // 있다는 사실을 모른다. 실제로 그러고 있었다.
      for (final scenario in scenarios) {
        expect(
          scenario.result.lineById('cost_service_fee'),
          isNotNull,
          reason: scenario.id,
        );
      }
    });
  });
}
