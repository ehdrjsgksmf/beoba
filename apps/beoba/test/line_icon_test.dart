import 'dart:convert';
import 'dart:io';

import 'package:beoba/src/widgets/line_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repo.dart';

/// 이모지를 뺀 자리에 선 아이콘이 선다(DECISIONS 286번).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final groups = (jsonDecode(File(
    '${repoRoot().path}/packages/domain_data/assets/groups/groups.json',
  ).readAsStringSync()) as Map<String, dynamic>)['groups'] as List<dynamic>;

  test('★ 묶음의 icon 은 이모지가 아니라 그림 열쇠다 — 적힌 열쇠는 전부 그림이 있다', () {
    final emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
    for (final g in groups.cast<Map<String, dynamic>>()) {
      final icon = g['icon'] as String?;
      if (icon == null) continue;
      expect(emoji.hasMatch(icon), isFalse, reason: '${g['id']} 에 이모지: $icon');
      expect(LineIcons.shapes.containsKey(icon), isTrue,
          reason: '${g['id']} 의 열쇠 「$icon」 에 그림이 없습니다');
    }
  });

  test('★ 화면에 서는 묶음은 그림이 있어야 한다 — 분야가 붙는 날 그림 없이 서지 않게', () {
    // 분야가 0개인 묶음은 화면에 안 선다(DECISIONS 228). 그래서 「다치거나 사고가
    // 났을 때」 · 「관공서와 부딪혔을 때」는 그림 없이 비워 두었다. 그 묶음에
    // 분야가 붙으면 여기서 걸린다 — 그림 없이 서면 아무도 모른다(DECISIONS 286).
    final dir = Directory('${repoRoot().path}/packages/domain_data/assets/domains');
    final used = <String>{};
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.json') || name.startsWith('_')) continue;
      final g = (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['group'];
      if (g is String) used.add(g);
    }
    expect(used, isNotEmpty, reason: '분야에서 묶음을 하나도 못 읽었습니다');
    for (final g in groups.cast<Map<String, dynamic>>()) {
      if (!used.contains(g['id'])) continue;
      final icon = g['icon'] as String?;
      expect(icon, isNotNull, reason: '「${g['name']}」 이 화면에 서는데 icon 이 없습니다');
      expect(LineIcons.shapes.containsKey(icon), isTrue,
          reason: '「${g['name']}」 의 열쇠 「$icon」 에 그림이 없습니다');
    }
  });

  test('받은 SVG 가 전부 읽히고 24×24 안에 든다', () {
    for (final entry in LineIcons.shapes.entries) {
      for (final shape in entry.value) {
        final bounds = shape.toPath().getBounds();
        expect(bounds.left, greaterThanOrEqualTo(0), reason: entry.key);
        expect(bounds.top, greaterThanOrEqualTo(0), reason: entry.key);
        expect(bounds.right, lessThanOrEqualTo(24), reason: entry.key);
        expect(bounds.bottom, lessThanOrEqualTo(24), reason: entry.key);
      }
    }
  });

  test('호(A)와 이어지는 좌표쌍(암묵 L · c)을 읽는다', () {
    // 방패 — 「c0 4.2-2.85 7.6-7 8.9-4.15-1.3-7-4.7-7-8.9」는 c 하나에 좌표가 두 벌이다.
    final shield = parseSvgPath('M12 3.5l7 2.6v5.3c0 4.2-2.85 7.6-7 8.9-4.15-1.3-7-4.7-7-8.9V6.1z');
    final b = shield.getBounds();
    expect(b.left, closeTo(5, 0.01));
    expect(b.right, closeTo(19, 0.01));
    expect(b.top, closeTo(3.5, 0.01));
    // 가방 손잡이 — 반원 호가 위로 솟는다(y 가 6.4 보다 작아진다).
    final bag = parseSvgPath('M8.8 8.2V6.4a3.2 3.2 0 0 1 6.4 0v1.8');
    expect(bag.getBounds().top, lessThan(6.4));
  });

  testWidgets('타일은 42×42 이고 모르는 열쇠면 그림 없이 자리만 둔다', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconTile('house'),
        IconTile('없는열쇠'),
      ])),
    ));
    expect(tester.getSize(find.byType(IconTile).first), const Size(42, 42));
    expect(tester.takeException(), isNull);
  });
}
