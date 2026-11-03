import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/engine.dart';
import '../core/json_logic.dart';
import '../core/money.dart';
import 'cost_result.dart';

/// 비용 계산. 금액은 전부 `int` (원 단위).
///
/// 계산 순서가 고정돼 있다:
/// 1. tier 선택 — `amount < tier.max` (**미만**). 소가 1억원은 세 번째 구간이다
/// 2. 계산식의 `rounding` 을 **여기서 1회만** 적용
/// 3. modifier 를 **정의된 배열 순서대로** 곱한다.
///    곱한 뒤 그 modifier 에 `rounding` 이 있으면 그때만 다시 끝수를 처리한다
///
/// 3의 단서가 중요하다. 끝수 처리는 **조문이 준용하라고 적어 둔 자리에서만** 한다.
/// 인지법 제7조 제4항은 준용한다고 적혀 있고 제16조에는 그런 말이 없다.
class CostEngine implements Engine<CostResult> {
  const CostEngine();

  @override
  CostResult compute(Domain domain, CaseFacts facts) {
    final data = facts.toJsonLogicData();
    final lines = <CostLine>[];

    for (final item in domain.costs) {
      if (!JsonLogic.test(item.showIf, data)) continue;
      final line = computeOne(item, facts);
      if (line != null) lines.add(line);
    }

    final total = lines.fold<int>(0, (sum, line) => sum + line.amount);
    return CostResult(lines: lines, total: total);
  }

  /// 갈래마다 한 벌씩. 사용자가 아직 안 정한 것을 묻지 않고 나란히 낸다.
  ///
  /// 사용자가 이미 답한 필드와 **어긋나는** 시나리오는 버린다. 나중에 그걸 묻는
  /// 질문이 생기면 답이 이기고 갈래가 저절로 하나로 줄어든다.
  ///
  /// 시나리오가 없는 분야는 예전대로 한 벌만 나온다.
  List<ScenarioCostResult> computeScenarios(Domain domain, CaseFacts facts) {
    // **셀 비용 항목이 아예 없으면 갈래도 없다.** 빈 갈래 하나를 돌려주면
    // 화면이 「금액을 계산할 만한 정보가 아직 없어요」를 내는데, 그 분야에는
    // 영영 안 채워진다 — 빈 칸은 0으로 읽힌다(DECISIONS 125번).
    if (domain.costs.isEmpty) return const [];

    if (domain.costScenarios.isEmpty) {
      return [
        ScenarioCostResult(
          id: '',
          label: '',
          assumed: const {},
          result: compute(domain, facts),
        ),
      ];
    }

    final results = <ScenarioCostResult>[];
    for (final scenario in domain.costScenarios) {
      if (_contradicts(scenario, facts)) continue;
      // 아예 밟을 수 없는 갈래는 금액도 내지 않는다.
      final only = scenario.showIf;
      if (only != null && !JsonLogic.test(only, facts.toJsonLogicData())) {
        continue;
      }
      results.add(
        ScenarioCostResult(
          id: scenario.id,
          label: scenario.label,
          whatIsThis: scenario.whatIsThis,
          option: scenario.option,
          assumed: Map<String, Object?>.unmodifiable(scenario.facts),
          // 사용자가 답한 값이 이긴다. 가정은 빈 칸만 메운다.
          result: compute(domain, facts.merge(scenario.facts)),
        ),
      );
    }
    return List<ScenarioCostResult>.unmodifiable(results);
  }

  /// 사용자가 이미 다르게 답한 갈래인가.
  static bool _contradicts(CostScenario scenario, CaseFacts facts) {
    for (final entry in scenario.facts.entries) {
      final answered = facts.values[entry.key];
      if (answered != null && answered != entry.value) return true;
    }
    return false;
  }

