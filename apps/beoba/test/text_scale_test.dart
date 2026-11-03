import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 타깃 사용자가 소외계층이다. 시스템 글꼴을 키워 쓰는 사람이 많다.
///
/// 배율 2.0 에서 화면이 넘치면 안 된다. 넘치면 Flutter 가 예외를 던지므로
/// `takeException()` 이 비어 있는지로 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scale = 2.0;

  /// 작은 화면일수록 넘치기 쉽다. 흔한 저가 안드로이드 폭에 맞춘다.
  const narrow = Size(360, 780);

  /// **순서가 규칙이다.** 예전에는 `physicalSize` 를 먼저 정하면서 그때의
  /// 기기 배율(3.0)을 곱했고, 그다음 줄에서 배율을 1 로 바꿨다. 그러면
  /// 논리 크기가 360 이 아니라 **1080** 이 된다 — 좁은 화면을 시험한다고
  /// 적어 두고 실제로는 태블릿보다 넓은 화면을 시험하고 있었다.
  ///
  /// 그래서 배율 2.0 에서 위쪽 줄이 63px 넘치는 것을 이 검사가 못 봤다.
  /// **배율을 먼저 1 로 두고 크기를 그대로 넣는다.**
  Future<void> withNarrowScreen(WidgetTester tester, Future<void> Function() body) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = narrow;
    addTearDown(tester.view.reset);
    await body();
  }

  testWidgets('배율 2.0 — 홈 · 분야 선택 · 인터뷰', (tester) async {
    await withNarrowScreen(tester, () async {
      await pumpApp(tester, textScale: scale);
      expect(tester.takeException(), isNull);

      // 홈도 길다. 큰 줄·잘하는 것·못 하는 것·슬로건까지 굴려서 본다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();

      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 첫 화면에는 묶음 줄만 선다(DECISIONS 237번). 배율 2.0 에서는
      // 묶음 줄도 화면 밖으로 나가므로 헬퍼가 굴려서 올린다.
      await pickDomainFromList(tester, kDebtRecoveryDomainId);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('배율 2.0 — 정리 카드 · 결과', (tester) async {
    await withNarrowScreen(tester, () async {
      final container = await pumpApp(tester, textScale: scale);
      seedAnswers(container, kDebtRecoveryDomainId);

      container.read(routerProvider).go(Routes.summary(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 결과는 길다. 끝까지 굴려도 넘치지 않아야 한다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('배율 2.0 — 하드스톱 확인 · 차단', (tester) async {
    await withNarrowScreen(tester, () async {
      await pumpApp(tester, textScale: scale);

      await tester.enterText(find.byType(TextField).first, '사기죄로 고소하려고 합니다');
      await tester.pump();
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();
      // 첫 화면에는 묶음 줄만 선다(DECISIONS 237번). 배율 2.0 에서는
      // 묶음 줄도 화면 밖으로 나가므로 헬퍼가 굴려서 올린다.
      await pickDomainFromList(tester, kDebtRecoveryDomainId);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('네, 맞습니다'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('배율 2.0 — 위기 안내 (전체 화면)', (tester) async {
    await withNarrowScreen(tester, () async {
      await pumpApp(tester, textScale: scale);

      await tester.enterText(find.byType(TextField).first, '돈 때문에 죽고 싶습니다');
      await tester.pump();
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();
      // 첫 화면에는 묶음 줄만 선다(DECISIONS 237번). 배율 2.0 에서는
      // 묶음 줄도 화면 밖으로 나가므로 헬퍼가 굴려서 올린다.
      await pickDomainFromList(tester, kDebtRecoveryDomainId);
      expect(tester.takeException(), isNull);

      // 전화번호가 큰 글자라 배율을 먹으면 가장 먼저 넘친다.
      expect(find.text('109'), findsOneWidget);
    });
  });

  testWidgets('배율 2.0 — 준비 중 분야 안내', (tester) async {
    await withNarrowScreen(tester, () async {
      // 준비 중 분야가 0개라 목록에서는 못 간다. 화면을 직접 연다.
      final container = await pumpApp(tester, textScale: scale);
      container.read(routerProvider).go(Routes.upcoming(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('결과가 없을 때(readiness red)도 넘치지 않는다', (tester) async {
    await withNarrowScreen(tester, () async {
      final container = await pumpApp(tester, textScale: scale);
      seedAnswers(
        container,
        kDebtRecoveryDomainId,
        answers: const {'q_claim_type': 'loan'},
      );

      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
