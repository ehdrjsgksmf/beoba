import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/domain_select/domain_select_screen.dart';
import 'package:beoba/src/screens/domain_select/upcoming_screen.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/screens/interview/interview_screen.dart';
import 'package:beoba/src/screens/interview/redirect_notice.dart';
import 'package:beoba/src/screens/summary/summary_screen.dart';
import 'package:beoba/src/widgets/why_ask_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_coverage.dart';
import 'support/test_app.dart';

/// 홈에서 인터뷰까지 실제로 굴러가는지 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 홈 → 분야 선택 → 인터뷰 첫 질문.
  Future<void> startInterview(WidgetTester tester, {String narrative = ''}) async {
    await pumpApp(tester);

    if (narrative.isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, narrative);
      await tester.pump();
    }

    await tester.tap(find.text(HomeScreen.start));
    await tester.pumpAndSettle();

    // 첫 화면에는 묶음 줄만 선다(DECISIONS 237번). 묶음을 거쳐 들어간다.
    await pickDomainFromList(tester, kDebtRecoveryDomainId);

    // 첫 질문은 역할 확인, 그다음이 법원 서류다. **기한이 정해진 서류를
    // 다른 무엇보다 먼저 묻는다**(DECISIONS 121번). 그 뒤부터가 기존 흐름.
    await tester.tap(find.text('제가 받아야 할 돈입니다'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(InterviewScreen.next));
    await tester.pumpAndSettle();

    await tester.tap(find.text('없습니다'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(InterviewScreen.next));
    await tester.pumpAndSettle();
  }

  group('홈', () {
    testWidgets('처음 보이는 곳에는 인사말·입력창·시작하기만 있다', (tester) async {
      // 이탈은 첫 화면에 읽을 게 몇 개냐로 갈린다. 설명은 접힌 선 아래로 내렸다.
      await pumpApp(tester);

      expect(find.text(HomeScreen.greetingName), findsOneWidget);
      expect(find.text(HomeScreen.lead), findsOneWidget);
      expect(find.text(HomeScreen.privacy), findsOneWidget);
      expect(find.text(HomeScreen.start), findsOneWidget);
    });

    testWidgets('하지 않는 일은 아래에서 밝힌다', (tester) async {
      // 먼저 내미는 변명과 묻는 사람에게 하는 대답은 다르게 읽힌다.
      await pumpApp(tester);

      expect(find.text(HomeScreen.cannotTitle), findsOneWidget);
      for (final (headline, _) in HomeScreen.cannotDo) {
        expect(find.text(headline), findsOneWidget);
      }
    });

    testWidgets('AI 를 쓴다고 말하지 않는다', (tester) async {
      // M1 은 도메인 JSON 과 결정론적 엔진뿐이다. 안 쓰는 것을 쓴다고 적으면
      // "AI 가 지어내지 않는다" 는 제품의 안전 논리가 첫 화면에서 무너진다.
      await pumpApp(tester);

      for (final word in ['인공지능', 'AI', '챗봇']) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '첫 화면이 "$word" 를 말하고 있습니다 (DECISIONS 32번)',
        );
      }
    });

    testWidgets('M1 에 없는 기능을 약속하지 않는다', (tester) async {
      // 첫 화면에서 약속하고 끝까지 안 나오면 사용자는 못 찾은 줄 알고 다시 뒤진다.
      await pumpApp(tester);
      expect(find.textContaining('연결'), findsNothing);
    });

    // 개인정보 고지의 자리는 **입력창 바로 아래**다. 여기 있던 「위에 있다」는
    // 규칙은 「자판이 입력창 아래를 통째로 가린다」는 가정 위에 서 있었는데,
    // 본문이 스크롤이라 입력창과 함께 밀려 올라온다(keyboard_test 가 잰다).
    // 규칙은 home_v3_test 「개인정보 줄은 입력창 바로 아래다」로 옮겼다.
  });

  group('분야 선택', () {
    testWidgets('분야 이름이 코드가 아니라 JSON 에서 온다', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();

      final bundle = container.read(domainBundleProvider).requireValue;

      // **준비 중 분야가 0개가 됐다.** debt_relief 가 마지막이었다
      // (DECISIONS 143번). 회색 카드도 함께 사라진다.
      expect(bundle.upcoming, isEmpty);
      expect(find.text(DomainSelectScreen.comingSoon), findsNothing);

      // **개수를 손으로 적지 않는다.** 분야가 늘 때 여기만 뒤처진다
      // (DECISIONS 247번).
      expect(bundle.selectable, hasLength(allDomainIds().length));

      // **묶음마다 열어서 본다.** 첫 화면에는 묶음 줄만 있으므로 거기서만
      // 찾으면 「분야 이름이 하나도 없다」로 통과해 버린다.
      for (final (group, domains) in bundle.grouped) {
        if (group != null) {
          container.read(routerProvider).go(Routes.domainGroup(group.id));
          await tester.pumpAndSettle();
        }
        for (final domain in domains) {
          await tester.ensureVisible(find.text(domain.name));
          expect(find.text(domain.name), findsOneWidget);
        }
      }
    });

    testWidgets('준비 중 화면은 살아 있다 — 다음 분야를 위해', (tester) async {
      // 회색 카드가 막다른 길이면 사용자는 여기서 앱을 닫는다. 지금은
      // 준비 중 분야가 0개라 화면에 닿을 길이 없지만, **여섯 번째 분야를
      // 열 때 다시 쓴다.** 그때 깨져 있으면 안 된다.
      final container = await pumpApp(tester);
      container.read(routerProvider).go(Routes.upcoming(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(find.text(UpcomingScreen.title), findsOneWidget);
      expect(find.text(UpcomingScreen.channelsTitle), findsOneWidget);
      // 창구 번호가 실제로 실린다.
      expect(find.text('132'), findsWidgets);
    });
  });

  group('인터뷰', () {
    testWidgets('첫 질문과 "왜 묻나요?" 가 함께 나온다', (tester) async {
      await startInterview(tester);

      expect(find.text('어떤 돈을 받지 못하고 계신가요?'), findsOneWidget);
      // whyAsk 는 제품의 차별점이다. 질문만 있고 이유가 없으면 안 된다.
      expect(find.byType(WhyAskCard), findsOneWidget);
      expect(find.text(WhyAskCard.title), findsOneWidget);
      // 괄호 병기가 밑줄로 옮겨 갔다. 문장은 짧아지고 뜻은 시트로 간다.
      expectScreenText(
        tester,
        '돈의 성격에 따라 밟을 수 있는 절차가 달라집니다. 시효도 달라집니다.',
      );
    });

    testWidgets('필수 질문은 답하기 전까지 다음으로 못 넘어간다', (tester) async {
      await startInterview(tester);

      final next = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, InterviewScreen.next),
      );
      expect(next.onPressed, isNull);

      await tester.tap(find.text('빌려준 돈'));
      await tester.pumpAndSettle();

      final enabled = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, InterviewScreen.next),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('답하면 다음 질문으로 넘어가고 뒤로 가면 답이 남아 있다', (tester) async {
      await startInterview(tester);

      await tester.tap(find.text('빌려준 돈'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(InterviewScreen.next));
      await tester.pumpAndSettle();

      expect(find.text('받지 못한 금액은 얼마인가요?'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('어떤 돈을 받지 못하고 계신가요?'), findsOneWidget);
      // 되돌아왔을 때 고른 답이 그대로 채워져 있어야 한다.
      expect(find.text(InterviewScreen.save), findsOneWidget);
    });

    testWidgets('다른 분야로 가야 하는 답은 안내로 끊고 창구를 준다', (tester) async {
      await startInterview(tester);

      // '못 받은 임금' 은 wage_theft 로 넘긴다. 아직 준비 중인 분야다.
      await tester.tap(find.text('못 받은 임금·월급'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(InterviewScreen.next));
      await tester.pumpAndSettle();

      expect(find.text(RedirectNotice.title), findsOneWidget);
      // 끊기만 하고 끝내지 않는다. 어디로 가면 되는지는 말한다.
      expect(find.text(RedirectNotice.channelsTitle), findsOneWidget);
      expect(find.text('1350'), findsOneWidget);
    });

    testWidgets('보증금은 debt_recovery 로 끝까지 안내하지 않는다', (tester) async {
      // 보증금 반환에는 전용 절차가 있다. 여기서 계속 가면 틀린 절차를 알려준다.
      // 지웠다면 이 사람은 "그 밖의 돈" 을 골라 끝까지 틀린 안내를 받았을 것이다.
      await startInterview(tester);

      await pickDomainFromList(tester, 'deposit_return');
      await tester.tap(find.text(InterviewScreen.next));
      await tester.pumpAndSettle();

      expect(find.text(RedirectNotice.title), findsOneWidget);
      expect(find.text('1588-1663'), findsOneWidget);
    });
  });

  group('사건 정리 카드', () {
    testWidgets('답한 내용이 라벨로 표시되고 고치기 버튼이 붙는다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId);

      container.read(routerProvider).go(Routes.summary(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(find.text(SummaryScreen.fixTitle), findsOneWidget);
      expect(find.text(SummaryScreen.fixRow), findsWidgets);

      // 코드가 'loan' 을 번역하지 않는다. 라벨은 데이터에서 온다.
      expect(find.text('빌려준 돈'), findsOneWidget);
      // 금액과 날짜는 포매터 한 곳을 거친다.
      expect(find.text('50,000,000원'), findsOneWidget);
      expect(find.text('2026년 3월 1일'), findsOneWidget);
    });

    testWidgets('고치기를 누르면 그 질문으로 돌아간다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId);

      container.read(routerProvider).go(Routes.summary(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      await tester.tap(find.text(SummaryScreen.fixRow).first);
      await tester.pumpAndSettle();

      expect(find.text('받아야 할 돈인가요, 갚아야 할 돈인가요?'), findsOneWidget);
      expect(find.text(InterviewScreen.save), findsOneWidget);
    });
  });
}
