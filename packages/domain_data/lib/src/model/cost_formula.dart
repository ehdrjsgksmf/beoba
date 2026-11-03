import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'cost_formula.freezed.dart';
part 'cost_formula.g.dart';

/// 비용 계산식 4종. 넷째는 **금액을 모른다는 것**이다.
///
/// freezed 유니온 대신 직접 쓴다 — `type` 판별자 값이 스키마에 그대로 노출되므로
/// 생성기 버전에 맡기지 않는다.
sealed class CostFormula {
  const CostFormula();

  factory CostFormula.fromJson(JsonMap json) {
    final type = json['type'];
    return switch (type) {
      'tiered' => TieredCostFormula.fromJson(json),
      'fixed' => FixedCostFormula.fromJson(json),
      'perUnit' => PerUnitCostFormula.fromJson(json),
      'unknown' => const UnknownCostFormula(),
      _ => throw FormatException('알 수 없는 비용 계산식 type: $type'),
    };
  }

  String get type;

  JsonMap toJson();
}

/// 구간별 요율. `amount < tier.max` (**미만**) 인 첫 구간을 쓴다.
///
/// ⚠️ 소가 정확히 1억원은 세 번째 구간이다. 두 번째가 아니다.
class TieredCostFormula extends CostFormula {
  const TieredCostFormula({
    required this.input,
    required this.tiers,
    this.rounding,
  });

  factory TieredCostFormula.fromJson(JsonMap json) => TieredCostFormula(
        input: json['input'] as String,
        // 구간표는 로드 후 절대 바뀌지 않는다. 잠가 둔다 (DECISIONS.md 1번)
        tiers: List<CostTier>.unmodifiable(
          (json['tiers'] as List<dynamic>)
              .map((t) => CostTier.fromJson(Map<String, dynamic>.from(t as Map))),
        ),
        rounding: json['rounding'] == null
            ? null
            : CostRounding.fromJson(
                Map<String, dynamic>.from(json['rounding'] as Map),
              ),
      );

  /// 계산 입력이 담긴 `CaseFacts` 필드명.
  final String input;
  final List<CostTier> tiers;

  /// tier 계산 **직후 1회만** 적용.
  final CostRounding? rounding;

  @override
  String get type => 'tiered';

  @override
  JsonMap toJson() => {
        'type': type,
        'input': input,
        'tiers': tiers.map((t) => t.toJson()).toList(),
        if (rounding != null) 'rounding': rounding!.toJson(),
      };
}

class FixedCostFormula extends CostFormula {
  const FixedCostFormula({required this.amount});

  factory FixedCostFormula.fromJson(JsonMap json) =>
      FixedCostFormula(amount: (json['amount'] as num).toInt());

  final int amount;

  @override
  String get type => 'fixed';

  @override
  JsonMap toJson() => {'type': type, 'amount': amount};
}

/// **금액을 모르는 항목.** 조문이 이 항목을 예납·비용으로 못박았는데
/// 금액표를 우리가 못 가진 자리다.
///
/// 개인회생의 회생위원 보수가 그렇다 — 채무자회생법 제590조가 예납을 명하고
/// 규칙 제87조 제1항 제3호가 회생위원 보수를 예납 항목으로 못박는데,
/// 액수는 예규 [별표 1]에 있고 그 별표를 못 받았다.
///
/// **항목을 빼지 않는다.** 항목이 넷인데 둘만 세면 화면이 「이게 전부」로
/// 읽힌다(DECISIONS 155번). 줄은 내고 금액 자리에 「아직 확인 못 했어요」를
/// 낸다. 합계에는 0으로 들어간다 — 모르는 값을 짐작해서 더하지 않는다.
class UnknownCostFormula extends CostFormula {
  const UnknownCostFormula();

  @override
  String get type => 'unknown';

  @override
  JsonMap toJson() => {'type': type};
}

/// 송달료처럼 `단가 × (당사자 수 × 절차별 회수)`.
class PerUnitCostFormula extends CostFormula {
  const PerUnitCostFormula({
    required this.unitPrice,
    required this.unitsFormula,
  });

  factory PerUnitCostFormula.fromJson(JsonMap json) => PerUnitCostFormula(
        unitPrice: (json['unitPrice'] as num).toInt(),
        unitsFormula: UnitsFormula.fromJson(
          Map<String, dynamic>.from(json['unitsFormula'] as Map),
        ),
      );

  final int unitPrice;
  final UnitsFormula unitsFormula;

  @override
  String get type => 'perUnit';

  @override
  JsonMap toJson() => {
        'type': type,
        'unitPrice': unitPrice,
        'unitsFormula': unitsFormula.toJson(),
      };
}

class CostFormulaConverter implements JsonConverter<CostFormula, JsonMap> {
  const CostFormulaConverter();

