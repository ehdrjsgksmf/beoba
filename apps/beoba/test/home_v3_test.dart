import 'dart:io';

import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/app/theme.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/home/home_screen.dart';
import 'package:beoba/src/widgets/today_pill.dart';
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 홈 v3.
///
/// **첫 화면이 앱 전체의 신뢰를 정한다.** 결과 화면에서 조문을 통째로 인용하며
/// 쌓아 온 것을 홈 한 줄이 깎을 수 있다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('확인 안 된 숫자를 두지 않는다', () {
    testWidgets('홈에 통계도 카운터도 없다', (tester) async {
      await pumpApp(tester);

      // 목업에 있던 것들. 출처가 없거나 셀 방법이 없다.
      for (final banned in const [
        '78만',
        '90%',
        '함께한 사람',
        '변호사 없이',
        '대부분이에요',
      ]) {
        expectNoScreenText(tester, banned);
      }
    });

    test('앱 코드 어디에도 그 문구가 없다', () {
      // 화면에서 지웠는데 상수로 남아 있으면 다음 사람이 다시 꺼내 쓴다.
      final home = Directory('lib/src/screens/home');
      final sources = [
        for (final file in home.listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart'))
            file.readAsStringSync(),
      ].join('\n');

      expect(sources, isNotEmpty);
      for (final banned in const ['78만', '90%', '함께한 사람', '민사 사건']) {
        expect(sources, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('방어선 — 문구를 다듬어도 이 뜻은 남는다', () {
    testWidgets('법률 상담이 아니라는 말이 홈에 있다', (tester) async {
      // 변호사법 제112조 제3호 방어선이다.
      await pumpApp(tester);
      final texts = renderedTexts(tester);

      expect(
        texts.any(
          (t) => t.contains('법률 상담이 아니') || t.contains('변호사처럼 상담해드릴 수 없'),
        ),
        isTrue,
        reason: '홈에서 이 선이 사라졌습니다',
      );
    });

    testWidgets('승패를 말하지 않는다는 말이 홈에 있다', (tester) async {
      // 사용자가 처음부터 못박은 선이다. 예측하는 서비스가 아니다.
      await pumpApp(tester);
      expectScreenText(tester, '이길지 질지는 알려드릴 수 없어요');
    });
  });

  group('오늘은 한 군데서 온다', () {
    /// 부를 때마다 하루씩 넘어가는 시계. **자정을 사이에 둔 순간**을 흉내낸다.
    ///
    /// 예전에는 화면과 계산이 각자 `clock.today()` 를 불러서, 이런 시계 앞에서
    /// 홈은 어제 · 계산은 오늘이 됐다.
    testWidgets('홈 날짜와 기한 계산이 같은 날을 본다', (tester) async {
      final clock = _DriftingKstClock(const KstDate(2026, 8, 15));
      final container = await pumpApp(tester, clock: clock);

      final shown = ref0(container);
      final used = container
          .read(appClockProvider)
          .today();

      expect(shown, used, reason: '표시와 계산이 다른 날을 봅니다');
      expect(find.text('${TodayPill.prefix} ${_fmt(shown)}'), findsOneWidget);

      // **시계는 딱 한 번 불렸다.** 화면도 계산도 그 한 값을 나눠 쓴다.
      // 두 번 불리면 그 사이에 자정이 끼어들 수 있다.
      expect(clock.calls, 1, reason: '오늘을 두 번 물었습니다');
    });

    testWidgets('계산이 쓰는 시계도 흔들리지 않는다', (tester) async {
      final clock = _DriftingKstClock(const KstDate(2026, 8, 15));
      final container = await pumpApp(tester, clock: clock);
      seedAnswers(container, kDebtRecoveryDomainId);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      final today = container.read(todayProvider);
      final app = container.read(appClockProvider);
      // 몇 번을 물어도 같은 날이다. 원래 시계는 그 사이에도 계속 넘어간다.
      expect(app.today(), today);
      expect(app.today(), today);
      expect(container.read(appClockProvider).today(), today);

      // 기한도 같은 날을 기준으로 셌다.
      final deadlines =
          container.read(deadlineResultsProvider(kDebtRecoveryDomainId));
      for (final deadline in deadlines) {
        expect(
          deadline.daysRemaining,
          deadline.dueDate.differenceInDays(today),
          reason: deadline.id,
        );
      }
    });
  });

  group('약속은 두 층으로 나눈다', () {
    testWidgets('첫 화면은 사실만 짧게 말한다', (tester) async {
      await pumpApp(tester);

      expectScreenText(tester, HomeScreen.privacy);
      // **자판이 있는 한 사실이 아닌 말.** 다시 들어오는 것을 막는다.
      expectNoScreenText(tester, '어디에도 남지 않');
      expect(find.text(HomeScreen.privacyMore), findsOneWidget);
    });

    testWidgets('자세히를 누르면 못 막는 것까지 말한다', (tester) async {
      await pumpApp(tester);
      // 800x600 테스트 화면에서는 입력창 네 줄 아래라 접힌 선 밑에 있다.
      // 폰(360x780)에서는 자판이 올라와도 화면 안이다 — keyboard_test 가 잰다.
      await tester.ensureVisible(find.text(HomeScreen.privacyMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeScreen.privacyMore));
      await tester.pumpAndSettle();

      // 첫 줄이 고쳐졌다 — 집계가 나가므로 「인터넷으로 보내지 않아요」는
      // 더 이상 정확하지 않다(DECISIONS 136번). 나가지 않는 것은 적으신 글이다.
      expectScreenText(tester, '적으신 글은 나가지 않아요');
      expectScreenText(tester, '어떤 분야를 보셨는지만 세어요');
      expectScreenText(tester, '껐다 켜면 남지 않아요');
      expectScreenText(tester, '브라우저 뒤로 가기에도 남지 않아요');
      // **겁만 주고 끝내지 않는다.** 어디서 지우는지까지 말한다.
      expectScreenText(tester, '자판이 자주 쓰는 말을 스스로 기억할 수 있어요');
      expectScreenText(tester, '자판 설정에서 지우실 수 있어요');

      // 법 이야기가 아니다. 층 배지를 달지 않는다.
      expectNoScreenText(tester, '법에 있는 내용');
      expectNoScreenText(tester, '적용될 가능성');
    });

    testWidgets('소스에도 그 말이 없다', (tester) async {
      final home = File('lib/src/screens/home/home_screen.dart');
      expect(home.readAsStringSync(), isNot(contains('어디에도 남지 않')));
    });

    /// **자리를 재지 않는다. 구조를 본다.**
    ///
    /// 「바로 다음 형제」는 스크롤 본문에서 아무것도 보장하지 못한다 —
    /// 입력창만 따라 올라가고 이 줄은 뒤에 남는다. 입력창의 **일부**여야
    /// 한다(DECISIONS 119번). 좌표로 재면 여백을 고칠 때마다 깨진다.
    testWidgets('개인정보 줄은 입력창 안에 있다', (tester) async {
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byType(TextField),
          matching: find.text(HomeScreen.privacy),
        ),
        findsOneWidget,
        reason: '개인정보 줄이 입력창 밖으로 나갔습니다 (helper 가 아닙니다)',
      );
      expect(
        find.descendant(
          of: find.byType(TextField),
          matching: find.text(HomeScreen.privacyMore),
        ),
        findsOneWidget,
      );
    });

    testWidgets('자세히는 손가락으로 누를 수 있다', (tester) async {
      await pumpApp(tester);

      final tap = find.ancestor(
        of: find.text(HomeScreen.privacyMore),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getRect(tap).height,
        greaterThanOrEqualTo(BeobaTapTarget.minimum),
      );
    });
  });

  group('AI 라고 부르지 않는다', () {
    /// **안 쓰는데 그렇게 부르면 안 된다.**
    ///
    /// AI기본법 제2조 5호의 생성형도 아니고, 제2조 2호의 「자율성과 적응성을
    /// 가지고 추론하는」 것도 아니다. 규칙 표를 따라 내려갈 뿐이다.
    /// 그러니 제31조의 고지 의무도 지금은 없다(DECISIONS 32번).
    ///
    /// **이 잠금이 곧 알림 장치다.** 언젠가 진짜로 쓰게 되면 이 테스트를
    /// 고치게 되고, 그때 제31조를 같이 보게 된다.
    Future<void> expectNoAi(WidgetTester tester, String where) async {
      for (final banned in const ['AI', '인공지능', '에이아이']) {
        expectNoScreenText(tester, banned, reason: '$where — $banned');
      }
    }

    testWidgets('홈', (tester) async {
      await pumpApp(tester);
      await expectNoAi(tester, '홈');
    });

    testWidgets('인터뷰', (tester) async {
      final container = await pumpApp(tester);
      container
          .read(routerProvider)
          .go(Routes.interview(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      await expectNoAi(tester, '인터뷰');
    });

    testWidgets('결과', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      await expectNoAi(tester, '결과');

      for (final card in const ['드는 돈', '준비물', '어느 법원', '앞으로 밟는 길']) {
        final finder = find.text(card);
        if (finder.evaluate().isEmpty) continue;
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }
      await expectNoAi(tester, '결과(펼친 뒤)');
    });
  });

  group('라우트에 사용자 입력을 싣지 않는다', () {
    testWidgets('자유 입력을 라우터에 싣지 않는다', (tester) async {
      // **`extra` 로 넘기면 웹에서 브라우저 히스토리 state 에 들어간다.**
      // 주소창에는 안 보여도 뒤로·앞으로에 남고 세션 복원으로 디스크까지 간다.
      const secret = '작년 3월에 오백만원을 빌려줬어요';
      final container = await pumpApp(tester);

      await tester.enterText(find.byType(TextField).first, secret);
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeScreen.start));
      await tester.pumpAndSettle();

      final state = container.read(routerProvider).state;
      expect(state.extra, isNull, reason: '자유 입력이 라우트에 실렸습니다');
      expect(state.uri.toString(), isNot(contains('빌려줬')));

      // 그래도 다음 화면은 그 글을 알고 있다. 메모리로 왔기 때문이다.
      expect(container.read(pendingNarrativeProvider), secret);
    });

    testWidgets('주소창에 답변이 실리지 않는다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      final uri = container.read(routerProvider).state.uri.toString();
      expect(uri, '/result/$kDebtRecoveryDomainId');
      // 금액도 날짜도 주소에 없다.
      expect(uri, isNot(contains('50000000')));
      expect(uri, isNot(contains('2026')));
    });
  });
}

KstDate ref0(ProviderContainer container) => container.read(todayProvider);

String _fmt(KstDate d) => '${d.year}년 ${d.month}월 ${d.day}일';

/// 부를 때마다 하루씩 넘어가는 시계.
class _DriftingKstClock implements KstClock {
  _DriftingKstClock(this._start);

  final KstDate _start;
  int calls = 0;

  @override
  KstDate today() {
    calls++;
    return _start.addDays(calls);
  }

  @override
  DateTime nowUtc() => DateTime.utc(_start.year, _start.month, _start.day);

  /// 표시 전용이라 흔들지 않는다. 국내 사용자다.
  @override
  KstDate localToday() => _start.addDays(calls == 0 ? 1 : calls);
}
