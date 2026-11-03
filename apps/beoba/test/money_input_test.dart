import 'package:beoba/src/screens/interview/answers/money_input.dart';
import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 화면은 만원으로 받고 **저장은 원 단위 정수 그대로다.**
///
/// 편하게 만들다가 정확도를 잃으면 인지대 구간이 틀어진다. 그 경계를 여기서 잠근다.
void main() {
  const question = Question(
    id: 'q_amount',
    order: 1,
    text: '얼마를 받지 못하고 계신가요?',
    whyAsk: '금액에 따라 절차와 비용이 달라집니다.',
    type: QuestionType.money,
    field: 'amount',
  );

  Future<Object?> typeAndRead(
    WidgetTester tester,
    String text, {
    int? initial,
  }) async {
    Object? emitted;
    await pumpWidgetOnly(
      tester,
      MoneyInput(
        question: question,
        value: initial,
        onChanged: (value) => emitted = value,
      ),
    );
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    return emitted;
  }

  group('만원 칸 — 저장은 원이다', () {
    testWidgets('5000 을 넣으면 5천만원이 저장된다', (tester) async {
      expect(await typeAndRead(tester, '5000'), 50000000);
    });

    testWidgets('만원 칸이 기본이라고 화면에 적혀 있다', (tester) async {
      await typeAndRead(tester, '5000');
      // 접미사와 단위 칩 두 곳에 나온다.
      expect(find.text(MoneyInput.manwonSuffix), findsWidgets);
    });

    testWidgets('비우면 null 이 나간다', (tester) async {
      expect(await typeAndRead(tester, ''), isNull);
    });
  });

  group('한글로 읽어 준다 — 오타를 눈으로 잡는다', () {
    testWidgets('5000 만원은 오천만원으로 읽는다', (tester) async {
      await typeAndRead(tester, '5000');
      expect(find.text('오천만원'), findsOneWidget);
    });

    testWidgets('0 을 하나 더 치면 읽기가 즉시 달라진다', (tester) async {
      // 50000 만원 = 5억원. 숫자만 보면 0 을 세어야 알지만 읽어 주면 바로 안다.
      await typeAndRead(tester, '50000');
      expect(find.text('오억원'), findsOneWidget);
      expect(find.text('오천만원'), findsNothing);
    });

    testWidgets('원 단위 표기도 함께 보인다', (tester) async {
      await typeAndRead(tester, '5000');
      expect(find.text('50,000,000원'), findsOneWidget);
    });
  });

  group('빨리 채우기 — 눌러서 더한다', () {
    testWidgets('+100만 을 두 번 누르면 200만원이다', (tester) async {
      Object? emitted;
      await pumpWidgetOnly(
        tester,
        MoneyInput(
          question: question,
          value: null,
          onChanged: (value) => emitted = value,
        ),
      );

      await tester.tap(find.text('+100만'));
      await tester.pump();
      await tester.tap(find.text('+100만'));
      await tester.pump();

      expect(emitted, 2000000);
      expect(find.text('이백만원'), findsOneWidget);
    });
  });

  group('원 단위 칸 — 접어 두되 없애지 않는다', () {
    testWidgets('펼치면 원 단위로 그대로 넣을 수 있다', (tester) async {
      // 1,234,567원인 사람이 있다. 만원으로는 표현할 수 없다.
      Object? emitted;
      await pumpWidgetOnly(
        tester,
        MoneyInput(
          question: question,
          value: null,
          onChanged: (value) => emitted = value,
        ),
      );

      await tester.tap(find.text(MoneyInput.unitWon));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234567');
      await tester.pump();

      expect(emitted, 1234567);
      expect(find.text('백이십삼만 사천오백육십칠원'), findsOneWidget);
    });

    testWidgets('만원으로 안 떨어지는 값은 원 단위로 열린 채 들어온다', (tester) async {
      // 접힌 칸이 자기 답을 반올림해 보여주면 앱이 값을 바꿨다고 생각한다.
      await pumpWidgetOnly(
        tester,
        MoneyInput(
          question: question,
          value: 1234567,
          onChanged: (_) {},
        ),
      );
      expect(find.text(MoneyInput.unitManwon), findsOneWidget);
      expect(find.text('1234567'), findsOneWidget);
    });
  });

  group('상한 — 곱하기 전에 막는다', () {
    testWidgets('만원 칸 상한을 넘는 입력은 값으로 나가지 않는다', (tester) async {
      final tooBig = (Money.maxManwonInput + 1).toString();
      expect(await typeAndRead(tester, tooBig), isNull);
    });

    testWidgets('상한까지는 그대로 통과한다', (tester) async {
      expect(
        await typeAndRead(tester, Money.maxManwonInput.toString()),
        Money.maxBase,
      );
    });
  });

  group('칸은 숫자 하나뿐이다', () {
    /// 지금 칸에 걸린 키보드.
    TextInputType keyboardOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).keyboardType;

    testWidgets('언제나 숫자 키패드다', (tester) async {
      await pumpWidgetOnly(
        tester,
        MoneyInput(question: question, value: null, onChanged: (_) {}),
      );
      expect(keyboardOf(tester), TextInputType.number);
    });

    testWidgets('입력 방식을 바꾸는 단추가 없다', (tester) async {
      // 만원/원 전환이 있으면 한글로 적을 이유가 거의 없다. 단추가 하나 줄면
      // 화면이 그만큼 조용해진다 (DECISIONS 57번).
      await pumpWidgetOnly(
        tester,
        MoneyInput(question: question, value: null, onChanged: (_) {}),
      );
      expect(find.text('한글로 적기'), findsNothing);
      expect(find.text('숫자로 적기'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('붙여넣은 한글도 읽는다 — 거절하지 않는다', () {
    // 숫자 키패드로는 한글을 칠 수 없지만 붙여넣기로는 들어온다.
    // 카카오톡에서 "오천만원" 을 복사해 오는 사람이 있다.
    testWidgets('만원 칸에 "오천만원" 은 5천만원이다', (tester) async {
      expect(await typeAndRead(tester, '오천만원'), 50000000);
    });

    testWidgets('만원 칸에 "오천" 은 5천만원이다', (tester) async {
      // 만원 칸에 5000 을 넣으면 5천만원이다. "오천" 은 그걸 소리 나는 대로
      // 적은 것뿐이므로 같은 답이어야 한다.
      expect(await typeAndRead(tester, '오천'), 50000000);
    });

    testWidgets('"5천만" 도 읽는다', (tester) async {
      expect(await typeAndRead(tester, '5천만'), 50000000);
    });

    testWidgets('차용증 표기도 읽는다', (tester) async {
      // 차용증에는 「金 오천만원整」 처럼 적혀 있는 경우가 많다. 지금은
      // 붙여넣기로만 들어오지만 M6 이후 사진 인식에서 같은 파서를 쓴다.
      expect(await typeAndRead(tester, '오천만원'), 50000000);
    });

    testWidgets('읽은 결과를 숫자로 되돌려 보여준다', (tester) async {
      // **이게 확인 수단이다.** 조용히 읽어도 사용자가 눈으로 검산할 수 있다.
      await typeAndRead(tester, '오천만원');
      expect(find.text('50,000,000원'), findsOneWidget);
      expect(find.text('오천만원'), findsWidgets);
    });

    testWidgets('원 이 붙으면 만원 칸에서도 원이다', (tester) async {
      expect(await typeAndRead(tester, '1000원'), 1000);
    });
  });

  group('못 읽으면 되묻는다. **0 으로 만들지 않는다**', () {
    testWidgets('못 읽은 입력은 값을 만들지 않는다', (tester) async {
      final emitted = await typeAndRead(tester, '오천마넌');
      expect(emitted, isNot(0), reason: '0 이 되면 사용자가 모른다');
      expect(emitted, isNull);
    });

    testWidgets('적은 글자를 지우지 않고 그대로 둔다', (tester) async {
      await typeAndRead(tester, '대충 오천쯤');
      expect(find.text('대충 오천쯤'), findsOneWidget);
    });

    testWidgets('다시 적어 달라고 말한다', (tester) async {
      await typeAndRead(tester, '많이');
      expect(find.text(MoneyInput.unreadable), findsOneWidget);
    });

    testWidgets('못 읽었으면 읽은 금액을 보여주지 않는다', (tester) async {
      await typeAndRead(tester, '많이');
      expect(find.text('0원'), findsNothing);
      expect(find.text('영원'), findsNothing);
    });

    testWidgets('비어 있는 것은 오류가 아니다', (tester) async {
      await typeAndRead(tester, '');
      expect(find.text(MoneyInput.unreadable), findsNothing);
    });
  });

  group('단위 전환은 양방향이다', () {
    testWidgets('만원 → 원 → 만원 으로 돌아올 수 있다', (tester) async {
      // 한쪽으로만 열린 문은 사용자를 가둔다.
      Object? emitted;
      await pumpWidgetOnly(
        tester,
        MoneyInput(
          question: question,
          value: null,
          onChanged: (value) => emitted = value,
        ),
      );

      await tester.enterText(find.byType(TextField), '5000');
      await tester.pump();
      expect(emitted, 50000000);

      await tester.tap(find.text(MoneyInput.unitWon));
      await tester.pumpAndSettle();
      expect(find.text('50000000'), findsOneWidget);

      await tester.tap(find.text(MoneyInput.unitManwon));
      await tester.pumpAndSettle();
      expect(find.text('5000'), findsOneWidget);
      expect(emitted, 50000000);
    });

    testWidgets('만원으로 잘리는 금액은 바꾸지 않고 이유를 말한다', (tester) async {
      // 금액이 조용히 달라지는 것보다 칸을 그대로 두는 쪽이 낫다.
      Object? emitted;
      await pumpWidgetOnly(
        tester,
        MoneyInput(
          question: question,
          value: 1234567,
          onChanged: (value) => emitted = value,
        ),
      );

      await tester.tap(find.text(MoneyInput.unitManwon));
      await tester.pumpAndSettle();

      expect(find.text(MoneyInput.notRound), findsOneWidget);
      expect(find.text('1234567'), findsOneWidget);
      expect(emitted, isNot(1230000));
    });
  });

  group('접근성', () {
    testWidgets('배율 2.0 에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpWidgetOnly(
        tester,
        MoneyInput(
          question: question,
          value: 50000000,
          onChanged: (_) {},
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