  @override
  CostFormula fromJson(JsonMap json) => CostFormula.fromJson(json);

  @override
  JsonMap toJson(CostFormula object) => object.toJson();
}

/// 끝수 처리. **한 조문이 두 가지를 함께 말하므로 한 덩어리로 둔다.**
///
/// 민사소송 등 인지법 제2조 제2항 —
/// 「계산한 인지액이 1천원 미만이면 그 인지액은 1천원으로 하고, 1천원 이상이면
/// 100원 미만은 계산하지 아니한다.」
///
/// 둘은 **택일**이다. 1천원 미만이면 올리고, 그렇지 않으면 버린다.
/// 이걸 `roundDown` 하나로만 두면 소액에서 인지액이 1천원 아래로 내려간다 —
/// 실제로 그러고 있었다.
///
/// 어디에 붙는지가 곧 어느 조문이 준용되는지다. `TieredCostFormula.rounding` 은
/// 제2조 제2항 그 자체이고, `CostModifier.rounding` 은 그 조문을 **준용하는**
/// 자리(제7조 제4항)에만 붙는다. 준용 규정이 없는 자리(제16조)에는 붙이지 않는다.
@freezed
abstract class CostRounding with _$CostRounding {
  const factory CostRounding({
    /// 이 값 미만이면 이 값으로 **올린다**.
    int? minimum,

    /// [minimum] 이상이면 이 단위 미만을 **버린다**.
    int? roundDown,
  }) = _CostRounding;

  factory CostRounding.fromJson(JsonMap json) => _$CostRoundingFromJson(json);
}

/// `max: null` = 무한대 구간.
@freezed
abstract class CostTier with _$CostTier {
  const factory CostTier({
    int? max,
    required double rate,
    @Default(0) int add,
  }) = _CostTier;

  factory CostTier.fromJson(JsonMap json) => _$CostTierFromJson(json);
}

/// `단가 × (당사자 수 × 절차별 회수)` 의 회수 부분.
@freezed
abstract class UnitsFormula with _$UnitsFormula {
  const factory UnitsFormula({
    @Default(1) int parties,
    @Default(<String, int>{}) Map<String, int> roundsByProcedure,

    /// **절차가 같아도 회수가 갈리는 자리.** 먼저 맞는 규칙이 이긴다.
    ///
    /// 소액사건이 그렇다. 사용자가 고르는 갈래가 아니라 **소가로 자동 결정된다** —
    /// 소액사건심판규칙 제1조의2 가 제소한 때의 소송목적의 값으로 정한다. 인지대는
    /// 소액이든 아니든 같은 산식이고 **달라지는 것은 송달료 회차뿐**이다.
    /// 그래서 갈래를 늘리지 않고 소송 갈래 **안에서** 회수를 가른다.
    ///
    /// 여기 조건도 `showIf` 와 같은 모양이라 검증기가 그대로 본다.
    @Default(<UnitsRule>[]) List<UnitsRule> roundsWhen,

    /// 절차를 안 가를 때의 회수.
    ///
    /// **절차를 묻지 않는 분야가 있다.** 상속은 한정승인이든 포기든 기간연장이든
    /// 라류 1건당 값이 같아서 갈래를 묻지 않는다. 그때 절차표를 억지로 채우거나
    /// 늘 참인 조건을 지어내는 대신 여기에 적는다.
    ///
    /// 0 이면 안 쓴다 — 절차표나 조건 규칙이 답을 내야 한다.
    @Default(0) int defaultRounds,

    /// 사람 수와 **무관하게 먼저 붙는 회수.**
    ///
    /// 회생·파산이 그렇다 — 예규 [별표 1]이 「10회 + 채권자수 × 8회」로
    /// 적어 둔다. 앞의 10회는 채권자가 몇이든 붙는다. 이걸 못 적으면
    /// 사람 수를 늘려 흉내 내게 되고, 그러면 조문과 다른 산식이 된다.
    @Default(0) int baseRounds,

    /// 절차를 고르는 `CaseFacts` 필드명.
    @Default('procedure') String procedureField,

    /// 당사자 수를 사용자 입력에서 읽을 때 쓰는 필드명 (있으면 우선).
    String? partiesField,
  }) = _UnitsFormula;

  factory UnitsFormula.fromJson(JsonMap json) => _$UnitsFormulaFromJson(json);
}

/// 조건이 맞으면 이 회수를 쓴다.
@freezed
abstract class UnitsRule with _$UnitsRule {
  const factory UnitsRule({
    /// 「소액사건」 — 화면과 검증기 메시지에 그대로 쓰인다.
    required String label,
    required JsonMap showIf,
    required int rounds,
  }) = _UnitsRule;

  factory UnitsRule.fromJson(JsonMap json) => _$UnitsRuleFromJson(json);
}
