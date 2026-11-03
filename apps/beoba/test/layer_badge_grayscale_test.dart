import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:beoba/src/app/theme.dart';
import 'package:beoba/src/widgets/layer_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// ★★ **세 층 배지는 색을 빼도 서로 갈려야 한다 — 면이든 테두리든.**
///
/// 색맹인 분과 흑백 출력 둘 다에 걸리는 자리다. 실제로 그려서 흑백으로 바꾸고
/// 픽셀을 잰다(DECISIONS 286번).
///
/// 처음 시험은 **면만 보고** 통과시켰다. 그런데 흑백에서 적용(옅은 노랑)과 확인
/// 안 됨(흰)의 면은 1.07 로 거의 같고, 둘을 가르던 점선은 1.64 라 사실상 안 보였다.
/// 그래서 셋을 면과 테두리로 같이 가르고, 시험도 **둘 중 하나로 확실히 갈리는지**를 본다.
///
/// ```
/// 법에 있는 내용    진한 면 · 흰 글자 · 테두리 없음
/// 적용될 가능성     옅은 면 · 실선 1px
/// 확인 안 된 것     흰 면 · 점선 1px
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const styles = [LayerStyle.statute, LayerStyle.likely, LayerStyle.unknown];
  const names = ['법에 있는 내용', '적용될 가능성', '확인 안 된 것'];

  // sRGB → 상대 밝기(WCAG). 흑백으로 바꾼 값이다.
  double luminance(int r, int g, int b) {
    double c(int v) {
      final s = v / 255;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b);
  }

  double contrast(double a, double b) =>
      (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

  for (final compact in [false, true]) {
    testWidgets('흑백으로 바꿔도 셋이 서로 갈린다 — 면이든 테두리든'
        '${compact ? ' (조문 카드의 작은 배지)' : ''}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 200);
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: buildBeobaTheme(),
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: BeobaColors.bg,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in styles) ...[
                  LayerBadge(style: s, compact: compact),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ));

      const ratio = 4.0;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final (bytes, width) = (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: ratio);
        final data =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return (data!.buffer.asUint8List(), image.width);
      }))!;
      final origin = tester.getTopLeft(find.byKey(key));

      double grayAt(double lx, double ly) {
        final px = ((lx - origin.dx) * ratio).floor();
        final py = ((ly - origin.dy) * ratio).floor();
        final i = (py * width + px) * 4;
        return luminance(bytes[i], bytes[i + 1], bytes[i + 2]);
      }

      final page = luminance(255, 255, 255);
      final fills = <double>[];
      final kinds = <String>[];

      for (var k = 0; k < styles.length; k++) {
        final rect = tester.getRect(find.byType(LayerBadge).at(k));
        // 면 — 왼쪽 여백 안쪽, 테두리와 글자에 안 닿는 자리.
        final fill = grayAt(rect.left + 4, rect.center.dy);

        // 테두리 — 윗변(선 두께 1px 의 한가운데)을 따라 훑는다.
        final edgeY = rect.top + 0.5;
        final samples = <double>[
          for (var x = rect.left + 10; x < rect.right - 10; x += 1 / ratio)
            grayAt(x, edgeY),
        ];
        final darkest = samples.reduce(math.min);
        final edge = contrast(darkest, fill);
        final covered = samples
                .where((g) => contrast(g, fill) >= edge * 0.6 && edge > 1.2)
                .length /
            samples.length;
        final kind = edge < 1.2
            ? '없음'
            : covered >= 0.85
                ? '실선'
                : '점선';
        fills.add(fill);
        kinds.add(kind);

        // ignore: avoid_print
        print('${names[k]}${compact ? ' (작은)' : ''} — 면이 화면과 '
            '${contrast(fill, page).toStringAsFixed(2)} · 테두리 $kind '
            '(면 대비 ${edge.toStringAsFixed(2)} · 덮은 비율 '
            '${(covered * 100).round()}%)');

        if (kind != '없음') {
          expect(edge, greaterThanOrEqualTo(3),
              reason: '${names[k]} 의 테두리가 흑백에서 면 대비 3:1 을 못 넘습니다');
        }
      }

      expect(kinds, ['없음', '실선', '점선'],
          reason: '테두리 모양이 설계와 다릅니다');

      // ★ 셋이 **서로** 갈린다 — 면이 3:1 이상 다르거나, 테두리 모양이 다르다.
      for (var a = 0; a < 3; a++) {
        for (var b = a + 1; b < 3; b++) {
          final byFill = contrast(fills[a], fills[b]) >= 3;
          final byBorder = kinds[a] != kinds[b];
          expect(byFill || byBorder, isTrue,
              reason: '${names[a]} 와 ${names[b]} 가 흑백에서 안 갈립니다');
        }
      }
    });
  }

  test('받은 색표 그대로였다면 — 법과 적용의 면이 흑백에서 같아진다(기록)', () {
    double hex(int c) =>
        luminance((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
    expect(contrast(hex(0xE6F6EF), hex(0xFFF6E5)), lessThan(1.1));
    // 받은 점선 #C4CBD3 은 흰 면 대비 1.6 — 흑백에서 안 보였다.
    expect(contrast(hex(0xC4CBD3), hex(0xFFFFFF)), lessThan(3));
  });

  test('배지 글자는 제 면 위에서 4.5:1 · 테두리는 3:1 을 넘는다', () {
    double of(Color c) => luminance(
        (c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());
    for (final s in styles) {
      expect(contrast(of(s.badgeText), of(s.badgeFill)),
          greaterThanOrEqualTo(4.5),
          reason: s.label);
      final border = s.badgeBorder;
      if (border != null) {
        expect(contrast(of(border), of(s.badgeFill)), greaterThanOrEqualTo(3),
            reason: '${s.label} 테두리');
      }
    }
  });
}
