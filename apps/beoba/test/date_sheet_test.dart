import 'package:beoba/src/screens/interview/answers/date_sheet.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 「정확히 모른다」를 정식 답으로 받는 자리.
///
/// 그리고 **휠이 유일한 입력 경로여서는 안 된다.** `ListWheelScrollView` 는
/// 스크린리더 지원이 약하다. 휠만 두면 못 쓰는 사람이 생기고, 그 사람들은 이 앱이
/// 돕겠다고 한 사람들과 겹친다.
void main() {
  // 기준일은 2026년 8월 15일 (testClock).
  const today = KstDate(2026, 8, 15);

  Future<void> pumpSheet(
    WidgetTester tester, {
    ApproxDate? initial,
    bool allowsApproximate = true,
    bool allowsPast = true,
    bool allowsFuture = true,
    double textScale = 1,
  }) =>
      pumpWidgetOnly(
        tester,
        DateSheet(
          today: today,
          initial: initial,
          allowsPast: allowsPast,
          allowsFuture: allowsFuture,
          allowsApproximate: allowsApproximate,
        ),
        textScale: textScale,
      );

  group('「모름」은 정식 선택지다', () {
    testWidgets('처음 열면 커서가 「모름」에 있다', (tester) async {
      // 기본값이 특정 날짜면 아무것도 안 한 사람이 그 날짜로 확정된다.
      // 조작하지 않은 사람이 거짓을 얻어서는 안 된다.
      await pumpSheet(tester);
      expect(find.text('2026년'), findsOneWidget);
    });

    testWidgets('월·일 휠에 「모름」 항목이 있다', (tester) async {
      await pumpSheet(tester);
      expect(find.text(DateSheet.unknown), findsWidgets);
    });

    testWidgets('어림값을 안 받는 질문에는 「모름」이 없다', (tester) async {
      // 법원 서류를 받은 날은 서류에 적혀 있다. 어림이 있을 수 없다.
      await pumpSheet(tester, allowsApproximate: false);
      expect(find.text(DateSheet.unknown), findsNothing);
    });

    testWidgets('그때는 오늘 날짜로 시작한다', (tester) async {
      await pumpSheet(tester, allowsApproximate: false);
      expect(find.text('2026년 8월 15일'), findsOneWidget);
    });
  });

  group('연 휠에는 「모름」이 없다', () {
    testWidgets('연도를 모르면 답하지 않은 것이다', (tester) async {
      // 연도를 모르면 어떤 계산도 못 한다.
      await pumpSheet(tester);
      // 「모름」은 월·일 두 곳에만 있다. 연 휠까지 있으면 셋이 된다.
      expect(find.text(DateSheet.unknown), findsNWidgets(2));
    });
  });

  group('휠이 유일한 경로가 아니다', () {
    testWidgets('숫자로 직접 넣는 칸이 있다', (tester) async {
      await pumpSheet(tester);
      expect(find.text(DateSheet.typeInstead), findsOneWidget);
    });

    testWidgets('직접 넣은 값이 그대로 답이 된다', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), '2023-03');
      await tester.pumpAndSettle();
      expect(find.text('2023년 3월'), findsOneWidget);
    });

    testWidgets('일까지 넣으면 정확한 날짜가 된다', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), '2023-03-15');
      await tester.pumpAndSettle();
      expect(find.text('2023년 3월 15일'), findsOneWidget);
    });

    testWidgets('읽지 못하면 되묻는다', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), '2023-99');
      await tester.pumpAndSettle();
      expect(find.text(DateSheet.typeBad), findsOneWidget);
    });

    testWidgets('휠에도 스크린리더가 읽을 이름과 값이 붙어 있다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(tester);
      expect(
        find.bySemanticsLabel(DateSheet.yearLabel),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('범위를 벗어난 값은 확정하지 못한다', () {
    testWidgets('과거만 받는 질문에 앞날을 넣으면 막는다', (tester) async {
      await pumpSheet(tester, allowsFuture: false);
      await tester.enterText(find.byType(TextField), '2030-01-01');
      await tester.pumpAndSettle();
      expect(find.text(DateSheet.outOfRangePast), findsOneWidget);
    });
  });

  group('접근성', () {
    testWidgets('배율 2.0 에서 시트가 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpSheet(tester, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
