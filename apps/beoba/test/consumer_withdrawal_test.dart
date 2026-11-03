import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/screens/result/sections/pinned_caution_card.dart';
import 'package:beoba/src/widgets/legal_basis_card.dart';
import 'package:engines/engines.dart' show KstDate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 산 물건 무르기.
///
/// **7일이다.** 이 앱에서 제일 짧은 기한이고 제일 흔하다. 그리고 대부분은
/// 「반품 안 된대요」라는 판매자 말을 그대로 믿고 포기한다 — 그 말을 막는
/// 것이 이 분야가 하는 일이다.
///
/// 우리는 **무를 수 있는지 판정하지 않는다.** 제17조 제2항 다섯 호는 사실
/// 판단이 필요하고, 「가치가 현저히 감소」가 얼마인지 우리는 모른다.
const String kWithdrawal = 'consumer_withdrawal';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 조문 원문을 전부 편다.
  ///
  /// **안 열면 안 그려지고, 안 그려지면 검사가 못 본다**(DECISIONS 175번).
  /// 각 호는 「조문 원문 보기」 뒤에 통째로 들어 있다.
  Future<void> openAllStatutes(WidgetTester tester) async {
    // 여는 손잡이가 **글자가 아니라 읽어 주는 이름**이라 `find.text` 로는
    // 안 잡힌다. 카드 자체를 한 번씩 누른다 — 전부 접힌 채로 시작한다.
    final cards = find.byType(LegalBasisCard);
    for (var i = 0; i < cards.evaluate().length; i++) {
      await tester.ensureVisible(cards.at(i));
      await tester.pumpAndSettle();
      await tester.tap(cards.at(i), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }

  /// 물음 카드 하나를 연다. 접힌 것은 안 그려진다.
  Future<void> openQuestion(WidgetTester tester, String question) async {
    final head = find.text(question);
    expect(head, findsOneWidget, reason: '「$question」 물음이 없습니다');
    await tester.ensureVisible(head);
    await tester.pumpAndSettle();
    await tester.tap(head, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> openResult(
    WidgetTester tester,
    Map<String, Object?> answers,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    seedAnswers(container, kWithdrawal, answers: answers);
    container.read(routerProvider).go(Routes.result(kWithdrawal));
    await tester.pumpAndSettle();
  }

  const online = {
    'q_purchase_channel': 'online',
    'q_reason': 'changed_mind',
    'q_delivery_date': KstDate(2026, 8, 10),
  };

  const onlineCard = {
    'q_purchase_channel': 'online',
    'q_reason': 'changed_mind',
    'q_delivery_date': KstDate(2026, 8, 10),
    'q_payment': 'card',
  };

  /// 집으로 찾아왔거나 전화로 권유받아 산 갈래. **기산점이 계약서를 받은 날이다.**
  const doorstep = {
    'q_purchase_channel': 'doorstep',
    'q_contract_date': KstDate(2026, 8, 10),
    'q_reason': 'changed_mind',
  };

  const doorstepCard = {
    'q_purchase_channel': 'doorstep',
    'q_contract_date': KstDate(2026, 8, 10),
    'q_reason': 'changed_mind',
    'q_payment': 'card',
  };

  group('★ 7일을 세기 시작하는 날이 셋이다', () {
    // 제17조 제1항이 각 호로 셋을 적어 두었다. **하나를 고르면 그건 우리가
    // 고른 기산점이 된다**(DECISIONS 170번). 셋을 나란히 펴고 본인이 찾게 한다.
    const starts = <String, String>{
      '1호': '그 서면을 받은 때보다 재화등의 공급이 늦게 이루어진 경우',
      '2호': '통신판매업자의 주소를 안 날 또는 알 수 있었던 날부터 7일',
      '3호': '그 방해 행위가 종료한 날부터 7일',
    };

    for (final entry in starts.entries) {
      testWidgets('${entry.key} 가 조문 그대로 화면에 있다', (tester) async {
        await openResult(tester, online);
        await openAllStatutes(tester);
        expectScreenText(tester, entry.value);
      });
    }

    testWidgets('★ 더 긴 기간을 약정했으면 그 기간이라는 괄호를 빼지 않는다', (tester) async {
      await openResult(tester, online);
      // 판매자가 「30일 반품」을 걸어 두었으면 그게 이긴다. 이 줄을 빼면
      // 우리가 법정 기간으로 줄이는 셈이 된다(DECISIONS 182번).
      expectScreenText(tester, '더 긴 기간을 약속해');
      await openAllStatutes(tester);
      expectScreenText(tester, '기간보다 긴 기간으로 약정한 경우에는 그 기간');
    });

    testWidgets('어느 날로 셌는지 화면이 스스로 말한다', (tester) async {
      await openResult(tester, online);
      expectScreenText(tester, '화면의 날짜는 물건을 받으신 날로 센 것이라');
    });
  });

  group('★ 7일이 지나도 길이 하나 더 있다', () {
    testWidgets('제17조 제3항 카드가 7일 카드 **바로 아래**에 선다', (tester) async {
      await openResult(tester, online);

      final cards = find.byType(PinnedCautionCard);
      final tops = <double, String>{};
      for (var i = 0; i < cards.evaluate().length; i++) {
        final rect = tester.getRect(cards.at(i));
        final texts = <String>[
          for (final text in tester.widgetList<Text>(
            find.descendant(of: cards.at(i), matching: find.byType(Text)),
          ))
            text.data ?? text.textSpan?.toPlainText() ?? '',
        ];
        tops[rect.top] = texts.join(' ');
      }

      final order = tops.keys.toList()..sort();
      final joined = [for (final top in order) tops[top]!];

      final first = joined.indexWhere((t) => t.contains('7일을 세기 시작하는 날이 세 가지'));
      final second = joined.indexWhere((t) => t.contains('물건이 광고나 설명과 다르거나'));
      expect(first, isNonNegative, reason: '기산점 카드가 없습니다');
      expect(
        second,
        first + 1,
        reason: '「7일 지났으니 끝」으로 닫고 나가는 사람을 잡는 카드라 '
            '바로 아래여야 합니다',
      );
    });

    testWidgets('두 기간이 함께 걸리고, 안 날은 우리가 안 센다', (tester) async {
      await openResult(tester, online);
      expectScreenText(tester, '공급받은 날부터 3개월 이내');
      expectScreenText(tester, '안 날은 본인만 아시는 날이라 저희가 세어 드리지 않아요');
    });

    testWidgets('★ 반품 비용이 갈래마다 다르다 — 짝으로 낸다', (tester) async {
      await openResult(tester, online);
      // ① 갈래(마음이 바뀜)는 소비자가, ③ 갈래(광고와 다름)는 판매자가.
      expectScreenText(tester, '돌려보내는 비용은 판매자가 부담한다고');

      await openQuestion(tester, '돌려보내는 비용은 누가 내나요?');
      expectScreenText(tester, '비용은 소비자가 부담한다고 법에 적혀 있어요');
    });
  });

  group('★ 예외 목록보다 단서가 먼저다', () {
    testWidgets('표시를 안 해 두면 2호부터 5호까지가 무력화된다', (tester) async {
      await openResult(tester, online);

      expectScreenText(tester, '명확하게 표시하지 않았거나');
      await openAllStatutes(tester);
      expectScreenText(tester, '제2호부터 제5호까지의 규정에 해당하는 경우에도 청약철회등을 할 수 있다');
      // 1호 단서도 뺄 수 없다. 열어 본 것과 망가뜨린 것은 다르다.
      expectScreenText(tester, '내용을 확인하기 위하여 포장 등을 훼손한 경우는 제외한다');
    });

    testWidgets('다투면 증명은 판매자가 한다', (tester) async {
      await openResult(tester, online);
      await openQuestion(tester, '증거가 없는데 어떻게 하나요?');
      await openAllStatutes(tester);
      expectScreenText(tester, '통신판매업자가 이를 증명하여야 한다');
    });
  });

  group('통신판매가 아닌 갈래', () {
    testWidgets('매장에서 산 것은 여기서 멈추되 「무를 수 없어요」라고 안 한다', (tester) async {
      await openResult(tester, const {'q_purchase_channel': 'store'});

      expectScreenText(tester, '이 화면이 보는 법은 둘이에요');
      expectNoScreenText(tester, '무를 수 없어요');
      expectNoScreenText(tester, '7일을 세기 시작하는 날이 세 가지');
    });
  });

  group('금지 문구', () {
    testWidgets('★ 무를 수 있다고 단정하지 않는다', (tester) async {
      await openResult(tester, online);

      for (final word in const [
        '무를 수 있어요',
        '환불받으실 수 있어요',
        '반품 가능합니다',
        '판매자가 잘못',
        '소비자원에 신고하세요',
        '지금 당장',
        '서두르세요',
      ]) {
        expectNoScreenText(tester, word);
      }
    });
  });

  group('★ 집으로 찾아왔거나 전화로 권유받은 갈래 — 14일이다', () {
    testWidgets('기산점 넷을 나란히 편다. 셋이 아니다', (tester) async {
      await openResult(tester, doorstep);
      expectScreenText(tester, '14일을 세기 시작하는 날이 네 가지로 적혀 있어요');
      await openAllStatutes(tester);
      // 제3호가 이 갈래에만 있다. 계약서에 무르는 이야기가 안 적혀 있으면
      // 그것을 안 날부터 다시 14일이다. **이 갈래에서 그런 계약서가 흔하다.**
      expectScreenText(
        tester,
        '청약철회등에 관한 사항이 적혀 있지 아니한 경우에는 청약철회등을 할 수 있음을 안 날',
      );
      expectScreenText(tester, '방문판매업자등이 청약철회등을 방해한 경우');
    });

    testWidgets('어느 날로 셌는지 화면이 스스로 말한다', (tester) async {
      await openResult(tester, doorstep);
      expectScreenText(tester, '화면의 날짜는 계약서를 받으신 날로 센 것이라');
    });

    testWidgets('14일이 지나도 3개월·30일 갈래가 그대로 선다', (tester) async {
      await openResult(tester, doorstep);
      expectScreenText(tester, '공급받은 날부터 3개월 이내');
      await openAllStatutes(tester);
      // 조문 출처는 각자 것이다. 전자상거래법 제17조 제3항이 아니다.
      expectScreenText(tester, '제1항 또는 제2항에도 불구하고');
    });

    testWidgets('★ 예외 목록은 넷까지다 — 다섯으로 옮겨 적지 않는다', (tester) async {
      await openResult(tester, doorstep);
      await openAllStatutes(tester);
      expectScreenText(tester, '제2호부터 제4호까지의 규정에 해당하더라도 청약철회등을 할 수 있다');
      expectNoScreenText(tester, '제2호부터 제5호까지의 규정에 해당하는 경우에도');
    });
  });

  /// ★ **두 법이 섞이면 화면은 멀쩡하고 값만 틀린다.**
  ///
  /// 반품 비용이 정반대다 — 전자상거래법 제18조 제9항은 소비자가 내고,
  /// 방문판매법 제9조 제9항은 판매자가 낸다. 같은 「무르기」인데 어디서
  /// 샀느냐로 뒤집힌다(DECISIONS 186번). 조용히 틀리기 딱 좋은 자리라
  /// 조문 원문의 낱말로 잠근다 — 우리가 쓴 문장은 닮게 쓸 수 있지만
  /// 「방문판매자등이 부담하며」와 「소비자가 부담하며」는 안 닮는다.
  group('★ 두 법이 섞이지 않는다 — 반품 비용', () {
    testWidgets('찾아온 판매 갈래에는 「방문판매자등이 부담하며」만 있다', (tester) async {
      await openResult(tester, doorstep);
      expectScreenText(tester, '돌려보내는 데 필요한 비용은 판매자가 부담한다고 법에 적혀 있어요');
      await openAllStatutes(tester);
      expectScreenText(tester, '반환에 필요한 비용은 방문판매자등이 부담하며');
      expectNoScreenText(tester, '반환에 필요한 비용은 소비자가 부담하며');
    });

    testWidgets('인터넷 갈래에는 「소비자가 부담하며」만 있다', (tester) async {
      await openResult(tester, onlineCard);
      await openQuestion(tester, '돌려보내는 비용은 누가 내나요?');
      await openAllStatutes(tester);
      expectScreenText(tester, '반환에 필요한 비용은 소비자가 부담하며');
      expectNoScreenText(tester, '반환에 필요한 비용은 방문판매자등이 부담하며');
    });

    testWidgets('★ 카드 결제 카드도 갈래를 탄다 — 결제 수단만 보고 뜨지 않는다', (tester) async {
      // 전에는 paymentMethod 만 보고 떠서, 찾아온 판매 갈래가 열리면
      // 전자상거래법 제18조 제3항이 그 사람에게 그대로 갔다. 검사 (u)가 잡았다.
      await openResult(tester, doorstepCard);
      await openQuestion(tester, '판매자가 연락을 안 받아요');
      await openAllStatutes(tester);
      expectScreenText(tester, '방문판매자등은 …');
      expectNoScreenText(tester, '통신판매업자는 소비자가 「여신전문금융업법」');
    });

    testWidgets('찾아온 판매 갈래에 7일짜리 카드가 하나도 없다', (tester) async {
      await openResult(tester, doorstep);
      expectNoScreenText(tester, '7일을 세기 시작하는 날이 세 가지');
      expectNoScreenText(tester, '통신판매업자와 재화등의 구매에 관한 계약을 체결한 소비자');
    });
  });

  group('매장 갈래는 막다른 골목이 아니다', () {
    testWidgets('★ 길에서 붙잡혀 매장에 들어간 경우가 있다고 조문을 편다', (tester) async {
      await openResult(tester, const {'q_purchase_channel': 'store'});

      expectScreenText(tester, '길에서 권유받아 매장으로 따라 들어가 계약하신 경우라면');
      await openAllStatutes(tester);
      expectScreenText(tester, '유인하여 사업장에서 계약의 청약을 받거나 계약을 체결하는 경우를 포함한다');
      // 우리가 「방문판매입니다」라고 정하지 않는다. 앞 질문으로 되돌려 보낸다.
      expectNoScreenText(tester, '방문판매입니다');
    });
  });

}
