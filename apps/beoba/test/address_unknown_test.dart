import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/summary_cards.dart';
import 'package:beoba/src/screens/result/sections/document_section.dart';
import 'package:beoba/src/widgets/fee_schedule_view.dart';
import 'package:engines/engines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **「어렵습니다」로 끝내지 않는다.**
///
/// 주소를 모른다고 답하면 지금까지는 「지급명령과 조정은 어렵습니다」만 말하고
/// 끝났다. 그 사람에게 남은 길을 안 알려주고 있었다 — 제462조 단서가
/// 「공시송달 외의 방법으로 송달할 수 있는 경우에 한한다」고 적은 것은
/// 뒤집으면 **소송에는 그 길이 있다**는 말이다. 같은 조문의 뒷면이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final noAddress = {...completeAnswers, 'q_debtor_address_known': 'no'};

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

  Future<void> ask(WidgetTester tester, String question) async {
    final finder = find.text(question);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('「어렵습니다」 다음에 길이 온다', () {
    testWidgets('두 물음이 나란히 서고 순서가 정해져 있다', (tester) async {
      final container = await openResult(tester, answers: noAddress);
      final ids = container
          .read(cautionsProvider(kDebtRecoveryDomainId))
          .map((c) => c.id)
          .toList();

      expect(ids, contains('ct_payment_order_needs_address'));
      expect(ids, contains('ct_service_by_publication'));
      expect(
        ids.indexOf('ct_service_by_publication'),
        ids.indexOf('ct_payment_order_needs_address') + 1,
        reason: '「어렵습니다」 **바로 다음** 자리여야 한다',
      );
    });

    testWidgets('주소를 안다고 답하면 뜨지 않는다', (tester) async {
      final container = await openResult(tester);

      expect(
        container.read(cautionsProvider(kDebtRecoveryDomainId)).map((c) => c.id),
        isNot(contains('ct_service_by_publication')),
      );
    });

    testWidgets('눌러야 답이 나오고 조문 넷이 함께 온다', (tester) async {
      await openResult(tester, answers: noAddress);

      expect(find.textContaining('소송은 길이 있어요'), findsNothing);
      await ask(tester, '주소를 끝내 못 찾으면 어떻게 되나요?');

      expect(find.textContaining('소송은 길이 있어요'), findsOneWidget);
      expect(find.text('민사소송법 제194조 제1항'), findsOneWidget);
      expect(find.text('민사소송법 제194조 제2항'), findsOneWidget);
      expect(find.text('민사소송법 제196조 제1항'), findsOneWidget);
      expect(find.text('민사소송법 제173조 제1항'), findsOneWidget);
    });
  });

  group('제173조는 사실이지 말리는 말이 아니다', () {
    /// **빼면 「판결 받았으니 끝났다」고 믿게 된다.** 그건 되돌리기 어렵다.
    const late = '나중에 상대가 알게 되면 그때부터 2주 안에 다툴 수 있어요';

    testWidgets('뒤늦게 다툴 수 있다는 말이 빠지지 않는다', (tester) async {
      await openResult(tester, answers: noAddress);
      await ask(tester, '주소를 끝내 못 찾으면 어떻게 되나요?');

      expect(find.textContaining(late), findsOneWidget);
    });

    testWidgets('말리는 말이 섞이지 않는다', (tester) async {
      await openResult(tester, answers: noAddress);
      await ask(tester, '주소를 끝내 못 찾으면 어떻게 되나요?');

      for (final banned in const [
        '하지 마세요',
        '권하지',
        '어렵습니다만',
        '소용이 없',
        '의미가 없',
        '헛수고',
        '못 받습니다',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets('주소를 알아내는 방법은 쓰지 않는다', (tester) async {
      // 근거가 없고 절차마다 요건이 다르다. 창구로 보낸다.
      await openResult(tester, answers: noAddress);
      await ask(tester, '주소를 끝내 못 찾으면 어떻게 되나요?');

      for (final banned in const ['초본', '주민등록', '보정명령', '사실조회']) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });
  });

  group('내용증명 — 아직 안 한 것이지 없는 것이 아니다', () {
    final notSent = {...completeAnswers, 'q_demanded': 'none'};

    testWidgets('안 보낸 사람에게도 목록에 남는다', (tester) async {
      final container = await openResult(tester, answers: notSent);
      final document = container
          .read(documentResultsProvider(kDebtRecoveryDomainId))
          .firstWhere((d) => d.id == 'doc_certified_mail');

      expect(document.have, DocumentHave.missing);
      expect(document.ifMissing, isNotNull);
    });

    testWidgets('「보내세요」가 아니라 「보내실 수 있어요」다', (tester) async {
      await openResult(tester, answers: notSent);
      await _openMissing(tester, 'doc_certified_mail');

      expect(find.textContaining('아직 안 보내셨어도 괜찮아요'), findsOneWidget);
      expect(find.textContaining('보내세요'), findsNothing);
      expect(find.textContaining('보내셔야'), findsNothing);
    });

    testWidgets('6개월 주의가 따라온다', (tester) async {
      await openResult(tester, answers: notSent);
      await _openMissing(tester, 'doc_certified_mail');

      expect(find.textContaining('6개월 안에 다음 절차를 밟지 않으면'), findsOneWidget);
      expect(find.text('민법 제174조'), findsWidgets);
    });

    testWidgets('요금표를 두 벌로 만들지 않는다', (tester) async {
      // 화면에 그리는 것은 `proc_certified_mail.fees` **그 자체**다.
      // 우체국 요금이 오르면 고칠 자리가 한 곳이어야 한다.
      final container = await openResult(tester, answers: notSent);
      final bundle = container.read(domainBundleProvider).requireValue;
      final procedure = bundle
          .byId(kDebtRecoveryDomainId)
          .procedures
          .firstWhere((p) => p.id == 'proc_certified_mail');

      final document = container
          .read(documentResultsProvider(kDebtRecoveryDomainId))
          .firstWhere((d) => d.id == 'doc_certified_mail');
      expect(document.ifMissing!.seeProcedure, procedure.id);

      await _openMissing(tester, 'doc_certified_mail');
      final views = tester.widgetList<FeeScheduleView>(
        find.byType(FeeScheduleView),
      );
      expect(views, hasLength(1));
      expect(identical(views.single.fees, procedure.fees), isTrue);
    });
  });
}

/// 준비물 카드를 펴고 그 서류의 「없으면 어떻게 하나요」를 누른다.
Future<void> _openMissing(WidgetTester tester, String documentId) async {
  final card = find.text(DocumentCard.title);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();

  // 이 시나리오에서 펼칠 문이 달린 서류는 하나뿐이다. 둘이 되면 여기서 깨져
  // 테스트가 무엇을 누르는지 다시 말하게 만든다.
  final button = find.text(DocumentSection.missingAction);
  expect(button, findsOneWidget, reason: documentId);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}
