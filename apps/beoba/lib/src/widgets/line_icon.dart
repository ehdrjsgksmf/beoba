import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// **단색 선 아이콘.** 이모지를 뺐다(DECISIONS 286번).
///
/// 공통 — viewBox 0 0 24 24 · 채움 없음 · 선 currentColor · 두께 1.8 · 둥근 끝.
/// 그림은 받은 SVG 를 글자 그대로 옮겼다. 패키지를 들이지 않고 필요한 명령만
/// 읽는다(M L H V C S A Z 와 그 소문자).
///
/// **어느 묶음에 어느 그림인지는 데이터가 정한다** — `groups.json` 의 `icon` 이
/// 여기 열쇠를 가리킨다. 열쇠가 없으면 그림을 안 그린다(지어 그리지 않는다).
abstract final class LineIcons {
  static const Map<String, List<LineShape>> shapes = {
    // 일하다 생긴 일
    'briefcase': [
      LineRect(2.5, 7.5, 19, 12.5, 2.4),
      LinePath('M9 7.5V5.6a1.6 1.6 0 0 1 1.6-1.6h2.8A1.6 1.6 0 0 1 15 5.6v1.9'),
      LinePath('M2.5 12.6h19'),
    ],
    // 살던 집 문제
    'house': [
      LinePath('M3.4 10.6L12 3.4l8.6 7.2'),
      LinePath('M5.6 12.2v7.9h12.8v-7.9'),
      LinePath('M10 20.1v-4.9h4v4.9'),
    ],
    // 사고파는 일
    'bag': [
      LinePath('M4.6 8.2h14.8l-1.2 11.1a1.6 1.6 0 0 1-1.6 1.4H7.4a1.6 1.6 0 0 1-1.6-1.4z'),
      LinePath('M8.8 8.2V6.4a3.2 3.2 0 0 1 6.4 0v1.8'),
    ],
    // 돈을 받거나 갚는 일
    'banknote': [
      LineRect(2.5, 6.2, 19, 11.6, 2.4),
      LineCircle(12, 12, 2.7),
      LinePath('M6.2 9.6v4.8M17.8 9.6v4.8'),
    ],
    // 누가 나를 속였을 때
    'alert-bubble': [
      LinePath('M20.4 12.5c0 3.8-3.75 6.9-8.4 6.9a10 10 0 0 1-2.6-.34l-5.2 1.5 1.1-3.6a6.5 6.5 0 0 1-1.7-4.46c0-3.81 3.75-6.9 8.4-6.9s8.4 3.09 8.4 6.9z'),
      LinePath('M12 9.3v3.5'),
      LinePath('M12 15.3h.01'),
    ],
    // 가족과 안전
    'shield': [
      LinePath('M12 3.5l7 2.6v5.3c0 4.2-2.85 7.6-7 8.9-4.15-1.3-7-4.7-7-8.9V6.1z'),
      LinePath('M9.3 12.1l2 2 3.5-3.7'),
    ],
  };
}

/// 그림 한 조각.
sealed class LineShape {
  const LineShape();
  Path toPath();
}

class LineRect extends LineShape {
  const LineRect(this.x, this.y, this.w, this.h, this.r);
  final double x, y, w, h, r;
  @override
  Path toPath() => Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), Radius.circular(r)));
}

class LineCircle extends LineShape {
  const LineCircle(this.cx, this.cy, this.r);
  final double cx, cy, r;
  @override
  Path toPath() =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

class LinePath extends LineShape {
  const LinePath(this.d);
  final String d;
  @override
  Path toPath() => parseSvgPath(d);
}

/// SVG `d` 를 읽는다. 받은 그림에 나오는 명령만 — M L H V C S A Z.
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  double? lastC2x, lastC2y;

  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final upper = cmd.toUpperCase();
    switch (upper) {
      case 'M':
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        lastC2x = null;
        // 이어지는 좌표쌍은 선이다(SVG 규칙).
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.lineTo(x, y);
        lastC2x = null;
      case 'H':
        x = (rel ? x : 0) + next();
        path.lineTo(x, y);
        lastC2x = null;
      case 'V':
        y = (rel ? y : 0) + next();
        path.lineTo(x, y);
        lastC2x = null;
      case 'C':
        final x1 = (rel ? x : 0) + next(), y1 = (rel ? y : 0) + next();
        final x2 = (rel ? x : 0) + next(), y2 = (rel ? y : 0) + next();
        final ex = (rel ? x : 0) + next(), ey = (rel ? y : 0) + next();
        path.cubicTo(x1, y1, x2, y2, ex, ey);
        lastC2x = x2;
        lastC2y = y2;
        x = ex;
        y = ey;
      case 'S':
        final x1 = lastC2x == null ? x : 2 * x - lastC2x;
        final y1 = lastC2y == null ? y : 2 * y - lastC2y;
        final x2 = (rel ? x : 0) + next(), y2 = (rel ? y : 0) + next();
        final ex = (rel ? x : 0) + next(), ey = (rel ? y : 0) + next();
        path.cubicTo(x1, y1, x2, y2, ex, ey);
        lastC2x = x2;
        lastC2y = y2;
        x = ex;
        y = ey;
      case 'A':
        final rx = next(), ry = next(), rotation = next();
        final largeArc = next() != 0, sweep = next() != 0;
        final ex = (rel ? x : 0) + next(), ey = (rel ? y : 0) + next();
        path.arcToPoint(
          Offset(ex, ey),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        x = ex;
        y = ey;
        lastC2x = null;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        lastC2x = null;
      default:
        throw FormatException('읽지 못하는 SVG 명령: $cmd', d);
    }
  }
  return path;
}

/// 선 아이콘 하나. 없는 열쇠면 빈자리.
class LineIcon extends StatelessWidget {
  const LineIcon(this.name, {this.size = 22, this.color, super.key});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final shapes = LineIcons.shapes[name];
    if (shapes == null) return SizedBox(width: size, height: size);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LineIconPainter(shapes, color ?? BeobaColors.brand),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  const _LineIconPainter(this.shapes, this.color);

  final List<LineShape> shapes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final shape in shapes) {
      canvas.drawPath(shape.toPath(), paint);
    }
  }

  @override
  bool shouldRepaint(_LineIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shapes != shapes;
}

/// 아이콘 타일 — 42×42 · 둥글기 13 · 강조 옅은 면 · 아이콘 22 강조색.
class IconTile extends StatelessWidget {
  const IconTile(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BeobaColors.brandSoft,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusIcon),
      ),
      child: LineIcon(name, color: BeobaColors.brand),
    );
  }
}
