import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/widgets/legal_basis_card.dart';
import 'package:engines/engines.dart' show KstDate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 나눠서 산 물건.
///
/// **이 화면에는 손잡이가 둘이다.** 무르는 것(제8조, 7일)과, 아직 안 낸 값을
/// 안 내겠다고 말하는 것(제16조)이다. 둘째에는 **며칠 안에 하라는 기간이 안
/// 적혀 있다** — 7일이 지난 사람에게 남는 유일한 손잡이라 여기가 중심이다.
///
/// 우리는 **여섯 호 중 어디에 해당하는지 정하지 않는다.** 「하자담보책임을
/// 이행하지 아니한 경우」인지는 사실 판단이다. 원문을 펴고 본인이 찾게 한다.
const String kInstallment = 'installment_purchase';

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

  Future<void> openResult(
    WidgetTester tester,
    Map<String, Object?> answers,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    seedAnswers(container, kInstallment, answers: answers);
    container.read(routerProvider).go(Routes.result(kInstallment));
    await tester.pumpAndSettle();
  }

  const lender = {
    'q_installment_shape': 'three_plus',
    'q_installment_payee': 'lender',
    'q_installment_contract_date': KstDate(2026, 8, 10),
    'q_installment_left': 'yes',
  };

  const seller = {
    'q_installment_shape': 'three_plus',
    'q_installment_payee': 'seller',
    'q_installment_contract_date': KstDate(2026, 8, 10),
    'q_installment_left': 'yes',
  };

  /// ★★ **여섯 호가 화면까지 닿아야 한다.**
  ///
  /// 우리가 「당신은 4호」라고 붙이지 않기로 했으니, 대신 **여섯을 다 펴야
  /// 한다.** 하나라도 빠지면 그 사람은 자기 자리를 못 찾는다. 실제로 걸리는
  /// 것은 3호(물건이 안 왔다)·4호(고장인데 안 고쳐 준다)·2호(계약이 깨졌다)다.
  group('★ 지급을 거절할 수 있는 여섯 가지가 조문 그대로 있다', () {
    const grounds = <String, String>{
      '1호 — 계약이 불성립·무효': '할부계약이 불성립ㆍ무효인 경우',
      '2호 — 취소·해제·해지': '할부계약이 취소ㆍ해제 또는 해지된 경우',
      '3호 — 물건이 안 왔다': '공급 시기까지 소비자에게 공급되지 아니한 경우',
      '4호 — 고장인데 안 고쳐 준다': '할부거래업자가 하자담보책임을 이행하지 아니한 경우',
      '5호 — 목적을 달성할 수 없다': '할부계약의 목적을 달성할 수 없는 경우',
      '6호 — 다른 법률로 철회했다': '다른 법률에 따라 정당하게 청약을 철회한 경우',
    };

    for (final entry in grounds.entries) {
      testWidgets('${entry.key} 가 화면에 있다', (tester) async {
        await openResult(tester, lender);
        await openAllStatutes(tester);
        expectScreenText(tester, entry.value);
      });
    }

    testWidgets('★ 여섯 중 어디인지 우리가 정하지 않는다', (tester) async {
      await openResult(tester, lender);
      expectScreenText(tester, '어디에 해당하는지는 저희가 정하지 않아요');
      for (final word in const ['4호에 해당', '해당됩니다', '거절할 수 있습니다']) {
        expectNoScreenText(tester, word);
      }
    });
  });

  group('★ 이 손잡이에는 기간이 안 적혀 있다', () {
    testWidgets('7일이 지나도 남는 자리라고 화면이 말한다', (tester) async {
      await openResult(tester, lender);
      expectScreenText(tester, '이 조에는 며칠 안에 하라는 기간이 안 적혀 있어요');
    });

    testWidgets('무르는 7일과 다른 자리라고 붙여 둔다', (tester) async {
      await openResult(tester, lender);
      expectScreenText(tester, '무르는 7일과는 다른 자리예요');
    });
  });

  /// ★ **이 줄이 없으면 앞의 손잡이가 쓸모없다.**
  ///
  /// 「말은 했는데 그다음은?」에서 멈춘다. 답이 없으면 받아들인 것으로 본다는
  /// 줄이 있어야 기다릴 수 있다.
  group('★ 답이 없으면 받아들인 것으로 본다', () {
    testWidgets('5영업일 · 7영업일이 화면에 있다', (tester) async {
      await openResult(tester, lender);
      expectScreenText(tester, '판 곳은 5영업일, 카드사·캐피탈은 7영업일이에요');
      await openAllStatutes(tester);
      expectScreenText(tester, '1. 할부거래업자는 5영업일 2. 신용제공자는 7영업일');
    });

    testWidgets('제16조 제6항이 조문 그대로 있다', (tester) async {
      await openResult(tester, lender);
      await openAllStatutes(tester);
      expectScreenText(tester, '소비자의 할부금 지급 거절의사를 수용한 것으로 본다');
    });
  });

  /// ★ **포기하게 만드는 제일 큰 이유를 조문으로 지운다.**
  ///
  /// 「안 내면 신용에 문제 생긴다」가 그 이유인데 조문이 정면으로 막고 있다.
  /// 금지어(신용 점수)는 그대로 지키고 조문 문언만 낸다.
  group('★ 다투는 동안 연체자로 처리하면 안 된다', () {
    testWidgets('제16조 제7항과 제10조 제8항이 함께 있다', (tester) async {
      await openResult(tester, lender);
      expectScreenText(tester, '약정한 날 안에 갚지 않은 사람으로 처리하는 등');
      await openAllStatutes(tester);
      expectScreenText(tester, '분쟁이 해결될 때까지 할부금 지급 거절을 이유로');
      expectScreenText(tester, '분쟁이 해결될 때까지 할부금 지급거절을 이유로');
    });

    testWidgets('우리 문장으로 신용 이야기를 하지 않는다', (tester) async {
      await openResult(tester, lender);
      for (final word in const ['신용점수', '신용 점수', '신용등급', '연체자가 되지 않습니다']) {
        expectNoScreenText(tester, word);
      }
    });
  });

  group('★ 금액 문턱은 카드사 쪽에만 붙는다', () {
    testWidgets('카드사·캐피탈에 내면 10만원·20만원이 나온다', (tester) async {
      await openResult(tester, lender);
      await openQuestion(tester, '카드사에도 안 내겠다고 할 수 있나요?');
      expectScreenText(tester, '시행령은 10만원, 신용카드로 사신 경우에는 20만원으로 정해 두었어요');
      expectScreenText(tester, '거절할 당시에 아직 안 내신 나머지예요');
    });

    testWidgets('판 곳에 직접 내면 금액 조건이 없다고 말한다', (tester) async {
      await openResult(tester, seller);
      await openQuestion(tester, '금액이 작아도 되나요?');
      expectScreenText(tester, '금액에 관한 조건이 붙어 있지 않아요');
      expectNoScreenText(tester, '시행령은 10만원, 신용카드로 사신 경우에는 20만원으로 정해 두었어요');
    });
  });

  group('★ 이 법이 말하는 나눠 내기는 좁다', () {
    testWidgets('뜻풀이가 조건 없이 먼저 선다', (tester) async {
      await openResult(tester, const {'q_installment_shape': 'unknown'});
      expectScreenText(tester, '2개월 이상의 기간에 걸쳐 3번 이상 나누어 내고');
      await openAllStatutes(tester);
      expectScreenText(tester, '2개월 이상의 기간에 걸쳐 3회 이상 나누어 지급하고');
    });

    testWidgets('2개월 두 번은 여기서 멈추되 「무를 수 없어요」라고 안 한다', (tester) async {
      await openResult(tester, const {'q_installment_shape': 'fewer'});
      expectScreenText(tester, '이 화면이 다루는 거래가 아니라는 뜻이에요');
      expectNoScreenText(tester, '무를 수 없어요');
      expectNoScreenText(tester, '지급을 거절할 수 있다고 법에 적혀 있어요');
    });
  });

  /// ★ **겉이 닮은 법 셋이 값은 다르다**(DECISIONS 186번).
  group('★ 다른 두 법이 한 글자도 안 섞인다', () {
    testWidgets('전자상거래법도 방문판매법도 근거로 안 선다', (tester) async {
      await openResult(tester, lender);
      await openAllStatutes(tester);
      expectNoScreenText(tester, '통신판매업자');
      expectNoScreenText(tester, '방문판매자등');
      expectNoScreenText(tester, '14일');
    });
  });

  group('금지 문구', () {
    testWidgets('★ 안 내도 된다고 단정하지 않는다', (tester) async {
      await openResult(tester, lender);

      for (final word in const [
        '안 내셔도 됩니다',
        '안 내도 돼요',
        '전액 돌려',
        '무를 수 있어요',
        '판매자가 잘못',
        '지금 당장',
        '서두르세요',
      ]) {
        expectNoScreenText(tester, word);
      }
    });
  });
}
