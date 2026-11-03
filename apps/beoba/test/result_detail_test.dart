import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/result/result_detail_screen.dart';
import 'package:beoba/src/screens/result/result_screen.dart';
import 'package:beoba/src/screens/result/sections/cost_breakdown_view.dart';
import 'package:beoba/src/screens/result/sections/deadline_section.dart';
import 'package:beoba/src/screens/result/sections/near_miss_notice.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 「140,000원」만 있고 **왜 그 숫자인지**가 없으면 근거가 있다고 할 수 없다.
/// 그리고 빈 화면은 정상 동작이어도 실패처럼 보인다.
void main() {
  Future<void> openResult(
    WidgetTester tester, {
    Map<String, Object?> answers = completeAnswers,
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(container, kDebtRecoveryDomainId, answers: answers);
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
  }

  /// 접힌 카드를 편다. 내역·절차는 이제 요약의 카드 안에 있다.
  Future<void> openCard(WidgetTester tester, String title) async {
    final finder = find.text(title);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// 비용 카드를 펴고 그 안의 첫 계산 근거까지 연다.
  Future<void> openFirstBreakdown(WidgetTester tester) async {
    await openCard(tester, CostCard.title);
    final open = find.text(CostBreakdownView.open).first;
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
  }

  group('계산 근거 — 두 번 접혀 있다', () {
    testWidgets('카드가 접혀 있으면 근거를 열 문도 없다', (tester) async {
      // 급한 사람은 갈래별 합계만 보고 나간다.
      await openResult(tester);

      expect(find.text(CostBreakdownView.open), findsNothing);
      expect(find.text(CostBreakdownView.tierLabel), findsNothing);
    });

    testWidgets('카드를 펴면 항목마다 근거를 열 문이 있다', (tester) async {
      await openResult(tester);
      await openCard(tester, CostCard.title);

      expect(find.text(CostBreakdownView.open), findsWidgets);
      expect(find.text(CostBreakdownView.tierLabel), findsNothing);
    });

    testWidgets('열면 엔진이 밟은 단계가 그대로 나온다', (tester) async {
      await openResult(tester);
      await openFirstBreakdown(tester);

      // 소가 5,000만원 · 소송 · 전자소송 아님 → 230,000원
      expect(find.text(CostBreakdownView.inputLabel), findsOneWidget);
      expect(find.text('50,000,000원'), findsWidgets);
      expect(find.text(CostBreakdownView.tierLabel), findsOneWidget);
      expect(find.textContaining('0.45%'), findsOneWidget);
    });

    testWidgets('화면이 다시 계산하지 않는다', (tester) async {
      // 최종 금액은 엔진이 낸 값 그대로여야 한다.
      await openResult(tester);
      await openFirstBreakdown(tester);

      expect(find.text('230,000원'), findsWidgets);
    });
  });

  group('경계값 — 아슬아슬하면 알린다', () {
    final justOver = {
      ...completeAnswers,
      // not-a-legal-number: 테스트 입력값. 3,000만원을 1,500원 넘겼다.
      'q_amount': 30001500,
    };

    testWidgets('1,500원 넘겼으면 절차 카드에서 알린다', (tester) async {
      await openResult(tester, answers: justOver);
      await openCard(tester, ProcedureCard.title);

      expect(find.text(NearMissNotice.headline), findsOneWidget);
      expect(find.textContaining('30,000,000원 이하'), findsOneWidget);
      expect(find.textContaining('1,500원'), findsOneWidget);
    });

    testWidgets('경계 안이면 아무 말도 안 한다', (tester) async {
      await openResult(tester);
      await openCard(tester, ProcedureCard.title);
      expect(find.text(NearMissNotice.headline), findsNothing);
    });

    testWidgets('배율 2.0 에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openResult(tester, answers: justOver);
      expect(tester.takeException(), isNull);
    });
  });

  group('기한이 비었을 때 이유를 말한다', () {
    // 언제까지 받기로 했는지를 안 답하면 소멸시효가 안 걸리고,
    // 법원 서류도 안 받았으면 답변서·이의신청도 안 걸린다.
    const noDeadline = {
      'q_role': 'creditor',
      'q_claim_type': 'loan',
      'q_amount': 50000000, // not-a-legal-number: 테스트 입력값
      'q_evidence_written': ['contract'],
      'q_transfer_record': 'yes',
      'q_demanded': 'none',
      'q_debtor_response': 'no_response',
      'q_debtor_address_known': 'yes',
      'q_court_document': 'none',
    };

    testWidgets('없다고만 하지 않는다', (tester) async {
      await openResult(tester, answers: noDeadline);

      expect(find.text(DeadlineSection.empty), findsOneWidget);
      expect(find.text(DeadlineSection.emptyWhen), findsOneWidget);
    });

    testWidgets('언제 생기는지 데이터가 준 말로 알려준다', (tester) async {
      await openResult(tester, answers: noDeadline);

      expect(find.text('법원에서 소장을 받으시면 그날부터 30일이 걸려요'), findsOneWidget);
      expect(find.text('지급명령을 받으시면 그날부터 2주가 걸려요'), findsOneWidget);
    });

    testWidgets('걸린 기한이 있으면 그 안내는 안 나온다', (tester) async {
      // 위젯만 띄워 본다. 지금 데이터에서는 법원 서류를 받아야 기한이 걸리는데
      // (소멸시효는 unverified 라 로더가 걷어낸다) 그 경로는 하드스톱으로 끊긴다.
      await pumpWidgetOnly(
        tester,
        DeadlineSection(
          deadlines: [
            DeadlineResult(
              id: 'dl_x',
              label: '시험용 기한',
              dueDate: const KstDate(2026, 9, 14),
              daysRemaining: 30,
              severity: Severity.warning,
              basis: const LegalBasis(law: '민법', article: '제1조'),
              verification: VerificationStatus.verified,
            ),
          ],
          appearsWhen: const ['이럴 때 생겨요'],
        ),
      );
      expect(find.text(DeadlineSection.emptyWhen), findsNothing);
    });
  });

  group('서류·절차를 어떻게 하는지 연결한다', () {
    testWidgets('절차의 자세한 설명이 절차 카드 안에 있다', (tester) async {
      await openResult(tester);
      await openCard(tester, ProcedureCard.title);

      expect(
        find.textContaining('3부를 작성해'),
        findsOneWidget,
        reason: 'proc_certified_mail.detail 이 화면에 없습니다',
      );
    });

    testWidgets('공식 사이트 주소가 글자로도 보인다', (tester) async {
      // 링크가 안 열리는 환경이 있다.
      await openResult(tester);
      await openCard(tester, ProcedureCard.title);

      expect(find.textContaining('scourt.go.kr'), findsWidgets);
    });
  });

  group('요약 ↔ 근거', () {
    testWidgets('요약에서 눌러 근거 화면으로 가고 뒤로 돌아온다', (tester) async {
      await openResult(tester);

      await tester.tap(find.text(ResultScreen.detail));
      await tester.pumpAndSettle();
      expect(find.text(ResultDetailScreen.title), findsOneWidget);

      await tester.tap(find.text(ResultDetailScreen.back));
      await tester.pumpAndSettle();
      expect(find.text(ResultScreen.detail), findsOneWidget);
    });

    testWidgets('배율 2.0 에서 근거 화면이 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openResult(tester);
      await tester.tap(find.text(ResultScreen.detail));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
