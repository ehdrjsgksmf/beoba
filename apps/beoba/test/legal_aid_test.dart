import 'package:beoba/src/app/router.dart';
import 'package:engines/engines.dart' show KstDate;
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 소송구조 — **돈이 없어서 온 사람에게 금액만 내밀면 그건 벽이다.**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openResult(
    WidgetTester tester,
    String domainId, {
    required Map<String, Object?> answers,
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(container, domainId, answers: answers);
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();
    return container;
  }

  /// 데이터 한 벌. 분야마다 복사하지 않는다.
  String aidText(ProviderContainer container) {
    final aid = container
        .read(domainBundleProvider)
        .requireValue
        .crisis
        .cautions
        .firstWhere((caution) => caution.id == 'ct_legal_aid');
    return '${aid.condition} ${aid.consequence} ${aid.question}';
  }

  group('비용 카드 바로 아래, 접힌 채로', () {
    testWidgets('받을 쪽 결과에 붙는다', (tester) async {
      final container = await openResult(
        tester,
        kDebtRecoveryDomainId,
        answers: completeAnswers,
      );

      expect(find.text(CostCard.title), findsOneWidget);
      expectScreenText(tester, '이 돈을 지금 안 내는 길이 있어요');
      // **접혀 있다.** 얼마인지 먼저 보고 나서 읽는 순서다.
      expectNoScreenText(tester, '소송구조를 신청할 수 있다고');

      await tester.ensureVisible(find.text('이 돈을 지금 안 내는 길이 있어요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 돈을 지금 안 내는 길이 있어요'));
      await tester.pumpAndSettle();
      expectScreenText(tester, '소송구조를 신청할 수 있다고');
      expectScreenText(tester, '민사소송법 제128조 제1항');
      expect(container.read(legalAidProvider(kDebtRecoveryDomainId)), isNotNull);
    });

    testWidgets('상속 결과에도 같은 것이 붙는다', (tester) async {
      final container = await openResult(
        tester,
        'inheritance',
        answers: const {
          'q_known_date': KstDate(2026, 7, 1),
          'q_estate_known': 'unknown',
          'q_filer_count': 1,
          'q_deceased_address': '서울특별시 종로구',
          'q_was_minor': 'no',
        },
      );

      expectScreenText(tester, '이 돈을 지금 안 내는 길이 있어요');
      expect(container.read(legalAidProvider('inheritance')), isNotNull);
    });
  });

  group('안 붙는 자리', () {
    testWidgets('갚는 쪽에는 안 붙는다 — 비용 섹션 자체가 없다', (tester) async {
      final container = await openResult(
        tester,
        kDebtRecoveryDomainId,
        answers: const {
          'q_role': 'debtor',
          'q_debtor_situation': 'seizure',
          'q_seizure_when': 'after',
        },
      );

      expect(find.text(CostCard.title), findsNothing);
      expectNoScreenText(tester, '이 돈을 지금 안 내는 길이 있어요');
      expect(container.read(legalAidProvider(kDebtRecoveryDomainId)), isNull);
    });
  });

  group('★ 유예와 면제는 다르다', () {
    testWidgets('우리 말에 「면제」도 「안 내도」도 없다', (tester) async {
      final container = await pumpApp(tester);
      final ours = aidText(container);

      // 「담보면제」는 제129조 제1항 제3호의 **조문 원문**이라 여기 없다.
      // 인용한 남의 말과 우리 주장은 다른 축이다(DECISIONS 129번).
      for (final banned in const [
        '면제',
        '안 내도',
        '신청하세요',
        '받을 수 있어요',
      ]) {
        expect(
          ours.contains(banned),
          isFalse,
          reason: '우리 말에 「$banned」가 들어갔습니다',
        );
      }
    });

    testWidgets('미룬다고 말하고, 나중에 낼 수 있다고 말한다', (tester) async {
      final container = await pumpApp(tester);
      final ours = aidText(container);

      expect(ours, contains('미룰 수 있어요'));
      expect(ours, contains('안 내는 것이 아니라'));
      // 형편이 나아지면 알려야 한다 — 규칙 제27조 제2항이 신고 의무를 둔다.
      expect(ours, contains('법원에 알려야 해요'));
    });

    testWidgets('승패를 말하지 않는다', (tester) async {
      final container = await pumpApp(tester);
      final aid = container
          .read(domainBundleProvider)
          .requireValue
          .crisis
          .cautions
          .firstWhere((caution) => caution.id == 'ct_legal_aid');

      // 단서(「패소할 것이 분명한 경우」)는 조문 원문에만 있고 우리 말에는 없다.
      expect(aid.legalBasis!.text, contains('패소할 것이 분명한 경우'));
      expect(aid.consequence, isNot(contains('패소')));
      expect(aid.consequence, isNot(contains('승소')));
    });

    testWidgets('자금능력 기준을 숫자로 말하지 않는다', (tester) async {
      final container = await pumpApp(tester);
      final ours = aidText(container);

      expect(RegExp(r'\d').hasMatch(ours), isFalse);
    });
  });
}
