import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/result/sections/crossroads_section.dart';
import 'package:beoba/src/widgets/fee_schedule_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 갈림길 — **소송 말고도 있다는 걸 여기서 처음 보게 된다.**
///
/// 결과 화면이 「지급명령이냐 소송이냐」로만 갈려 있으면 나홀로소송 안내서로
/// 읽힌다. 실제 사다리는 그보다 앞에서 시작한다.
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

  Future<void> choose(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('갈래가 셋이다', () {
    testWidgets('결과 화면 아래에 셋 다 있다', (tester) async {
      await openResult(tester);

      expect(find.text(CrossroadsSection.beforeCourt), findsOneWidget);
      expect(find.text(CrossroadsSection.court), findsOneWidget);
      expect(find.text(CrossroadsSection.unsure), findsOneWidget);
    });

    testWidgets('「법적조치」라고 쓰지 않는다', (tester) async {
      // 내용증명도 공증도 조정도 전부 법적 절차라 정확하지 않고, 무겁게 들린다.
      await openResult(tester);
      expect(find.textContaining('법적조치'), findsNothing);
    });

    testWidgets('처음에는 아무것도 펼쳐져 있지 않다', (tester) async {
      await openResult(tester);
      expect(find.text(CrossroadsSection.noRush), findsNothing);
    });
  });

  group('고른 갈래가 다른 갈래를 감추지 않는다', () {
    testWidgets('하나를 펴도 나머지 둘이 그대로 있다', (tester) async {
      await openResult(tester);
      await choose(tester, CrossroadsSection.beforeCourt);

      expect(find.text(CrossroadsSection.court), findsOneWidget);
      expect(find.text(CrossroadsSection.unsure), findsOneWidget);
    });

    testWidgets('다시 누르면 접힌다 — 되돌아올 수 있다', (tester) async {
      await openResult(tester);
      await choose(tester, CrossroadsSection.unsure);
      expect(find.text(CrossroadsSection.noRush), findsOneWidget);

      await choose(tester, CrossroadsSection.unsure);
      expect(find.text(CrossroadsSection.noRush), findsNothing);
    });
  });

  group('법원 전에 할 수 있는 것', () {
    testWidgets('앞쪽 계단이 비어 있지 않다', (tester) async {
      // 여기가 비면 이 앱은 소송 안내서가 된다.
      await openResult(tester);
      await choose(tester, CrossroadsSection.beforeCourt);

      expect(find.text('내용증명'), findsWidgets);
      expect(find.text('공정증서'), findsWidgets);
    });

    testWidgets('순서를 권하지 않는다', (tester) async {
      await openResult(tester);
      await choose(tester, CrossroadsSection.beforeCourt);

      expect(find.text(_StepsHint.text), findsWidgets);
      // 「~가 더 낫습니다」류는 없다.
      expect(find.textContaining('더 낫'), findsNothing);
      expect(find.textContaining('먼저 하'), findsNothing);
    });

    testWidgets('내용증명 비용이 구성으로 나온다 — 총액은 안 낸다', (tester) async {
      // 장수가 우편요금 구간과 등본 매수를 **동시에** 움직인다. 모르는 것을
      // 더해 하나의 숫자로 내놓으면 그건 계산이 아니라 짐작이다.
      await openResult(tester);
      await choose(tester, CrossroadsSection.beforeCourt);

      expect(find.text('2,400원'), findsWidgets); // 등기
      expect(find.text('1,300원'), findsWidgets); // 내용증명
      expect(find.text('470원 ~ 590원'), findsWidgets); // 우편요금 — 범위 그대로
      expect(find.text(FeeScheduleView.title), findsWidgets);
      // 더한 값이 어디에도 없다.
      expect(find.textContaining('합계'), findsNothing);
      expect(find.text('5,600원'), findsNothing);
    });

    testWidgets('공정증서에 「그 문구가 빠지면 그냥 종이」가 붙는다', (tester) async {
      // 공증만 받고 「강제집행을 승낙한다」는 취지가 없으면 헛일이다.
      // **이 한 줄이 제일 중요하다.**
      await openResult(tester);
      await choose(tester, CrossroadsSection.court);
      await choose(tester, CrossroadsSection.beforeCourt);

      expect(find.textContaining('그 문구가 빠지면 그냥 종이'), findsOneWidget);
    });

    testWidgets('법원 쪽에는 조정이 있다', (tester) async {
      await openResult(tester);
      await choose(tester, CrossroadsSection.court);

      expect(find.text('민사조정'), findsWidgets);
      expect(find.text('제소전화해'), findsWidgets);
    });
  });

  group('아직 못 정한 사람', () {
    testWidgets('재촉하지 않고 기간이 있다는 것만 알린다', (tester) async {
      await openResult(tester);
      await choose(tester, CrossroadsSection.unsure);

      expect(find.text(CrossroadsSection.noRush), findsOneWidget);
      expect(find.text(CrossroadsSection.deadlineHint), findsOneWidget);
      expect(find.textContaining('빨리'), findsNothing);
      expect(find.textContaining('서두르'), findsNothing);
    });

    testWidgets('물어볼 곳이 함께 온다', (tester) async {
      // 창구는 데이터에서 온다. 코드에 기관명·번호를 적지 않는다.
      await openResult(tester);
      await choose(tester, CrossroadsSection.unsure);

      expect(find.text('132'), findsWidgets);
    });
  });
}

/// `_Steps.hint` 는 private 이라 값만 옮겨 적는다. 바뀌면 이 테스트가 깨진다.
abstract final class _StepsHint {
  static const String text = '순서대로 해야 하는 것은 아니에요. 조건을 보고 고르세요.';
}
