import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/result/sections/welfare_door.dart';
import 'package:beoba/src/welfare/welfare_match.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/handover_numbers.dart';
import 'support/test_app.dart';

/// **법률과 복지가 만나는 자리.** 이 앱만 할 수 있는 자리이고, 그래서
/// 조심해서 놓아야 한다.
///
/// 잇는 기준은 하나뿐이다 — 제도 쪽 근거법령(`baslawList`)의 이름이 분야가
/// 적어 둔 이름과 맞는가. **주제가 비슷해 보인다는 이유로는 안 잇는다.**
///
/// 여기서 건수를 못 박는다. 상세를 더 받으면 늘어날 값이라 **줄어들면**
/// 무언가 끊어진 것이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const today = KstDate(2026, 8, 15);

  late CentralWelfareCatalog catalog;
  late DomainBundle bundle;

  setUpAll(() async {
    catalog = await const AssetWelfareSource().loadCentral();
    bundle = await loadTestBundle();
  });

  int linked(String domainId) {
    final bridge = bundle.byId(domainId).welfareBridge;
    expect(bridge, isNotNull, reason: '$domainId 에 다리가 없습니다');
    // 다리가 **잇는** 건수다 — 먼저 보이는 것과 접힌 것을 합한다. 가구상황이
    // 적힌 제도는 안 고르면 접히지만 다리가 끊어진 것은 아니다(DECISIONS 287번).
    final match = matchWelfare(
      catalog: catalog,
      answers: WelfareAnswers(bridge: bridge),
      today: today,
    );
    return match.matched + match.folded.length;
  }

  group('★ 다리는 근거법령으로만 잇는다', () {
    /// 2026-08-30 기준. 상세 368/461(1순위 끝)에서 잰 값이다.
    ///
    /// **줄어들면 무언가 끊어진 것이다.** 늘어나는 것은 정상이다 —
    /// 상세를 더 받으면 `baslawList` 가 붙는 건이 늘어난다.
    ///
    /// ★ **늘어나면 바닥값을 같이 올린다.** 안 올리면 바닥이 낡아서
    /// 끊어진 것을 못 잡는다 — 18에 머물러 있으면 20이 18로 줄어도 초록이다.
    const floor = <String, int>{
      'wage_theft': 2,
      'unemployment_benefit': 5,
      'unfair_dismissal': 5,
      'debt_recovery': 21,
      'debt_relief': 32,
      // 상세를 받자 생긴 다리다. 여섯 다 `detailFetched` 라 카드가 다 그려진다.
      'work_injury': 6,
      // 두 법을 근거로 든 제도 여덟. 여덟 다 `detailFetched` 다.
      // **한부모가족지원법이 나중에 들어왔다** — 원문이 `law/` 에 없던 동안은
      // 다리에 이름을 못 적었고(검사 (w)가 막는다) 둘뿐이었다.
      // 「양육비 이행 원스톱 종합서비스」가 두 법에 다 걸려 **한 번만** 센다.
      'child_support': 8,
    };

    for (final entry in floor.entries) {
      test('${entry.key} — ${entry.value}건 이상', () {
        expect(
          linked(entry.key),
          greaterThanOrEqualTo(entry.value),
          reason: '${entry.key} 의 다리가 끊어졌습니다. '
              '근거법령 이름이 바뀌었거나 다리에서 빠졌습니다',
        );
      });
    }

    /// 다리가 없는 분야. **바닥값 표와 합치면 분야 전부가 되어야 한다.**
    ///
    /// 중고거래가 어느 쪽에도 없었다 — 다리가 없는데 「없다」고 말하는
    /// 쪽에도 안 적혀 있어서, 다리가 생겨도 아무도 몰랐다.
    const noBridge = <String>[
      'deposit_return',
      'inheritance',
      'consumer_withdrawal',
      'installment_purchase',
      'voice_phishing',
      'secondhand_fraud',
      'estate_division',
      'jeonse_fraud',
    ];

    test('★ 분야를 몇 개 돌았는지 센다', () {
      // 다리가 있는 쪽과 없는 쪽이 **분야 전부를 나눠 가져야 한다.**
      expectsEveryDomain(
        'welfare_bridge_test 의 floor + noBridge',
        [...floor.keys, ...noBridge],
      );
    });

    test('★ 다리가 없는 분야는 한 건도 안 잇는다', () {
      // 「이을 근거가 없으면 입구도 없다.」 보증금·상속·무르기에는
      // 주제가 비슷해 보이는 제도가 있지만 근거법령이 안 맞는다.
      for (final id in noBridge) {
        expect(
          bundle.byId(id).welfareBridge,
          isNull,
          reason: '$id 에 다리가 생겼습니다. 근거법령으로 이은 것이 맞나요?',
        );
      }
    });

    test('★ 인수인계의 입구 합과 서로 다른 제도 수', () {
      // **검사기는 이 값을 못 센다.** matchWelfare 가 앱 코드에 있어서다.
      // 세는 법을 검사기에 한 벌 더 쓰면 두 숫자가 갈린다. 그래서 셀 수
      // 있는 쪽이 문서를 본다.
      //
      // 두 숫자는 뜻이 다르다 — 세로로 더한 것이 입구 합이고, 같은 제도가
      // 여러 분야에 서므로 실제 제도 수는 그보다 적다.
      var sum = 0;
      final services = <String>{};
      for (final domainId in allDomainIds()) {
        final bridge = bundle.byId(domainId).welfareBridge;
        if (bridge == null) continue;
        final match = matchWelfare(
          catalog: catalog,
          answers: WelfareAnswers(bridge: bridge),
          today: today,
        );
        sum += match.matched + match.folded.length;
        services.addAll([
          for (final s in [...match.detailed, ...match.listOnly, ...match.folded])
            s.id,
        ]);
      }
      // ignore: avoid_print
      print('복지 다리 — 입구 합 $sum · 서로 다른 제도 ${services.length}');
      expectHandoverNumber('입구 합', RegExp(r'입구 합 (\d+)'), sum);
      expectHandoverNumber(
        '서로 다른 제도',
        RegExp(r'서로 다른 제도 (\d+)'),
        services.length,
      );
    });

    test('다리가 없으면 좁히지 않는다 — 접힌 것까지 합하면 전체다', () {
      final all = matchWelfare(
        catalog: catalog,
        answers: const WelfareAnswers(),
        today: today,
      );
      expect(all.matched + all.folded.length, catalog.services.length);
      expect(all.bridgeCount, isNull);
    });

    test('★ 다리로 좁힌 뒤에도 전체 건수를 함께 낸다', () {
      final match = matchWelfare(
        catalog: catalog,
        answers: WelfareAnswers(bridge: bundle.byId('wage_theft').welfareBridge),
        today: today,
      );

      // 「이것뿐이구나」로 읽히지 않게 두 숫자를 다 갖고 있어야 한다.
      expect(match.bridgeCount, 2);
      expect(match.total, catalog.services.length);
    });
  });

  group('결과 화면의 한 줄', () {
    testWidgets('다리가 있는 분야에는 선다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId, answers: completeAnswers);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byType(WelfareDoor),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(WelfareDoor.label), findsOneWidget);
    });

    testWidgets('★ 조건 없는 약속을 하지 않는다', (tester) async {
      await pumpApp(tester);

      // 「~면 ~도 됩니다」류가 이 줄에 한 마디도 없다.
      for (final word in ['도 됩니다', '받으실 수 있', '해당됩니다', '지원받']) {
        expect(
          WelfareDoor.label.contains(word),
          isFalse,
          reason: '건너가는 줄이 「$word」라고 약속하고 있습니다',
        );
      }
    });

    testWidgets('★ 산재 — 입구를 눌러서 0건이 되지 않는다', (tester) async {
      // **다리를 놓기 전에 눌러 본다.** 입구는 섰는데 눌러 보면 0건인
      // 화면을 세우지 않는다(DECISIONS 228). 여섯 다 `detailFetched` 라
      // 이름·요약뿐인 줄이 아니라 카드가 다 그려진다.
      //
      // 2026-08-30 에 상세를 더 받자 넷이 여섯이 됐다. **손을 안 댔다** —
      // 자료 쪽 `baslawList` 에 산재보험법이 붙은 것뿐이다(DECISIONS 239).
      final match = matchWelfare(
        catalog: catalog,
        answers: WelfareAnswers(bridge: bundle.byId('work_injury').welfareBridge),
        today: today,
      );

      expect(match.matched, 6);
      expect(match.detailed, hasLength(6), reason: '상세가 없는 건이 섞여 있습니다');
      expect(match.listOnly, isEmpty);
      expect(
        [for (final s in match.detailed) s.name],
        containsAll(<String>[
          '산재근로자 사회심리재활지원',
          '산재근로자 생활안정자금융자',
          '산재근로자원직장복귀지원',
          '산재근로자직업훈련',
          '(산재근로자)케어센터지원',
          '산재근로자 대체인력지원',
        ]),
      );
    });

    testWidgets('다리가 없는 분야에는 안 선다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(
        container,
        'inheritance',
        answers: const {
          'q_death_date': KstDate(2026, 7, 1),
          'q_relationship': 'child',
          'q_debt_known': 'unknown',
        },
      );
      container.read(routerProvider).go(Routes.result('inheritance'));
      await tester.pumpAndSettle();

      expect(find.byType(WelfareDoor), findsNothing);
    });
  });
}
