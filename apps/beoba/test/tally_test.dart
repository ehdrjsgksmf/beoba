import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/tally/tally.dart';
import 'package:beoba/src/widgets/privacy_sheet.dart';
import 'package:beoba/src/widgets/tally_consent_sheet.dart';
import 'package:engines/engines.dart' show SessionTally;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **집계는 원문 없이 센다.**
///
/// 조합해도 사람이 특정되지 않는다 — 지역·금액·날짜가 없기 때문이다.
/// 「상속 · 받을 쪽 · q_known_date 에서 나감」은 아무도 아니다.
class _RecordingSink implements TallySink {
  final List<SessionTally> sent = [];

  @override
  Future<void> send(SessionTally tally) async => sent.add(tally);
}

/// 보내다 터지는 곳. **화면이 멈추면 안 된다.**
class _BrokenSink implements TallySink {
  @override
  Future<void> send(SessionTally tally) async => throw StateError('끊김');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, _RecordingSink)> openResult(
    WidgetTester tester, {
    bool? consent = true,
  }) async {
    final sink = _RecordingSink();
    final container = await pumpApp(
      tester,
      tallySink: sink,
      consent: MemoryConsentStore(consent),
    );
    seedAnswers(container, kDebtRecoveryDomainId, answers: completeAnswers);
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return (container, sink);
  }

  group('보내는 것은 다섯 칸뿐이다', () {
    test('키가 허용 목록과 정확히 같다', () {
      const tally = SessionTally(
        domain: 'wage_theft',
        role: 'creditor',
        exitAt: 'q_due_date',
        reached: false,
        version: '1.0.0',
      );

      expect(tally.toJson().keys, SessionTally.allowedKeys);
      expect(SessionTally.allowedKeys, hasLength(5));
    });

    test('날짜는 넣지 않는다 — 받는 쪽이 찍는다', () {
      const tally = SessionTally(
        domain: 'x',
        role: '',
        exitAt: '',
        reached: true,
        version: '1.0.0',
      );

      for (final key in tally.toJson().keys) {
        expect(key.toLowerCase(), isNot(contains('date')));
        expect(key.toLowerCase(), isNot(contains('time')));
      }
    });

    testWidgets('★ 값에 금액·날짜·원문이 없다', (tester) async {
      final (_, sink) = await openResult(tester);
      final sent = sink.sent.single.toJson();

      for (final entry in sent.entries) {
        // 앱 버전은 숫자다. 그건 사람에 대한 것이 아니라 우리 것이다.
        if (entry.key == 'version' || entry.value is! String) continue;
        expect(
          RegExp(r'\d').hasMatch(entry.value! as String),
          isFalse,
          reason: '${entry.key} = ${entry.value}',
        );
      }
      // 자유 입력 원문이 섞이지 않는다.
      expect(sent.values, isNot(contains(contains('빌려'))));
    });

    testWidgets('★ exitAt 은 질문 id 이지 답이 아니다', (tester) async {
      final (container, sink) = await openResult(tester);
      final questions = container
          .read(domainBundleProvider)
          .requireValue
          .byId(kDebtRecoveryDomainId)
          .intake
          .map((q) => q.id)
          .toSet();

      final exitAt = sink.sent.single.exitAt;
      // 결과까지 갔으면 물어볼 것이 없어 빈 문자열이다.
      expect(exitAt.isEmpty || questions.contains(exitAt), isTrue);
      // 답이 들어오면 안 된다.
      expect(exitAt, isNot('payment_order'));
      expect(exitAt, isNot('creditor'));
    });
  });

  group('물어보고 켠다', () {
    testWidgets('★ 「세지 마세요」면 아무것도 안 나간다', (tester) async {
      final (_, sink) = await openResult(tester, consent: false);
      expect(sink.sent, isEmpty);
    });

    testWidgets('아직 안 물어봤으면 안 나간다', (tester) async {
      final (_, sink) = await openResult(tester, consent: null);
      expect(sink.sent, isEmpty);
    });

    testWidgets('세션 하나에 한 번만 나간다', (tester) async {
      final (container, sink) = await openResult(tester);
      expect(sink.sent, hasLength(1));

      // 결과 화면을 다시 열어도 늘지 않는다.
      container.read(routerProvider).go(Routes.summary(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(sink.sent, hasLength(1));
    });

    testWidgets('보내다 터져도 화면이 멈추지 않는다', (tester) async {
      final container = await pumpApp(
        tester,
        tallySink: _BrokenSink(),
        consent: MemoryConsentStore(true),
      );
      seedAnswers(container, kDebtRecoveryDomainId, answers: completeAnswers);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expectScreenText(tester, '오늘 할 일');
    });

    testWidgets('두 버튼이 같은 무게다', (tester) async {
      await pumpApp(
        tester,
        consent: MemoryConsentStore(),
      );
      await tester.pumpAndSettle();

      expect(find.text(TallyConsentSheet.title), findsOneWidget);
      expect(find.text(TallyConsentSheet.yes), findsOneWidget);
      expect(find.text(TallyConsentSheet.no), findsOneWidget);
      // 느낌표를 쓰지 않는다. 마중이는 들뜨지 않는다.
      expect(TallyConsentSheet.title.contains('!'), isFalse);
      expect(TallyConsentSheet.body.contains('!'), isFalse);
    });
  });

  group('「자세히」 시트', () {
    test('여섯 줄이고 첫 줄이 고쳐졌다', () {
      expect(PrivacySheet.lines, hasLength(6));

      final first = PrivacySheet.lines.first.$2;
      expect(first, contains('적으신 글은 나가지 않아요'));
      // 집계가 나가므로 「인터넷으로 보내지 않아요」는 더 이상 정확하지 않다.
      expect(first, isNot(contains('인터넷으로 보내지 않아요')));

      final all = PrivacySheet.lines.map((line) => line.$2).join(' ');
      expect(all, contains('어떤 분야를 보셨는지만 세어요'));
      expect(all, contains('기기에 남겨요'));
      // 애매한 말을 쓰지 않는다.
      expect(all, isNot(contains('일부는')));
    });
  });
}
