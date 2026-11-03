import 'package:beoba/src/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/domain_scenarios.dart';
import 'support/test_app.dart';

/// **글자를 키워 쓰는 사람의 화면을 여섯 분야 전부에서 본다.**
///
/// `text_scale_test` 가 배율 2.0 을 보지만 **떼인 돈 한 갈래**뿐이었다.
/// 나머지 다섯 분야의 결과·상세 화면은 배율 1.0 말고는 아무도 안 봤다.
///
/// 실제로 여기서 하나 나왔다 — 🟡 의 근거 칩(`_BasisChips`)이 배율 1.3 부터
/// 오른쪽으로 잘렸다. **근거를 보여주는 칩에서 근거가 잘려 나갔고**, 잘린
/// 글자는 화면에 안 보이니 아무도 몰랐다.
///
/// 세로 길이(밀도)는 여기서 안 본다 — `result_density_test` 의 몫이고,
/// 배율에 따라 늘어나는 것이 당연한 축이다. 여기서 보는 것은 **가로**다.
/// 세로는 굴리면 되지만 가로는 굴릴 데가 없다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 흔한 저가 안드로이드 폭. 좁을수록 먼저 넘친다.
  const narrow = Size(360, 780);

  // **갈래 표는 `support/domain_scenarios.dart` 한 곳에 있다.** 여기 따로
  // 두면 분야가 늘 때 이 파일만 뒤처진다 — 산재가 처음부터 안 들어와 있었고
  // 양육비도 안 들어왔다. 열셋 중 열이었다.
  const scenarios = screenScenarios;

  for (final scale in const [1.3, 1.5, 2.0]) {
    for (final entry in scenarios.entries) {
      final (domainId, answers) = entry.value;

      testWidgets('배율 $scale — ${entry.key}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = narrow;
        addTearDown(tester.view.reset);

        final container = await pumpApp(tester, textScale: scale);
        seedAnswers(container, domainId, answers: answers);

        for (final route in [
          Routes.result(domainId),
          Routes.resultDetail(domainId),
        ]) {
          container.read(routerProvider).go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$route 첫 화면');

          // **끝까지 굴린다.** 화면 밖 항목은 아예 안 그려져서, 안 굴리면
          // 넘치는 자리가 있어도 검사가 못 본다.
          for (var i = 0; i < 12; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$route 아래쪽');
          }
        }
      });
    }
  }

  test('★ 분야를 몇 개 돌았는지 센다', () {
    // **가로는 굴릴 데가 없다.** 한 분야가 빠지면 그 분야의 배율 2.0 을
    // 아무도 안 본다 — 산재와 중고거래와 양육비가 그랬다.
    expectsEveryDomain(
      'result_scale_test 의 screenScenarios',
      [for (final entry in scenarios.values) entry.$1],
    );
  });
}
