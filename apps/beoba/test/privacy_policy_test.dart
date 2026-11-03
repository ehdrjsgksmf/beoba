import 'dart:io';

import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/data/asset_policy_source.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/privacy/privacy_screen.dart';
import 'package:beoba/src/widgets/privacy_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 방침이 **앱 안에서도 열리는가**, 그리고 **우리끼리 보는 기록이 안 새는가**.
///
/// 굽는 쪽이 원본과 어긋났는지는 검사 (ah) 가 본다. 여기서 보는 것은 다르다 —
/// 구운 것이 **실제로 번들에 실려 화면까지 닿는가**이다. 자산 경로는 검사기가
/// 못 본다. `pubspec.yaml` 에서 한 줄만 빠져도 검사는 초록인데 화면은 빈다.
/// 방침 자산을 **화면을 세우기 전에** 읽는다.
///
/// 진짜 파일을 읽는 일이라 `runAsync` 밖에서는 끝나지 않는다 — 도메인 번들과
/// 복지 자료를 밖에서 읽어 넘기는 것과 같은 이유다.
Future<List<PolicyBlockData>> readPolicy(WidgetTester tester) async =>
    (await tester.runAsync(() => const AssetPolicySource().load()))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('개인정보처리방침 — 자산', () {
    test('번들에서 읽힌다', () async {
      const source = AssetPolicySource();
      final blocks = await source.load();

      expect(blocks, isNotEmpty);
      expect(blocks.first.kind, 'title');
      expect(
        blocks.map((b) => b.text),
        contains('9. 물어보실 곳'),
        reason: '마지막 절까지 실려야 한다',
      );
    });

    test('「만드는 사람에게」는 한 글자도 안 들어간다', () async {
      const source = AssetPolicySource();
      final blocks = await source.load();
      final all = blocks.map((b) => b.text).join('\n');

      // 우리끼리 보는 기록에만 나오는 말들이다. 하나라도 새면 화면에
      // 검사기 설명과 조문 항목표가 그대로 나간다.
      for (final leaked in const [
        '만드는 사람에게',
        '검사 (ah)',
        'DECISIONS',
        '제30조',
      ]) {
        expect(all, isNot(contains(leaked)), reason: leaked);
      }
    });

    test('굽지 않은 서식이 남아 있지 않다', () async {
      const source = AssetPolicySource();
      final blocks = await source.load();

      for (final block in blocks) {
        expect(block.text, isNot(contains('**')), reason: block.text);
        expect(block.text, isNot(startsWith('#')), reason: block.text);
        expect(block.text, isNot(startsWith('- ')), reason: block.text);
      }
    });
  });

  group('개인정보처리방침 — 정적 한 장', () {
    /// 스토어 심사자와 기관 담당자가 여는 자리다. **Flutter 없이 열려야 한다.**
    final page = File('web/privacy-policy.html');

    test('바깥에서 가져오는 것이 하나도 없다', () {
      final html = page.readAsStringSync().replaceAll(
            RegExp(r'<!--[\s\S]*?-->'),
            ' ',
          );

      expect(html, isNot(contains('http://')));
      expect(html, isNot(contains('https://')));
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains('<link')));
      expect(html, isNot(contains('@import')));
      expect(html, isNot(contains('<img')));
    });

    test('우리끼리 보는 기록이 안 들어간다', () {
      final html = page.readAsStringSync();
      expect(html, isNot(contains('만드는 사람에게')));
      expect(html, contains('9. 물어보실 곳'));
    });
  });

  group('개인정보처리방침 — 화면', () {
    testWidgets('전문이 그려진다', (tester) async {
      final container = await pumpApp(tester, policy: await readPolicy(tester));
      container.read(routerProvider).go(Routes.privacy);
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(find.textContaining('9. 물어보실 곳'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('배율 2.0 에서 끝까지 굴려도 넘치지 않는다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.reset);

      final container = await pumpApp(
        tester,
        textScale: 2,
        policy: await readPolicy(tester),
      );
      container.read(routerProvider).go(Routes.privacy);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '첫 화면');

      for (var i = 0; i < 20; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '아래쪽 $i');
      }
    });

    testWidgets('요약 시트에서 전문으로 갈 수 있다', (tester) async {
      await pumpApp(tester, policy: await readPolicy(tester));

      final more = find.text(HomeScreen.privacyMore);
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text(PrivacySheet.title), findsOneWidget);

      await tester.tap(find.text(PrivacySheet.fullLabel));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
