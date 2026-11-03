import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/money.dart';
import 'limit_result.dart';

/// 상대가 요구한 금액을 법정 상한과 대조한다.
///
/// 판단하지 않는다. **법이 정한 숫자와 상대가 부른 숫자를 나란히 놓을 뿐이다.**
class LimitChecker {
  const LimitChecker();

  /// 요구 금액이 담긴 기본 입력 필드명.
  static const String requestedField = 'requestedAmount';

  /// 검사할 수 있는 규칙만 돌린다.
  ///
  /// 계산식도 없고 무조건 위법도 아니면 **검사할 것이 없다.** 그런 규칙까지 결과로
  /// 내보내면 화면에 판정 불가가 뜨고, 규칙이 달라고 한 적도 없는 입력 필드가 딸려
  /// 나온다. 안내만 하고 싶은 것은 상한 규칙 자리가 아니라 `cautions` 자리다.
  List<LimitResult> checkAll(Domain domain, CaseFacts facts) => [
        for (final rule in domain.limitRules)
          if (rule.alwaysIllegal || rule.formula != null)
            check(rule, facts.values),
      ];

  LimitResult check(LimitRule rule, Map<String, Object?> inputs) {
    final requested = _asInt(inputs[requestedField]);

    // 입력과 무관하게 위법인 경우가 있다. 계산할 것도 없다.
    if (rule.alwaysIllegal) {
      return _result(
        rule,
        verdict: LimitVerdict.alwaysIllegal,
        legalMax: 0,
        requested: requested,
        excess: requested,
        message: rule.message ?? '법이 허용하지 않는 요구입니다.',
        inputs: _requestedOnly(requested),
      );
    }

    final formula = rule.formula;
    if (formula == null) {
      // 규칙이 달라고 하지 않은 입력을 결과에 달지 않는다. 달면 화면과 리포트에
      // 필드명이 그대로 새어 나온다.
      return _result(
        rule,
        verdict: LimitVerdict.unknown,
        requested: requested,
        message: rule.message ?? '',
        inputs: const {},
      );
    }

    switch (formula) {
      case ThresholdLimitFormula():
        return _checkThreshold(rule, formula, inputs);

      case FixedLimitFormula(:final amount):
        return _compare(
          rule,
          legalMax: amount,
          requested: requested,
          inputs: _requestedOnly(requested),
        );

      case TieredWithCapLimitFormula():
        final variantKey = inputs[formula.variantField]?.toString();
        final amount = transactionAmount(formula, inputs);
        final used = <String, Object?>{
          formula.amountField: ?amount,
          formula.variantField: ?variantKey,
          ..._requestedOnly(requested),
        };

        final legalMax = legalMaxOf(formula, inputs);
        if (legalMax == null) {
          return _result(
            rule,
            verdict: LimitVerdict.unknown,
            requested: requested,
            message: '판단에 필요한 정보가 부족합니다.',
            inputs: used,
          );
        }
        return _compare(
          rule,
          legalMax: legalMax,
          requested: requested,
          inputs: used,
        );
    }
  }

  /// 요구 금액만 담은 입력 기록. 없으면 빈 맵.
  static Map<String, Object?> _requestedOnly(int? requested) =>
      requested == null ? const {} : {requestedField: requested};

  /// 구간표 + 상한으로 법정 최대 금액을 구한다. 입력이 모자라면 null.
  int? legalMaxOf(TieredWithCapLimitFormula formula, Map<String, Object?> inputs) {
    final variantKey = inputs[formula.variantField]?.toString();
    final tiers = variantKey == null ? null : formula.variants[variantKey];
    if (tiers == null || tiers.isEmpty) return null;

    final amount = transactionAmount(formula, inputs);
    if (amount == null) return null;

    for (final tier in tiers) {
      final max = tier.max;
      if (max != null && amount >= max) continue;
      final computed = Money.applyRate(amount, tier.rate);
      final cap = tier.cap;
      return cap != null && computed > cap ? cap : computed;
    }
    return null;
  }

