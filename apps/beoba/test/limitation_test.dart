import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/limitation_card.dart';
import 'package:beoba/src/widgets/verification_badge.dart';
import 'package:domain_data/domain_data.dart' show LimitationKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/test_app.dart';

/// **시효는 계산하지 않고 갈래로 낸다.**
///
/// 몇 년인지가 사건마다 달라서 우리가 고르면 틀릴 수 있다. 날짜를 세지 않고
/// 법에 어떻게 쓰여 있는지를 나란히 낸다(DECISIONS 107번).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openResult(
    WidgetTester tester, {
    Map<String, Object?> answers = completeAnswers,
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(container, kDebtRecoveryDomainId, answers: answers);
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openCard(WidgetTester tester) async {
    final finder = find.text(LimitationCard.title);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('갈래를 나란히 낸다', () {
    testWidgets('넷이 다 나오고 어느 하나를 고르지 않는다', (tester) async {
      final container = await openResult(tester);
      final branches = container
          .read(limitationRulesProvider(kDebtRecoveryDomainId))
          .where((r) => r.kind == LimitationKind.branch)
          .toList();

      // 분야 넷 다음에 공통 조각이 온다. 마지막이 「짧은 쪽으로」다.
      expect(branches.map((r) => r.id), [
        'lm_general',
        'lm_commercial',
        'lm_short_list',
        'lm_one_year',
        'lm_judgment_ten',
        'lm_shorter',
      ]);
      // 「짧은 쪽으로」가 몇 년인가 무리의 **맨 끝**이다. 조문 갈래를 다 보고
      // 나서 읽는 줄이라 앞에 오면 고르는 말처럼 보인다.

      await openCard(tester);
      expectScreenText(tester, '원칙은 10년');
      expectScreenText(tester, '5년일 수 있어요');
      expectScreenText(tester, '3년짜리 목록에 있으면 3년이에요');
      expectScreenText(tester, '1년짜리 목록도 따로 있어요');

      // **각 호를 뽑지 않는다.** 조문 전체가 붙고 본인이 찾는다.
      expect(find.text('민법 제162조 제1항'), findsOneWidget);
      expect(find.text('상법 제64조'), findsOneWidget);
      expect(find.text('민법 제163조'), findsOneWidget);
      expect(find.text('민법 제164조'), findsOneWidget);
      expect(find.text('민법 제163조 제6호'), findsNothing);
    });

    testWidgets('★ 조문 갈래에는 배지가 없고, 우리가 고른 줄에만 있다', (tester) async {
      // **안 정한 것이지 못 정한 것이 아니다.** 조문을 그대로 옮긴 줄에는
      // 배지를 안 단다. 「짧은 쪽으로 적어 두세요」는 조문이 아니라 우리가
      // 고른 방향이라 하나만 달린다(DECISIONS 168번).
      await openResult(tester);
      await openCard(tester);

      expect(find.text(VerificationBadge.message), findsOneWidget);
      expectScreenText(tester, '헷갈리면 짧은 쪽으로 적어 두세요');
      expectScreenText(tester, '그게 정답이라는 뜻은 아니에요');
    });

    testWidgets('상행위에는 뜻을 정한 조문이 함께 온다', (tester) async {
      // 「상행위」가 무엇인지가 제64조에 없고 제47조에 있다.
      await openResult(tester);
      await openCard(tester);

      expect(find.text('상법 제64조'), findsOneWidget);
      expect(find.text('상법 제47조'), findsOneWidget);
    });
  });

  group('못 한다로 끝내지 않는다', () {
    testWidgets('맨 위에 왜 못 하는지, 맨 아래에 어디로 가는지', (tester) async {
      await openResult(tester);

      expectScreenText(tester, '날짜로 계산해 드리지 못해요');
      await openCard(tester);
      expectScreenText(tester, '아래 창구에서 무료로 물어보실 수 있어요');
    });

    testWidgets('기산점을 풀어 쓰지 않는다', (tester) async {
      // 조문은 「권리를 행사할 수 있는 때」까지다. 그 뒤는 우리 말 한 줄뿐이다.
      await openResult(tester);
      await openCard(tester);

      expect(find.text('민법 제166조'), findsOneWidget);
      expectScreenText(tester, '그게 언제인지는 사정마다 달라서 저희가 정하지 않아요');
      expectNoScreenText(tester, '다음 날부터');
    });
  });

  group('해당하는 사람에게만', () {
    testWidgets('★ 내용증명 6개월은 안 보낸 사람에게도 보인다', (tester) async {
      // 예전에는 보낸 사람에게만 냈다. 그런데 **보낸 사람이 안심한 채
      // 6개월을 넘기는 것**이 훨씬 비싸고, 라벨이 조건절이라 안 보낸 분에게는
      // 해당 없는 줄로 읽힌다(DECISIONS 169번).
      final sent = await openResult(tester);
      expect(
        sent.read(limitationRulesProvider(kDebtRecoveryDomainId)).map((r) => r.id),
        contains('lm_certified_mail'),
      );
      await openCard(tester);
      expect(find.text('민법 제174조'), findsOneWidget);
      // 소를 냈다가 취하돼도 6개월이라는 조문이 함께 온다.
      expect(find.text('민법 제170조'), findsOneWidget);
      expectScreenText(tester, '보내 두셨다면');

      final notSent = await openResult(
        tester,
        answers: {...completeAnswers, 'q_demanded': 'none'},
      );
      expect(
        notSent
            .read(limitationRulesProvider(kDebtRecoveryDomainId))
            .map((r) => r.id),
        contains('lm_certified_mail'),
      );
    });

    testWidgets('★ 시효 카드는 분야가 연수 갈래를 선언한 곳에만 붙는다', (tester) async {
      // 갚을 쪽 분야에 붙으면 「기다리면 없어진다」로 읽힌다.
      //
      // **두 목록을 손으로 적지 않는다.** 어느 분야가 연수 갈래를 선언했는지는
      // 데이터가 안다. 넷만 적어 두었더니 나머지 아홉은 아무도 안 봤다.
      final container = await pumpApp(tester);
      final bundle = container.read(domainBundleProvider).requireValue;

      final covered = <String>[];
      for (final domainId in allDomainIds()) {
        covered.add(domainId);
        final declared = bundle.byId(domainId).limitationRules.isNotEmpty;
        expect(
          container.read(limitationRulesProvider(domainId)),
          declared ? isNotEmpty : isEmpty,
          reason: declared
              ? '$domainId 은 연수 갈래를 선언했는데 카드가 안 붙습니다'
              : '$domainId 은 연수 갈래가 없는데 카드가 붙습니다',
        );
      }
      expectsEveryDomain('limitation_test 의 시효 카드', covered);
    });

    testWidgets('재촉하지 않는다', (tester) async {
      await openResult(tester);
      await openCard(tester);

      for (final banned in const [
        '서두르',
        '늦기 전에',
        '소용없',
        // **낱말이 아니라 우리 말을 막는다.** 민법 제184조 제1항이
        // 「소멸시효의 이익은 미리 포기하지 못한다」이고, 그건 포기하라는
        // 말의 정반대다. 막을 것은 「포기하세요」다.
        '포기하세요',
        '포기하시',
        '이미 늦',
        '지났습니다',
        '지났어요',
        '남았습니다',
        '남았어요',
      ]) {
        expectNoScreenText(tester, banned);
      }
    });
  });

  group('★ 채무자에게는 시효를 말하지 않는다', () {
    /// 같은 문장이 역할에 따라 정반대로 작동한다.
    ///
    /// 받을 사람에게 「지났을 수 있어요」는 포기로, 갚으라는 요구를 받은
    /// 사람에게 같은 말은 **대응을 안 하는 쪽**으로 민다. 그러면 그대로
    /// 판결이 난다.
    testWidgets('갚아야 할 돈이라고 답하면 카드가 아예 없다', (tester) async {
      final container = await openResult(
        tester,
        answers: {
          ...completeAnswers,
          'q_role': 'debtor',
          // 갚을 쪽은 갈래를 하나 더 고른다. 받을 쪽 답은 리플레이가 버린다.
          'q_debtor_situation': 'collection',
        },
      );

      expect(
        container.read(limitationRulesProvider(kDebtRecoveryDomainId)),
        isEmpty,
      );
      // 카드가 아무것도 그리지 않는다.
      expect(find.text(LimitationCard.title), findsNothing);
      expectNoScreenText(tester, '시효');
      expectNoScreenText(tester, LimitationCard.title);

      // **길은 연다.** 시효를 지칭하지 않으면서.
      expectScreenText(tester, LimitationForDebtor.line);
      expectNoScreenText(tester, '주장할 수 있어요');
    });
  });

  group('우리가 계산한 숫자가 없다', () {
    testWidgets('카드 안에 연도가 하나도 없다', (tester) async {
      // 10년·5년·3년은 조문에 있는 말이라 괜찮다. 「2029」 같은 연도가
      // 나오면 우리가 셌다는 뜻이다.
      await openResult(tester);
      await openCard(tester);

      final card = find.byType(LimitationCard);
      final texts = tester
          .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .join('\n');

      expect(texts, isNotEmpty);
      expect(
        RegExp(r'(19|20)\d\d년').hasMatch(texts),
        isFalse,
        reason: '카드 안에 연도가 있습니다. 우리가 계산했다는 뜻입니다',
      );
    });
  });
}
