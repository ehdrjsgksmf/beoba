import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/widgets/today_pill.dart';
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// D-14 가 어디서 나온 숫자인지 사용자가 스스로 검산할 수 있어야 한다.
///
/// 앱이 오늘을 잘못 알고 있으면 모든 기한이 틀리는데, 날짜를 안 보여주면 그걸
/// 확인할 방법이 없다.
void main() {
  // 기준일은 2026년 8월 15일 (testClock).
  const shown = '오늘 2026년 8월 15일';

  testWidgets('오늘 날짜는 KstClock 에서만 온다', (tester) async {
    await pumpApp(tester);
    expect(find.text(shown), findsOneWidget);
  });

  testWidgets('화면을 옮겨 다녀도 계속 보인다', (tester) async {
    final container = await pumpApp(tester);

    await tester.tap(find.text(HomeScreen.start));
    await tester.pumpAndSettle();
    expect(find.text(shown), findsOneWidget);

    // 첫 화면에는 묶음 줄만 선다(DECISIONS 237번).
    await pickDomainFromList(tester, kDebtRecoveryDomainId);
    expect(find.text(shown), findsOneWidget);

    seedAnswers(container, kDebtRecoveryDomainId);
    container.read(routerProvider).go(Routes.summary(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    expect(find.text(shown), findsOneWidget);

    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    expect(find.text(shown), findsOneWidget);
  });

  testWidgets('한 화면에 하나만 있다', (tester) async {
    // AppBar 와 본문에 겹쳐 들어가면 같은 정보가 두 번 보인다.
    await pumpApp(tester);
    expect(find.byType(TodayPill), findsOneWidget);
  });

  group('해외 접속 — 현지 날짜를 병기한다', () {
    // 뉴욕에서 밤에 열면 현지는 14일인데 KST 는 15일이다.
    const abroad = FixedKstClock.abroad(
      kst: KstDate(2026, 8, 15),
      local: KstDate(2026, 8, 14),
    );

    testWidgets('두 날짜가 다르면 두 줄이 나온다', (tester) async {
      await pumpWidgetOnly(tester, const TodayPill(), clock: abroad);
      expect(find.text('오늘 2026년 8월 15일 (한국)'), findsOneWidget);
      expect(find.text('2026년 8월 14일 (현지)'), findsOneWidget);
    });

    testWidgets('두 날짜가 같으면 한 줄만 나온다', (tester) async {
      // 국내 사용자에게 현지 표시는 소음이다.
      await pumpWidgetOnly(tester, const TodayPill());
      expect(find.text('오늘 2026년 8월 15일'), findsOneWidget);
      expect(find.textContaining('현지'), findsNothing);
      expect(find.textContaining('(한국)'), findsNothing);
    });

    testWidgets('기한 계산은 KST 를 그대로 쓴다', (tester) async {
      // **표시만 병기다.** 여기가 흔들리면 M0 부터 지킨 것이 무너진다.
      expect(abroad.today(), const KstDate(2026, 8, 15));
    });

    testWidgets('배율 2.0 에서 두 줄이 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpWidgetOnly(tester, const TodayPill(), clock: abroad, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