  /// 비용 항목 하나. 계산에 필요한 입력이 없으면 null.
  ///
  /// **밟은 단계를 그대로 남긴다.** 화면이 숫자를 다시 만들면 두 곳이 갈라지고,
  /// 갈라지면 어느 쪽이 맞는지 아무도 모른다.
  CostLine? computeOne(CostItem item, CaseFacts facts) {
    final steps = _baseSteps(item.formula, facts);
    if (steps == null) return null;

    final data = facts.toJsonLogicData();
    var amount = steps.base;
    final applied = <String>[];
    final modifiers = <AppliedModifier>[];

    for (final modifier in item.modifiers) {
      if (!JsonLogic.test(modifier.condition, data)) continue;
      final multiplied = Money.applyMultiplier(amount, modifier.multiply);
      // 준용 규정이 있는 자리에만 끝수를 처리한다. 없으면 곱한 값 그대로 간다.
      amount = applyRounding(multiplied, modifier.rounding);
      applied.add(modifier.id);
      modifiers.add(
        AppliedModifier(
          id: modifier.id,
          // 말은 데이터에서 온다. 코드가 배수를 설명하지 않는다.
          label: modifier.label,
          multiply: modifier.multiply,
          beforeRounding: multiplied,
          rounding: modifier.rounding,
          basis: modifier.legalBasis,
          amount: amount,
        ),
      );
    }

    return CostLine(
      id: item.id,
      label: item.label,
      whatIsThis: item.whatIsThis,
      amount: amount,
      amountKnown: item.formula is! UnknownCostFormula,
      guidanceFloor: guidanceFloorOf(item.formula),
      appliedModifiers: applied,
      basis: item.legalBasis,
      alsoBasis: item.alsoBasis,
      verification: item.verification.status,
      openPart: item.verification.openPart,
      breakdown: CostBreakdown(
        base: steps.base,
        amount: amount,
        input: steps.input,
        tier: steps.tier,
        tierFloor: steps.tierFloor,
        rated: steps.rated,
        rounding: steps.rounding,
        beforeRounding: steps.beforeRounding,
        unitPrice: steps.unitPrice,
        units: steps.units,
        modifiers: modifiers,
      ),
    );
  }

  /// modifier 적용 전까지 밟은 단계.
  _BaseSteps? _baseSteps(CostFormula formula, CaseFacts facts) {
    switch (formula) {
      // 금액을 모르는 줄. 계산할 것이 없고 0 으로 남는다.
      case UnknownCostFormula():
        return const _BaseSteps(base: 0);
      case FixedCostFormula(:final amount):
        return _BaseSteps(base: amount);

      case TieredCostFormula(:final input, :final tiers, :final rounding):
        final value = facts.money(input);
        if (value == null) return null;
        final tier = selectTier(tiers, value);
        if (tier == null) return null;
        final rated = Money.applyRate(value, tier.rate);
        final raw = rated + tier.add;
        return _BaseSteps(
          base: applyRounding(raw, rounding),
          input: value,
          tier: tier,
          tierFloor: _floorOf(tiers, tier),
          rated: rated,
          rounding: rounding,
          beforeRounding: raw,
        );

      case PerUnitCostFormula(:final unitPrice, :final unitsFormula):
        final units = _units(unitsFormula, facts);
        if (units == null) return null;
        return _BaseSteps(
          base: Money.perUnit(unitPrice, units),
          unitPrice: unitPrice,
          units: units,
        );
    }
  }

  /// 끝수 처리. **택일이다.** 최저액 미만이면 올리고, 아니면 버린다.
  ///
  /// 인지법 제2조 제2항이 한 문장으로 둘을 함께 말한다 — 「1천원 미만이면 1천원으로
  /// 하고, 1천원 이상이면 100원 미만은 계산하지 아니한다」. 버림만 하면 소액에서
  /// 인지액이 1천원 아래로 내려간다.
  static int applyRounding(int amount, CostRounding? rounding) {
    if (rounding == null) return amount;
    final minimum = rounding.minimum;
    if (minimum != null && amount < minimum) return minimum;
    return Money.roundDown(amount, rounding.roundDown);
  }

