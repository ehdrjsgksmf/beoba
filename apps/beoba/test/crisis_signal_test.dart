import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/crisis/crisis_signal.dart';
import 'package:beoba/src/providers/crisis_providers.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/screens/crisis/crisis_screen.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/widgets/crisis_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// `autoTriggers` 는 **차단이 아니다.** 안내를 보여주고, 닫으면 하던 일을 계속한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    container = await bootstrappedContainer();
  });

  InterviewController controller() =>
      container.read(interviewSessionProvider(kDebtRecoveryDomainId).notifier);

  List<CrisisSignal> all() =>
      container.read(allCrisisSignalsProvider(kDebtRecoveryDomainId));

  CrisisSignal? priority() =>
      container.read(priorityCrisisSignalProvider(kDebtRecoveryDomainId));

  group('신호를 찾는다', () {
    test('자유 입력의 낱말로 걸린다', () {
      controller().start('도박 때문에 돈을 빌렸어요');

      expect(all().map((s) => s.id), contains('trg_gambling'));
    });

    test('연결처가 JSON 에서 그대로 온다', () {
      controller().start('도박 때문에 돈을 빌렸어요');

      final signal = all().firstWhere((s) => s.id == 'trg_gambling');
      expect(signal.channels.map((c) => c.phone), containsAll(['1336', '1600-5500']));
      // 코드에 기관명·번호를 적지 않는다.
      expect(signal.channels.map((c) => c.org), contains('한국도박문제예방치유원'));
    });

    test('마약은 차단이 아니라 연결로 간다', () {
      controller().start('마약 때문에 돈이 필요했습니다');

      expect(all().map((s) => s.id), contains('trg_drug'));
      // 형사 차단은 걸리지 않는다 (1단계에서 패턴을 뺐다).
      expect(
        container
            .read(hardStopsProvider(kDebtRecoveryDomainId))
            .map((s) => s.id),
        isEmpty,
      );
    });

    test('priority 신호가 앞에 온다', () {
      controller().start('돈이 없어서 죽고 싶습니다');

      expect(all().length, greaterThan(1));
      expect(all().first.id, 'trg_mental');
      expect(priority()?.id, 'trg_mental');
    });

    test('걸릴 낱말이 없으면 아무것도 없다', () {
      controller().start('빌려준 돈을 못 받고 있습니다');
      expect(all(), isEmpty);
    });
  });

  group('선택지에서 온 값으로는 걸리지 않는다', () {
    test('"돈이 없다고 합니다" 를 골라도 신호가 0건이다', () {
      // 상대가 돈이 없다고 했다는 답이다. 채권자에게 긴급복지를 띄우면 안 된다.
      controller().answer('q_role', 'creditor');
      controller().answer('q_debtor_response', 'no_money');

      expect(container.read(caseFactsProvider(kDebtRecoveryDomainId)).values,
          containsPair('debtorResponse', 'no_money'));
      expect(all(), isEmpty);
    });

    test('같은 낱말이라도 사용자가 쓴 것이면 걸린다', () {
      controller().start('돈이 없어서 굶고 있습니다');
      expect(all().map((s) => s.id), contains('trg_money_crisis'));
    });
  });

  group('닫기는 제거가 아니라 강등이다', () {
    test('priority 를 닫으면 전체 화면은 물러나되 고정 줄로 남는다', () {
      controller().start('죽고 싶습니다');
      expect(priority()?.id, 'trg_mental');

      controller().dismissSignal('trg_mental');

      expect(priority(), isNull);
      expect(
        container.read(pinnedCrisisSignalProvider(kDebtRecoveryDomainId))?.id,
        'trg_mental',
      );
      // 하단 목록에도 계속 남는다.
      expect(all().map((s) => s.id), contains('trg_mental'));
    });

    test('일반 신호를 닫으면 배너는 사라지고 하단에만 남는다', () {
      controller().start('도박 때문에 돈을 빌렸어요');
      expect(
        container
            .read(bannerCrisisSignalsProvider(kDebtRecoveryDomainId))
            .map((s) => s.id),
        contains('trg_gambling'),
      );

      controller().dismissSignal('trg_gambling');

      expect(
        container.read(bannerCrisisSignalsProvider(kDebtRecoveryDomainId)),
        isEmpty,
      );
      expect(all().map((s) => s.id), contains('trg_gambling'));
    });
  });

  group('화면', () {
    Future<void> startWith(WidgetTester tester, String narrative) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField).first, narrative);
      await tester.pump();
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();
      // 첫 화면에는 묶음 줄만 선다. 묶음을 거쳐 분야로 들어간다.
      await pickDomainFromList(tester, 'debt_recovery');
    }

    testWidgets('priority 신호는 전체 화면으로 덮는다', (tester) async {
      await startWith(tester, '돈 때문에 죽고 싶습니다');

      expect(find.byType(CrisisScreen), findsOneWidget);
      expect(find.text(CrisisScreen.title), findsOneWidget);
      // 번호가 글자로도 보인다. 데스크톱에서 옮겨 적을 수 있어야 한다.
      expect(find.text('109'), findsOneWidget);
      expect(find.text('자살예방상담전화'), findsOneWidget);
    });

    testWidgets('차단이 아니다 — 닫으면 하던 일로 돌아간다', (tester) async {
      await startWith(tester, '돈 때문에 죽고 싶습니다');

      await tester.tap(find.text(CrisisScreen.close));
      await tester.pumpAndSettle();

      expect(find.byType(CrisisScreen), findsNothing);
      expect(find.text('받아야 할 돈인가요, 갚아야 할 돈인가요?'), findsOneWidget);
      // 닫아도 한 줄은 남는다.
      expect(find.text(CrisisPinnedBar.label), findsOneWidget);
    });

    testWidgets('일반 신호는 인터뷰 안에 배너로 뜬다', (tester) async {
      await startWith(tester, '도박 때문에 돈을 빌렸어요');

      expect(find.byType(CrisisScreen), findsNothing);
      expect(find.text(CrisisBanners.heading), findsOneWidget);
      expect(find.text('1336'), findsOneWidget);
    });

    testWidgets('결과 화면 하단에는 닫은 것도 남는다', (tester) async {
      final container = await pumpApp(tester);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start('도박 때문에 돈을 빌렸어요');
      seedAnswers(container, kDebtRecoveryDomainId);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .dismissSignal('trg_gambling');

      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(CrisisFooter.heading),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(CrisisFooter.heading), findsOneWidget);
    });
  });

  group('주소에 아무것도 남기지 않는다', () {
    testWidgets('위기 화면 주소에 트리거 id 가 없다', (tester) async {
      final container = await pumpApp(tester);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start('죽고 싶습니다');
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      final location = container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

      expect(find.byType(CrisisScreen), findsOneWidget);
      expect(location, isNot(contains('trg_')));
      expect(location, Routes.crisis(kDebtRecoveryDomainId));
    });
  });
}
