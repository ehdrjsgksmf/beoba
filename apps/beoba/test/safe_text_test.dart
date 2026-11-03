import 'package:beoba/src/safety/disclaimers.dart';
import 'package:beoba/src/safety/safe_text.dart';
import 'package:engines/engines.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 화면에 나가는 문구가 SafetyFilter 를 통과하는지 **위젯 빌드 시점에** 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SafeText — 통과', () {
    testWidgets('안전한 문구는 그대로 그린다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const SafeText('받지 못한 금액은 얼마인가요?', where: 'test'),
      );

      expect(find.text('받지 못한 금액은 얼마인가요?'), findsOneWidget);
      expect(find.byType(BlockedNotice), findsNothing);
    });

    testWidgets('quote scope 는 인용 조문을 막지 않는다', (tester) async {
      // 조문 원문에 100% 같은 표기가 나올 수 있다. strict 면 조문이 통째로 막힌다.
      const quoted = '지연손해금은 연 100%를 넘을 수 없다';
      expect(SafetyFilter.isSafe(quoted), isFalse);

      await pumpWidgetOnly(
        tester,
        const SafeText(quoted, where: 'test', scope: SafetyScope.quote),
      );

      expect(find.text(quoted), findsOneWidget);
    });

    testWidgets('disclaimer scope 는 "하지 않는다" 고지를 통과시킨다', (tester) async {
      const text = Disclaimers.noOutcomePrediction;
      // strict 로는 `승소` 때문에 막힌다. 부분 문자열 검사는 부정문을 모른다.
      expect(SafetyFilter.isSafe(text), isFalse);

      await pumpWidgetOnly(
        tester,
        const SafeText(text, where: 'test', scope: SafetyScope.disclaimer),
      );

      expect(find.text(text), findsOneWidget);
      expect(find.byType(BlockedNotice), findsNothing);
    });

    testWidgets('disclaimer scope 도 단정 표현은 그대로 막는다', (tester) async {
      // 면제는 `승소` 라는 낱말 하나뿐이다. 예측 문장이 새어 나가면 안 된다.
      expect(
        SafetyFilter.isSafe(
          '승소 가능성이 높습니다',
          scope: SafetyScope.disclaimer,
        ),
        isFalse,
      );
      expect(
        SafetyFilter.isSafe('유리합니다', scope: SafetyScope.disclaimer),
        isFalse,
      );
    });
  });

  group('SafeText — 차단', () {
    testWidgets('금지 표현은 디버그에서 실패한다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const SafeText('이 사건은 유리합니다', where: 'test'),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('차단되면 문구 대신 대체 안내를 그린다 (릴리스 동작)', (tester) async {
      // 디버그에서는 assert 가 먼저 던져 위젯이 끝까지 그려지지 않는다.
      // 릴리스 경로를 보려면 그 예외만 끈다.
      SafeText.debugAssertOnViolation = false;
      addTearDown(() => SafeText.debugAssertOnViolation = true);

      await pumpWidgetOnly(
        tester,
        const SafeText('무조건 받으실 수 있습니다', where: 'test'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('무조건 받으실 수 있습니다'), findsNothing);
      expect(find.text(BlockedNotice.message), findsOneWidget);
    });

    testWidgets('차단되면 SafetyReporter 가 불린다', (tester) async {
      final reporter = RecordingSafetyReporter();

      await pumpWidgetOnly(
        tester,
        const SafeText('승소 가능성이 높습니다', where: 'DeadlineResult.label'),
        reporter: reporter,
      );
      tester.takeException();

      expect(reporter.patterns, isNotEmpty);
      expect(reporter.wheres, contains('DeadlineResult.label'));
    });

    testWidgets('보고에 문구 원문을 남기지 않는다', (tester) async {
      final reporter = RecordingSafetyReporter();
      // 자유 입력에는 이름·전화번호가 섞인다. 로그로 새면 안 된다.
      const secret = '홍길동님은 무조건 받으실 수 있습니다';

      await pumpWidgetOnly(
        tester,
        const SafeText(secret, where: 'HomeScreen.narrative'),
        reporter: reporter,
      );
      tester.takeException();

      expect(reporter.patterns, isNotEmpty);
      for (final line in reporter.everything) {
        expect(line, isNot(contains('홍길동')));
        expect(line, isNot(contains(secret)));
      }
    });
  });
}
