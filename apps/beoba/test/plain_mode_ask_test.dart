import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/plain/plain_mode_store.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/tally/tally.dart';
import 'package:beoba/src/widgets/plain_mode_ask_sheet.dart';
import 'package:beoba/src/widgets/plain_mode_switch.dart';
import 'package:beoba/src/widgets/tally_consent_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 처음 여실 때의 물음 둘 — **한 실행에 겹쳐 뜨지 않는다** (DECISIONS 289번).
///
/// ```
/// 처음 열 때              쉬운 말 물음 하나만
/// 첫 결과 화면           아무것도 안 띄움
/// 결과를 떠나 도착한 화면  집계 동의
/// 다음에 열 때            (아직 답 안 하셨으면) 집계 동의
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('보기 한 쌍은 데이터에서 온다', () {
    test('★ 실제 데이터에 원문과 쉬운 말이 둘 다 있고 서로 다르다', () async {
      final bundle = await loadTestBundle();
      final example = PlainModeAskSheet.exampleFrom(bundle);
      expect(example, isNotNull,
          reason: '보기 물음이나 그 쉬운 말이 데이터에서 사라졌습니다');
      final (before, after) = example!;
      final domain = bundle.byId(PlainModeAskSheet.exampleDomain);
      final question = domain.intake
          .singleWhere((q) => q.id == PlainModeAskSheet.exampleQuestion);
      expect(before, question.text);
      expect(after, domain.plain['intake.${question.id}.text']);
      expect(after, isNot(before));
    });

    test('★ 「어려운 말」 · 「짧고」를 약속하지 않는다 — 쉬운 말은 문장을 바꾼다', () {
      expect(PlainModeAskSheet.title, isNot(contains('어려운 말')));
      expect(PlainModeAskSheet.title, isNot(contains('짧')));
    });
  });

  group('처음 여실 때', () {
    testWidgets('★ 쉬운 말 물음 하나만 뜬다 — 집계 동의는 안 겹친다', (tester) async {
      final store = MemoryPlainModeStore();
      await pumpApp(tester,
          plainStore: store, consent: MemoryConsentStore());

      expect(find.byType(PlainModeAskSheet), findsOneWidget);
      expect(find.byType(TallyConsentSheet), findsNothing);
      expect(find.textContaining('유언으로 정해 두신 게 있나요?'), findsOneWidget);

      await tester.tap(find.text(PlainModeAskSheet.keep));
      await tester.pumpAndSettle();

      expect(find.byType(PlainModeAskSheet), findsNothing);
      expect(find.byType(TallyConsentSheet), findsNothing,
          reason: '열자마자 상자 둘이 연달아 뜨면 읽지 않고 닫습니다');
      expect(await store.read(), isFalse);
    });

    testWidgets('「쉬운 말로 볼게요」를 누르면 켜지고 기억된다', (tester) async {
      final store = MemoryPlainModeStore();
      final container = await pumpApp(tester, plainStore: store);

      await tester.tap(find.text(PlainModeAskSheet.plain));
      await tester.pumpAndSettle();

      expect(container.read(plainModeProvider), isTrue);
      expect(await store.read(), isTrue);
    });

    testWidgets('뒤로 가기 · 바깥 누름으로 안 닫힌다', (tester) async {
      await pumpApp(tester, plainStore: MemoryPlainModeStore());

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(PlainModeAskSheet), findsOneWidget);
    });

    testWidgets('★ 두 버튼이 같은 모양이다 — 색으로 밀지 않는다', (tester) async {
      await pumpApp(tester, plainStore: MemoryPlainModeStore());

      final buttons = find.descendant(
        of: find.byType(PlainModeAskSheet),
        matching: find.byType(OutlinedButton),
      );
      expect(buttons, findsNWidgets(2));
      expect(find.descendant(
        of: find.byType(PlainModeAskSheet),
        matching: find.byType(FilledButton),
      ), findsNothing);
      expect(tester.getSize(buttons.at(0)), tester.getSize(buttons.at(1)));
    });

    for (final (scale, first) in [
      (1.0, PlainModeAskSheet.keep),
      (1.5, PlainModeAskSheet.plain),
    ]) {
      testWidgets('글자 배율 $scale 이면 「$first」가 앞이다 — 순서만 바뀐다',
          (tester) async {
        final container = await pumpApp(
          tester,
          plainStore: MemoryPlainModeStore(),
          textScale: scale,
        );

        final keepX = tester.getCenter(find.text(PlainModeAskSheet.keep)).dx;
        final plainX = tester.getCenter(find.text(PlainModeAskSheet.plain)).dx;
        expect(first == PlainModeAskSheet.keep ? keepX < plainX : plainX < keepX,
            isTrue);
        // **저절로 켜지 않는다.**
        expect(container.read(plainModeProvider), isFalse);
      });
    }
  });

  group('기억한다', () {
    testWidgets('★ 켜 두셨으면 다시 열어도 켜져 있고, 물음이 안 뜬다', (tester) async {
      final container =
          await pumpApp(tester, plainStore: MemoryPlainModeStore(true));

      expect(container.read(plainModeProvider), isTrue);
      expect(find.byType(PlainModeAskSheet), findsNothing);
    });

    testWidgets('스위치로 바꾼 것도 기억한다', (tester) async {
      final store = MemoryPlainModeStore(false);
      await pumpApp(tester, plainStore: store);

      await tester.tap(find.text(PlainModeSwitch.label).first);
      await tester.pumpAndSettle();
      expect(await store.read(), isTrue);
    });

    testWidgets('★ 스위치가 결과 화면 위에도 있다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId, answers: completeAnswers);
      container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();

      expect(find.text(PlainModeSwitch.label), findsOneWidget);
    });
  });

  group('집계 동의는 첫 결과를 본 뒤에', () {
    testWidgets('★ 결과 화면에서는 안 뜨고, 떠나서 도착한 화면에서 뜬다', (tester) async {
      final container = await pumpApp(
        tester,
        plainStore: MemoryPlainModeStore(),
        consent: MemoryConsentStore(),
      );
      await tester.tap(find.text(PlainModeAskSheet.keep));
      await tester.pumpAndSettle();

      seedAnswers(container, kDebtRecoveryDomainId, answers: completeAnswers);
      final router = container.read(routerProvider);
      router.go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      expect(find.byType(TallyConsentSheet), findsNothing,
          reason: '결과를 가리면 안 됩니다');

      // 결과 안에서 오가는 것은 떠난 것이 아니다.
      router.go(Routes.resultDetail(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      expect(find.byType(TallyConsentSheet), findsNothing);

      router.go(Routes.home);
      await tester.pumpAndSettle();
      expect(find.byType(TallyConsentSheet), findsOneWidget);
    });

    testWidgets('이미 답하셨으면 떠나도 안 뜬다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(container, kDebtRecoveryDomainId, answers: completeAnswers);
      final router = container.read(routerProvider);
      router.go(Routes.result(kDebtRecoveryDomainId));
      await tester.pumpAndSettle();
      router.go(Routes.home);
      await tester.pumpAndSettle();
      expect(find.byType(TallyConsentSheet), findsNothing);
    });

    testWidgets('다음에 여실 때 — 쉬운 말은 답하셨고 동의는 아직이면 홈에서 묻는다',
        (tester) async {
      await pumpApp(
        tester,
        plainStore: MemoryPlainModeStore(false),
        consent: MemoryConsentStore(),
      );
      expect(find.byType(PlainModeAskSheet), findsNothing);
      expect(find.byType(TallyConsentSheet), findsOneWidget);
    });
  });
}
