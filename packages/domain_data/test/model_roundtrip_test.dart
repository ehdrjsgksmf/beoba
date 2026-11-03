import 'dart:convert';

import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

import 'support/domain_assets.dart';

/// 모델이 JSON 을 **잃지 않고** 표현하는지 본다.
///
/// `fromJson → toJson → fromJson → toJson` 이 같은 결과를 내면
/// 필드를 빠뜨리거나 컨버터가 값을 뭉개지 않았다는 뜻이다.
void main() {
  group('모델 왕복', () {
    for (final file in domainAssetFiles()) {
      final domainId = domainIdOf(file);

      test('$domainId — 왕복해도 값이 그대로다', () {
        final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

        final once = Domain.fromJson(raw).toJson();
        final twice = Domain.fromJson(once).toJson();

        expect(jsonEncode(twice), jsonEncode(once));
      });
    }

    test('debt_recovery — 원본의 값이 실제로 실려 있다', () {
      final raw =
          jsonDecode(readDomainJson('debt_recovery')) as Map<String, dynamic>;
      final domain = Domain.fromJson(raw);

      expect(domain.id, 'debt_recovery');
      expect(domain.version, '1.0.0');
      expect(domain.lastVerifiedAt, const KstDate(2026, 8, 15));
      expect(domain.scoring?.greenThreshold, 14);
      // 「상대방은 어떤 사람인가요」가 사라져 열둘이다. 시효 갈래를 가르려고
      // 두었던 질문인데 갈래를 나란히 내면서 읽는 곳이 없어졌다
      // (DECISIONS 107번).
      expect(domain.intake, hasLength(18));
      expect(domain.intake.first.whyAsk, isNotEmpty);
      expect(domain.intake.first.id, 'q_role', reason: '역할 확인이 먼저다');
      expect(
        domain.questionById('q_claim_type')!.options.first.value,
        'loan',
      );
      expect(
        domain.questionById('q_court_document')!.options.last.setsField,
        isNotNull,
      );
      // 소멸시효가 기한 카드에서 빠져 둘이다(DECISIONS 107번).
      expect(domain.deadlines, hasLength(3));
      expect(domain.deadlines.first.tests, isNotEmpty);
      // 대신 갈래로 나란히 낸다. **어느 분야에나 걸리는 것은 `_shared_crisis`
      // 로 옮겼다** — 기산점·멈추는 일·내용증명 6개월·판결 10년·미리 포기
      // 못 함. 여기 남은 여섯은 이 분야의 연수 갈래다(DECISIONS 167번).
      expect(domain.limitationRules, hasLength(6));
      expect(
        domain.limitationRules.where((r) => r.kind == LimitationKind.branch),
        hasLength(4),
      );
      expect(domain.costs, hasLength(2));
      // 앞쪽 계단(공정증서·민사조정·제소전화해)이 붙어 아홉이 됐다.
      expect(domain.procedures, hasLength(9));
      // **사다리의 앞쪽이 비어 있으면 소송 안내서가 된다.** 법원 전에 할 수
      // 있는 칸이 하나라도 남아 있는지 본다.
      expect(
        domain.procedures.where((p) => p.stage == ProcedureStage.beforeCourt),
        hasLength(3),
      );
    });

    test('인지대 계산식이 구간까지 그대로 읽힌다', () {
      final domain = Domain.fromJson(
        jsonDecode(readDomainJson('debt_recovery')) as Map<String, dynamic>,
      );
      final formula = domain.costById('cost_stamp_fee')!.formula;

      expect(formula, isA<TieredCostFormula>());
      final tiered = formula as TieredCostFormula;
      expect(tiered.input, 'claimAmount');
      expect(tiered.rounding!.roundDown, 100);
      expect(tiered.rounding!.minimum, 1000, reason: '인지법 제2조 제2항 — 1천원 미만은 1천원');
      expect(tiered.tiers, hasLength(4));
      expect(tiered.tiers[2].max, 1000000000);
      expect(tiered.tiers.last.max, isNull, reason: '마지막은 무한 구간이다');
    });

    test('송달료 계산식이 perUnit 으로 읽힌다', () {
      final domain = Domain.fromJson(
        jsonDecode(readDomainJson('debt_recovery')) as Map<String, dynamic>,
      );
      final formula = domain.costById('cost_service_fee')!.formula;

      expect(formula, isA<PerUnitCostFormula>());
      final perUnit = formula as PerUnitCostFormula;
      expect(perUnit.unitPrice, 5500);
      expect(perUnit.unitsFormula.parties, 2);
      expect(perUnit.unitsFormula.roundsByProcedure['lawsuit'], 15);
    });

    test('_shared_crisis — 상한 계산식 3종이 모두 읽힌다', () {
      final shared = Domain.fromJson(
        jsonDecode(readDomainJson('_shared_crisis')) as Map<String, dynamic>,
      );

      final byId = {for (final rule in shared.limitRules) rule.id: rule};
      expect(byId['lr_loan_broker_fee']!.alwaysIllegal, isTrue);
      expect(byId['lr_loan_broker_fee']!.formula, isNull);
      // 임계표(ThresholdLimitFormula)를 쓰는 규칙은 지금 데이터에 없다.
      // 이자 상한이 유일했는데 시행령 숫자가 없어 내렸다 (DECISIONS 73번).
      // 모델 자체의 왕복은 limit_formula_test.dart 가 본다.
      expect(byId['lr_brokerage_fee']!.formula, isA<TieredWithCapLimitFormula>());
      expect(byId['lr_ccrs_fee']!.formula, isA<FixedLimitFormula>());

      final brokerage =
          byId['lr_brokerage_fee']!.formula! as TieredWithCapLimitFormula;
      expect(brokerage.variants.keys, containsAll(['lease', 'sale']));
      expect(brokerage.variants['lease'], hasLength(6));
      expect(brokerage.monthlyRentConversion?.multiplier, 100);
      expect(brokerage.monthlyRentConversion?.fallbackMultiplier, 70);
    });

    test('_shared_crisis — inputs 는 필드명 + 한글 라벨 객체다', () {
      final shared = Domain.fromJson(
        jsonDecode(readDomainJson('_shared_crisis')) as Map<String, dynamic>,
      );

      final byId = {for (final rule in shared.limitRules) rule.id: rule};

      // 4개 규칙 모두 라벨을 가진다. 라벨 없는 입력은 화면에서 필드명이 새어 나온다.
      for (final rule in shared.limitRules) {
        expect(rule.inputs, isNotEmpty, reason: '${rule.id} 에 inputs 가 없습니다');
        for (final input in rule.inputs) {
          expect(input.field, isNotEmpty);
          expect(input.label, isNotEmpty);
        }
      }

      final brokerage = byId['lr_brokerage_fee']!.inputs;
      expect(
        brokerage.map((i) => i.field),
        ['transactionAmount', 'dealType', 'requestedAmount'],
      );
      expect(brokerage.map((i) => i.label), ['거래금액', '거래 유형', '요구받은 금액']);
    });

    test('LimitInput 은 JSON 왕복을 견딘다', () {
      const input = LimitInput(field: 'transactionAmount', label: '거래금액');
      expect(LimitInput.fromJson(input.toJson()), input);
    });

    test('_shared_crisis — 하드스톱은 전부 키워드다', () {
      final shared = Domain.fromJson(
        jsonDecode(readDomainJson('_shared_crisis')) as Map<String, dynamic>,
      );

      // **필드 트리거를 쓰는 하드스톱이 하나도 없다.** 유일했던
      // hs_court_document 가 내려갔기 때문이다 — 막았던 상황에 우리가 셀 수
      // 있는 기한이 있었다(DECISIONS 121번). 지금 남은 둘은 형사·가사로,
      // 정말 해 줄 것이 하나도 없는 자리다.
      expect(shared.hardStops, isNotEmpty);
      for (final stop in shared.hardStops) {
        expect(
          stop.trigger,
          isA<KeywordHardStopTrigger>(),
          reason: '${stop.id} — 필드 트리거라면 「해 줄 게 하나도 없는가」를 '
              '다시 보세요',
        );
      }
    });

    test('FieldHardStopTrigger 는 그대로 읽힌다 — 쓰는 데이터가 없을 뿐', () {
      // 모델을 지우지 않는다. 「본인이 형사처벌 대상」처럼 답 하나로 확정되는
      // 자리가 다시 나오면 그때 쓴다.
      final stop = HardStop.fromJson(const {
        'id': 'hs_probe',
        'screen': 'hardstop_probe',
        'trigger': {'type': 'field', 'field': 'hasCourtDocument', 'equals': true},
        'checklist': ['하나', '둘'],
      });

      final field = stop.trigger as FieldHardStopTrigger;
      expect(field.field, 'hasCourtDocument');
      expect(field.equalsValue, true);
      expect(stop.checklist, hasLength(2));
    });

    test('debt_recovery — 법원 서류 안내가 체크리스트를 물려받았다', () {
      final domain = Domain.fromJson(
        jsonDecode(readDomainJson('debt_recovery')) as Map<String, dynamic>,
      );
      final caution =
          domain.cautions.firstWhere((c) => c.id == 'ct_court_document');

      expect(caution.display, AlertDisplay.stop);
      expect(caution.checklist, hasLength(5));
      expect(caution.channels, contains('crisis_debt'));
    });

    test('용어집 — 갈래에 따라 조문이 있고 없다', () {
      final glossary = Glossary.fromJson(
        jsonDecode(readGlossaryJson()) as Map<String, dynamic>,
      );

      expect(glossary.terms, isNotEmpty);
      for (final entry in glossary.terms) {
        if (entry.kind.hasStatute) {
          // 🟢 는 조문 원문을 싣는다. 원문이 없으면 🟢 가 아니다.
          expect(entry.lawRef?.text, isNotEmpty, reason: entry.term);
        } else {
          // **🟡 에 근거 배지를 붙이면 안 된다.** 우리 말에 조문 이름을 달면
          // 법이 그렇게 정했다는 뜻이 된다.
          expect(entry.lawRef, isNull, reason: entry.term);
        }
      }
      expect(glossary.byTerm('지급명령')?.kind, GlossaryKind.statute);
      expect(glossary.byTerm('각하')?.kind, GlossaryKind.ourWords);
      expect(glossary.byTerm('없는말'), isNull);
    });

    test('알 수 없는 type 은 조용히 넘기지 않는다', () {
      expect(
        () => CostFormula.fromJson(const {'type': '새로운방식'}),
        throwsFormatException,
      );
      expect(
        () => LimitFormula.fromJson(const {'type': '새로운방식'}),
        throwsFormatException,
      );
      expect(
        () => HardStopTrigger.fromJson(const {'type': '새로운방식'}),
        throwsFormatException,
      );
    });
  });
}
