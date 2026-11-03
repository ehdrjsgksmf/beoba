import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/limitation_card.dart';
import 'package:beoba/src/widgets/legal_basis_card.dart';
import 'package:domain_data/domain_data.dart'
    show Domain, KeywordHardStopTrigger, LimitationKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/domain_scenarios.dart';
import 'support/test_app.dart';

/// **상속재산 나누기 — 함정 여덟을 잠근다.**
///
/// 이 분야는 옆 분야(「물려받은 빚·재산」)와 갈래가 다르다. 라류 대 마류이고,
/// 창구 기준이 다르고, 상대방이 있고, 조정 전치가 붙는다. **겉이 닮아서
/// 한쪽 규칙을 그대로 옮기면 조용히 틀린다** — 여기 있는 것은 전부 그
/// 「조용히」를 소리 나게 만드는 잠금이다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const id = 'estate_division';
  const answers = <String, Object?>{
    'q_stage': 'stuck',
    'q_heir_count': 3,
    'q_opponent_address': '서울특별시 종로구',
    'q_will_direction': 'none',
    'q_share_transferred': 'no',
    'q_late_heir': 'no',
  };

  Future<ProviderContainer> openResult(WidgetTester tester) async {
    final container = await pumpApp(tester);
    seedAnswers(container, id, answers: answers);
    container.read(routerProvider).go(Routes.result(id));
    await tester.pumpAndSettle();
    return container;
  }

  Future<Domain> load(WidgetTester tester) async {
    final container = await pumpApp(tester);
    return container.read(domainBundleProvider).requireValue.byId(id);
  }

  group('함정 1 — 제999조는 대괄호를 떼고 인용할 수 없다', () {
    testWidgets('조문 원문과 위헌 표시가 한 조각이다', (tester) async {
      final domain = await load(tester);
      final rules = domain.limitationRules
          .where((r) => r.legalBasis.article?.startsWith('제999조') ?? false);
      expect(rules, isNotEmpty);

      for (final rule in rules) {
        final text = rule.legalBasis.text ?? '';
        // 본문만 있고 대괄호가 없으면 「10년이 그대로 살아 있다」로 읽힌다.
        expect(text, contains('10년을 경과하면 소멸된다'),
            reason: '${rule.id} — 조문 본문이 빠졌습니다');
        expect(text, contains('단순위헌'),
            reason: '${rule.id} — 위헌 표시가 조문에서 떨어졌습니다. '
                '본문과 대괄호는 한 조각이어야 합니다');
        expect(text, contains('제1014조에 관한 부분'),
            reason: '${rule.id} — 위헌의 범위가 빠졌습니다. '
                '「10년 전부」로 읽히면 반대로 안내하는 것입니다');
      }
    });

    testWidgets('★ 조문을 펴지 않아도 우리 말로 범위가 보인다', (tester) async {
      // **조문 원문은 기본으로 접힌다.** 대괄호가 legalBasis.text 에만
      // 있으면 「조문 원문 보기」를 누른 사람만 본다. 그래서 note 가
      // 안전장치가 아니라 필수다.
      await openResult(tester);

      final card = find.text(LimitationCard.title);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      // 조문은 접힌 채로 둔다 — 아무것도 안 누른 상태가 기본이다.
      expect(find.text(LegalBasisCard.close), findsNothing,
          reason: '조문이 펴진 채로 시작하면 이 검사가 뜻을 잃습니다');

      expect(
        find.textContaining('10년 전부가 아니라'),
        findsWidgets,
        reason: '접힌 화면에서 위헌의 범위가 안 보입니다. '
            'note 나 label 에 우리 말로 있어야 합니다',
      );
    });

    testWidgets('세 갈래를 나란히 낸다. 어느 하나를 고르지 않는다', (tester) async {
      final container = await openResult(tester);
      final branches = container
          .read(limitationRulesProvider(id))
          .where((r) => r.kind == LimitationKind.branch)
          .map((r) => r.id)
          .toList();
      expect(
        branches,
        containsAll(<String>[
          'lm_recovery_three',
          'lm_recovery_ten',
          'lm_late_heir',
        ]),
      );

      // showIf 로 감추면 우리가 「이 사람이 제1014조다」를 판정하는 것이 된다.
      final late = container
          .read(domainBundleProvider)
          .requireValue
          .byId(id)
          .limitationRules
          .firstWhere((r) => r.id == 'lm_late_heir');
      expect(late.showIf, isNull,
          reason: '뒤늦게 상속인이 된 경우를 조건으로 감추면 우리가 판정하는 것입니다');
    });
  });

  group('함정 2 — 조문이 순서를 말하므로 순서를 낸다', () {
    testWidgets('협의가 먼저이고 그 자리는 법원 밖이다', (tester) async {
      final domain = await load(tester);
      expect(
        domain.procedures
            .map((p) => '${p.id}/${p.stage.name}/${p.step}')
            .toList(),
        [
          'proc_agree/beforeCourt/1',
          'proc_mediation/court/2',
          'proc_trial/court/3',
        ],
      );
    });

    testWidgets('★ 왜 여기서는 순서를 내는지가 데이터에 적혀 있다', (tester) async {
      // 양육비의 제재 셋은 조문이 순서를 말하지 않아 배열 순서로 우선순위를
      // 말하지 않기로 했다. 나란히 놓이면 다음 사람이 헷갈린다.
      final domain = await load(tester);
      expect(domain.note, isNotNull);
      expect(domain.note, contains('조문이 순서를 말하는가'));
    });

    testWidgets('「협의가 안 되면 법원」이 아니라 조문이 협의를 밖에 두었다', (tester) async {
      final domain = await load(tester);
      final card = domain.cautions.firstWhere((c) => c.id == 'ct_talk_first');
      // 가사소송법이 부르는 것은 제1013조 제2항뿐이다. 제1항은 어느 호에도 없다.
      final refs = <String?>[
        card.legalBasis?.article,
        ...card.alsoBasis.map((b) => b.article),
      ];
      expect(refs, contains('제1013조 제1항'));
      expect(refs, contains('제2조 제1항 제2호 나목 10)'));
      expect(refs, contains('제269조 제1항'));
      expect(refs, contains('제50조 제1항'));
    });
  });

  group('함정 3 — 몫을 계산하지 않는다', () {
    testWidgets('기여분에 금액도 계산식도 없다', (tester) async {
      final domain = await load(tester);
      final card = domain.cautions.firstWhere((c) => c.id == 'ct_contribution');
      expect(card.legalBasis?.article, '제1008조의2 제2항');
      expect(card.consequence, contains('계산해 드릴 수 없어요'));

      // 「얼마」를 내는 자리가 기여분에 하나도 없어야 한다.
      expect(
        domain.costs.map((c) => c.id),
        isNot(contains('cost_contribution')),
      );
    });

    testWidgets('분야 머리가 「어디에 어떻게 신청하나」라고 말한다', (tester) async {
      final domain = await load(tester);
      expect(domain.note, contains('「어디에 어떻게 신청하나」 분야다'));
    });

    testWidgets('분할 심판의 인지대는 금액 없이 줄만 낸다', (tester) async {
      final domain = await load(tester);
      final line =
          domain.costs.firstWhere((c) => c.id == 'cost_division_filing_fee');
      expect(line.formula.type, 'unknown',
          reason: '0원으로 적으면 「안 든다」가 됩니다');
      expect(line.verification.openPart, isNotNull);
    });
  });

  group('함정 4 — 관할 기준이 옆 분야와 다르다', () {
    testWidgets('상대방 주소이지 돌아가신 분 주소가 아니다', (tester) async {
      final container = await pumpApp(tester);
      final bundle = container.read(domainBundleProvider).requireValue;
      final here = bundle.byId(id).jurisdiction.single;
      final there = bundle.byId('inheritance').jurisdiction.single;

      expect(here.inputField, 'opponentAddress');
      expect(there.inputField, 'deceasedAddress');
      expect(here.inputField, isNot(there.inputField),
          reason: '두 분야가 같은 묶음에 있어 헷갈리기 쉬운 자리입니다');
    });

    testWidgets('각 분야가 자기 조문을 근거로 든다', (tester) async {
      final container = await pumpApp(tester);
      final bundle = container.read(domainBundleProvider).requireValue;

      final here = bundle
          .byId(id)
          .jurisdictionGuide!
          .basis
          .map((b) => b.article)
          .toList();
      final there = bundle
          .byId('inheritance')
          .jurisdictionGuide!
          .basis
          .map((b) => b.article)
          .toList();

      // 제44조 제1항은 머리에 「라류」라고 못박혀 있어 마류에 안 걸린다.
      expect(here, contains('제46조'));
      expect(here, isNot(contains('제44조 제1항 제6호')));
      expect(there, contains('제44조 제1항 제6호'));
      expect(there, isNot(contains('제46조')));
    });
  });

  group('함정 5 — 상대방이 여럿이면 조문이 안 닫힌다', () {
    testWidgets('우리가 고르지 않고 열어 둔다', (tester) async {
      final domain = await load(tester);
      final card =
          domain.cautions.firstWhere((c) => c.id == 'ct_many_opponents');
      expect(card.verification.openPart, isNotNull);
      expect(card.verification.openPart, contains('관할'));
      // 규칙 제110조와 법 제46조를 같이 낸다. 하나만 내면 안 닫힌 것이 안 보인다.
      final refs = <String?>[
        card.legalBasis?.article,
        ...card.alsoBasis.map((b) => b.article),
      ];
      expect(refs, containsAll(<String>['제110조', '제46조']));
    });
  });

  group('함정 6 — 우리가 못 세는 기한은 Deadline 이 아니다', () {
    testWidgets('법원이 정해 고지하는 기간은 카드로만 낸다', (tester) async {
      final domain = await load(tester);
      expect(domain.deadlines, isEmpty,
          reason: '시작하는 날을 법원이 정하는 기간을 D-day 로 내면 틀립니다');

      final card = domain.cautions.firstWhere((c) => c.id == 'ct_court_period');
      expect(card.legalBasis?.article, '제113조');
      // **243번과 같은 자리인데 이유가 다르다.** 그 구분이 데이터에 남아야
      // 다음 사람이 잘못 적용하지 않는다.
      expect(card.verification.note, contains('DECISIONS 243번'));
      expect(card.verification.note, contains('DECISIONS 248번'));
    });
  });

  group('함정 7 — 언제 돌아가셨느냐로 적용이 갈린다', () {
    testWidgets('적용례를 note 에 적고 왜 (z) 가 아닌지도 적는다', (tester) async {
      final domain = await load(tester);
      final card =
          domain.cautions.firstWhere((c) => c.id == 'ct_special_benefit');
      final note = card.verification.note ?? '';
      expect(note, contains('2024년 4월 25일'));
      expect(note, contains('검사 (z)에 걸지 않는다'));
      // (z) 는 「그날이 지나면 옛 조문이 틀린 것이 된다」를 잡는다.
      expect(note, contains('없어지는 옛 조문이 없고'));
    });
  });

  group('함정 8 — 조정 전치는 옆 분야에 없던 단계다', () {
    testWidgets('제50조와 제51조를 조문 그대로 낸다', (tester) async {
      final container = await pumpApp(tester);
      final bundle = container.read(domainBundleProvider).requireValue;
      final domain = bundle.byId(id);

      final step = domain.procedures.firstWhere((p) => p.id == 'proc_mediation');
      expect(step.legalBasis?.article, '제50조 제1항');
      expect(step.legalBasis?.text, contains('먼저 조정을 신청하여야 한다'));
      expect(step.alsoBasis.map((b) => b.article), contains('제51조 제1항'));

      // 옆 분야(라류)에는 이 단계가 없다.
      final neighbour = bundle.byId('inheritance');
      expect(
        neighbour.procedures.map((p) => p.legalBasis?.article),
        isNot(contains('제50조 제1항')),
      );
    });
  });

  group('막던 것을 열었다', () {
    testWidgets('상속재산분할은 더 이상 막히지 않고 유류분은 그대로 막힌다', (tester) async {
      final container = await pumpApp(tester);
      final crisis = container.read(domainBundleProvider).requireValue.crisis;
      List<String> patternsOf(String id) =>
          (crisis.hardStops.firstWhere((h) => h.id == id).trigger
                  as KeywordHardStopTrigger)
              .patterns;

      final family = patternsOf('hs_family');
      expect(family, isNot(contains('상속재산분할')));
      expect(family, isNot(contains('상속 분쟁')));
      expect(family, isNot(contains('유류분')),
          reason: '유류분은 따로 세웠습니다. 옆길 문구가 이혼 쪽에는 거짓입니다');
      // 이혼 계열은 계속 막는다 — 아직 안 여는 것이다.
      expect(family, contains('양육권'));

      // 유류분도 계속 막는다. 다만 자기 화면에서 막는다.
      expect(patternsOf('hs_inheritance_share'), contains('유류분'));
    });

    testWidgets('★ 막는 문구가 능력이 아니라 준비 상태를 말한다', (tester) async {
      // 「안내해 드릴 수 없어요」는 영영 안 된다로 읽힌다. 제목이
      // 「아직」이라고 말하는데 본문이 그걸 되돌리고 있었다.
      final container = await pumpApp(tester);
      final crisis = container.read(domainBundleProvider).requireValue.crisis;

      for (final id in ['hs_family', 'hs_inheritance_share']) {
        final stop = crisis.hardStops.firstWhere((h) => h.id == id);
        expect(stop.message, isNotNull,
            reason: '$id — 본문이 없으면 공통 기본값이 나갑니다');
        expect(stop.message, contains('아직 준비하지 못했어요'));
        // **왜인지는 적는다.** 우리가 실제로 아는 이유다.
        expect(stop.message, contains('법이 정한 절차'));
        // **언제쯤인지는 적지 않는다.** 그건 약속이 된다.
        expect(stop.message, isNot(contains('예정')));
        expect(stop.message, isNot(contains('곧')));
      }
    });

    testWidgets('★ 옆길은 유류분 쪽에만 있고, 대신 하라고 말하지 않는다',
        (tester) async {
      final container = await pumpApp(tester);
      final crisis = container.read(domainBundleProvider).requireValue.crisis;
      final share =
          crisis.hardStops.firstWhere((h) => h.id == 'hs_inheritance_share');
      final family = crisis.hardStops.firstWhere((h) => h.id == 'hs_family');

      expect(share.message, contains('상속재산 나누기'));
      // **「같은 일은 아니에요」가 안전장치다.** 이 줄이 없으면 「유류분 대신
      // 이걸 하세요」로 읽히고, 그건 우리가 판단한 것이 된다.
      expect(share.message, contains('같은 일은 아니에요'));

      // 이혼·양육권으로 온 사람에게 상속 이야기는 참이 아니다.
      expect(family.message, isNot(contains('상속')));
    });
  });

  group('유류분으로 새어 나가지 않는다', () {
    // **지금은 안 엽니다.** 그런데 상속재산 분할과 주제가 붙어 있어서
    // 우리 문장이 한 번만 흘려도 사람이 「여기서 되는구나」로 읽는다.
    // 그러면 하드스톱이 뒤에서 막아도 이미 기대를 만든 뒤다.
    testWidgets('★ 데이터 어디에도 「유류분」이 없다 — 조문 원문까지 본다',
        (tester) async {
      final container = await pumpApp(tester);
      // **로더가 실은 값 그대로 본다.** 자산 파일을 다시 읽지 않는다 —
      // 위젯 테스트에서 rootBundle 을 직접 부르면 멈춘다.
      final json =
          container.read(domainBundleProvider).requireValue.byId(id).toJson();

      // `detect` 는 화면에 안 나가는 기계 장치다. exceptPatterns 가 바로
      // **유류분을 이 분야로 안 끌어오려고** 적어 둔 것이라 여기서 뺀다.
      json.remove('detect');

      final hits = <String>[];
      void walk(Object? node, String where) {
        if (node is String) {
          if (node.contains('유류분')) hits.add(where);
        } else if (node is List) {
          for (final (i, v) in node.indexed) {
            walk(v, '$where[$i]');
          }
        } else if (node is Map<String, dynamic>) {
          for (final e in node.entries) {
            walk(e.value, '$where.${e.key}');
          }
        }
      }

      walk(json, 'estate_division');
      expect(
        hits,
        isEmpty,
        reason: '유류분은 아직 안 여는 것입니다. 조문 원문에서 걸렸다면 '
            '여는 덩어리가 유류분에 닿았다는 뜻이니 멈추고 다시 정하세요: '
            '${hits.join(', ')}',
      );
    });

    testWidgets('물어보면 여전히 멈춰 세운다', (tester) async {
      final container = await pumpApp(tester);
      final crisis = container.read(domainBundleProvider).requireValue.crisis;
      final stop =
          crisis.hardStops.firstWhere((h) => h.id == 'hs_inheritance_share');
      final trigger = stop.trigger as KeywordHardStopTrigger;
      expect(trigger.patterns, contains('유류분'));
    });
  });

  group('갈래 표에 실려 있다', () {
    test('화면 검사가 이 분야를 돈다', () {
      expect(
        screenScenarios.values.map((s) => s.$1),
        contains(id),
        reason: '표에 없으면 밀도·가로 넘침·쉬운 말 셋이 이 분야를 안 봅니다',
      );
    });
  });
}
