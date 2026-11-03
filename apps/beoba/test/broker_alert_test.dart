import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/defense/broker_watch.dart';
import 'package:beoba/src/providers/broker_providers.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/widgets/broker_alert_card.dart';
import 'package:beoba/src/widgets/legal_basis_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// ② 방어 — 브로커가 하는 말이 사용자 문장에 있으면 되짚어 준다.
///
/// **차단이 아니다.** 브로커를 만났다고 앱을 못 쓰게 하면 그 사람은 브로커에게
/// 돌아간다. 전체 화면도 아니다 — 전체 화면은 `trg_mental` 하나뿐이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('걸리는 자리 — 홈 자유 서술', () {
    late ProviderContainer container;

    setUp(() async {
      container = await bootstrappedContainer();
    });

    InterviewController controller() =>
        container.read(interviewSessionProvider(kDebtRecoveryDomainId).notifier);

    List<BrokerWarning> all() =>
        container.read(allBrokerWarningsProvider(kDebtRecoveryDomainId));

    test('브로커의 말을 옮겨 적으면 걸린다', () {
      controller().start('통장 빌려주면 돈 준다고 해요');
      expect(all().map((w) => w.id), contains('ba_account_lend'));
    });

    test('분야 파일의 경보도 함께 본다', () {
      // ba_debt_collection 은 debt_recovery 에 있고 나머지는 _shared_crisis 에 있다.
      controller().start('돈을 대신 받아준다는 사람이 있어요');
      expect(all().map((w) => w.id), contains('ba_debt_collection'));
    });

    test('멈춰 세우는 것이 먼저 온다', () {
      controller().start('사진 한 장만 주면 된다면서 신용등급 올려 준대요');

      final ids = all().map((w) => w.id).toList();
      expect(ids, contains('ba_photo_extortion_loan'));
      expect(ids, contains('ba_credit_erase'));
      expect(
        ids.indexOf('ba_photo_extortion_loan'),
        lessThan(ids.indexOf('ba_credit_erase')),
      );
    });

    test('위험도와 무게는 다른 축이다', () {
      // 착수금 선입금 요구는 severity 가 red 인데 멈춰 세우지 않는다.
      // 위험도는 높지만 사용자가 **지금 되돌릴 것이 없다.**
      controller().start('착수금 먼저 보내라고 하는데요');

      final warning = all().firstWhere((w) => w.id == 'ba_upfront_fee');
      expect(warning.isHighRisk, isTrue);
      expect(warning.isStop, isFalse);
    });

    test('멈춰 세우는 것은 셋뿐이다', () {
      // 넷째가 되고 싶어지면 검증기가 빌드를 세운다.
      const expected = {
        'ba_account_lend',
        'ba_photo_extortion_loan',
        'ba_body_collateral_loan',
      };
      for (final id in expected) {
        controller().start(_narrativeFor(id));
        final warning = all().firstWhere((w) => w.id == id);
        expect(warning.isStop, isTrue, reason: id);
      }
    });

    test('아무 말도 안 적으면 아무것도 안 걸린다', () {
      controller().start('');
      expect(all(), isEmpty);
    });

    test('평범한 문장에는 걸리지 않는다', () {
      // 이 앱에 실제로 올 사람의 말이다. 낱말 정답지가 잡지 못하는 조합을 본다.
      for (final text in const [
        '오년 전에 빌려준 돈을 장기간 못 받고 있어요',
        '체크카드로 이체한 내역은 있는데 차용증이 없어요',
        '변호사 착수금이 얼마나 드는지 알고 싶어요',
      ]) {
        controller().start(text);
        expect(all(), isEmpty, reason: text);
      }
    });
  });

  group('닫기 — 그 화면에서만 물러난다', () {
    late ProviderContainer container;

    setUp(() async {
      container = await bootstrappedContainer();
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start('통장 빌려주면 돈 준다고 해요');
    });

    test('닫으면 인터뷰에서는 사라진다', () {
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .dismissSignal('ba_account_lend');

      expect(
        container
            .read(openBrokerWarningsProvider(kDebtRecoveryDomainId))
            .map((w) => w.id),
        isNot(contains('ba_account_lend')),
      );
    });

    test('닫아도 결과 화면에는 남는다', () {
      // 브로커는 결과를 본 뒤에 연락한다.
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .dismissSignal('ba_account_lend');

      expect(
        container
            .read(allBrokerWarningsProvider(kDebtRecoveryDomainId))
            .map((w) => w.id),
        contains('ba_account_lend'),
      );
    });
  });

  group('화면 — 데이터의 말만 쓴다', () {
    Future<ProviderContainer> openResult(
      WidgetTester tester,
      String narrative,
    ) async {
      final container = await pumpApp(tester);
      final controller =
          container.read(interviewSessionProvider(kDebtRecoveryDomainId).notifier);
      controller.start(narrative);
      completeAnswers.forEach(controller.answer);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('브로커의 말임이 분명하게 나온다', (tester) async {
      await openResult(tester, '통장 빌려주면 돈 준다고 해요');

      // 「~라고 하셨네요」가 아니다. 사용자는 그 말을 옮긴 것이지 한 것이 아니다.
      expect(find.text(BrokerAlertCard.heading), findsWidgets);
      expect(find.textContaining('하셨네요'), findsNothing);
      expect(find.textContaining('속으셨'), findsNothing);
    });

    testWidgets('phrase 와 truth 가 데이터 그대로 나온다', (tester) async {
      await openResult(tester, '통장 빌려주면 돈 준다고 해요');

      await tester.scrollUntilVisible(
        find.textContaining('통장 · 체크카드 · 비밀번호만'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('통장 · 체크카드 · 비밀번호만'), findsOneWidget);
      expect(find.textContaining('잔액이 0원이어도'), findsOneWidget);
    });

    testWidgets('근거 조문은 접히지 않는다', (tester) async {
      // 그 자리에서 판단해야 하는 정보다. 한 번 더 누르게 하지 않는다.
      await openResult(tester, '통장 빌려주면 돈 준다고 해요');

      final quote = find.textContaining('접근매체를 양도하거나 양수한 자');
      await tester.scrollUntilVisible(
        quote,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(quote, findsOneWidget);
      expect(find.text(LegalBasisCard.open), findsNothing);
    });

    testWidgets('걸린 게 없으면 자리조차 없다', (tester) async {
      await openResult(tester, '오년 전에 빌려준 돈을 못 받고 있어요');

      expect(find.byType(BrokerAlertCard), findsNothing);
      expect(find.text(BrokerAlertSection.heading), findsNothing);
    });

    testWidgets('경보 하나가 화면 두 장을 넘지 않는다', (tester) async {
      // 채권추심의 근거는 「추심업이란」 → 「대상 채권이란」 → 시행령 →
      // 민사집행법의 **네 단 사슬**이다. 원문을 다 펼쳤더니 카드 하나가
      // 1,870px — 화면 두 장 반이었고, 정작 읽어야 할 truth 가 안 보였다.
      // 사슬(alsoBasis)을 접어 960px 로 줄였다. 조문 이름과 🟢 라벨은 남는다.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await openResult(tester, '돈을 대신 받아준다는 사람이 있어요');

      final height = tester.getSize(find.byType(BrokerAlertCard).first).height;
      expect(height, lessThan(844 * 2), reason: '${height}px');
    });

    testWidgets('결과 화면에서는 닫기가 없다', (tester) async {
      await openResult(tester, '통장 빌려주면 돈 준다고 해요');

      final card = tester.widget<BrokerAlertCard>(
        find.byType(BrokerAlertCard).first,
      );
      expect(card.onDismiss, isNull);
    });
  });

  group('무게 — display 가 정한다. severity 는 색이다', () {
    testWidgets('stop 은 큰 머리글과 창구 버튼을 단다', (tester) async {
      final container = await pumpApp(tester);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start('사진 한 장만 주면 된대요');
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 1));
      await tester.pumpAndSettle();

      expect(find.text(BrokerAlertCard.stopHeading), findsOneWidget);
      // 창구는 데이터가 준다. 코드에 번호를 적지 않는다.
      expect(find.text('경찰 신고'), findsOneWidget);
    });

    testWidgets('붉지만 안 멈추는 경보가 있다', (tester) async {
      // severity red · display inline. 조문도 창구도 똑같이 붙는다 —
      // **덜 중요해서 인라인이 아니다.**
      final container = await pumpApp(tester);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start('착수금 먼저 보내라고 하는데요');
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 1));
      await tester.pumpAndSettle();

      expect(find.text(BrokerAlertCard.stopHeading), findsNothing);
      expect(find.text(BrokerAlertCard.heading), findsOneWidget);
      // 창구는 그대로 붙는다.
      expect(find.text('금감원에 신고'), findsOneWidget);
    });

    testWidgets('stop 이 아니면 큰 머리글이 없다', (tester) async {
      final container = await pumpApp(tester);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start('폰테크 하면 된다고 해요');
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 1));
      await tester.pumpAndSettle();

      expect(find.byType(BrokerAlertCard), findsOneWidget);
      expect(find.text(BrokerAlertCard.stopHeading), findsNothing);
      expect(find.text(BrokerAlertCard.heading), findsOneWidget);
    });

    testWidgets('차단이 아니다 — 인터뷰가 그대로 열려 있다', (tester) async {
      final container = await pumpApp(tester);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start('사진 한 장만 주면 된대요');
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 1));
      await tester.pumpAndSettle();

      // 하드스톱 화면이 아니고, 질문과 다음 버튼이 그대로 있다.
      expect(find.byType(BrokerAlertCard), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
    });
  });
}

/// 그 경보가 걸리는 문장. 정답지의 양성 사례에서 그대로 가져왔다.
String _narrativeFor(String alertId) => switch (alertId) {
      'ba_account_lend' => '통장 빌려주면 돈 준대요',
      'ba_photo_extortion_loan' => '사진 한 장만 주면 된대요',
      'ba_body_collateral_loan' => '몸으로 갚으라고 합니다',
      _ => '',
    };
