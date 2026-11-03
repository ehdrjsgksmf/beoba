import 'package:beoba/src/screens/interview/answers/date_input.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 달력을 열지 않고도 답할 수 있어야 한다.
///
/// 그리고 **범위는 데이터가 정한다.** 요구한 날은 지난 날이고 변제기는 아직 안
/// 왔을 수 있다. 이걸 코드에 박으면 분야 지식이 코드로 새어 나간다.
void main() {
  Question dateQuestion(DateRange range) => Question(
        id: 'q_date',
        order: 1,
        text: '언제였나요?',
        whyAsk: '날짜가 기준점이 됩니다.',
        type: QuestionType.date,
        dateRange: range,
        datePrecision: DatePrecisionPolicy.approximate,
        field: 'someDate',
      );

  Future<Object?> tapChip(
    WidgetTester tester,
    DateRange range,
    String chip, {
    ApproxDate? initial,
  }) async {
    Object? emitted;
    await pumpWidgetOnly(
      tester,
      DateInput(
        question: dateQuestion(range),
        value: initial,
        onChanged: (value) => emitted = value,
      ),
    );
    await tester.tap(find.text(chip));
    await tester.pump();
    return emitted;
  }

  // 기준일은 2026년 8월 15일 (testClock).
  group('상대 표현 — KstClock 에서만 온다', () {
    testWidgets('오늘', (tester) async {
      expect(await tapChip(tester, DateRange.past, '오늘'), const ApproxDate(2026, 8, 15));
    });

    testWidgets('어제', (tester) async {
      expect(await tapChip(tester, DateRange.past, '어제'), const ApproxDate(2026, 8, 14));
    });

    testWidgets('그저께', (tester) async {
      expect(await tapChip(tester, DateRange.past, '그저께'), const ApproxDate(2026, 8, 13));
    });

    testWidgets('1주일 전', (tester) async {
      expect(await tapChip(tester, DateRange.past, '1주일 전'), const ApproxDate(2026, 8, 8));
    });

    testWidgets('달을 넘어가도 맞는다', (tester) async {
      // 8월 1일 기준의 1주일 전은 7월이다. 달력 산술을 KstDate 에 맡긴다.
      expect(const KstDate(2026, 8, 1).addDays(-7), const KstDate(2026, 7, 25));
    });
  });

  group('상대 표현은 7일까지만 둔다', () {
    testWidgets('한 달 전 같은 칩은 없다', (tester) async {
      // 「3주 전」은 날짜보다 부정확하고, 그 착각이 그대로 기한 계산으로 번진다.
      await pumpWidgetOnly(
        tester,
        DateInput(
          question: dateQuestion(DateRange.past),
          value: null,
          onChanged: (_) {},
        ),
      );
      for (final (_, days) in DateInput.pastChips) {
        expect(days, lessThanOrEqualTo(7));
      }
      for (final (_, days) in DateInput.futureChips) {
        expect(days, lessThanOrEqualTo(7));
      }
      expect(find.text('한 달 전'), findsNothing);
    });

    testWidgets('7일을 넘는 날짜는 달력이 유일한 길이다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DateInput(
          question: dateQuestion(DateRange.past),
          value: null,
          onChanged: (_) {},
        ),
      );
      expect(find.text(DateInput.pick), findsOneWidget);
    });
  });

  group('범위 — 데이터가 정한다', () {
    testWidgets('과거만 받는 질문에는 앞날 칩이 없다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DateInput(
          question: dateQuestion(DateRange.past),
          value: null,
          onChanged: (_) {},
        ),
      );
      expect(find.text('오늘'), findsOneWidget);
      expect(find.text('내일'), findsNothing);
      expect(find.text('1주일 뒤'), findsNothing);
    });

    testWidgets('제한 없는 질문에는 앞날 칩도 나온다', (tester) async {
      // 변제기는 아직 안 왔을 수 있다.
      expect(
        await tapChip(tester, DateRange.any, '1주일 뒤'),
        const ApproxDate(2026, 8, 22),
      );
    });

    testWidgets('앞날만 받는 질문에는 지난 칩이 없다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DateInput(
          question: dateQuestion(DateRange.future),
          value: null,
          onChanged: (_) {},
        ),
      );
      expect(find.text('어제'), findsNothing);
      expect(find.text('내일'), findsOneWidget);
    });
  });

  group('고른 날을 다시 읽어 준다', () {
    testWidgets('그저께를 고르면 날짜와 이름이 함께 보인다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DateInput(
          question: dateQuestion(DateRange.past),
          value: const ApproxDate(2026, 8, 13),
          onChanged: (_) {},
        ),
      );
      expect(find.text('2026년 8월 13일 (그저께)'), findsOneWidget);
    });

    testWidgets('상대 표현이 없는 날짜는 날짜만 보인다', (tester) async {
      await pumpWidgetOnly(
        tester,
        DateInput(
          question: dateQuestion(DateRange.past),
          value: const ApproxDate(2026, 3, 1),
          onChanged: (_) {},
        ),
      );
      expect(find.text('2026년 3월 1일'), findsOneWidget);
    });
  });

  group('접근성', () {
    testWidgets('배율 2.0 에서 칩이 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpWidgetOnly(
        tester,
        DateInput(
          question: dateQuestion(DateRange.any),
          value: const ApproxDate(2026, 8, 13),
          onChanged: (_) {},
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
