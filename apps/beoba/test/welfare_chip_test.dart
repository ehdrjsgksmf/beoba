import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/app/theme.dart';
import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/welfare_providers.dart';
import 'package:beoba/src/screens/welfare/welfare_chips.dart';
import 'package:beoba/src/welfare/welfare_match.dart';
import 'package:domain_data/domain_data.dart' show CentralWelfareCatalog;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 복지 알약 칩 — **누르면 두 숫자가 바로 바뀐다** (DECISIONS 289번).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  double of(Color c) => luminance(
      (c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());

  late CentralWelfareCatalog catalog;
  setUpAll(() async {
    catalog = await const AssetWelfareSource().loadCentral();
  });

  void narrow(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
  }

  group('흑백에서도 갈린다', () {
    testWidgets('★ 실제로 그려서 — 고른 면과 안 고른 면이 3:1 을 넘는다', (tester) async {
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
            child: Row(
              children: [
                WelfareChip(
                    label: '저소득', where: 't', selected: false, onTap: () {}),
                const SizedBox(width: 8),
                WelfareChip(
                    label: '장애인', where: 't', selected: true, onTap: () {}),
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
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return (data!.buffer.asUint8List(), image.width);
      }))!;
      final origin = tester.getTopLeft(find.byKey(key));

      double grayAt(Offset p) {
        final px = ((p.dx - origin.dx) * ratio).floor();
        final py = ((p.dy - origin.dy) * ratio).floor();
        final i = (py * width + px) * 4;
        return luminance(bytes[i], bytes[i + 1], bytes[i + 2]);
      }

      final off = tester.getRect(find.byType(WelfareChip).at(0));
      final on = tester.getRect(find.byType(WelfareChip).at(1));
      // 왼쪽 여백 안쪽 — 둥근 끝 안이고 글자에 안 닿는 자리.
      final offFill = grayAt(Offset(off.left + 8, off.center.dy));
      final onFill = grayAt(Offset(on.left + 8, on.center.dy));
      final measured = contrast(offFill, onFill);
      // ignore: avoid_print
      print('칩 흑백 — 안 고른 면 대 고른 면 ${measured.toStringAsFixed(2)}');
      expect(measured, greaterThanOrEqualTo(3));
    });

    test('글자는 제 면 위에서 4.5:1 을 넘는다', () {
      expect(contrast(of(BeobaColors.bg), of(BeobaColors.brand)),
          greaterThanOrEqualTo(4.5));
      expect(contrast(of(BeobaColors.ink2), of(BeobaColors.surfaceStrong)),
          greaterThanOrEqualTo(4.5));
      expect(contrast(of(BeobaColors.ink3), of(BeobaColors.surfaceStrong)),
          greaterThanOrEqualTo(4.5));
    });

    testWidgets('「+」는 안 고른 칩에만 보이고, 고르면 감추되 자리는 남는다', (tester) async {
      await pumpWidgetOnly(
        tester,
        Wrap(children: [
          WelfareChip(label: '저소득', where: 't', selected: false, onTap: () {}),
          WelfareChip(label: '저소득', where: 't', selected: true, onTap: () {}),
        ]),
      );
      final visibility = tester
          .widgetList<Visibility>(find.descendant(
            of: find.byType(WelfareChip),
            matching: find.byType(Visibility),
          ))
          .toList();
      expect(visibility.map((v) => v.visible), [true, false]);
      // 폭이 같다 — 누르면 뒤 칩이 밀리지 않는다.
      expect(tester.getSize(find.byType(WelfareChip).at(0)).width,
          tester.getSize(find.byType(WelfareChip).at(1)).width);
    });
  });

  group('누를 자리', () {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('★ 배율 $scale — 제일 긴 이름도 안 넘치고 칩마다 48 이상', (tester) async {
        narrow(tester);
        final names = {
          for (final s in catalog.services) ...s.households,
        }.toList();
        await pumpWidgetOnly(
          tester,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BeobaSpace.pageH),
            child: WelfareChipRow(
              names: names,
              picked: {names.first},
              where: 't',
              onToggle: (_) {},
            ),
          ),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        for (final chip in find.byType(WelfareChip).evaluate()) {
          final size = tester.getSize(find.byWidget(chip.widget));
          expect(size.height, greaterThanOrEqualTo(BeobaTapTarget.minimum));
          expect(size.width, greaterThanOrEqualTo(BeobaTapTarget.minimum));
        }
      });
    }
  });

  testWidgets('★ 스크린리더 — 상태가 같이 읽히고 「+」는 안 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWidgetOnly(
      tester,
      Wrap(children: [
        WelfareChip(label: '저소득', where: 't', selected: false, onTap: () {}),
        WelfareChip(label: '장애인', where: 't', selected: true, onTap: () {}),
      ]),
    );

    final off = tester.getSemantics(find.byType(WelfareChip).at(0));
    final on = tester.getSemantics(find.byType(WelfareChip).at(1));
    expect(off, isSemantics(isButton: true, hasSelectedState: true,
        isSelected: false));
    expect(on, isSemantics(isButton: true, hasSelectedState: true,
        isSelected: true));
    expect(off.label, isNot(contains('+')));
    expect(off.label, contains('저소득'));
    handle.dispose();
  });

  group('물음 화면 — 누르면 두 숫자가 바로 바뀐다', () {
    Future<void> openAsk(WidgetTester tester) async {
      narrow(tester);
      final container = await pumpApp(tester, welfare: catalog);
      container.read(routerProvider).go(Routes.welfare());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(WelfareChipRow),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    (int, int) shown(WidgetTester tester) {
      final line = tester.widget<WelfareSplitLine>(find.byType(WelfareSplitLine));
      return (line.first, line.folded);
    }

    (int, int) expected(WidgetTester tester) {
      final container = ProviderScope.containerOf(
          tester.element(find.byType(WelfareSplitLine)));
      final match = matchWelfare(
        catalog: catalog,
        answers: container.read(welfareAnswersProvider),
        today: container.read(todayProvider),
      );
      return (match.matched, match.folded.length);
    }

    testWidgets('★ 누르면 앞이 늘고 뒤가 준다 — 「좁아진다」가 아니다', (tester) async {
      await openAsk(tester);
      final before = shown(tester);
      expect(before, expected(tester));

      await tester.tap(find.text('저소득'));
      await tester.pump();
      final after = shown(tester);
      expect(after, expected(tester));
      expect(after.$1, greaterThan(before.$1));
      expect(after.$2, lessThan(before.$2));

      // 다시 누르면 풀린다.
      await tester.tap(find.text('저소득'));
      await tester.pump();
      expect(shown(tester), before);
    });

    testWidgets('★ 연달아 빨리 눌러도 숫자가 밀리지 않는다', (tester) async {
      await openAsk(tester);
      for (final name in ['저소득', '장애인', '다자녀', '장애인']) {
        await tester.tap(find.text(name));
        await tester.pump(const Duration(milliseconds: 16));
        expect(shown(tester), expected(tester), reason: '$name 을 누른 직후');
      }
    });

    testWidgets('★ 눌러도 칩 순서와 자리가 안 바뀐다', (tester) async {
      await openAsk(tester);
      final chips = find.byType(WelfareChip);
      final before = [
        for (var i = 0; i < chips.evaluate().length; i++)
          (tester.widget<WelfareChip>(chips.at(i)).label,
              tester.getTopLeft(chips.at(i))),
      ];

      await tester.tap(find.text('장애인'));
      await tester.pumpAndSettle();

      final after = [
        for (var i = 0; i < chips.evaluate().length; i++)
          (tester.widget<WelfareChip>(chips.at(i)).label,
              tester.getTopLeft(chips.at(i))),
      ];
      expect(after, before);
    });

    testWidgets('물결이 없다', (tester) async {
      await openAsk(tester);
      expect(
        find.descendant(
            of: find.byType(WelfareChip), matching: find.byType(InkWell)),
        findsNothing,
      );
    });
  });
}
