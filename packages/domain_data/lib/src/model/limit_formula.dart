import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'limit_formula.freezed.dart';
part 'limit_formula.g.dart';

/// 법정 상한 계산식 3종.
sealed class LimitFormula {
  const LimitFormula();

  factory LimitFormula.fromJson(JsonMap json) {
    final type = json['type'];
    return switch (type) {
      'tiered_with_cap' => TieredWithCapLimitFormula.fromJson(json),
      'threshold' => ThresholdLimitFormula.fromJson(json),
      'fixed' => FixedLimitFormula.fromJson(json),
      _ => throw FormatException('알 수 없는 상한 계산식 type: $type'),
    };
  }

  String get type;

  JsonMap toJson();
}

/// 거래유형(`variants` 키)별 구간표 + 구간별 상한.
class TieredWithCapLimitFormula extends LimitFormula {
  const TieredWithCapLimitFormula({
    this.variants = const {},
    this.variantField = 'dealType',
    this.amountField = 'transactionAmount',
    this.monthlyRentConversion,
  });

  factory TieredWithCapLimitFormula.fromJson(JsonMap json) {
    final rawVariants = json['variants'] as Map<dynamic, dynamic>? ?? const {};
    final conversion = json['monthlyRentConversion'];
    return TieredWithCapLimitFormula(
      // 구간표는 로드 후 절대 바뀌지 않는다. 잠가 둔다 (DECISIONS.md 1번)
      variants: Map<String, List<LimitTier>>.unmodifiable(
        rawVariants.map(
          (key, value) => MapEntry(
            key as String,
            List<LimitTier>.unmodifiable(
              (value as List<dynamic>).map(
                (t) => LimitTier.fromJson(Map<String, dynamic>.from(t as Map)),
              ),
            ),
          ),
        ),
      ),
      variantField: json['variantField'] as String? ?? 'dealType',
      amountField: json['amountField'] as String? ?? 'transactionAmount',
      monthlyRentConversion: conversion is Map
          ? MonthlyRentConversion.fromJson(Map<String, dynamic>.from(conversion))
          : null,
    );
  }

  /// 거래유형 → 구간표. 예: `lease`, `sale`
  final Map<String, List<LimitTier>> variants;

  /// 거래유형이 담긴 입력 필드명.
  final String variantField;

  /// 거래금액이 담긴 입력 필드명.
  final String amountField;
  final MonthlyRentConversion? monthlyRentConversion;

  @override
  String get type => 'tiered_with_cap';

  @override
  JsonMap toJson() => {
        'type': type,
        'variants': variants.map(
          (key, value) => MapEntry(key, value.map((t) => t.toJson()).toList()),
        ),
        'variantField': variantField,
        'amountField': amountField,
        if (monthlyRentConversion != null)
          'monthlyRentConversion': monthlyRentConversion!.toJson(),
      };
}

/// 값이 임계치를 넘는지 본다. 예: 법정 최고금리.
class ThresholdLimitFormula extends LimitFormula {
  const ThresholdLimitFormula({
    required this.input,
    this.thresholds = const [],
  });

  factory ThresholdLimitFormula.fromJson(JsonMap json) => ThresholdLimitFormula(
        input: json['input'] as String,
        thresholds: List<ThresholdRule>.unmodifiable(
          (json['thresholds'] as List<dynamic>? ?? const []).map(
            (t) => ThresholdRule.fromJson(Map<String, dynamic>.from(t as Map)),
          ),
        ),
      );

  final String input;

  /// **정의된 순서대로** 검사한다. 큰 임계치를 앞에 둔다.
  final List<ThresholdRule> thresholds;

  @override
  String get type => 'threshold';

  @override
  JsonMap toJson() => {
        'type': type,
        'input': input,
        'thresholds': thresholds.map((t) => t.toJson()).toList(),
      };
}

class FixedLimitFormula extends LimitFormula {
  const FixedLimitFormula({required this.amount});

  factory FixedLimitFormula.fromJson(JsonMap json) =>
      FixedLimitFormula(amount: (json['amount'] as num).toInt());

  final int amount;

  @override
  String get type => 'fixed';

  @override
  JsonMap toJson() => {'type': type, 'amount': amount};
}

class LimitFormulaConverter implements JsonConverter<LimitFormula?, JsonMap?> {
  const LimitFormulaConverter();

  @override
  LimitFormula? fromJson(JsonMap? json) =>
      json == null ? null : LimitFormula.fromJson(json);

  @override
  JsonMap? toJson(LimitFormula? object) => object?.toJson();
}

/// `cap: null` = 상한 없음. `max: null` = 무한 구간.
@freezed
abstract class LimitTier with _$LimitTier {
  const factory LimitTier({
    int? max,
    required double rate,
    int? cap,
  }) = _LimitTier;

  factory LimitTier.fromJson(JsonMap json) => _$LimitTierFromJson(json);
}

/// 월세를 환산 보증금으로 바꾸는 규칙.
///
/// 보증금 + (월차임 × [multiplier]). 합산액이 [fallbackThreshold] 미만이면
/// 보증금 + (월차임 × [fallbackMultiplier]).
@freezed
abstract class MonthlyRentConversion with _$MonthlyRentConversion {
  const factory MonthlyRentConversion({
    @Default(100) int multiplier,
    @Default(70) int fallbackMultiplier,
    @Default(0) int fallbackThreshold,
    String? note,
    @Default('deposit') String depositField,
    @Default('monthlyRent') String monthlyRentField,
  }) = _MonthlyRentConversion;

  factory MonthlyRentConversion.fromJson(JsonMap json) =>
      _$MonthlyRentConversionFromJson(json);
}

/// `{ "over": 0.20, "verdict": "over", "message": "..." }`
@freezed
abstract class ThresholdRule with _$ThresholdRule {
  const factory ThresholdRule({
    required double over,
    required String verdict,
    @Default('') String message,
  }) = _ThresholdRule;

  factory ThresholdRule.fromJson(JsonMap json) => _$ThresholdRuleFromJson(json);
}
