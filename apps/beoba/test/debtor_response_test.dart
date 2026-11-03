import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/caution_section.dart';
import 'package:beoba/src/screens/result/sections/document_section.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/widgets/verification_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 상대가 뭐라고 했는지에 따라 **알아두실 것**이 달라진다.
///
/// **절차를 권하지는 않는다.** 「다투지 않을 것 같으면 더 빠르고 싼 절차가
/// 있습니다」는 승패 예측을 유도하는 문장이라 내렸다. 값마다 조문이 말하는
/// 사실 하나씩만 붙이고 고르는 것은 사용자에게 맡긴다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openResult(
    WidgetTester tester,
    String response, {
    Map<String, Object?> extra = const {},
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(
      container,
      kDebtRecoveryDomainId,
      answers: {...completeAnswers, 'q_debtor_response': response, ...extra},
    );
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> ask(WidgetTester tester, String question) async {
    final finder = find.text(question);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  List<String> cautionIds(ProviderContainer container) => container
      .read(cautionsProvider(kDebtRecoveryDomainId))
      .map((c) => c.id)
      .toList();

  group('값마다 하나씩 붙는다', () {
    const cases = <String, String>{
      'will_pay': 'ct_response_will_pay',
      'partial': 'ct_response_partial',
      'no_money': 'ct_response_no_money',
      'denies': 'ct_response_disputed',
      'counterclaim': 'ct_response_disputed',
      'no_contact': 'ct_response_no_contact',
    };

    testWidgets('여섯 값이 다섯 안내로 간다', (tester) async {
      for (final entry in cases.entries) {
        final container = await openResult(tester, entry.key);
        expect(cautionIds(container), contains(entry.value), reason: entry.key);
      }
    });

    testWidgets('한 번에 하나만 뜬다', (tester) async {
      final container = await openResult(tester, 'no_money');
      final ids = cautionIds(container).where((id) => id.startsWith('ct_response_'));
      expect(ids, hasLength(1));
    });

    testWidgets('다투는 두 값은 **같은 문장**을 쓴다', (tester) async {
      // 갈라서 다르게 말하면 그게 곧 「이 경우엔 이게 낫다」가 된다.
      final denies = await openResult(tester, 'denies');
      final a = denies
          .read(cautionsProvider(kDebtRecoveryDomainId))
          .firstWhere((c) => c.id == 'ct_response_disputed');

      final counter = await openResult(tester, 'counterclaim');
      final b = counter
          .read(cautionsProvider(kDebtRecoveryDomainId))
          .firstWhere((c) => c.id == 'ct_response_disputed');

      expect(a.consequence, b.consequence);
      expect(a.question, b.question);
    });
  });

  group('권하지 않는다', () {
    testWidgets('「~가 낫습니다」류가 화면에 하나도 없다', (tester) async {
      for (final response in const [
        'will_pay',
        'partial',
        'no_money',
        'denies',
        'counterclaim',
        'no_contact',
      ]) {
        await openResult(tester, response);
        // 「유리·불리」는 뺐다. 머리의 고지가 **부정문으로** 그 말을 담고 있다 —
        // 「사건의 결과를 예측하거나 유불리를 판단하지 않습니다」. 부분 문자열
        // 검사는 부정문을 구분하지 못한다(DECISIONS 23 과 같은 자리).
        for (final banned in const [
          '낫습니다',
          '나아요',
          '더 나은',
          '권해',
          '추천',
          '이길',
          '하셔야 합니다',
        ]) {
          expect(find.textContaining(banned), findsNothing, reason: '$response — $banned');
        }
      }
    });

    testWidgets('갚겠다고 해도 소송 갈래를 감추지 않는다', (tester) async {
      // **말과 행동은 다르다.**
      final container = await openResult(tester, 'will_pay');
      final ids = container
          .read(costScenariosProvider(kDebtRecoveryDomainId))
          .map((s) => s.id);

      expect(ids, contains('cs_lawsuit_paper'));
      expect(ids, contains('cs_payment_order_paper'));
      expect(ids, contains('cs_mediation_paper'));
    });

    testWidgets('다툰다고 해서 절차 순서가 바뀌지 않는다', (tester) async {
      // 사다리는 늘 같은 순서다.
      final calm = await openResult(tester, 'will_pay');
      final disputed = await openResult(tester, 'denies');

      expect(
        disputed.read(proceduresProvider(kDebtRecoveryDomainId)).map((p) => p.id),
        calm.read(proceduresProvider(kDebtRecoveryDomainId)).map((p) => p.id),
      );
    });
  });

  group('물음을 눌러야 답이 나온다', () {
    testWidgets('개인회생 중에는 시효가 흐르지 않는다는 말이 조문과 함께 온다', (tester) async {
      // 「기다리면 시효로 손해본다」는 걱정을 조문이 직접 덜어 준다.
      await openResult(tester, 'no_money');

      expect(find.textContaining('시효도 흐르지 않아요'), findsNothing);
      await ask(tester, '상대가 돈이 없다고 하나요?');

      expect(find.textContaining('시효도 흐르지 않아요'), findsOneWidget);
      expect(find.text('채무자 회생 및 파산에 관한 법률 제600조 제4항'), findsOneWidget);
    });

    testWidgets('연락과 주소를 가른다', (tester) async {
      await openResult(tester, 'no_contact');
      await ask(tester, '연락이 안 되시나요?');

      expect(find.textContaining('연락이 안 되는 것과 주소를 모르는 것은 달라요'),
          findsOneWidget);
    });

    testWidgets('일부 변제 안내에 조문 둘이 붙는다', (tester) async {
      // 문장의 두 마디가 각각 조문에 있다 — 승인이 중단사유라는 것(제168조
      // 제3호)과 중단사유가 끝난 때부터 새로 센다는 것(제178조 제1항).
      await openResult(tester, 'partial');
      await ask(tester, '일부라도 받으셨나요?');

      expect(find.text('민법 제168조 제3호'), findsOneWidget);
      expect(find.text('민법 제178조 제1항'), findsOneWidget);

      // 조문이 왔어도 **적용은 여전히 열려 있다.** 일부 변제가 승인인지는
      // 우리가 판단하지 않는다.
      expect(find.textContaining('볼 수 있어요'), findsOneWidget);
      expect(find.text(VerificationBadge.message), findsWidgets);
    });

    testWidgets('일부 변제 안내는 날짜를 바꾸지 않는다', (tester) async {
      // 상대의 말이나 행동이 승인인지는 사실관계 평가라 하지 않는다.
      final withPartial = await openResult(tester, 'partial');
      final a = withPartial
          .read(deadlineResultsProvider(kDebtRecoveryDomainId))
          .map((d) => '${d.id}:${d.dueDate.toIso()}')
          .toList();

      final withDenies = await openResult(tester, 'denies');
      final b = withDenies
          .read(deadlineResultsProvider(kDebtRecoveryDomainId))
          .map((d) => '${d.id}:${d.dueDate.toIso()}')
          .toList();

      expect(a, b, reason: '안내가 계산을 건드리면 안 된다');
    });
  });

  group('이미 있다고 답한 서류', () {
    testWidgets('준비물 카드가 챙긴 개수로 시작한다', (tester) async {
      // 차용증이 있다고 답한 사람에게 「차용증을 준비하세요」를 다시 내밀고
      // 있었다. **그게 원래 그 질문을 한 이유다.**
      final container = await openResult(
        tester,
        'no_response',
        extra: {
          'q_evidence_written': ['contract', 'message'],
          'q_transfer_record': 'yes',
        },
      );
      final documents =
          container.read(documentResultsProvider(kDebtRecoveryDomainId));
      final have = documents.where((d) => d.alreadyHave).map((d) => d.id);

      expect(have, containsAll(['doc_contract', 'doc_messages', 'doc_transfer_record']));
      expect(
        find.text(DocumentCard.haveLine(have.length, documents.length)),
        findsOneWidget,
      );
    });

    testWidgets('자료가 없다고 답해도 이미 한 일은 남는다', (tester) async {
      final container = await openResult(
        tester,
        'no_response',
        extra: {
          'q_evidence_written': ['none'],
          'q_transfer_record': 'cash',
        },
      );
      final documents =
          container.read(documentResultsProvider(kDebtRecoveryDomainId));

      final have = documents.where((d) => d.alreadyHave).map((d) => d.id);

      // 자료는 하나도 없다고 답했다.
      expect(have, isNot(contains('doc_contract')));
      expect(have, isNot(contains('doc_transfer_record')));
      // 주소를 알고 내용증명을 보냈다는 답은 **그대로 「챙긴 것」이다.**
      // 자료가 없다고 해서 이미 한 일까지 지우지 않는다.
      expect(have, ['doc_debtor_address', 'doc_certified_mail']);
      expect(
        find.text(DocumentCard.haveLine(2, documents.length)),
        findsOneWidget,
      );
    });

    testWidgets('목록에서 지우지 않고 표시만 바꾼다', (tester) async {
      // 지우면 사용자가 「내가 뭘 냈더라」를 못 본다.
      await openResult(
        tester,
        'no_response',
        extra: {
          'q_evidence_written': ['contract'],
          'q_transfer_record': 'yes',
        },
      );

      final card = find.text(DocumentCard.title);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.text('차용증 · 계약서'), findsWidgets);
      expect(find.text(DocumentSection.alreadyHave), findsWidgets);
    });
  });

  group('묻는 이유를 고쳤다', () {
    test('whyAsk 가 절차를 약속하지 않는다', () async {
      final container = await bootstrappedContainer();
      final question = container
          .read(domainBundleProvider)
          .requireValue
          .byId(kDebtRecoveryDomainId)
          .intake
          .firstWhere((q) => q.id == 'q_debtor_response');

      // 「다투지 않을 것 같으면 더 빠르고 싼 절차가 있습니다」는 승패 예측을
      // 유도한다 — 「다투지 않을 것 같다」를 누가 판단하는가.
      expect(question.whyAsk, isNot(contains('다투지 않을 것 같으면')));
      expect(question.whyAsk, isNot(contains('빠르고 싼')));
    });
  });

  group('안내는 화면에도 나온다', () {
    testWidgets('물음이 「달라질 수 있는 것」 아래에 있다', (tester) async {
      await openResult(tester, 'will_pay');

      expect(find.text(CautionSection.title), findsOneWidget);
      expect(find.text('상대가 갚겠다고 하셨나요?'), findsOneWidget);
    });
  });
}
