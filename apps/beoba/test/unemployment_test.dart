import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/receive_window_card.dart';
import 'package:beoba/src/screens/result/sections/today_card.dart';
import 'package:beoba/src/widgets/legal_basis_card.dart';
import 'package:engines/engines.dart' show KstDate;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 일이 끊겼을 때.
///
/// **이 분야의 기한은 성격이 다르다.** 다른 기한은 「그 안에 신청해야 한다」인데
/// 이것은 「그 안에 다 받아야 한다」다(고용보험법 제48조 제1항). 늦게 신청하면
/// 신청할 권리를 잃는 것이 아니라 **아직 안 받은 날짜를 잃는다.**
///
/// 그리고 **우리는 되는지 안 되는지 말하지 않는다.** 제58조가 판정 주체를
/// 조문에 박아 두었다 — 「직업안정기관의 장이 인정하는 경우에는」.
const String kUnemployment = 'unemployment_benefit';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openAllStatutes(WidgetTester tester) async {
    final cards = find.byType(LegalBasisCard);
    for (var i = 0; i < cards.evaluate().length; i++) {
      await tester.ensureVisible(cards.at(i));
      await tester.pumpAndSettle();
      await tester.tap(cards.at(i), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }

  Future<void> openQuestion(WidgetTester tester, String question) async {
    final head = find.text(question);
    expect(head, findsOneWidget, reason: '「$question」 물음이 없습니다');
    await tester.ensureVisible(head);
    await tester.pumpAndSettle();
    await tester.tap(head, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> openResult(
    WidgetTester tester,
    Map<String, Object?> answers,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    seedAnswers(container, kUnemployment, answers: answers);
    container.read(routerProvider).go(Routes.result(kUnemployment));
    await tester.pumpAndSettle();
    return container;
  }

  const notYet = {
    'q_last_work_date': KstDate(2026, 8, 1),
    'q_reported': 'not_yet',
    'q_insured_months': 'under_six',
  };

  const reported = {
    'q_last_work_date': KstDate(2026, 8, 1),
    'q_reported': 'yes',
    'q_insured_months': 'six_plus',
  };

  /// ★★ **신청 기한이 아니라 받는 기간이다**(DECISIONS 189번).
  ///
  /// 이 앱의 다른 기한과 문장이 달라야 한다. 다른 기한은 「그날까지 하세요」이고
  /// 이것은 「그날이 지나면 남은 날짜가 사라져요」다. 같은 카드로 그리면 정확히
  /// 반대 방향으로 안심시키는 화면이 된다.
  group('★ 12개월은 신청 기한이 아니라 받는 기간이다', () {
    testWidgets('전용 카드로 서고, 「오늘 할 일」의 기한이 아니다', (tester) async {
      final container = await openResult(tester, notYet);

      expect(find.byType(ReceiveWindowCard), findsOneWidget);
      expectScreenText(tester, ReceiveWindowCard.title);
      expect(
        container.read(receiveWindowProvider(kUnemployment)), hasLength(1));
      // **「오늘 할 일」에 안 들어간다.** 들어가면 「그날까지 신청하면 된다」로
      // 읽히는데 실제로는 늦어지는 만큼 받을 날이 줄어든다.
      expect(
        container.read(dueDeadlinesProvider(kUnemployment)),
        isEmpty,
        reason: '받는 기간이 기한 자리에 들어가 있습니다',
      );
      expect(find.byType(TodayCard), findsOneWidget);
    });

    testWidgets('★ 지나면 무엇이 사라지는지 카드가 스스로 말한다', (tester) async {
      await openResult(tester, notYet);
      expectScreenText(tester, '아직 못 받은 날짜가 남아 있어도 더는 못 받아요');
      expectScreenText(tester, '늦어지는 만큼 받을 수 있는 날이 줄어들어요');
    });

    testWidgets('D-day 를 붙이지 않는다 — 세는 날이 아니라 닫히는 창이다', (tester) async {
      await openResult(tester, notYet);
      expectNoScreenText(tester, 'D-');
      expectNoScreenText(tester, '일 남음');
      expectNoScreenText(tester, 'D+');
      expectNoScreenText(tester, '일 지남');
      expectNoScreenText(tester, 'D-DAY');
    });

    testWidgets('이직일이 아니라 이직일의 다음 날부터 12개월이다', (tester) async {
      await openResult(tester, notYet);
      // 2026-08-01 에 마지막 근무 → 기산일 8월 2일 → 2027년 8월 1일까지.
      expectScreenText(tester, '2027년 8월 1일${ReceiveWindowCard.until}');
      await openAllStatutes(tester);
      expectScreenText(tester, '이직일의 다음 날부터 계산하기 시작하여 12개월 내에');
    });

    testWidgets('늦어지면 두 번 깎인다고 한 카드에서 말한다', (tester) async {
      await openResult(tester, notYet);
      expectScreenText(tester, '신고가 늦어져도 그 기간은 늘어나지 않아요');
      expectScreenText(tester, '실제로 받는 날이 두 번 줄어들어요');
      await openAllStatutes(tester);
      expectScreenText(tester, '7일간은 대기기간으로 보아 구직급여를 지급하지 아니한다');
    });
  });

  /// ★ **이 분야에서 제일 위험한 자리.**
  ///
  /// 「제 발로 나왔으니 안 되겠지」로 아예 안 가 보는 사람이 제일 많은데,
  /// 제58조 제2호 다목이 고용노동부령의 **정당한 사유** 쪽으로 문을 열어 두고
  /// 있다. 그 목록을 우리는 못 봤다(DECISIONS 191번).
  group('★ 우리가 되는지 안 되는지 말하지 않는다', () {
    testWidgets('판정 주체가 조문 문언 그대로 화면에 있다', (tester) async {
      await openResult(tester, notYet);
      expectScreenText(tester, '직업안정기관의 장이 인정하는 경우에는');
      await openAllStatutes(tester);
      expectScreenText(
        tester,
        '해당한다고 직업안정기관의 장이 인정하는 경우에는 수급자격이 없는 것으로 본다',
      );
    });

    testWidgets('★ 이직 사유를 묻는 질문이 하나도 없다', (tester) async {
      final container = await pumpApp(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(kUnemployment);

      // 물으면 우리가 제58조 각 호에 대입하는 모양이 된다. 부당해고에서
      // 「부당한 것 같나요」를 안 만든 것과 같다(DECISIONS 190번).
      expect(
        domain.intake.map((q) => q.field).toSet(),
        {'lastWorkDate', 'reported', 'insuredMonths'},
        reason: '이 분야가 묻는 것은 셋뿐입니다',
      );

      final asked = [
        for (final question in domain.intake) ...[
          question.text,
          question.whyAsk,
          for (final option in question.options) option.label,
        ],
      ];
      for (final word in const ['이직 사유', '그만두', '퇴사', '왜 나오', '해고']) {
        expect(
          asked.where((t) => t.contains(word)),
          isEmpty,
          reason: '「$word」 를 묻고 있습니다. 물으면 우리가 제58조에 대입하게 됩니다',
        );
      }
    });

    testWidgets('정당한 사유 목록을 못 봤다고 말한다', (tester) async {
      await openResult(tester, notYet);
      expectScreenText(tester, '정당한 사유 목록은 저희가 아직 못 봤어요');
    });

    testWidgets('★ 제58조 각 호가 원문 그대로 있다', (tester) async {
      await openResult(tester, notYet);
      await openAllStatutes(tester);
      for (final ho in const [
        '중대한 귀책사유(歸責事由)로 해고된 피보험자',
        '전직 또는 자영업을 하기 위하여 이직한 경우',
        '고용노동부령으로 정하는 정당한 사유에 해당하지 아니하는 사유로 이직한 경우',
      ]) {
        expectScreenText(tester, ho);
      }
    });
  });

  /// ★★ 실무에서 제일 자주 막히는 자리인데 조문 둘이 양쪽에서 받친다.
  group('★ 회사가 이직확인서를 안 써 줄 때', () {
    testWidgets('본인이 요청하는 길과 고용센터가 요청하는 길이 함께 있다', (tester) async {
      await openResult(tester, notYet);
      await openQuestion(tester, '회사가 서류를 안 써 줘요');
      await openAllStatutes(tester);
      expectScreenText(tester, '요청을 받은 사업주는 고용노동부령으로 정하는 바에 따라 이직확인서를 발급하여 주어야 한다');
      expectScreenText(tester, '이직확인서의 제출을 요청할 수 있다');
    });
  });

  group('★ 스스로 접는 이유를 조문으로 지운다', () {
    testWidgets('짧게 다녔어도 3년 안이면 앞 회사 기간을 합친다', (tester) async {
      await openResult(tester, notYet);
      expectScreenText(tester, '전에 다니던 회사를 그만둔 날부터 3년 안에');
      await openAllStatutes(tester);
      expectScreenText(tester, '종전의 적용 사업에서의 피보험기간을 합산한다');
      // 단서를 빼면 반대쪽 사람에게 틀린 기대를 준다.
      expectScreenText(tester, '구직급여를 지급받은 사실이 있는 경우에는');
    });

    testWidgets('6개월이 넘는다고 하시면 합산 카드는 안 뜬다', (tester) async {
      await openResult(tester, reported);
      expectNoScreenText(tester, '전에 다니던 회사를 그만둔 날부터 3년 안에');
    });

    testWidgets('180일을 우리가 세지 않는다고 말한다', (tester) async {
      await openResult(tester, notYet);
      await openQuestion(tester, '무슨 조건이 있나요?');
      expectScreenText(tester, '저희가 세어 드리지 않아요');
      await openAllStatutes(tester);
      expectScreenText(tester, '합산하여 180일 이상일 것');
      expectScreenText(tester, '기준기간은 이직일 이전 18개월로 하되');
    });
  });

  group('신고했는지에 따라 갈린다', () {
    testWidgets('아직 안 하셨으면 두 번 깎인다는 카드가 펼쳐진다', (tester) async {
      await openResult(tester, notYet);
      expectScreenText(tester, '지체 없이');
      expectNoScreenText(tester, '대기기간으로 보아 지급하지 않는다고 법에 적혀 있어요');
    });

    testWidgets('하셨으면 대기기간 카드로 바뀐다', (tester) async {
      await openResult(tester, reported);
      await openQuestion(tester, '신고하면 바로 나오나요?');
      expectScreenText(tester, '대기기간으로 보아 지급하지 않는다고 법에 적혀 있어요');
      expectNoScreenText(tester, '실제로 받는 날이 두 번 줄어들어요');
    });
  });

  group('★ 늘어나려면 신고해야 한다', () {
    testWidgets('「신고하면」을 빼지 않는다', (tester) async {
      await openResult(tester, notYet);
      await openQuestion(tester, '지금 일할 수 없는 사정이 있어요');
      expectScreenText(tester, '신고해야 늘어난다고 적혀 있어서, 신고 없이 지나가면 늘어나지 않아요');
      await openAllStatutes(tester);
      expectScreenText(tester, '직업안정기관에 신고한 경우에는');
    });
  });

  group('없는 값을 없다고 말한다', () {
    testWidgets('★ 못 받은 조문은 「더 있다」로 두고 우리 말로 풀지 않는다', (tester) async {
      await openResult(tester, notYet);
      await openQuestion(tester, '표에서 제 줄이 어느 것인가요?');
      // 제50조 제4항은 원문이 있고 제3항은 아직 못 받았다.
      expectScreenText(tester, '그 밖의 조건도 같은 조에 더 있는데 저희가 그 원문을 아직 못 받았어요');
      // 못 받은 조문의 내용을 우리가 지어내지 않는다.
      for (final word in const ['적용 제외', '소급', '신고를 안 했으면']) {
        expectNoScreenText(tester, word);
      }
    });
  });


  /// ★ **칸은 못 골라도 표는 낸다**(DECISIONS 193번).
  ///
  /// 며칠분인지를 안 보여주면 「12개월 안에 다 받아야 한다」가 반쪽으로 서고,
  /// 왜 늦으면 손해인지가 안 와닿는다. 표는 2행 5열뿐이라 본인이 찾는다.
  group('★ 소정급여일수 표를 같은 카드에서 낸다', () {
    testWidgets('범위 한 줄이 펼친 채로 먼저 보인다', (tester) async {
      await openResult(tester, notYet);
      expectScreenText(tester, '나이와 일한 기간에 따라 120일에서 270일 사이예요');
    });

    testWidgets('표가 12개월 카드 안에 있다 — 따로 서지 않는다', (tester) async {
      await openResult(tester, notYet);
      final card = find.byType(ReceiveWindowCard);
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('[별표 1]'),
        ),
        findsWidgets,
        reason: '표가 12개월 카드 밖에 있습니다. 둘은 한 이야기입니다',
      );
    });

    testWidgets('두 줄이 조문 그대로 있다', (tester) async {
      await openResult(tester, notYet);
      await openAllStatutes(tester);
      expectScreenText(tester, '이직일 현재 연령 50세 미만');
      expectScreenText(tester, '1년 이상 3년 미만 150일');
      expectScreenText(tester, '이직일 현재 연령 50세 이상');
      expectScreenText(tester, '10년 이상 270일');
    });

    testWidgets('★ 비고를 빼지 않는다 — 장애인은 50세 이상 줄로 본다', (tester) async {
      await openResult(tester, notYet);
      await openAllStatutes(tester);
      // 표만 내고 비고를 빼는 것이 이 표에서 제일 쉬운 실수다.
      expectScreenText(
        tester,
        '장애인은 50세 이상인 것으로 보아 위 표를 적용한다',
      );
    });

    testWidgets('대기기간 7일이 같은 카드에 붙어 그림이 닫힌다', (tester) async {
      await openResult(tester, notYet);
      final card = find.byType(ReceiveWindowCard);
      expect(
        find.descendant(of: card, matching: find.textContaining('제49조 제1항')),
        findsWidgets,
      );
    });

    testWidgets('★ 우리가 「당신은 180일」이라고 쓰지 않는다', (tester) async {
      await openResult(tester, notYet);
      for (final word in const [
        '180일을 받으',
        '210일을 받으',
        '귀하의 소정급여일수',
        '당신은 120일',
      ]) {
        expectNoScreenText(tester, word);
      }
      await openQuestion(tester, '표에서 제 줄이 어느 것인가요?');
      expectScreenText(tester, '저희는 세지 않고 표만 그대로 내요');
    });
  });

  group('금지 문구', () {
    testWidgets('★ 된다고도 안 된다고도 쓰지 않는다', (tester) async {
      await openResult(tester, notYet);

      for (final word in const [
        '자발적 퇴사는 안 됩니다',
        '받으실 수 있어요',
        '받을 수 있습니다',
        '실업급여 대상이 아니에요',
        '대상이 아닙니다',
        '신청하세요',
        '빨리',
        '서두르세요',
        '지금 당장',
      ]) {
        expectNoScreenText(tester, word);
      }
    });
  });
}
