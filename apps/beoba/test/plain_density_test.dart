import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:engines/engines.dart' show KstDate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/domain_scenarios.dart';
import 'support/test_app.dart';

/// 쉬운 말 모드의 밀도.
///
/// **쉬운 말은 문장을 짧게 여러 개로 쪼개기 때문에 세로가 늘어난다.**
/// 그런데 예산은 그대로 4.12다 — 쉬운 말 때문에 상한을 올리지 않는다.
/// 올리기 시작하면 「이건 특별하니까」가 계속 생기고, 그때부터 예산은
/// 예산이 아니다(DECISIONS 134번).
///
/// 그래서 축을 하나 더 놓고 잰다 — 지금까지 **배율**로만 재던 것을
/// **배율 × 모드**로 잰다. 넘치면 문장을 되돌리지 말고 카드를 접는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 360.0;
  const height = 780.0;

  /// 결과 화면 예산. `result_density_test` 와 같은 값이다.
  const maxScreens = 4.12;

  /// 홈 예산. `home_density_test` 와 같은 값이다.
  const homeBudget = 3.5;

  const heaviest = <String, Object?>{
    'q_injury_date': KstDate(2026, 8, 1),
    'q_injury_kind': 'work',
    'q_treated_days': 'longer',
  };

  Future<double> measureResult(
    WidgetTester tester,
    Map<String, Object?> answers, {
    required bool plain,
    double scale = 1,
    String domainId = 'work_injury',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(width, height);
    addTearDown(tester.view.reset);

    final container = await pumpApp(tester, textScale: scale);
    if (plain) container.read(plainModeProvider.notifier).toggle();
    seedAnswers(container, domainId, answers: answers);
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    return (position.maxScrollExtent + position.viewportDimension) / height;
  }

  group('★ 쉬운 말 — 모든 분야', () {
    // **쉬운 말 밀도를 두 분야에서만 재고 있었다.** 나머지 열하나는
    // 아무도 안 봤다 — 예산은 같은 4.12인데도 그랬다. 갈래 표를
    // `screenScenarios` 하나로 모으면서 열셋을 다 돈다.
    for (final entry in screenScenarios.entries) {
      final (domainId, answers) = entry.value;

      testWidgets('${entry.key} — 쉬운 말 · 배율 1.0', (tester) async {
        final screens = await measureResult(
          tester,
          answers,
          plain: true,
          domainId: domainId,
        );
        // ignore: avoid_print
        print('쉬운 말 밀도 · ${entry.key} — '
            '${screens.toStringAsFixed(3)}화면');
        expect(
          screens,
          lessThan(maxScreens),
          reason: '${entry.key} — 쉬운 말에서 예산을 넘었습니다. 갈래를 '
              '줄이지 말고 카드를 접으세요 — 그리고 무엇을 접었는지 적으세요',
        );
      });
    }

    test('★ 분야를 몇 개 돌았는지 센다', () {
      expectsEveryDomain(
        'plain_density_test 의 screenScenarios',
        [for (final entry in screenScenarios.values) entry.$1],
      );
    });
  });

  group('★ 두 축이 겹칠 때 — 쉬운 말 × 배율 1.5', () {
    testWidgets('산재 · 가장 무거운 갈래', (tester) async {
      // **두 축이 겹치는 자리다.** 배율 상한은 절대값이 아니라 증가폭으로
      // 잰다(`result_density_test` 와 같은 눈금 1.9배).
      final one = await measureResult(tester, heaviest, plain: true);
      final half =
          await measureResult(tester, heaviest, plain: true, scale: 1.5);
      // ignore: avoid_print
      print('산재 밀도 · 가장 무거운 갈래 · 쉬운 말 · 배율 1.5 — '
          '${half.toStringAsFixed(3)}화면 '
          '(${(half / one).toStringAsFixed(2)}배)');
      expect(
        half / one,
        lessThan(1.9),
        reason: '쉬운 말에서 배율이 오를 때 더 많이 늘어납니다. '
            '문장을 지우지 말고 줄바꿈을 보세요',
      );
    });
  });

  group('★ 홈과 분야 목록도 다시 잰다', () {
    testWidgets('홈 — 쉬운 말에서도 상한 안', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(width, height);
      addTearDown(tester.view.reset);

      final container = await pumpApp(tester);
      container.read(plainModeProvider.notifier).toggle();
      await tester.pumpAndSettle();

      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final screens =
          (position.maxScrollExtent + position.viewportDimension) / height;
      // ignore: avoid_print
      print('홈 밀도 · 쉬운 말 · 배율 1.0 — ${screens.toStringAsFixed(3)}화면');
      expect(screens, lessThan(homeBudget));
    });

    testWidgets('분야 목록 — 쉬운 말에서도 상한 안', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(width, height);
      addTearDown(tester.view.reset);

      final container = await pumpApp(tester);
      container.read(plainModeProvider.notifier).toggle();
      container.read(routerProvider).go(Routes.domains);
      await tester.pumpAndSettle();

      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final screens =
          (position.maxScrollExtent + position.viewportDimension) / height;
      // ignore: avoid_print
      print('분야 목록 밀도 · 쉬운 말 · 배율 1.0 — ${screens.toStringAsFixed(3)}화면');
      expect(screens, lessThan(3.5));
    });
  });
}