  /// 거래금액. 월세면 환산 보증금으로 바꾼다.
  int? transactionAmount(
    TieredWithCapLimitFormula formula,
    Map<String, Object?> inputs,
  ) {
    final direct = _asInt(inputs[formula.amountField]);
    final conversion = formula.monthlyRentConversion;
    if (conversion == null) return direct;

    final monthlyRent = _asInt(inputs[conversion.monthlyRentField]);
    if (monthlyRent == null || monthlyRent == 0) return direct;

    final deposit = _asInt(inputs[conversion.depositField]) ?? direct ?? 0;
    return convertMonthlyRent(conversion, deposit: deposit, monthlyRent: monthlyRent);
  }

  /// 보증금 + (월차임 × 배수). 합산액이 기준 미만이면 낮은 배수를 쓴다.
  static int convertMonthlyRent(
    MonthlyRentConversion conversion, {
    required int deposit,
    required int monthlyRent,
  }) {
    final primary = deposit + monthlyRent * conversion.multiplier;
    if (primary >= conversion.fallbackThreshold) return primary;
    return deposit + monthlyRent * conversion.fallbackMultiplier;
  }

  LimitResult _checkThreshold(
    LimitRule rule,
    ThresholdLimitFormula formula,
    Map<String, Object?> inputs,
  ) {
    final value = _asNum(inputs[formula.input]);
    if (value == null) {
      return _result(
        rule,
        verdict: LimitVerdict.unknown,
        message: '판단에 필요한 정보가 부족합니다.',
      );
    }

    final used = <String, Object?>{formula.input: value};
    for (final threshold in formula.thresholds) {
      if (value > threshold.over) {
        return _result(
          rule,
          verdict: _verdictFrom(threshold.verdict),
          message: threshold.message,
          inputs: used,
        );
      }
    }
    return _result(
      rule,
      verdict: LimitVerdict.within,
      message: rule.verdicts?['at'] ?? '법정 기준 이내입니다.',
      inputs: used,
    );
  }

  LimitResult _compare(
    LimitRule rule, {
    required int legalMax,
    required int? requested,
    Map<String, Object?> inputs = const {},
  }) {
    if (requested == null) {
      return _result(
        rule,
        verdict: LimitVerdict.unknown,
        legalMax: legalMax,
        message: rule.message ?? '요구받은 금액을 입력하면 법정 상한과 대조해 드립니다.',
        inputs: inputs,
      );
    }
    if (requested > legalMax) {
      return _result(
        rule,
        verdict: LimitVerdict.over,
        legalMax: legalMax,
        requested: requested,
        excess: requested - legalMax,
        message: rule.verdicts?['over'] ?? '법정 상한을 넘습니다.',
        inputs: inputs,
      );
    }
    return _result(
      rule,
      verdict: LimitVerdict.within,
      legalMax: legalMax,
      requested: requested,
      excess: 0,
      message: rule.verdicts?['at'] ?? '법정 상한 이내입니다.',
      inputs: inputs,
    );
  }

  LimitVerdict _verdictFrom(String raw) => switch (raw) {
        'void_all' => LimitVerdict.voidAll,
        'over' => LimitVerdict.over,
        'within' || 'at' => LimitVerdict.within,
        'always_illegal' => LimitVerdict.alwaysIllegal,
        _ => LimitVerdict.unknown,
      };

  LimitResult _result(
    LimitRule rule, {
    required LimitVerdict verdict,
    required String message,
    int? legalMax,
    int? requested,
    int? excess,
    Map<String, Object?> inputs = const {},
  }) =>
      LimitResult(
        ruleId: rule.id,
        label: rule.label,
        verdict: verdict,
        legalMax: legalMax,
        requested: requested,
        excess: excess,
        message: message,
        basis: rule.legalBasis,
        action: rule.action,
        verification: rule.verification.status,
        inputs: Map<String, Object?>.unmodifiable(inputs),
      );

  static int? _asInt(Object? value) => switch (value) {
        final int i => i,
        final num n when n == n.roundToDouble() => n.toInt(),
        final String s => int.tryParse(s.replaceAll(',', '')),
        _ => null,
      };

  static num? _asNum(Object? value) => switch (value) {
        final num n => n,
        final String s => num.tryParse(s),
        _ => null,
      };
}
