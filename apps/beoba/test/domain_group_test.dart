import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/domain_select/domain_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 분야 묶음.
///
/// **목록이 꽉 찼다.** 열두 분야에서 3.469화면이고 상한이 3.5다. 이름을 줄여
/// 버티는 것은 한두 개가 한계인데 분야는 아홉 개가 더 들어온다.
///
/// 열세 번째(양육비)가 들어와 `family` 가 처음 섰는데 **묶음 줄은 0.928화면
/// 그대로다.** 묶음만 분야 수와 무관한 값을 갖는다는 것이 실제로 지켜졌다.
///
/// 검색어 줄을 빼는 길도 재 봤다 — 2.797화면. 그런데 **그 길은 스물둘을 못
/// 버틴다**(5.021화면). 카드당 43.6px 을 버는데 그 이득이 **카드 수에 비례해
/// 같이 늘기** 때문이다. 묶음만 분야 수와 무관한 값을 갖는다.
///
/// ```
///                       12개      22개
/// 카드 목록             3.469     6.262
/// 검색어 줄 뺀 카드      2.797     5.021
/// 묶음 줄               0.93      0.93
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 360.0;
  const height = 780.0;

  /// 카드 목록과 같은 상한을 쓴다. 묶음이라고 느슨하게 두지 않는다.
  const maxScreens = 3.5;

  late DomainBundle real;
  setUpAll(() async => real = await loadTestBundle());

  double screens(WidgetTester tester) {
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    return (position.maxScrollExtent + position.viewportDimension) / height;
  }

  Future<double> open(
    WidgetTester tester,
    String location, {
    double scale = 1,
    bool plain = false,
    DomainBundle? bundle,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(width, height);
    addTearDown(tester.view.reset);

    final container =
        await pumpApp(tester, textScale: scale, overrideBundle: bundle);
    if (plain) container.read(plainModeProvider.notifier).toggle();
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
    return screens(tester);
  }

  /// 진짜 분야를 복사해 스물둘로 채운다. **카드가 진짜라서 잰 값도 진짜다.**
  DomainBundle stuffed(int total) {
    final base = real.selectable;
    final domains = {...real.domains};
    for (var i = 0; domains.length < total + 1; i++) {
      final from = base[i % base.length];
      final id = 'zz_fake_$i';
      domains[id] = from.copyWith(id: id, homeOrder: 1000 + i);
    }
    return DomainBundle(
      domains: domains,
      crisis: real.crisis,
      reports: real.reports,
      holidays: real.holidays,
      glossary: real.glossary,
      courts: real.courts,
      groupCatalog: real.groupCatalog,
    );
  }

  group('★ 묶음 규칙', () {
    test('★ 한 분야는 한 묶음에만 든다', () {
      // 칸이 하나뿐이라 구조로 불가능하다. **그래도 센다** — 나중에 누가
      // 묶음 쪽에 분야 목록을 적으면 그때 이 검사가 먼저 운다.
      final seen = <String, String>{};
      for (final (group, domains) in real.grouped) {
        for (final domain in domains) {
          expect(
            seen.containsKey(domain.id),
            isFalse,
            reason: '${domain.id} 가 ${seen[domain.id]} 와 '
                '${group?.id} 두 군데에 있습니다',
          );
          seen[domain.id] = '${group?.id}';
        }
      }
      expect(seen.length, real.selectable.length,
          reason: '묶음에서 사라진 분야가 있습니다');
    });

    test('★ 분야가 0개인 묶음은 화면에 안 선다', () {
      // 눌러서 0건이 되는 입구는 세우지 않는다(DECISIONS 228번).
      for (final (group, domains) in real.grouped) {
        expect(domains, isNotEmpty, reason: '${group?.id} 가 비었습니다');
      }

      // 여덟을 적어 두었지만 지금 서는 것은 그중 일부다. 나머지는 그 분야가
      // 들어오는 날 저절로 선다 — 코드를 고칠 일이 없다.
      final standing = {
        for (final (group, _) in real.grouped)
          if (group != null) group.id,
      };
      expect(standing.length, lessThan(real.groupCatalog.groups.length));
      expect(standing, containsAll(<String>['work', 'trade', 'money']));
    });

    test('묶음 없는 분야는 사라지지 않는다', () {
      // 묶음을 안 적은 분야가 생기면 목록 끝에 카드째 나온다.
      final orphan = real.byId('debt_recovery').copyWith(group: null);
      final bundle = DomainBundle(
        domains: {...real.domains, 'debt_recovery': orphan},
        crisis: real.crisis,
        reports: real.reports,
        holidays: real.holidays,
        glossary: real.glossary,
        courts: real.courts,
        groupCatalog: real.groupCatalog,
      );
      final loose = [
        for (final (group, domains) in bundle.grouped)
          if (group == null) ...domains,
      ];
      expect([for (final d in loose) d.id], ['debt_recovery']);
    });
  });

  group('★ 묶음 목록의 밀도', () {
    testWidgets('지금 — 배율 1.0', (tester) async {
      final value = await open(tester, Routes.domains);
      // ignore: avoid_print
      print('묶음 목록 · 보통 · 13개 — ${value.toStringAsFixed(3)}화면');
      expect(value, lessThanOrEqualTo(maxScreens));
    });

    testWidgets('쉬운 말 — 배율 1.0', (tester) async {
      final value = await open(tester, Routes.domains, plain: true);
      // ignore: avoid_print
      print('묶음 목록 · 쉬운 말 · 13개 — ${value.toStringAsFixed(3)}화면');
      expect(value, lessThanOrEqualTo(maxScreens));
    });

    testWidgets('★ 분야가 스물둘이어도 첫 화면은 안 늘어난다', (tester) async {
      final value =
          await open(tester, Routes.domains, bundle: stuffed(22));
      // ignore: avoid_print
      print('묶음 목록 · 보통 · 22개 — ${value.toStringAsFixed(3)}화면');
      expect(
        value,
        lessThanOrEqualTo(maxScreens),
        reason: '분야가 늘었다고 첫 화면이 늘어나면 묶음을 만든 뜻이 없습니다',
      );
    });

    testWidgets('★ 스물둘 · 쉬운 말', (tester) async {
      final value = await open(
        tester,
        Routes.domains,
        bundle: stuffed(22),
        plain: true,
      );
      // ignore: avoid_print
      print('묶음 목록 · 쉬운 말 · 22개 — ${value.toStringAsFixed(3)}화면');
      expect(value, lessThanOrEqualTo(maxScreens));
    });

    testWidgets('가장 무거운 묶음을 열어도 상한 안이다', (tester) async {
      for (final (group, domains) in real.grouped) {
        if (group == null) continue;
        final value = await open(tester, Routes.domainGroup(group.id));
        // ignore: avoid_print
        print('묶음 안 · ${group.name}(${domains.length}가지) — '
            '${value.toStringAsFixed(3)}화면');
        expect(value, lessThanOrEqualTo(maxScreens));
      }
    });
  });

  group('★ 묶음 화면이 말하는 것', () {
    testWidgets('첫 화면에 묶음 이름과 개수가 있다', (tester) async {
      await open(tester, Routes.domains);
      for (final (group, domains) in real.grouped) {
        if (group == null) continue;
        expect(find.text(group.name), findsOneWidget);
        expect(
          find.text(DomainSelectScreen.countLabel(domains.length)),
          findsWidgets,
        );
      }
    });

    testWidgets('묶음을 열면 그 분야만 나온다', (tester) async {
      await open(tester, Routes.domainGroup('home'));
      expect(find.text('전세·월세 보증금'), findsOneWidget);
      expect(find.text('떼인 돈 받기'), findsNothing);
    });
  });
}
