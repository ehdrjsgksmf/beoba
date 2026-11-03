import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/interview/interview_screen.dart';
import 'package:beoba/src/screens/interview/redirect_notice.dart';
import 'package:beoba/src/screens/result/result_screen.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/screens/result/sections/today_card.dart';
import 'package:beoba/src/screens/summary/summary_screen.dart';
import 'package:domain_data/domain_data.dart' show QuestionType;
import 'package:engines/engines.dart' show CostResult, ScenarioCostResult;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **홈에서 결과까지 손으로 걸어간다.**
///
/// 445건이 통과하는 동안 지급명령을 받은 사람은 아무 기한도 못 보고 있었다.
/// 엔진에 값을 먹이는 테스트는 전부 초록이었기 때문이다 — 화면을 거쳐 결과까지
/// 간 테스트가 **하나도 없었다**(DECISIONS 123번).
///
/// 여기서 보는 것은 둘뿐이다. **결과 화면에 닿았는가**, 그리고 **맨 위가
/// 무엇인가.** 값이 맞는지는 도메인 JSON 의 `tests[]` 가 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 홈 → 분야 선택 → 첫 질문.
  Future<ProviderContainer> enter(WidgetTester tester, String domainName) async {
    final container = await pumpApp(tester);
    await tester.tap(find.text(HomeScreen.start));
    await tester.pumpAndSettle();

    // 첫 화면에는 묶음 줄만 선다(DECISIONS 237번). 이름으로 분야를 찾아
    // 그 묶음을 거쳐 들어간다.
    final bundle = container.read(domainBundleProvider).requireValue;
    final domain =
        bundle.selectable.firstWhere((d) => d.name == domainName);
    await pickDomainFromList(tester, domain.id);
    return container;
  }

  /// 지금 화면에 떠 있는 질문. 답한 것에서 파생된다.
  String? currentQuestionId(ProviderContainer container, String domainId) {
    final step = container.read(currentStepProvider(domainId));
    if (step == null) return null;
    return questionAtStep(
      container.read(applicableQuestionsProvider(domainId)),
      step,
    )?.id;
  }

  /// **위젯을 실제로 누른다.** 프로바이더에 값을 심지 않는다.
  ///
  /// 심으면 「닿을 수 있는가」를 묻지 않게 된다 — 그게 이번에 뚫린 자리다.
  Future<void> walk(
    WidgetTester tester,
    ProviderContainer container,
    String domainId,
    Map<String, String> picks,
  ) async {
    for (var guard = 0; guard < 30; guard++) {
      if (find.byType(SummaryScreen).evaluate().isNotEmpty) return;
      if (find.text(RedirectNotice.title).evaluate().isNotEmpty) return;

      final id = currentQuestionId(container, domainId);
      if (id == null) return;

      final question = container
          .read(applicableQuestionsProvider(domainId))
          .firstWhere((q) => q.id == id);

      switch (question.type) {
        case QuestionType.money:
          await tester.enterText(
            find.byType(TextField).first,
            '5000000', // not-a-legal-number: 테스트 입력값
          );
        case QuestionType.date:
          // 기준일은 2026년 8월 15일이라 1주일 전은 8월 8일이다.
          await tester.tap(find.text(picks[id] ?? '1주일 전'));
        case QuestionType.number:
          await tester.enterText(find.byType(TextField).first, '1');
        case QuestionType.text:
          await tester.enterText(
            find.byType(TextField).first,
            picks[id] ?? '서울특별시 종로구',
          );
        case QuestionType.single:
        case QuestionType.multi:
          final label = picks[id];
          expect(label, isNotNull, reason: '$id 에 고를 답을 정해 주세요');
          await tester.tap(find.text(label!));
      }
      await tester.pumpAndSettle();

      final next = find.text(InterviewScreen.next);
      await tester.tap(next.evaluate().isEmpty
          ? find.text(InterviewScreen.save)
          : next);
      await tester.pumpAndSettle();
    }
    fail('질문이 30개를 넘었습니다 — 흐름이 돌고 있습니다');
  }

  /// 정리 카드에서 결과로.
  Future<void> toResult(WidgetTester tester) async {
    expect(
      find.byType(SummaryScreen),
      findsOneWidget,
      reason: '정리 카드에 닿지 못했습니다',
    );
    await tester.tap(find.text(SummaryScreen.next));
    await tester.pumpAndSettle();
    expect(
      find.byType(ResultScreen),
      findsOneWidget,
      reason: '결과 화면에 닿지 못했습니다',
    );
  }

  /// 맨 위 카드에 이 말이 실렸는가.
  ///
  /// **순서를 좌표로 재지 않는다.** 「오늘 할 일」 카드가 맨 위라는 것은
  /// result_order_test 가 따로 잠근다. 여기서는 그 카드에 무엇이 실렸는지만 본다.
  void expectOnTopCard(WidgetTester tester, String text) => expect(
        find.descendant(
          of: find.byType(TodayCard),
          matching: find.text(text),
        ),
        findsOneWidget,
        reason: '맨 위 카드에 「$text」이(가) 없습니다',
      );

  group('받을 쪽', () {
    testWidgets('빌려준 돈 · 서류 없음 — 결과 화면에 닿는다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 받아야 할 돈입니다',
        'q_court_document': '없습니다',
        'q_claim_type': '빌려준 돈',
        'q_evidence_written': '차용증·계약서가 있습니다',
        'q_transfer_record': '계좌이체 내역이 있습니다',
        'q_demanded': '아직 요구하지 않았습니다',
        'q_debtor_response': '연락이 되지 않습니다',
        'q_debtor_address_known': '알고 있습니다',
        'q_debtor_assets': '아는 게 없습니다',
      });
      await toResult(tester);
    });

    testWidgets('보증금 — 준비 중 안내로 끊긴다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 받아야 할 돈입니다',
        'q_court_document': '없습니다',
        'q_claim_type': '전세·월세 보증금',
      });

      expect(find.text(RedirectNotice.title), findsOneWidget);
      expect(find.byType(ResultScreen), findsNothing);
    });
  });

  group('★ 갚을 쪽 — 여기가 통째로 막혀 있었다', () {
    testWidgets('지급명령을 받았다 — 맨 위가 이의신청이다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 갚아야 할 돈입니다',
        'q_debtor_situation': '법원이나 기관에서 서류를 받았어요',
        'q_court_document': '지급명령을 받았습니다',
      });
      await toResult(tester);

      // **2주를 놓치면 확정된다.** 이 한 줄이 이번 작업의 전부다.
      expectOnTopCard(tester, '지급명령 이의신청');
    });

    testWidgets('소장을 받았다 — 맨 위가 답변서다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 갚아야 할 돈입니다',
        'q_debtor_situation': '법원이나 기관에서 서류를 받았어요',
        'q_court_document': '법원에서 소장을 받았습니다',
      });
      await toResult(tester);

      expectOnTopCard(tester, '답변서 제출');
    });

    testWidgets('압류가 개정 전이면 금액이 안 나간다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 갚아야 할 돈입니다',
        'q_debtor_situation': '통장이나 월급이 압류됐어요',
        'q_seizure_when': '그 전이에요',
        'q_court_document': '없습니다',
      });
      await toResult(tester);

      // **그때 판본을 갖고 있지 않다.** 찍어서 큰 금액이 나가는 쪽이 훨씬 위험하다.
      expectScreenText(tester, '그때는 정해진 금액이 지금과 달랐어요');
      expectNoScreenText(tester, '250만원');
    });

    testWidgets('압류 시점을 모르면 금액이 안 나간다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 갚아야 할 돈입니다',
        'q_debtor_situation': '통장이나 월급이 압류됐어요',
        'q_seizure_when': '잘 모르겠어요',
        'q_court_document': '없습니다',
      });
      await toResult(tester);

      expectNoScreenText(tester, '250만원');
    });

    testWidgets('압류됐다 — 결과에 닿고 압류금지가 실린다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 갚아야 할 돈입니다',
        'q_debtor_situation': '통장이나 월급이 압류됐어요',
        'q_seizure_when': '2026년 2월 이후예요',
        'q_court_document': '없습니다',
      });
      await toResult(tester);

      expectScreenText(tester, '압류가 들어와도');
      // **★ 합쳐서 250만원이다.** 각각이면 750만원이 된다.
      expectScreenText(tester, '모두 합쳐서 250만원까지');
      // 계산해 주지 않는다 — 월급을 묻지 않았다.
      expectNoScreenText(tester, '월급이 얼마');
    });
  });

  group('빈 섹션', () {
    /// **빈 칸은 0으로 읽힌다.** 항목이 없는 것과 값이 미정인 것은 다르다.
    testWidgets('갚을 쪽에는 비용·서류·관할·절차 카드가 아예 없다', (tester) async {
      final container = await enter(tester, '떼인 돈 받기');
      await walk(tester, container, kDebtRecoveryDomainId, const {
        'q_role': '제가 갚아야 할 돈입니다',
        'q_debtor_situation': '통장이나 월급이 압류됐어요',
        'q_seizure_when': '2026년 2월 이후예요',
        'q_court_document': '없습니다',
      });
      await toResult(tester);

      for (final title in const [
        CostCard.title,
        DocumentCard.title,
        JurisdictionCard.title,
        ProcedureCard.title,
      ]) {
        expect(find.text(title), findsNothing, reason: '$title 이 빈 채로 남았습니다');
      }
      // 「아직」이라는 말도 함께 사라져야 한다. 영영 안 끝나는 약속이다.
      expectNoScreenText(tester, '아직 없어요');
      expectNoScreenText(tester, '아직 추릴 수 없어요');
    });

    testWidgets('항목은 있고 값이 미정이면 「아직」이 살아 있다', (tester) async {
      // 답을 더 하면 채워지는 자리다. 여기서는 그 말이 정직하다.
      await pumpWidgetOnly(
        tester,
        const CostCard(
          scenarios: [
            ScenarioCostResult(
              id: 'cs_probe',
              label: '소송으로 하면',
              assumed: {},
              result: CostResult(lines: [], total: 0),
            ),
          ],
        ),
      );

      expect(find.text(CostCard.title), findsOneWidget);
      expectScreenText(tester, CostCard.empty);
    });
  });

  group('못 받은 임금 — 세 번째 분야', () {
    testWidgets('그만둔 사람은 맨 위가 14일 기한이다', (tester) async {
      final container = await enter(tester, '못 받은 임금');
      await walk(tester, container, 'wage_theft', const {
        'q_work_status': '그만뒀어요',
        'q_subcontract': '아니에요',
      });
      await toResult(tester);

      expectOnTopCard(tester, '금품 청산');
      // **제일 무서워하는 게 보복이다.** 제104조 제2항이 그 답이다.
      expectScreenText(tester, '불리하게 대하지 못한다');
    });

    testWidgets('재직 중이면 14일이 안 뜨고 매월 지급 조문이 뜬다', (tester) async {
      final container = await enter(tester, '못 받은 임금');
      await walk(tester, container, 'wage_theft', const {
        'q_work_status': '지금도 다니고 있어요',
        'q_subcontract': '아니에요',
      });
      await toResult(tester);

      expectNoScreenText(tester, '금품 청산');
      // 접힌 물음이라 버튼 글자만 보인다. 눌러야 조문이 나온다.
      expectScreenText(tester, '아직 다니는 중인데 월급이 밀렸어요');
    });

    testWidgets('금액을 묻지 않는다', (tester) async {
      final container = await enter(tester, '못 받은 임금');
      await walk(tester, container, 'wage_theft', const {
        'q_work_status': '그만뒀어요',
        'q_subcontract': '아니에요',
      });
      await toResult(tester);

      // 주휴수당·연장수당은 우리가 못 센다. 비용 카드도 없다.
      expectNoScreenText(tester, CostCard.title);
    });
  });

  group('상속', () {
    testWidgets('결과 화면 맨 위가 기한이다', (tester) async {
      final container = await enter(tester, '물려받은 빚·재산');
      await walk(tester, container, 'inheritance', const {
        // 3개월이 걸린 자리다. 기준일이 2026년 8월 15일이니 1주일 전이 기산점.
        'q_estate_known': '아직 모르겠어요',
        'q_was_minor': '아니요, 성인이었어요',
      });
      await toResult(tester);

      expectOnTopCard(tester, TodayCard.title);
    });
  });
}
