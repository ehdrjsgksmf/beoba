import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/data/asset_domain_source.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:engines/engines.dart' show KstDate, SafetyFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 일하다 다쳤을 때.
///
/// ★ **이 분야는 업무상 재해인지 판정하지 않는다.** 제37조 제1항 단서가
/// 「업무와 재해 사이에 상당인과관계가 없는 경우에는 그러하지 아니하다」이고
/// 그 판단은 근로복지공단이 한다. 각 호를 원문 그대로 펴고 본인이 찾게 한다.
const String kWorkInjury = 'work_injury';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    seedAnswers(container, kWorkInjury, answers: answers);
    container.read(routerProvider).go(Routes.result(kWorkInjury));
    await tester.pumpAndSettle();
    return container;
  }

  Map<String, Object?> answers(String kind) => {
        'q_injury_date': const KstDate(2026, 8, 1),
        'q_injury_kind': kind,
        'q_treated_days': 'longer',
      };

  const accidentHead = '일하다 다친 것은 어디에 적혀 있나요?';
  const commuteHead = '오가는 길은요?';
  const diseaseHead = '몸이나 마음이 나빠진 것도 적혀 있나요?';

  group('★★ 제37조 세 갈래가 화면까지 온다', () {
    testWidgets('일하다가요 → 업무상 사고만', (tester) async {
      await openResult(tester, answers('work'));

      expect(find.text(accidentHead), findsOneWidget);
      expect(find.text(commuteHead), findsNothing);
      expect(find.text(diseaseHead), findsNothing);
    });

    testWidgets('오가는 길에요 → 출퇴근 재해만', (tester) async {
      await openResult(tester, answers('commute'));

      expect(find.text(commuteHead), findsOneWidget);
      expect(find.text(accidentHead), findsNothing);
    });

    testWidgets('몸이나 마음이 나빠졌어요 → 업무상 질병만', (tester) async {
      await openResult(tester, answers('disease'));

      expect(find.text(diseaseHead), findsOneWidget);
      expect(find.text(accidentHead), findsNothing);
    });

    testWidgets('★ 잘 모르겠어요 → 셋을 다 편다', (tester) async {
      await openResult(tester, answers('unknown'));

      // **좁히는 것이 목적이 아니다.** 자기 자리를 못 찾은 사람에게
      // 세 갈래를 다 보여준다.
      expect(find.text(accidentHead), findsOneWidget);
      expect(find.text(commuteHead), findsOneWidget);
      expect(find.text(diseaseHead), findsOneWidget);
    });

    testWidgets('업무상 질병에 직장 내 괴롭힘이 들어 있다', (tester) async {
      await openResult(tester, answers('disease'));
      await openQuestion(tester, diseaseHead);

      expect(
        find.textContaining('직장 내 괴롭힘'),
        findsWidgets,
        reason: '「이건 산재가 아니겠지」로 아예 안 가는 자리입니다',
      );
    });

    testWidgets('★ 출퇴근 일탈·중단의 단서를 빼지 않는다', (tester) async {
      await openResult(tester, answers('commute'));
      await openQuestion(tester, commuteHead);

      expect(find.textContaining('통상적인 경로와 방법'), findsWidgets);
      // 단서를 빼면 「들렀으니 끝」이 된다.
      expect(find.textContaining('일상생활에 필요한 행위'), findsWidgets);
    });
  });

  group('★★ 회사를 거치는 절차가 아니다', () {
    testWidgets('첫 화면에 펼쳐 두는 카드가 이것 하나다', (tester) async {
      await openResult(tester, answers('work'));

      // **펼친 카드는 물음 머리를 안 그린다.** condition 과 consequence 만
      // 나온다 — 접힌 물음이 아니라 이미 펴 둔 말이기 때문이다.
      final card = find.text('산재 처리를 안 해준다는 말을 들으셨다면');
      expect(card, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(780),
        reason: '이 분야에서 제일 많이 막는 말입니다. 첫 화면에 있어야 합니다',
      );
    });

    testWidgets('조문이 말하게 하고 우리가 단정하지 않는다', (tester) async {
      await openResult(tester, answers('work'));

      expect(find.textContaining('신청하는 사람으로 적힌 것은 근로자'), findsWidgets);
      // 병원이 대신 낼 수 있다는 줄이 실제 손잡이다.
      expect(find.textContaining('병원 원무과'), findsWidgets);
    });
  });

  group('★ 다섯 명 미만도 빠지지 않는다', () {
    testWidgets('부당해고와의 대비를 한 줄로 낸다', (tester) async {
      await openResult(tester, answers('work'));
      await openQuestion(tester, '작은 곳도 되나요?');

      expect(find.textContaining('모든 사업 또는 사업장에 적용한다'), findsWidgets);
      expect(find.textContaining('다섯 명 미만이 빠지는 조문이 따로'), findsWidgets);
    });
  });

  group('★ 3일은 둘을 짝으로 낸다', () {
    testWidgets('요양급여와 휴업급여가 한 카드에 있다', (tester) async {
      await openResult(tester, answers('work'));
      await openQuestion(tester, '사흘이면 안 나오나요?');

      expect(find.textContaining('요양급여를 지급하지 아니한다'), findsWidgets);
      expect(find.textContaining('취업하지 못한 기간이 3일 이내'), findsWidgets);
    });
  });

  group('★ 안 된다고 했을 때', () {
    testWidgets('90일이 두 번이고 행정심판은 못 낸다', (tester) async {
      await openResult(tester, answers('work'));
      await openQuestion(tester, '안 된다고 하면 어떻게 되나요?');

      expect(find.textContaining('90일 이내'), findsWidgets);
      // 「행정심판 넣으면 되지」로 헛걸음하는 자리다.
      expect(find.textContaining('행정심판을 제기할 수 없다'), findsWidgets);
    });
  });

  group('★ 조문에 있는 무거운 단서를 빼지 않는다', () {
    testWidgets('고의·자해 조항에 단서가 함께 있다', (tester) async {
      await openResult(tester, answers('work'));
      await openQuestion(tester, '안 되는 경우도 적혀 있나요?');

      expect(find.textContaining('업무상의 재해로 보지 않는다'), findsWidgets);
      expect(
        find.textContaining('정상적인 인식능력 등이 뚜렷하게 낮아진 상태'),
        findsWidgets,
        reason: '단서를 빼면 그 자리에서 끝나는 것으로 읽힙니다',
      );
    });
  });

  group('데이터 — 다리와 금지어', () {
    late DomainBundle bundle;

    setUpAll(() async {
      bundle = await loadTestBundle();
    });

    test('★ 다리 셋 — 두 분야에서 오고, 이 분야에서 간다', () {
      final injury = bundle.byId(kWorkInjury);
      final ids = injury.cautions.map((c) => c.id).toSet();
      expect(ids, contains('ct_bridge_dismissal'));
      expect(ids, contains('ct_bridge_unemployment'));

      for (final from in const ['unfair_dismissal', 'unemployment_benefit']) {
        expect(
          bundle.byId(from).cautions.map((c) => c.id),
          contains('ct_hurt_at_work'),
          reason: '$from 에서 건너오는 한 줄이 없습니다',
        );
      }
    });

    test('★ 판정하는 말이 우리 문장에 없다', () {
      final injury = bundle.byId(kWorkInjury);
      final ours = <String>[
        for (final c in injury.cautions) ...[c.question, c.condition, c.consequence],
        for (final p in injury.procedures) p.label,
        for (final p in injury.procedures) ...[p.whatIsThis, p.detail].nonNulls,
        for (final q in injury.intake) ...[q.text, q.whyAsk],
      ];

      for (final sentence in ours) {
        expect(
          SafetyFilter.scan(sentence, where: kWorkInjury),
          isEmpty,
          reason: '「$sentence」',
        );
      }
    });

    test('★ 「회사」는 물음 머리에만 남는다', () {
      final injury = bundle.byId(kWorkInjury);
      final answersText = <String>[
        for (final c in injury.cautions) ...[c.condition, c.consequence],
        for (final p in injury.procedures) ...[p.whatIsThis, p.detail].nonNulls,
      ];

      // 조문이 쓰는 말은 「사업」·「사업주」다. 우리가 「회사가 해줘야」로
      // 바꿔 쓰면 회사를 거치는 절차인 것처럼 읽힌다.
      for (final sentence in answersText) {
        expect(sentence.contains('회사'), isFalse, reason: '「$sentence」');
      }

      // 다만 사람은 그 말로 묻는다. 물음 머리에는 남긴다.
      expect(
        injury.cautions.where((c) => c.question.contains('회사')),
        hasLength(1),
      );
    });

    test('시효가 셋 — 3년 · 5년 · 멈춤', () {
      final rules = bundle.byId(kWorkInjury).limitationRules;
      expect(rules.map((r) => r.id), [
        'lm_injury_three',
        'lm_injury_five',
        'lm_injury_interrupt',
      ]);
    });

    test('앱 번들에 실려 있다', () {
      expect(AssetDomainSource.bundledDomainIds, contains(kWorkInjury));
    });
  });
}
