import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/screens/result/sections/crossroads_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_scenarios.dart';
import 'support/test_app.dart';

/// 갈림길에 「이 길을 만드는 법」의 이름이 선다(DECISIONS 284번).
///
/// 목록은 위에서 아래로 이어지는 순서로 읽힌다. 서로 다른 법이라는 것을
/// **우리 말이 아니라 데이터가** 말하게 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openBoth(
    WidgetTester tester,
    String domainId,
    Map<String, Object?> answers,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    seedAnswers(container, domainId, answers: answers);
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();
    for (final label in [CrossroadsSection.beforeCourt, CrossroadsSection.court]) {
      final f = find.text(label);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('★ 전세사기 — 결정 신청과 고소장 내기가 서로 다른 법으로 선다',
      (tester) async {
    await openBoth(tester, 'jeonse_fraud', const {
      'q_first_contract': 'before',
      'q_apply_stage': 'not_yet',
      'q_auction': 'yes',
    });
    final steps = find.byType(CrossroadsSection);
    expect(
      find.descendant(
          of: steps, matching: find.text('전세사기피해자 지원 및 주거안정에 관한 특별법')),
      findsOneWidget,
    );
    expect(find.descendant(of: steps, matching: find.text('형사소송법')),
        findsOneWidget);
    expect(find.descendant(of: steps, matching: find.text('민사집행법')),
        findsOneWidget);
  });

  testWidgets('★ pathLaw 가 legalBasis 보다 먼저다 — 제소전화해는 인지법이 아니다',
      (tester) async {
    final (id, answers) = screenScenarios['떼인 돈 · 받을 쪽']!;
    await openBoth(tester, id, answers);
    final steps = find.byType(CrossroadsSection);
    // 제소전화해 카드의 legalBasis 는 인지법(인지 5분의 1)이다. 그 길을 만드는
    // 법은 민사소송법이라 pathLaw 에 적었다 — 줄에는 그쪽이 서야 한다.
    expect(find.descendant(of: steps, matching: find.text('제소전화해')),
        findsOneWidget, reason: '이 갈래에 제소전화해가 서야 이 시험이 뜻이 있습니다');
    expect(find.descendant(of: steps, matching: find.text('민사소송 등 인지법')),
        findsNothing);
    expect(find.descendant(of: steps, matching: find.text('민사소송법')),
        findsWidgets);
  });
}
