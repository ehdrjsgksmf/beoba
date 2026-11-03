import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/providers/welfare_providers.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/welfare/welfare_ask_screen.dart';
import 'package:beoba/src/screens/welfare/welfare_chips.dart';
import 'package:beoba/src/screens/welfare/welfare_list_screen.dart';
import 'package:beoba/src/welfare/welfare_match.dart';
import 'package:beoba/src/widgets/agency_notice_line.dart';
import 'package:beoba/src/widgets/section_card.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 두 번째 문 — 홈에서 목록까지.
///
/// **제일 중요한 것 하나** — 어느 줄에도 출처 딱지 없이 나가는 항목이 없다.
/// 이 층은 조문이 아니라 기관 안내문이고, 딱지를 빼면 남는 것은 근거 없는
/// 단정이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notice = AgencyNotice(
    agency: '고용노동부',
    checkedAt: KstDate(2026, 8, 22),
    dateScope: NoticeDateScope.dataset,
    dataset: '중앙부처복지서비스',
  );

  CentralWelfareService make(
    String name, {
    bool detail = true,
    List<String> topics = const [],
  }) =>
      CentralWelfareService(
        id: name,
        name: name,
        summary: '$name 한 줄 요약',
        url: 'https://www.bokjiro.go.kr/$name',
        ministry: '고용노동부',
        detailFetched: detail,
        target: detail ? '$name 지원대상' : '',
        criteria: detail ? '$name 선정기준' : '',
        benefit: detail ? '$name 지원내용' : '',
        topics: topics,
        notice: notice,
      );

  final catalog = CentralWelfareCatalog(
    dataset: '중앙부처복지서비스',
    source: '한국사회보장정보원',
    releasedAt: const KstDate(2026, 8, 22),
    totalCount: 3,
    detailFetchedCount: 2,
    services: [
      make('가제도'),
      make('나제도'),
      make('다제도', detail: false),
    ],
  );

  Future<void> openList(
    WidgetTester tester, {
    CentralWelfareCatalog? use,
  }) async {
    final container = await pumpApp(tester, welfare: use ?? catalog);
    container.read(routerProvider).go(Routes.welfareList());
    await tester.pumpAndSettle();
  }

  /// 「먼저 볼 것 N건 · 아래에 접어 둔 것 M건」 줄.
  Finder splitLine(int first, int folded) => find.byWidgetPredicate(
        (w) => w is WelfareSplitLine && w.first == first && w.folded == folded,
      );

  /// 본문 스크롤 하나만 고른다. 화면에 스크롤이 여럿이라 그냥 부르면 걸린다.
  Future<void> reveal(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  /// 접어 둔 「이름과 링크까지」 묶음을 편다.
  Future<void> openStubs(WidgetTester tester) async {
    await reveal(tester, find.text(WelfareListScreen.listOnlyHead));
    await tester.tap(find.text(WelfareListScreen.listOnlyHead));
    await tester.pumpAndSettle();
  }

  group('홈의 두 번째 갈래', () {
    testWidgets('★ 두 갈래가 나란히 서 있다', (tester) async {
      await pumpApp(tester, welfare: catalog);

      expect(find.text(HomeScreen.pick), findsOneWidget);
      expect(find.text(HomeScreen.pathProblem), findsOneWidget);
      expect(find.text(HomeScreen.welfareDoor), findsOneWidget);
    });

    testWidgets('★ 우리가 판정하는 말이 없다', (tester) async {
      await pumpApp(tester, welfare: catalog);

      // 「받을 수 있는 걸 알고 싶어요」는 사용자가 말하는 것이라 괜찮다.
      // 「받으실 수 있어요」는 우리가 말하는 것이라 안 된다.
      for (final word in ['받으실 수 있', '해당됩니다', '대상입니다']) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '홈이 「$word」라고 판정하고 있습니다',
        );
      }
    });

    testWidgets('누르면 물음 화면으로 간다', (tester) async {
      await pumpApp(tester, welfare: catalog);

      await reveal(tester, find.text(HomeScreen.welfareDoor));
      await tester.tap(find.text(HomeScreen.welfareDoor));
      await tester.pumpAndSettle();

      expect(find.text(WelfareAskScreen.title), findsOneWidget);
    });
  });

  group('물음은 셋이다', () {
    testWidgets('★ 안 쓰는 것은 묻지 않는다 — 사는 곳도 가구원 수도 없다', (tester) async {
      final container = await pumpApp(tester, welfare: catalog);
      container.read(routerProvider).go(Routes.welfare());
      await tester.pumpAndSettle();

      expect(find.text(WelfareAskScreen.birthLabel), findsOneWidget);
      expect(find.text(WelfareAskScreen.workLabel), findsOneWidget);
      expect(find.text(WelfareAskScreen.householdLabel), findsOneWidget);

      for (final word in ['사는 곳', '시·군', '가구원', '주소', '이름']) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '「$word」를 묻고 있습니다. 쓸 데가 없는 답입니다',
        );
      }
    });

    testWidgets('처음에는 아무 답도 골라져 있지 않다', (tester) async {
      final container = await pumpApp(tester, welfare: catalog);
      container.read(routerProvider).go(Routes.welfare());
      await tester.pumpAndSettle();

      expect(container.read(welfareAnswersProvider).work, isNull);
      expect(container.read(welfareAnswersProvider).birthYear, isNull);
    });

    testWidgets('가구상황 이름은 자료에서 온다', (tester) async {
      final withHouseholds = catalog.copyWith(
        services: [
          catalog.services.first.copyWith(households: ['저소득', '한부모·조손']),
          ...catalog.services.skip(1),
        ],
      );
      final container = await pumpApp(tester, welfare: withHouseholds);
      container.read(routerProvider).go(Routes.welfare());
      await tester.pumpAndSettle();

      expect(find.text('저소득'), findsOneWidget);
      expect(find.text('한부모·조손'), findsOneWidget);
    });
  });

  group('목록 — 두 층', () {
    testWidgets('★ 목록 머리에 자료 전체의 출처가 먼저 선다', (tester) async {
      await openList(tester);

      // 461건에 소관부처가 112곳이라 머리에 한 곳을 적을 수 없다.
      // 그래서 머리는 「각 기관」이라고 적고 받은 날을 밝힌다.
      expect(
        find.text('법에 적힌 게 아니라 각 기관이 알려 준 내용이에요. '
            '자료 받은 날 2026-08-22.'),
        findsOneWidget,
      );
    });

    testWidgets('★ 내용을 펼치면 그 항목의 기관 이름이 함께 나온다', (tester) async {
      await openList(tester);

      await reveal(tester, find.text('가제도'));
      await tester.tap(find.text('가제도'));
      await tester.pumpAndSettle();

      expect(
        find.text('법에 적힌 게 아니라 고용노동부에서 알려 준 내용이에요. '
            '마지막 확인 2026-08-22 (자료 전체 기준).'),
        findsWidgets,
      );
    });

    testWidgets('★ 이름과 링크만 있는 줄도 딱지를 달고 나간다', (tester) async {
      await openList(tester);
      await openStubs(tester);

      await reveal(tester, find.text('다제도'));
      final stub = find.ancestor(
        of: find.text('다제도'),
        matching: find.byType(SectionCard),
      );
      expect(
        find.descendant(of: stub, matching: find.byType(AgencyNoticeLine)),
        findsOneWidget,
      );
    });

    testWidgets('받은 날짜가 반드시 함께 나간다', (tester) async {
      await openList(tester);
      expect(find.textContaining('2026-08-22'), findsWidgets);
    });

    testWidgets('개수 줄이 두 층을 다 적는다', (tester) async {
      await openList(tester);

      // 「먼저 볼 것 · 접어 둔 것」 — 물음 화면과 같은 줄이다(DECISIONS 289번).
      expect(splitLine(3, 0), findsOneWidget);
      expect(
        find.text('자세한 내용까지 있는 것 2건 · 이름과 링크까지 1건.'),
        findsOneWidget,
      );
    });

    testWidgets('★ 상세 없는 것을 숨기지 않는다 — 접어 두되 건수를 적는다', (tester) async {
      await openList(tester);

      // 265건이 펼쳐져 있으면 목록이 아니라 벽이다. 대신 **머리에 건수와
      // 왜 안 받았는지가 적혀 있다** — 숨긴 것이 아니라 접은 것이다.
      await reveal(tester, find.text(WelfareListScreen.listOnlyHead));
      expect(
        find.textContaining(WelfareListScreen.listOnlyNote),
        findsOneWidget,
      );
      expect(find.textContaining('1건.'), findsWidgets);

      await openStubs(tester);
      await reveal(tester, find.text('다제도'));
      expect(find.text('다제도'), findsOneWidget);
      expect(find.text(WelfareListScreen.openLink), findsWidgets);
    });

    testWidgets('상세는 접혀 있고 펼치면 기관이 적은 문장이 나온다', (tester) async {
      await openList(tester);

      expect(find.text('가제도 지원대상'), findsNothing);
      await reveal(tester, find.text('가제도'));
      await tester.tap(find.text('가제도'));
      await tester.pumpAndSettle();

      expect(find.text('가제도 지원대상'), findsOneWidget);
      expect(find.text('가제도 선정기준'), findsOneWidget);
      expect(find.text('가제도 지원내용'), findsOneWidget);
    });

    testWidgets('하나도 안 걸리면 막다른 골목으로 두지 않는다', (tester) async {
      // 셋 다 「보훈대상자」로 적힌 자료에서 「저소득」을 고르면 아무것도 없다.
      final all = catalog.copyWith(
        services: [
          for (final s in catalog.services)
            s.copyWith(households: ['보훈대상자']),
        ],
      );
      final container = await pumpApp(tester, welfare: all);
      container.read(welfareAnswersProvider.notifier).toggleHousehold('저소득');
      container.read(routerProvider).go(Routes.welfareList());
      await tester.pumpAndSettle();

      expect(find.text(WelfareListScreen.emptyTitle), findsOneWidget);
      expect(find.text(WelfareListScreen.emptyBody), findsOneWidget);
    });
  });

  group('우리 판단인 것을 우리 판단이라고 적는다', () {
    testWidgets('나이대를 우리가 나눴다는 것을 밝힌다', (tester) async {
      final container = await pumpApp(tester, welfare: catalog);
      container.read(welfareAnswersProvider.notifier).setBirthYear(1991);
      container.read(routerProvider).go(Routes.welfareList());
      await tester.pumpAndSettle();

      expect(find.text(WelfareListScreen.ourCall), findsOneWidget);
      expect(find.text(WelfareLifeStage.youth), findsOneWidget);
      expect(find.text(WelfareLifeStage.middle), findsOneWidget);
    });
  });

  group('앱이 실제로 싣고 다니는 자료', () {
    testWidgets('한 건도 빠짐없이 출처를 갖고 있다', (tester) async {
      final real = await tester.runAsync(
        () => const AssetWelfareSource().loadCentral(),
      );

      for (final service in real!.services) {
        expect(
          service.notice.agency,
          isNotEmpty,
          reason: '${service.id} 에 알려 준 기관이 없습니다',
        );
      }
      expect(real.services, hasLength(real.totalCount));
    });
  });
}
