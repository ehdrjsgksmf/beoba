import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/limitation_card.dart';
import 'package:beoba/src/screens/result/sections/today_card.dart';
import 'package:engines/engines.dart' show KstDate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 계좌로 돈이 빠져나갔을 때.
///
/// **이 분야는 되돌릴 수 없는 단위가 시간이다.** 다른 분야는 기한이 달·해
/// 단위인데 여기는 몇 시간 안에 지급정지가 되느냐로 갈린다.
///
/// 그런데 우리가 하는 일은 재촉이 아니다 — **어디에 먼저 말해야 하는지**가
/// 돈이 나간 방식에 따라 갈리고, 그걸 아무도 안 알려 준다.
const String kVoicePhishing = 'voice_phishing';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openResult(
    WidgetTester tester,
    Map<String, Object?> answers,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    seedAnswers(container, kVoicePhishing, answers: answers);
    container.read(routerProvider).go(Routes.result(kVoicePhishing));
    await tester.pumpAndSettle();
  }

  group('★ 돈이 나간 방식에 따라 창구가 갈린다', () {
    // 제3조 제1항은 **가목·나목만** 적어 두었다. 계좌로 보냈거나 계좌에서
    // 빠져나간 경우다. 직접 건네거나 뽑아서 건넨 경우(다목·라목)는
    // 제2항이라 수사기관이 요청한다. **네 갈래를 다 화면까지 끌고 간다.**
    const bankSide = ['transfer', 'drained'];
    const otherSide = ['handed', 'withdrawn'];

    for (final path in bankSide) {
      testWidgets('$path — 금융회사에 직접 신청할 수 있다고 나온다', (tester) async {
        await openResult(tester, {'q_role': 'victim', 'q_money_path': path});
        expectScreenText(tester, '피해금을 보낸 계좌를 맡은 금융회사에도');
        expectNoScreenText(tester, '법이 적어 둔 신청 대상에 그 경우가 없어요');
      });
    }

    for (final path in otherSide) {
      testWidgets('$path — 이 절차로는 안 걸린다고 나온다', (tester) async {
        await openResult(tester, {'q_role': 'victim', 'q_money_path': path});
        expectScreenText(tester, '법이 적어 둔 신청 대상에 그 경우가 없어요');
        expectNoScreenText(tester, '피해금을 보낸 계좌를 맡은 금융회사에도');

        // **「경찰서로 가세요」라고 쓰지 않는다.** 조문이 적어 둔 데까지다.
        expectNoScreenText(tester, '경찰서로 가세요');
        expectNoScreenText(tester, '신고하세요');
      });
    }
  });

  group('기한', () {
    testWidgets('잔액이 적을 때 30일과, 공고 뒤 두 달이 함께 선다', (tester) async {
      await openResult(tester, const {
        'q_role': 'victim',
        'q_money_path': 'transfer',
        'q_stop_notice_date': KstDate(2026, 8, 10),
        'q_notice_date': KstDate(2026, 8, 12),
      });

      // 급한 것 하나가 위에 서고 나머지는 접힌다. **둘 다 데이터에 있는지**를
      // 보려면 접힌 쪽을 열어야 한다 — 안 열면 안 그려지고, 안 그려지면
      // 검사가 못 본다(DECISIONS 175번).
      expectScreenText(tester, '잔액이 적을 때 개시 요청');

      await tester.tap(find.text(TodayCard.moreOpen));
      await tester.pumpAndSettle();
      expectScreenText(tester, '공고 뒤에 하는 피해구제 신청');
    });

    testWidgets('★ 계좌가 막힌 쪽에는 우리가 날짜를 찍지 않는다', (tester) async {
      await openResult(tester, const {
        'q_role': 'account_holder',
        'q_frozen_date': KstDate(2026, 8, 1),
        'q_notice_date': KstDate(2026, 8, 5),
      });

      // 제7조 제1항은 **시작하는 날과 끝나는 날의 기준이 다르다.**
      // 하나로 합쳐 날짜를 찍으면 그건 우리가 만든 날짜다.
      expectScreenText(tester, '저희가 날짜를 계산해서 찍지 않아요');
      expectNoScreenText(tester, '잔액이 적을 때 개시 요청');
      expectNoScreenText(tester, '공고 뒤에 하는 피해구제 신청');
    });
  });

  group('★ 계좌가 막힌 쪽 — 제7조만 낸다', () {
    testWidgets('이의제기 절차가 나오고, 죄 이야기는 한 글자도 없다', (tester) async {
      await openResult(tester, const {
        'q_role': 'account_holder',
        'q_frozen_date': KstDate(2026, 8, 1),
      });

      expectScreenText(tester, '금융회사에 이의를 제기할 수 있다고 법에 적혀 있어요');

      for (final word in const [
        '처벌',
        '범죄',
        '공범',
        '형사',
        '조사를 받',
        '구속',
      ]) {
        expectNoScreenText(tester, word, reason: '역할 2에 「$word」 가 나가면 안 됩니다');
      }
    });

    testWidgets('★ 다른 분야의 공통 조각이 하나도 안 붙는다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kVoicePhishing, answers: const {
        'q_role': 'account_holder',
        'q_frozen_date': KstDate(2026, 8, 1),
      });

      // **분야가 연수 갈래를 선언한 곳에만 붙는다**(DECISIONS 167번).
      // 이 분야는 limitationRules 를 아예 선언하지 않았다.
      expect(container.read(limitationRulesProvider(kVoicePhishing)), isEmpty);

      container.read(routerProvider).go(Routes.result(kVoicePhishing));
      await tester.pumpAndSettle();

      expect(find.byType(LimitationCard), findsNothing);
      for (final word in const ['소멸시효', '시효가', '빚을 정리', '개인회생', '파산']) {
        expectNoScreenText(tester, word, reason: '「$word」 가 이 분야에 붙었습니다');
      }
    });
  });

  group('금지 문구', () {
    testWidgets('★ 다 돌아온다고 쓰지 않는다', (tester) async {
      await openResult(tester, const {
        'q_role': 'victim',
        'q_money_path': 'transfer',
      });

      // 제10조 제2항이 정면으로 부정한다 — 남은 돈을 나눈다.
      expectScreenText(tester, '이미 빠져나간 돈은 이 절차로는 돌아오지 않아요');

      for (final word in const [
        '전액 돌려',
        '다 돌려받',
        '모두 돌려받',
        '돌려받으실 수 있어요',
        '보이스피싱입니다',
        '사기당하셨',
        '지금 당장',
        '서두르세요',
      ]) {
        expectNoScreenText(tester, word);
      }
    });
  });
}
