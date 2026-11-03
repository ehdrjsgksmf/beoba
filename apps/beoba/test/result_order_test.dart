import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/format/formatters.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/widgets/broker_alert_card.dart';
import 'package:beoba/src/screens/result/result_screen.dart';
import 'package:beoba/src/screens/result/sections/deadline_section.dart';
import 'package:beoba/src/screens/result/sections/near_miss_notice.dart';
import 'package:beoba/src/screens/result/sections/period_rule_section.dart';
import 'package:beoba/src/screens/result/sections/limitation_card.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/screens/result/sections/today_card.dart';
import 'package:beoba/src/widgets/expandable_card.dart';
import 'package:beoba/src/widgets/legal_basis_card.dart';
import 'package:beoba/src/widgets/primary_button.dart';
import 'package:engines/engines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **눈에 띄어야 할 것은 이미 정해져 있다. 다만 사건마다 다르다.**
///
/// 기한이 하나라도 있으면 그게 맨 위다. 하나도 없으면 그 자리를 한 줄로 줄이고
/// 비용이 곧바로 온다 — 폰에서 재어 보니 맨 위가 빈 카드이고 정작 쓸모 있는
/// 비용이 맨 아래에 있었다 (DECISIONS 70).
///
/// 두 경우를 **둘 다** 잠근다. 한쪽만 잠그면 다른 쪽이 조용히 나빠진다.
void main() {
  /// 기한이 걸린 사건을 만든다.
  ///
  /// 지금 데이터로는 이 화면에 기한이 도달하지 못한다 — 법원 서류를 받아야 걸리는
  /// 기한은 하드스톱으로 끊기고 소멸시효는 `unverified` 라 로더가 걷어낸다
  /// (🔴 확인 목록). 그래서 엔진 결과를 갈아 끼운다.
  final urgent = DeadlineResult(
    id: 'dl_answer',
    label: '답변서 제출',
    dueDate: const KstDate(2026, 9, 14),
    daysRemaining: 30,
    severity: Severity.critical,
    basis: const LegalBasis(
      law: '민사소송법',
      article: '제256조 제1항',
      text: '피고는 소장의 부본을 송달받은 날부터 30일 이내에 답변서를 제출하여야 한다.',
    ),
    verification: VerificationStatus.verified,
  );

  Future<ProviderContainer> openResult(
    WidgetTester tester, {
    Map<String, Object?> answers = completeAnswers,
    List<DeadlineResult> deadlines = const [],
  }) async {
    final container = await pumpApp(
      tester,
      deadlines: deadlines.isEmpty ? null : deadlines,
    );
    seedAnswers(container, kDebtRecoveryDomainId, answers: answers);
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return container;
  }

  /// 화면에 그려진 세로 위치. 위에 있을수록 작다.
  double topOf(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  /// 스크롤하기 전에 보이는 높이.
  double viewportOf(WidgetTester tester) => tester.view.physicalSize.height / tester.view.devicePixelRatio;

  group('기한이 없을 때 — 비용이 곧바로 온다', () {
    testWidgets('맨 위는 오늘 할 일이다', (tester) async {
      await openResult(tester);

      final today = topOf(tester, find.byType(TodayCard));
      final cost = topOf(tester, find.byType(CostCard));
      expect(today, lessThan(cost));
    });

    testWidgets('시효 카드가 기한과 비용 사이에 온다', (tester) async {
      // **날짜로 계산하지 않는 것**이라 기한 카드에 넣지 않는다. 그렇다고
      // 맨 아래로 보내면 「기한이 없어요」만 보고 나가는 사람이 못 본다.
      await openResult(tester);

      final today = topOf(tester, find.byType(TodayCard));
      final limitation = topOf(tester, find.byType(LimitationCard));
      final cost = topOf(tester, find.byType(CostCard));

      expect(today, lessThan(limitation));
      expect(limitation, lessThan(cost));
      expect(
        limitation,
        lessThan(viewportOf(tester)),
        reason: '시효 카드를 보려고 스크롤해야 합니다',
      );
    });

    testWidgets('기한이 없다는 사실을 감추지 않는다', (tester) async {
      // 정상 경로로 온 사람이 기한을 하나도 못 보는 문제가 화면에 드러나 있어야
      // 한다. 한 줄을 지우면 문제가 사라지고, 사라지면 아무도 안 고친다.
      await openResult(tester);

      expect(find.text(DeadlineSection.empty), findsOneWidget);
      expect(find.text(DeadlineSection.emptyWhen), findsOneWidget);
    });

    testWidgets('D-day 뱃지도 「어떻게 셌나요」도 없다', (tester) async {
      // 셀 날짜가 없는데 「어떻게 셌나요」 는 말이 안 된다.
      await openResult(tester);
      expect(find.text(DeadlineSection.explainPeriod), findsNothing);
    });
  });

  group('기한이 있을 때 — 그게 오늘 할 일이다', () {
    testWidgets('가장 급한 기한이 맨 위 카드에 있다', (tester) async {
      await openResult(tester, deadlines: [urgent]);

      expect(find.text('답변서 제출'), findsOneWidget);
      expect(find.text(formatDDay(urgent)), findsOneWidget);
      expect(
        topOf(tester, find.byType(TodayCard)),
        lessThan(topOf(tester, find.byType(CostCard))),
      );
    });

    testWidgets('기한이 있으면 「없어요」 한 줄은 사라진다', (tester) async {
      await openResult(tester, deadlines: [urgent]);
      expect(find.text(DeadlineSection.empty), findsNothing);
    });

    testWidgets('날짜를 어떻게 셌는지 볼 길이 붙는다', (tester) async {
      // 검산할 수 없는 숫자는 믿을 이유도 없다.
      await openResult(tester, deadlines: [urgent]);
      expect(find.text(DeadlineSection.explainPeriod), findsOneWidget);
    });

    testWidgets('나머지 기한은 접혀 있다', (tester) async {
      final second = DeadlineResult(
        id: 'dl_payment_order_objection',
        label: '지급명령 이의신청',
        dueDate: const KstDate(2026, 8, 29),
        daysRemaining: 14,
        severity: Severity.critical,
        basis: urgent.basis,
        verification: VerificationStatus.verified,
      );
      await openResult(tester, deadlines: [urgent, second]);

      expect(find.text('지급명령 이의신청'), findsNothing);

      await tester.tap(find.text(TodayCard.moreOpen));
      await tester.pumpAndSettle();
      expect(find.text('지급명령 이의신청'), findsOneWidget);
    });
  });

  group('접힘과 고정', () {
    /// **개수는 세지 않는다.** 다섯 → 여섯 → 일곱으로 두 번 올렸고,
    /// 대리 지표가 계속 조정되면 재는 대상이 잘못된 것이다
    /// (DECISIONS 134번). 첫 화면 밀도는 `result_density_test` 가 잰다.
    ///
    /// 여기 남는 것은 **개수와 무관한 것** 둘이다.
    testWidgets('첫 화면에 펼쳐진 카드는 하나도 없다', (tester) async {
      await openResult(tester);

      // 펼쳐진 카드는 「접기」 를 달고 있다. 첫 화면에 하나도 없어야 한다.
      expect(find.text(ExpandableCard.collapse), findsNothing);
    });

    testWidgets('브로커 경보는 접히지 않는다', (tester) async {
      // 접히지 않는 예외다. 위기 창구와 같다 — 그 자리에서 판단해야 한다.
      final container = await pumpApp(tester);
      final controller = container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier);
      controller.start('통장 빌려주면 돈 준다고 해요');
      completeAnswers.forEach(controller.answer);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(find.byType(BrokerAlertCard), findsOneWidget);
    });

    testWidgets('하단 고정 버튼은 정확히 하나다', (tester) async {
      await openResult(tester);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text(ResultScreen.detail), findsOneWidget);
    });
  });

  group('요약에는 조문 원문이 없다', () {
    testWidgets('민법 조문도 기간 규칙도 요약에 안 나온다', (tester) async {
      // 결과를 보러 온 사람에게 계산 규칙을 먼저 읽히지 않는다.
      await openResult(tester);

      expect(find.byType(PeriodRuleSection), findsNothing);
      expect(find.textContaining('초일은 산입하지'), findsNothing);
      expect(find.textContaining('제157조'), findsNothing);
    });

    testWidgets('인지법 원문도 접힌 카드 안에 있어 안 나온다', (tester) async {
      await openResult(tester);
      expect(find.textContaining('소장에는 소송목적의 값에 따라'), findsNothing);
    });

    testWidgets('상세에는 있고, 규칙이 맨 아래다', (tester) async {
      final container = await openResult(tester);
      container
          .read(routerProvider)
          .go(Routes.resultDetail(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(find.byType(PeriodRuleSection), findsOneWidget);

      // 3층(이 사건의 이야기)이 규칙보다 위에 있어야 한다.
      final layers = find.text('법에 있는 내용');
      if (layers.evaluate().isNotEmpty) {
        expect(
          topOf(tester, find.byType(PeriodRuleSection)),
          greaterThan(topOf(tester, layers.first)),
        );
      }
    });
  });

  group('경계 알림은 제 카드 안에 있다', () {
    final justOver = {
      ...completeAnswers,
      // not-a-legal-number: 테스트 입력값. 3,000만원을 1,500원 넘겼다.
      'q_amount': 30001500,
    };

    testWidgets('독립 섹션으로 위에 끼어들지 않는다', (tester) async {
      // 새 기능을 넣을 때마다 「위에 두면 눈에 띄겠지」로 기한이 두 번 밀렸다.
      await openResult(tester, answers: justOver);
      expect(find.text(NearMissNotice.headline), findsNothing);
    });

    testWidgets('절차 카드를 펴면 나온다', (tester) async {
      await openResult(tester, answers: justOver);

      final card = find.text(ProcedureCard.title);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text(NearMissNotice.headline), findsOneWidget);
    });
  });

  group('갈래의 근거는 둘이다', () {
    testWidgets('관할 카드를 펴면 조문 이름이 둘 다 나온다', (tester) async {
      // 「어느 법원이 맡는가」(제2조)와 「보통재판적이 어디인가」(제3조)가
      // 갈라져 있다. 하나만 걸면 나머지가 화면에서도 매니페스트에서도 사라진다.
      await openResult(tester);

      final card = find.text(JurisdictionCard.title);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('민사소송법 제2조'), findsWidgets);
      expect(find.text('민사소송법 제3조'), findsWidgets);
      expect(find.text('민사소송법 제5조 제1항'), findsWidgets);
    });
  });

  group('조문 원문은 눌러서 본다 — 다만 접지 않는 자리가 있다', () {
    const basis = LegalBasis(
      law: '민법',
      article: '제174조',
      text: '최고는 6월내에 재판상의 청구, 파산절차참가, 화해를 위한 소환, '
          '임의출석, 압류 또는 가압류, 가처분을 하지 아니하면 시효중단의 효력이 없다.',
    );

    testWidgets('접힌 상태에서도 이름과 🟢 라벨은 보인다', (tester) async {
      await pumpWidgetOnly(tester, const LegalBasisCard(basis: basis));

      expect(find.text('민법 제174조'), findsOneWidget);
      expect(find.text('법에 있는 내용'), findsOneWidget);
      expect(find.textContaining('최고는 6월내에'), findsNothing);
    });

    testWidgets('누르면 원문이 나온다', (tester) async {
      await pumpWidgetOnly(tester, const LegalBasisCard(basis: basis));

      await tester.tap(find.text('민법 제174조'));
      await tester.pumpAndSettle();
      expect(find.textContaining('최고는 6월내에'), findsOneWidget);
    });

    testWidgets('위기 창구·브로커 경보의 근거는 접지 않는다', (tester) async {
      // 그 자리에서 판단해야 하는 정보다. 한 번 더 누르게 하지 않는다.
      await pumpWidgetOnly(
        tester,
        const LegalBasisCard(basis: basis, collapsible: false),
      );

      expect(find.textContaining('최고는 6월내에'), findsOneWidget);
    });
  });
}