  /// **안내할 때 이 아래로는 내려가지 않는다.** 조문 해석이 아니라 안전 여유다.
  ///
  /// 두 층을 섞지 않으려고 계산과 따로 둔다. `CostLine.amount` 는 조문대로의 값이고
  /// (제16조 뒤에는 준용이 없으니 900원이 맞다), `guidedAmount` 는 화면에 낼 값이다.
  /// 섞으면 나중에 어느 쪽이 조문이었는지 알 수 없게 된다.
  ///
  /// 틀리는 방향이 비대칭이라 이렇게 한다 — 900원으로 안내했는데 법원이 1,000원을
  /// 요구하면 **보정 명령**이 오고, 1,000원으로 안내했는데 실제가 900원이면
  /// 100원을 더 낼 뿐이다. 어림 날짜에서 가장 이른 날을 잡은 것과 같다.
  ///
  /// 값은 데이터에서 온다. 최저액을 코드에 적지 않는다.
  static int? guidanceFloorOf(CostFormula formula) => switch (formula) {
        TieredCostFormula(:final rounding) => rounding?.minimum,
        _ => null,
      };

  /// 고른 구간의 아래쪽 경계. 앞 구간의 `max` 이고, 첫 구간이면 0 이다.
  static int _floorOf(List<CostTier> tiers, CostTier selected) {
    var floor = 0;
    for (final tier in tiers) {
      if (identical(tier, selected)) return floor;
      floor = tier.max ?? floor;
    }
    return 0;
  }

  /// `amount < tier.max` 인 **첫** 구간. `max: null` 은 무한 구간.
  ///
  /// ⚠️ 소가 정확히 1억원이면 `100000000 < 100000000` 이 거짓이므로
  /// 두 번째 구간을 건너뛰고 **세 번째 구간**이 선택된다.
  static CostTier? selectTier(List<CostTier> tiers, int amount) {
    for (final tier in tiers) {
      final max = tier.max;
      if (max == null || amount < max) return tier;
    }
    return null;
  }

  int? _units(UnitsFormula formula, CaseFacts facts) {
    // **조건 규칙이 먼저다.** 절차를 묻지 않는 분야가 있다 — 상속은 한정승인
    // 이든 포기든 기간연장이든 라류 1건당 값이 같아서 갈래를 묻지 않는다.
    // 그런데 절차부터 읽고 없으면 돌려보내면, 조건 규칙이 있어도 못 센다.
    final rounds = _rounds(formula, facts.text(formula.procedureField), facts);
    if (rounds == null) return null;

    final partiesField = formula.partiesField;
    final parties = partiesField == null
        ? formula.parties
        : facts.get<int>(partiesField) ?? formula.parties;
    // 예규가 「10회 + 채권자수 × 8회」로 적어 둔 자리. 앞의 10회는
    // 사람 수와 무관하게 붙는다.
    return formula.baseRounds + parties * rounds;
  }

  /// 몇 회인가. **조건 규칙이 절차표를 이긴다. 먼저 맞는 것이 이긴다.**
  ///
  /// 소액사건은 사용자가 고르는 갈래가 아니라 소가로 정해진다. 절차는 그대로
  /// 소송인데 회수만 15회에서 10회로 내려간다.
  int? _rounds(UnitsFormula formula, String? procedure, CaseFacts facts) {
    final data = facts.toJsonLogicData();
    for (final rule in formula.roundsWhen) {
      if (JsonLogic.test(rule.showIf, data)) return rule.rounds;
    }
    if (procedure != null) {
      final byProcedure = formula.roundsByProcedure[procedure];
      if (byProcedure != null) return byProcedure;
    }
    return formula.defaultRounds > 0 ? formula.defaultRounds : null;
  }
}

/// `_baseSteps` 가 돌려주는 중간 결과. 이 파일 밖으로 나가지 않는다.
class _BaseSteps {
  const _BaseSteps({
    required this.base,
    this.input,
    this.tier,
    this.tierFloor,
    this.rated,
    this.rounding,
    this.beforeRounding,
    this.unitPrice,
    this.units,
  });

  final int base;
  final int? input;
  final CostTier? tier;
  final int? tierFloor;
  final int? rated;
  final CostRounding? rounding;
  final int? beforeRounding;
  final int? unitPrice;
  final int? units;
}
