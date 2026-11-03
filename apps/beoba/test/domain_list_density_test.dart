import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **열 개가 되면 목록도 밀도다.**
///
/// 결과 화면은 `result_density_test` 가 재는데, 분야 목록은 아무도 안 쟀다.
/// 그 사이 분야가 여섯에서 열로 늘었고, 이번에 카드마다 **작은 글씨 한 줄**이
/// 더 붙었다(DECISIONS 194번). 한 줄이 열 장이면 한 화면이 통째로 늘어난다.
///
/// ★ **열둘에서 3.469 로 상한(3.5)에 닿아 묶음으로 바꿨다**(DECISIONS 237번).
/// 첫 화면은 묶음 줄만 서고 카드는 묶음 안에 있다. 묶음 쪽 값은
/// `domain_group_test` 가 재고, 여기서는 **첫 화면과 카드 자체**를 본다.
///
/// 여기서 보는 것은 세로다. 가로 넘침은 `text_scale_test` 가 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 360.0;
  const height = 780.0;

  /// 배율 1.0 에서의 상한.
  ///
  /// **결과 화면(4.05)보다 짧아야 한다.** 결과는 읽는 화면이고 목록은 고르는
  /// 화면이라, 고르는 데 네 번 넘기게 하면 고르기 전에 지친다.
  ///
  /// 분야가 더 늘면 이 값이 아니라 **카드를 줄여야 한다** — 작은 글씨를
  /// 데이터로만 두거나(`visibleTerms`), 설명 줄을 접거나.
  const maxScreens = 3.5;

  /// 배율이 올라갈 때 늘어나도 되는 한계. 결과 화면과 같은 축이다.
  const maxGrowth = 1.9;

  double contentHeight(WidgetTester tester) {
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    return position.maxScrollExtent + position.viewportDimension;
  }

  Future<double> openList(WidgetTester tester, double scale) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(width, height);
    addTearDown(tester.view.reset);

    final container = await pumpApp(tester, textScale: scale);
    container.read(routerProvider).go(Routes.domains);
    await tester.pumpAndSettle();
    return contentHeight(tester) / height;
  }

  testWidgets('분야 목록 — 배율 1.0 · 1.3 · 1.5', (tester) async {
    final at = <double, double>{};
    for (final scale in const [1.0, 1.3, 1.5]) {
      at[scale] = await openList(tester, scale);
    }
    final growth = at[1.5]! / at[1.0]!;

    // ignore: avoid_print
    print('밀도 분야 목록 — 1.0 ${at[1.0]!.toStringAsFixed(2)} · '
        '1.3 ${at[1.3]!.toStringAsFixed(2)} · '
        '1.5 ${at[1.5]!.toStringAsFixed(2)} · '
        '증가율 ${growth.toStringAsFixed(2)}배');

    expect(
      at[1.0],
      lessThanOrEqualTo(maxScreens),
      reason: '분야 목록이 ${at[1.0]!.toStringAsFixed(2)}화면입니다. '
          '상한을 올리지 말고 카드를 줄이세요',
    );
    expect(
      growth,
      lessThanOrEqualTo(maxGrowth),
      reason: '배율 1.5 에서 ${growth.toStringAsFixed(2)}배가 됩니다',
    );
  });

  testWidgets('★ 되돌릴 수 없는 것이 위다 — 다만 화면에는 안 적는다', (tester) async {
    final container = await pumpApp(tester);
    final order = [
      for (final domain
          in container.read(domainBundleProvider).requireValue.selectable)
        domain.id,
    ];

    expect(
      order.take(5).toList(),
      const [
        'voice_phishing',
        'unfair_dismissal',
        // 산재는 부당해고 바로 다음이다. 시효가 3년이라 부당해고(3개월)보다
        // 아래이고, 무르기(7일·14일)보다는 위다.
        'work_injury',
        'consumer_withdrawal',
        'installment_purchase',
      ],
      reason: '되돌릴 수 없는 것이 위여야 합니다',
    );

    container.read(routerProvider).go(Routes.domains);
    await tester.pumpAndSettle();
    // **순서를 우리가 정했다고 쓰지 않는다.** 아래에 있는 사람이 덜 급한
    // 줄로 읽는다(DECISIONS 196번).
    for (final word in const ['급한 순서', '급한 것부터', '위에서부터 급']) {
      expectNoScreenText(tester, word);
    }
  });

  testWidgets('작은 글씨는 셋까지만 화면에 나온다', (tester) async {
    // **카드는 이제 묶음 안에 있다.** 묶음마다 열어서 본다 — 첫 화면에서만
    // 보면 「작은 글씨가 하나도 없다」로 통과해 버린다.
    final container = await pumpApp(tester);
    final bundle = container.read(domainBundleProvider).requireValue;

    for (final (group, domains) in bundle.grouped) {
      if (group == null) continue;
      container.read(routerProvider).go(Routes.domainGroup(group.id));
      await tester.pumpAndSettle();

      for (final domain in domains) {
        final shown = domain.searchTerms.take(3).join(' · ');
        expectScreenText(tester, shown, reason: '${domain.id} 의 작은 글씨');
        // 넷째부터는 데이터에만 있다. 걸림말로는 그대로 쓴다.
        if (domain.searchTerms.length > 3) {
          expectNoScreenText(tester, domain.searchTerms[3]);
        }
      }
    }
  });
}
