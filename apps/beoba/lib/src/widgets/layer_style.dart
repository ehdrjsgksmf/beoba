import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../layers/legal_layer.dart';
import '../safety/safe_text.dart';

/// 층별 색·라벨·배지 모양.
///
/// **색만으로 정보를 전달하지 않는다.** 한글 라벨을 항상 함께 단다.
///
/// `layer_block.dart` 안에 숨어 있었는데 근거 조문 카드도 같은 표시를 쓴다.
/// 조문 원문을 접어도 **🟢 라벨은 접히지 않는다** — 그게 우리 약속이라
/// 라벨 문자열이 두 벌이 되면 안 된다.
///
/// ## 2026-09-16 — 그림을 뺐다 (DECISIONS 286번)
///
/// 초록 네모에 체크(·망치)가 들어가면 「다 했다」로 읽힌다 — 체크박스의 문법이다.
/// **글자만 남긴 배지**로 바꿨다.
///
/// ★★ **색을 빼도 셋이 갈려야 한다** — 채움 · 옅음 · 점선. 색맹인 분과 흑백
/// 출력 둘 다에 걸리는 자리다. 받은 색표대로 두면 법(#E6F6EF)과 적용(#FFF6E5)의
/// 면이 흑백에서 1.04:1 로 **같아진다.** 그래서 법 배지만 **진짜로 채웠다** —
/// 진한 초록 면에 흰 글자(5.1:1). `layer_badge_grayscale_test` 가 잰다.
class LayerStyle {
  const LayerStyle({
    required this.label,
    required this.color,
    required this.background,
    required this.badgeFill,
    required this.badgeText,
    this.badgeBorder,
    this.badgeBorderDashed = false,
  });

  final String label;

  /// 층의 글자색 — 배지 밖에서 그 층의 말을 쓸 때(안내 상자 글자 등).
  final Color color;

  /// 층의 옅은 면 — 배지 밖의 안내 상자.
  final Color background;

  /// 배지 면.
  final Color badgeFill;

  /// 배지 글자.
  final Color badgeText;

  /// 배지 테두리 1px. 없으면 안 두른다. **면 대비 3:1 이상.**
  final Color? badgeBorder;

  /// 테두리가 점선인가. 아니면 실선.
  final bool badgeBorderDashed;

  /// 🟢 채움.
  static const LayerStyle statute = LayerStyle(
    label: '법에 있는 내용',
    color: BeobaColors.green,
    background: BeobaColors.greenSoft,
    badgeFill: BeobaColors.green,
    badgeText: BeobaColors.bg,
  );

  /// 🟡 옅음 + 실선.
  static const LayerStyle likely = LayerStyle(
    label: '적용될 가능성',
    color: BeobaColors.legalMaybe,
    background: BeobaColors.amberSoft,
    badgeFill: BeobaColors.amberSoft,
    badgeText: BeobaColors.amber,
    badgeBorder: BeobaColors.badgeLine,
  );

  /// 🔴 흰 면 + 점선.
  static const LayerStyle unknown = LayerStyle(
    label: '확인 안 된 것',
    color: BeobaColors.red,
    background: BeobaColors.redSoft,
    badgeFill: BeobaColors.bg,
    badgeText: BeobaColors.ink3,
    badgeBorder: BeobaColors.badgeDash,
    badgeBorderDashed: true,
  );

  static LayerStyle of(LegalLayer layer) => switch (layer) {
        LegalLayer.statute => statute,
        LegalLayer.likely => likely,
        LegalLayer.unknown => unknown,
      };
}

/// 세 층 배지. **글자만** 있다 — 12.5px / 700 · 좌우 11 · 상하 5 · 둥글기 7.
///
/// ★ **셋은 면과 테두리를 같이 써서 갈린다** — 진한 면 / 옅은 면 + 실선 / 흰 면 + 점선.
/// 흑백에서 적용과 확인 안 됨의 면이 거의 같아서(1.07) 면만으로는 안 갈렸다.
/// 테두리는 전경으로 그려 자리를 안 늘린다.
///
/// [compact] 는 조문 카드처럼 한 화면에 여러 번 되풀이되는 자리 — 좌우 8 · 상하 3.
/// 글자 크기 · 색 · 테두리는 같다.
class LayerBadge extends StatelessWidget {
  const LayerBadge({
    required this.style,
    this.where = 'LayerBadge.label',
    this.compact = false,
    super.key,
  });

  final LayerStyle style;
  final String where;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: style.badgeFill,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusBadge),
      ),
      child: SafeText(
        style.label,
        where: where,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: style.badgeText,
              height: 1.2,
            ),
      ),
    );

    final border = style.badgeBorder;
    if (border == null) return label;
    return CustomPaint(
      foregroundPainter:
          _BadgeBorderPainter(color: border, dashed: style.badgeBorderDashed),
      child: label,
    );
  }
}

/// 1px 둥근 네모 — 실선 또는 점선. Flutter 에는 점선 테두리가 없어서 그린다.
class _BadgeBorderPainter extends CustomPainter {
  const _BadgeBorderPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  static const double dash = 3;
  static const double gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(BeobaSpace.radiusBadge),
    ).deflate(0.5);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_BadgeBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
