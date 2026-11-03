import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/screens/detected/detected_screen.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/interview/interview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **자판이 올라온 화면.**
///
/// 이 화면들은 지금까지 한 번도 시험되지 않았다. 테스트 하네스가
/// `MediaQuery` 를 통째로 덮어써서 `viewInsets` 가 0 이었고, 그래서
/// `resizeToAvoidBottomInset`(자판이 올라오면 본문을 줄이는 장치)이 아예
/// 안 돌았다(DECISIONS 104번).
///
/// **자판을 내리고 버튼을 누르는 사람은 없다.** 그건 개발자 습관이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 흔한 저가 안드로이드 폭 + 자판 320.
  const width = 360.0;
  const height = 780.0;
  const keyboard = 320.0;

  void phoneWithKeyboard(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(width, height);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    // 노치와 제스처 바까지. SafeArea 가 실제로 도는지도 함께 본다.
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 24);
    addTearDown(tester.view.reset);
  }

  /// 버튼이 자판 위에 있고, 실제로 눌리는가.
  void expectAboveKeyboard(WidgetTester tester, Finder button, String where) {
    final rect = tester.getRect(button);
    expect(
      rect.bottom,
      lessThanOrEqualTo(height - keyboard),
      reason: '$where — 버튼이 자판 아래에 깔렸습니다',
    );
    expect(rect.top, greaterThanOrEqualTo(0), reason: '$where — 버튼이 화면 위로 나갔습니다');
  }

  group('홈 — 글을 적는 화면', () {
    testWidgets('자판을 내리지 않고 눌러도 눌린다', (tester) async {
      const narrative = '작년 3월에 오백만원을 빌려줬는데 계속 안 갚아요. '
          '문자로 여러 번 이야기했는데 답이 없습니다.';
      phoneWithKeyboard(tester);
      final container = await pumpApp(tester);

      await tester.enterText(find.byType(TextField).first, narrative);
      await tester.pumpAndSettle();

      // 입력창의 helper 다. 자판에 깔리면 helper 로 옮긴 뜻이 없어진다.
      expectAboveKeyboard(tester, find.text(HomeScreen.privacy), '개인정보 줄');
      expectAboveKeyboard(tester, find.text(HomeScreen.privacyMore), '자세히');
      expectAboveKeyboard(tester, find.text(HomeScreen.start), '홈');
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();

      expect(container.read(pendingNarrativeProvider), narrative);
      // 「빌려줬는데」가 걸려 분야를 알아챈다. 목록을 건너뛰고 확인 카드다.
      expect(find.text(DetectedScreen.title), findsOneWidget);
    });
  });

  group('인터뷰 — 자판이 뜨는 문항', () {
    /// 그 문항까지 간다. 앞 문항은 답을 심어 건너뛴다.
    Future<void> goTo(WidgetTester tester, int step, Map<String, Object?> answers) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId, answers: answers);
      container
          .read(routerProvider)
          .go(Routes.interview(kDebtRecoveryDomainId, step));
      await tester.pumpAndSettle();
    }

    testWidgets('금액 문항 — 다음 버튼이 자판 위에 있다', (tester) async {
      phoneWithKeyboard(tester);
      await goTo(tester, 4, const {
        'q_role': 'creditor',
        'q_court_document': 'none',
        'q_claim_type': 'loan',
      });

      expect(find.text('받지 못한 금액은 얼마인가요?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '5000000');
      await tester.pumpAndSettle();

      expectAboveKeyboard(tester, find.text(InterviewScreen.next), '금액 문항');
      await tester.tap(find.text(InterviewScreen.next));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('날짜 문항 — 시트를 열어도 자판 위에 있다', (tester) async {
      phoneWithKeyboard(tester);
      await goTo(tester, 5, const {
        'q_role': 'creditor',
        'q_court_document': 'none',
        'q_claim_type': 'loan',
        'q_amount': 5000000, // not-a-legal-number: 테스트 입력값
      });

      expect(find.text('언제까지 받기로 하셨나요?'), findsOneWidget);
      expectAboveKeyboard(tester, find.text(InterviewScreen.next), '날짜 문항');
      expect(tester.takeException(), isNull);
    });
  });

  group('노치와 제스처 바를 피한다', () {
    /// **폰마다 다르다.** 펀치홀·노치·상태표시줄 높이가 제각각이라
    /// 하나만 재면 그 하나만 맞는다. 작은 쪽과 큰 쪽을 둘 다 본다.
    ///
    /// 하네스가 `padding` 을 지우고 있던 동안 SafeArea 는 아무 일도 안 했다
    /// (DECISIONS 104번). 이제 실제로 돈다.
    const notches = <String, (double, double)>{
      '상태표시줄만': (24, 0),
      '노치 · 제스처 바': (59, 34),
    };

    for (final entry in notches.entries) {
      final (top, bottom) = entry.value;

      testWidgets('${entry.key} — 홈이 안 가리고 안 넘친다', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(width, height);
        tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
        addTearDown(tester.view.reset);

        await pumpApp(tester);
        expect(tester.takeException(), isNull);

        expect(
          tester.getRect(find.textContaining('오늘 2026')).top,
          greaterThanOrEqualTo(top),
          reason: '첫 줄이 노치 아래로 안 내려왔습니다',
        );
        expect(
          tester.getRect(find.text(HomeScreen.start)).bottom,
          lessThanOrEqualTo(height - bottom),
          reason: '버튼이 제스처 바에 깔렸습니다',
        );

        await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} — 결과 화면이 안 가리고 안 넘친다', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(width, height);
        tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
        addTearDown(tester.view.reset);

        final container = await pumpApp(tester);
        seedAnswers(container, kDebtRecoveryDomainId);
        container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
