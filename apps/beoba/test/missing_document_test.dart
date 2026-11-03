import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/document_section.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/widgets/missing_guide_view.dart';
import 'package:domain_data/domain_data.dart'
    show MissingGuide, Verification, VerificationStatus;
import 'package:engines/engines.dart' hide VerificationStatus;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **자료가 없어서 온 사람이 이 앱에 제일 많이 온다.**
///
/// 원칙이 둘이고 이 화면은 그 사이에 있다.
///
/// ```
/// 「자료가 없으면 안 됩니다」로 끝내지 않는다   → 그건 앱이 문을 닫는 것
/// 「이렇게 하면 됩니다」로 단정하지 않는다      → 그건 우리 선을 넘는 것
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 차용증도 계좌이체 내역도 없는 사람.
  const nothing = {
    'q_evidence_written': ['none'],
    'q_transfer_record': 'cash',
  };

  Future<ProviderContainer> openResult(
    WidgetTester tester, {
    Map<String, Object?> extra = const {},
  }) async {
    final container = await pumpApp(tester);
    seedAnswers(
      container,
      kDebtRecoveryDomainId,
      answers: {...completeAnswers, ...extra},
    );
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openDocuments(WidgetTester tester) async {
    final card = find.text(DocumentCard.title);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Future<void> openMissing(WidgetTester tester, {int at = 0}) async {
    final button = find.text(DocumentSection.missingAction).at(at);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('없다 · 있다 · 모른다를 가른다', () {
    testWidgets('안 물어본 것은 「모른다」다', (tester) async {
      // **아직 답을 안 한 사람에게 없다고 단정하면 안 된다.** 인터뷰를 중간에
      // 그만둔 사람 전원이 「아무것도 없는 사람」이 되어 버린다.
      final container = await pumpApp(tester);
      seedAnswers(
        container,
        kDebtRecoveryDomainId,
        answers: const {
          'q_role': 'creditor',
          'q_claim_type': 'loan',
          'q_amount': 5000000, // not-a-legal-number: 테스트 입력값
          'q_debtor_response': 'no_response',
          'q_debtor_address_known': 'yes',
          'q_court_document': 'none',
        },
      );
      final byId = {
        for (final d in container.read(documentResultsProvider(kDebtRecoveryDomainId)))
          d.id: d,
      };

      // 자료를 아직 안 물었다. **없다고 단정하지 않는다.**
      expect(byId['doc_contract']!.have, DocumentHave.unknown);
      expect(byId['doc_transfer_record']!.have, DocumentHave.unknown);
      expect(byId['doc_certified_mail']!.have, DocumentHave.unknown);
      // 주소는 안다고 답했으니 그것만 「있다」다.
      expect(byId['doc_debtor_address']!.have, DocumentHave.have);
      expect(byId.values.where((d) => d.isMissing), isEmpty);
    });

    testWidgets('없다고 답하면 「없다」다', (tester) async {
      final container = await openResult(tester, extra: nothing);
      final byId = {
        for (final d in container.read(documentResultsProvider(kDebtRecoveryDomainId)))
          d.id: d,
      };

      expect(byId['doc_contract']!.have, DocumentHave.missing);
      expect(byId['doc_transfer_record']!.have, DocumentHave.missing);
      // 자료가 없다고 답한 것과 주소를 안다고 답한 것은 **따로 센다.**
      expect(byId['doc_debtor_address']!.have, DocumentHave.have);
    });

    testWidgets('모르는 것에는 안 펼친다', (tester) async {
      // 결과 화면까지 오는 길에서는 두 질문이 `required` 라 「모른다」가 잘 안
      // 생긴다. 그래도 규칙은 **화면 쪽에 있어야** 한다 — 필수를 내리거나
      // 새 서류를 더할 때 여기서 막힌다. 그래서 위젯만 띄워 본다.
      await pumpWidgetOnly(
        tester,
        DocumentSection(
          documents: [_document(DocumentHave.unknown)],
          checked: const {},
          onToggle: (_) {},
        ),
      );

      expect(find.text(DocumentSection.missingAction), findsNothing);
    });

    testWidgets('없다고 답한 것에만 펼칠 문이 생긴다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DocumentSection(
          documents: [_document(DocumentHave.missing)],
          checked: const {},
          onToggle: (_) {},
        ),
      );

      expect(find.text(DocumentSection.missingAction), findsOneWidget);
    });

    testWidgets('있다고 답한 것에도 안 펼친다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DocumentSection(
          documents: [_document(DocumentHave.have)],
          checked: const {},
          onToggle: (_) {},
        ),
      );

      expect(find.text(DocumentSection.missingAction), findsNothing);
      expect(find.text(DocumentSection.alreadyHave), findsOneWidget);
    });
  });

  group('없을 때 — 그 자리에서 펼친다', () {
    testWidgets('누르기 전에는 안 보인다', (tester) async {
      await openResult(tester, extra: nothing);
      await openDocuments(tester);

      expect(find.text(DocumentSection.missingAction), findsWidgets);
      expect(find.text(MissingGuideView.altTitle), findsNothing);
    });

    testWidgets('차용증이 없으면 대신 쓸 수 있는 것이 나온다', (tester) async {
      await openResult(tester, extra: nothing);
      await openDocuments(tester);
      await openMissing(tester);

      expect(find.text(MissingGuideView.altTitle), findsOneWidget);
      expect(find.text('계좌이체 내역'), findsWidgets);
      expect(find.text('돈이 오간 걸 아는 사람'), findsOneWidget);
    });

    testWidgets('별도 화면으로 보내지 않는다', (tester) async {
      // 없는 사람이 한 번 더 이동하면 나간다.
      await openResult(tester, extra: nothing);
      await openDocuments(tester);
      await openMissing(tester);

      // 준비물 카드가 그대로 열려 있다.
      expect(find.text(DocumentCard.title), findsOneWidget);
    });
  });

  group('하나도 없을 때 — 문을 닫지 않는다', () {
    testWidgets('지금 만들 수 있는 것을 말한다', (tester) async {
      await openResult(tester, extra: nothing);
      await openDocuments(tester);
      await openMissing(tester);

      expect(find.textContaining('지금 만들 수 있는 것이 있어요'), findsOneWidget);
      expect(find.textContaining('지난 자료가 없어도 돼요'), findsOneWidget);
      // **「못 받습니다」로 끝내지 않는다.**
      expect(find.textContaining('못 받습니다'), findsNothing);
      expect(find.textContaining('받을 수 없습니다'), findsNothing);
    });

    testWidgets('공정증서의 조건이 같은 자리에 따라붙는다', (tester) async {
      // **같은 말을 두 번 쓰지 않는다** — 절차가 들고 있는 caution 을 그대로
      // 데려온다. 조건 없이 「만들 수 있어요」만 남으면 헛걸음을 시킨다.
      await openResult(tester, extra: nothing);
      await openDocuments(tester);
      await openMissing(tester);

      expect(find.textContaining('그 문구가 빠지면 그냥 종이'), findsWidgets);
      expect(find.text('민사집행법 제56조'), findsWidgets);
    });
  });

  group('선을 넘지 않는다', () {
    testWidgets('「인정됩니다」·「충분합니다」류가 0건이다', (tester) async {
      await openResult(tester, extra: nothing);
      await openDocuments(tester);
      await openMissing(tester);
      await openMissing(tester, at: 1);

      for (final banned in const [
        '인정됩니다',
        '인정돼요',
        '충분합니다',
        '충분해요',
        '증거가 됩니다',
        '이걸로 됩니다',
        '녹음',
        '녹취',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets('대안은 「자료가 될 수 있어요」에서 멈춘다', (tester) async {
      final container = await openResult(tester, extra: nothing);
      final guide = container
          .read(documentResultsProvider(kDebtRecoveryDomainId))
          .firstWhere((d) => d.id == 'doc_contract')
          .ifMissing!;

      for (final alternative in guide.alternatives) {
        expect(
          alternative.whatIsThis,
          contains('자료가 될 수 있어요'),
          reason: alternative.id,
        );
      }
    });

    testWidgets('구하는 법은 절차 사실만 적는다', (tester) async {
      final container = await openResult(tester, extra: nothing);
      final guide = container
          .read(documentResultsProvider(kDebtRecoveryDomainId))
          .firstWhere((d) => d.id == 'doc_transfer_record')
          .ifMissing!;

      expect(guide.howToGet, hasLength(1));
      expect(guide.howToGet.single.where, '거래하신 은행');
      expect(guide.ifNoneAtAll, isEmpty);
    });
  });

  group('지급명령 두 문장은 떨어지지 않는다', () {
    /// **앞 문장만 남으면 「증거 없어도 지급명령이면 된다」로 읽힌다.**
    const confirmed = '판결과 같은 효력이 생깁니다';
    const needsProof = '그때는 자료가 필요합니다';

    testWidgets('한 위젯 안에 둘 다 있다', (tester) async {
      await openResult(tester, extra: nothing);

      final card = find.text(ProcedureCard.title);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => t.contains(confirmed))
          .toList();

      expect(texts, isNotEmpty, reason: '확정 효력 문장이 화면에 없습니다');
      for (final text in texts) {
        expect(
          text,
          contains(needsProof),
          reason: '「$confirmed」이 「$needsProof」와 **같은 위젯**에 있어야 합니다',
        );
      }
    });

    test('데이터에서도 한 필드다', () async {
      final container = await bootstrappedContainer();
      final procedure = container
          .read(domainBundleProvider)
          .requireValue
          .byId(kDebtRecoveryDomainId)
          .procedures
          .firstWhere((p) => p.id == 'proc_payment_order');

      expect(procedure.detail, contains(confirmed));
      expect(procedure.detail, contains(needsProof));
      // 조문 둘이 함께 붙어 있다.
      expect(
        procedure.alsoBasis.map((b) => b.article),
        containsAll(['제474조', '제470조']),
      );
    });
  });
}

/// 상태만 갈아 끼운 서류 하나.
DocumentResult _document(DocumentHave have) => DocumentResult(
      id: 'doc_x',
      label: '시험용 서류',
      importance: Importance.high,
      issuedBy: '',
      onlineAvailable: false,
      verification: VerificationStatus.verified,
      have: have,
      ifMissing: const MissingGuide(
        ifNoneAtAll: '없을 때 할 말',
        verification: Verification(status: VerificationStatus.verified),
      ),
    );
