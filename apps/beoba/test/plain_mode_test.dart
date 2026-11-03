import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/widgets/plain_mode_switch.dart';
import 'package:beoba/src/widgets/say_this_card.dart';
import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show KstDate, PlainKoreanCheck, PlainRule;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 쉬운 한국어 한 벌.
///
/// ★ **번역이 아니다.** 검수해 줄 사람이 없는 번역문은 정확도 기준과 정면으로
/// 부딪힌다(DECISIONS 233번). 대신 오역 위험이 0인 둘을 넣었다 — 우리가 쓴
/// 문장을 짧게 쓴 한 벌과, 기관·서식 이름을 한국어 그대로 크게 보여 주는 카드.
///
/// ★ **조문 원문은 이 길로도 안 바뀐다.** 바꿀 수 있는 자리를 `kPlainTargets`
/// 가 정하고, 그 밖의 키는 `SchemaValidator` 가 막는다.
const String kWorkInjury = 'work_injury';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DomainBundle bundle;
  setUpAll(() async => bundle = await loadTestBundle());

  /// 원래 한 벌.
  Domain base() => bundle.byId(kWorkInjury);

  /// 쉬운 말 한 벌.
  Domain easy() => bundle.byId(kWorkInjury).inPlainKorean();

  Caution cautionOf(Domain d, String id) =>
      d.cautions.firstWhere((c) => c.id == id);
  Procedure procedureOf(Domain d, String id) =>
      d.procedures.firstWhere((p) => p.id == id);

  group('★ 바뀌는 것과 안 바뀌는 것', () {
    test('우리가 쓴 문장은 바뀐다', () {
      expect(
        cautionOf(easy(), 'ct_all_workplaces').consequence,
        isNot(cautionOf(base(), 'ct_all_workplaces').consequence),
      );
      expect(
        cautionOf(easy(), 'ct_all_workplaces').consequence,
        contains('사람 수로 빼는 줄은 여기에 없어요'),
      );
    });

    test('★ 조문 원문은 한 글자도 안 바뀐다', () {
      for (final id in [for (final c in base().cautions) c.id]) {
        expect(
          cautionOf(easy(), id).legalBasis?.text,
          cautionOf(base(), id).legalBasis?.text,
          reason: '$id 의 조문 원문이 바뀌었습니다',
        );
        expect(
          [for (final b in cautionOf(easy(), id).alsoBasis) b.text],
          [for (final b in cautionOf(base(), id).alsoBasis) b.text],
        );
      }
    });

    test('★ 기관 이름과 서식 이름도 안 바뀐다', () {
      final say = procedureOf(easy(), 'proc_care_claim').sayThis;
      expect(say?.agency, '근로복지공단');
      expect(say?.form, '요양급여 신청서');
    });

    test('한 벌에 없는 자리는 원래 문장 그대로다', () {
      // 이미 짧은 문장은 굳이 두 벌로 만들지 않는다.
      expect(
        procedureOf(easy(), 'proc_review').detail,
        procedureOf(base(), 'proc_review').detail,
      );
    });

    test('한 벌이 없는 분야는 자기 자신을 그대로 돌려준다', () {
      // **분야 이름으로 가리키지 않는다.** 예전에는 「아직 쉬운 말이 없는
      // 분야」 하나를 이름으로 박아 뒀는데, 그 분야에 쉬운 말을 붙이는 날
      // 이 검사가 깨졌다. 열넷이 다 차면 가리킬 분야가 아예 없어진다.
      // 재는 것은 분야가 아니라 **한 벌이 비었을 때의 행동**이다.
      final empty = bundle
          .byId('deposit_return')
          .copyWith(plain: const <String, String>{});
      expect(identical(empty.inPlainKorean(), empty), isTrue);
    });
  });

  group('★ 쉬운 말은 원래 문장보다 단정하지 않다', () {
    test('한 벌 전체를 검사에 통과시킨다', () {
      const checker = PlainKoreanCheck();
      final failures = <String>[];
      for (final entry in base().plain.entries) {
        final parts = entry.key.split('.');
        final original = switch (parts.first) {
          'cautions' => switch (parts.last) {
              'question' => cautionOf(base(), parts[1]).question,
              'condition' => cautionOf(base(), parts[1]).condition,
              _ => cautionOf(base(), parts[1]).consequence,
            },
          _ => null,
        };
        if (original == null) continue;
        for (final issue in checker.check(
          original: original,
          plain: entry.value,
          // 이 분야가 40자를 놓아 준 자리가 있으면 그 이유도 함께 넘긴다.
          // 안 넘기면 데이터는 멀쩡한데 이 검사만 빨개진다.
          longOk: base().plainLongOk[entry.key],
        )) {
          failures.add('${entry.key} — ${issue.message}');
        }
      }
      expect(failures, isEmpty);
    });
  });

  group('★ 검사가 비어 있지 않다', () {
    test('원래 문장을 그대로 쉬운 말이라 하면 몇 건이 걸리는가', () {
      // **검사가 무엇을 잡는지 눈으로 본다.** 통과만 보고 있으면 규칙이
      // 실제로 도는지 알 수 없다 — 원래 문장을 그대로 쉬운 말 자리에
      // 넣어 보면 그 분야에서 몇 건을 잡는지가 나온다.
      const checker = PlainKoreanCheck();
      final counted = <PlainRule, int>{};
      var slots = 0;

      void feed(String text) {
        if (text.trim().isEmpty) return;
        slots++;
        for (final issue in checker.check(original: text, plain: text)) {
          counted[issue.rule] = (counted[issue.rule] ?? 0) + 1;
        }
      }

      final d = base();
      feed(d.description ?? '');
      for (final q in d.intake) {
        feed(q.text);
        feed(q.whyAsk);
      }
      for (final c in d.cautions) {
        feed(c.question);
        feed(c.condition);
        feed(c.consequence);
      }
      for (final p in d.procedures) {
        feed(p.whatIsThis);
        feed(p.detail ?? '');
      }
      for (final r in d.limitationRules) {
        feed(r.note);
      }

      // ignore: avoid_print
      print('쉬운 말 검사 — 산재 $slots자리를 원래 문장 그대로 넣으면: '
          '${counted.entries.map((e) => '${e.key.name} ${e.value}건').join(' · ')}');
      expect(counted[PlainRule.tooLong], greaterThan(0));
    });
  });

  group('스위치', () {
    testWidgets('★ 기기 언어가 아니라 사람이 켠다 — 처음에는 꺼져 있다', (tester) async {
      final container = await pumpApp(tester);
      expect(container.read(plainModeProvider), isFalse);
      expect(find.byType(PlainModeSwitch), findsOneWidget);
    });

    testWidgets('★ 스위치 이름 자체가 쉬운 말이다', (tester) async {
      await pumpApp(tester);
      expect(find.text(PlainModeSwitch.label), findsOneWidget);
    });

    testWidgets('누르면 켜지고 다시 누르면 꺼진다', (tester) async {
      final container = await pumpApp(tester);
      await tester.tap(find.byType(PlainModeSwitch));
      await tester.pumpAndSettle();
      expect(container.read(plainModeProvider), isTrue);

      await tester.tap(find.byType(PlainModeSwitch));
      await tester.pumpAndSettle();
      expect(container.read(plainModeProvider), isFalse);
    });
  });

  group('★ 화면까지 온다', () {
    Future<ProviderContainer> openResult(WidgetTester tester,
        {required bool plain}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.reset);

      final container = await pumpApp(tester);
      if (plain) container.read(plainModeProvider.notifier).toggle();
      seedAnswers(container, kWorkInjury, answers: const {
        'q_injury_date': KstDate(2026, 8, 1),
        'q_injury_kind': 'commute',
        'q_treated_days': 'longer',
      });
      container.read(routerProvider).go(Routes.result(kWorkInjury));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('꺼져 있으면 원래 물음이 나온다', (tester) async {
      await openResult(tester, plain: false);
      expect(find.text('오가는 길은요?'), findsOneWidget);
    });

    testWidgets('★ 켜면 같은 자리에 쉬운 물음이 나온다', (tester) async {
      await openResult(tester, plain: true);
      expect(find.text('오가는 길에 다친 것도 되나요?'), findsOneWidget);
      expect(find.text('오가는 길은요?'), findsNothing);
    });
  });

  group('★ 이 말을 그대로 보여 주세요', () {
    testWidgets('기관 이름과 서식 이름이 크게 나온다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const SayThisCard(
          say: SayThis(agency: '근로복지공단', form: '요양급여 신청서'),
          where: 'test',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(SayThisCard.title), findsOneWidget);
      expect(find.text('근로복지공단'), findsOneWidget);
      expect(find.text('요양급여 신청서'), findsOneWidget);
      expect(find.text(SayThisCard.copy), findsOneWidget);
    });

    testWidgets('★ 눌러서 되면 복사했다고 말한다', (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await pumpWidgetOnly(
        tester,
        const SayThisCard(
          say: SayThis(agency: '근로복지공단', form: '요양급여 신청서'),
          where: 'test',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(SayThisCard.copy));
      await tester.pumpAndSettle();

      // 기관 이름과 서식 이름이 줄바꿈으로 붙어서 간다.
      expect((calls.single.arguments as Map)['text'],
          '근로복지공단\n요양급여 신청서');
      expect(find.text(SayThisCard.copied), findsOneWidget);
    });

    testWidgets('★ 복사가 막히면 글자를 고를 수 있게 띄운다', (tester) async {
      // **웹에서 실제로 이렇게 된다.** 엔진의 웹 클립보드는
      // `navigator.clipboard` 하나만 쓰고, 보안 컨텍스트가 아니면
      // `Clipboard is not available in the context.` 로 던진다.
      // 예전에는 아무도 그걸 안 잡아서 **눌렀는데 아무 일도 안 일어나는
      // 화면**이 됐다 — 성공인지 실패인지 사람이 알 수가 없었다.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(
            code: 'copy_fail',
            message: 'Clipboard is not available in the context.',
          );
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await pumpWidgetOnly(
        tester,
        const SayThisCard(
          say: SayThis(agency: '근로복지공단', form: '요양급여 신청서'),
          where: 'test',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(SayThisCard.copy));
      await tester.pumpAndSettle();

      // 실패했다고 말한다. 조용히 넘어가지 않는다.
      expect(find.text(SayThisCard.copyBlocked), findsOneWidget);
      // **그리고 길을 준다.** 사람이 직접 골라서 가져간다.
      expect(find.byType(SelectableText), findsOneWidget);
      final selectable =
          tester.widget<SelectableText>(find.byType(SelectableText));
      expect(selectable.data, '근로복지공단\n요양급여 신청서');

      // 버튼은 사라진다. 다시 눌러 보게 하지 않는다.
      expect(find.text(SayThisCard.copy), findsNothing);
      expect(find.text(SayThisCard.copied), findsNothing);
    });

    testWidgets('서식 이름이 없으면 그 줄만 빠진다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const SayThisCard(say: SayThis(agency: '근로복지공단'), where: 'test'),
      );
      await tester.pumpAndSettle();

      expect(find.text('근로복지공단'), findsOneWidget);
      expect(find.text(SayThisCard.formLabel), findsNothing);
    });
  });
}
