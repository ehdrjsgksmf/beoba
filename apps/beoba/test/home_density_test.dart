import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 홈의 밀도. **결과 화면만 재고 홈은 안 재고 있었다.**
///
/// 홈에 무언가를 붙일 때마다 「한 줄인데요」로 늘어난다. 결과 화면에서
/// 배운 것과 같다 — 개수로 세면 상한이 계속 올라가므로 **화면 수로 잰다**
/// (DECISIONS 134번).
///
/// ```
/// 첫 화면        인사말 · 두 갈래. 설명은 아무것도 안 보인다
/// 배율 1.0       전체 3.5화면 이내
/// 배율 1.5       1.0 값의 1.9배를 넘지 않는다
/// ```
///
/// **두 갈래가 둘 다 첫 화면 안에 있어야 한다.** 하나만 보이면 그게 곧
/// 「이쪽이 맞습니다」가 된다 — 나란히 놓은 뜻이 그 자리에서 없어진다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 360.0;
  const height = 780.0;

  /// 배율 1.0 에서의 상한. 두 갈래를 큰 버튼으로 세우고 잰 값이 2.30이다.
  ///
  /// **여유 0.30을 남겨 둔다.** 다음에 여기를 넘기려면 홈에서 무언가를
  /// 빼야 한다 — 상한을 올리는 것이 아니라.
  const budget = 3.5;

  /// 배율 사이의 비율 상한. 결과 화면과 같은 눈금을 쓴다.
  const scaleRatio = 1.9;

  Future<double> measure(WidgetTester tester, double scale) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(width, height);
    addTearDown(tester.view.reset);

    await pumpApp(tester, textScale: scale);

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    return (position.maxScrollExtent + position.viewportDimension) / height;
  }

  group('홈 — 첫 화면에 읽을 것', () {
    testWidgets('접힌 선 아래 것은 첫 화면에 없다', (tester) async {
      await measure(tester, 1);

      // **접히는 선은 화면 밑변이 아니다.** 시작하기 버튼이 붙박이라
      // 스크롤 되는 자리는 그 위에서 끝난다. 화면 높이로 재면 이미 안
      // 보이는 것을 「보인다」고 세게 된다.
      final fold = tester.getRect(find.byType(Scrollable).first).bottom;

      // 설명은 전부 아래에 있다. 궁금한 사람만 내려서 읽는다.
      for (final line in [
        HomeScreen.canTitle,
        HomeScreen.cannotTitle,
        HomeScreen.sloganBig,
      ]) {
        final found = find.text(line);
        expect(found, findsOneWidget);
        expect(
          tester.getTopLeft(found).dy,
          greaterThan(fold),
          reason: '「$line」이 첫 화면에 올라와 있습니다. '
              '첫 화면은 인사말·입력창·시작하기 셋뿐입니다',
        );
      }
    });

    testWidgets('★ 두 갈래가 둘 다 첫 화면 안에 있다', (tester) async {
      await measure(tester, 1);

      final fold = tester.getRect(find.byType(Scrollable).first).bottom;
      for (final line in [
        HomeScreen.pick,
        HomeScreen.pathProblem,
        HomeScreen.welfareDoor,
      ]) {
        expect(
          tester.getRect(find.text(line)).bottom,
          lessThan(fold),
          reason: '「$line」이 첫 화면 밖으로 밀렸습니다. '
              '한 갈래만 보이면 그게 곧 「이쪽이 맞습니다」가 됩니다',
        );
      }
    });

    testWidgets('입력창은 아래로 내렸지만 없애지 않았다', (tester) async {
      await measure(tester, 1);

      // 두 갈래 어디에도 자기 것이 안 보이는 사람이 갈 데다.
      expect(find.byType(TextField), findsOneWidget);
      // 시작하기는 붙박이라 자판이 올라와도 늘 눌린다(keyboard_test).
      expect(find.byType(PrimaryButton), findsOneWidget);
    });
  });

  group('홈 — 전체 길이', () {
    testWidgets('배율 1.0 에서 상한 안에 든다', (tester) async {
      final screens = await measure(tester, 1);
      // ignore: avoid_print
      print('홈 밀도 배율 1.0 — ${screens.toStringAsFixed(2)}화면');
      expect(screens, lessThanOrEqualTo(budget));
    });

    testWidgets('배율을 키워도 같은 비율로만 늘어난다', (tester) async {
      final one = await measure(tester, 1);
      final wide = await measure(tester, 1.5);
      // ignore: avoid_print
      print('홈 밀도 배율 1.5 — ${wide.toStringAsFixed(2)}화면 '
          '(${(wide / one).toStringAsFixed(2)}배)');
      expect(wide / one, lessThanOrEqualTo(scaleRatio));
    });
  });
}
