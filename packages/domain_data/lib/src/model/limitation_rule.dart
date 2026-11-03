import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'legal_basis.dart';
import 'verification.dart';

part 'limitation_rule.freezed.dart';
part 'limitation_rule.g.dart';

/// 소멸시효를 화면에 내는 자리.
///
/// **날짜로 계산하지 않는다.** 몇 년인지가 사건마다 달라서 우리가 고르면
/// 틀릴 수 있다. 대신 법에 어떻게 쓰여 있는지를 **갈래로 나란히** 낸다 —
/// 비용에서 이미 하고 있는 것과 같다([DECISIONS 75](#75)).
enum LimitationKind {
  /// 몇 년인가. **넷을 나란히 낸다. 어느 하나를 고르지 않는다.**
  @JsonValue('branch')
  branch,

  /// 언제부터 세는가.
  @JsonValue('start')
  start,

  /// 멈추는 일.
  @JsonValue('interrupt')
  interrupt,
}

/// 시효 조문 한 줄.
@freezed
abstract class LimitationRule with _$LimitationRule {
  const factory LimitationRule({
    required String id,
    required LimitationKind kind,

    /// 「원칙은 10년」 · 「5년일 수 있어요」
    required String label,

    /// 우리 말 한 줄. **조문에 없는 말은 전부 여기 있어야 한다.**
    ///
    /// 조문을 풀어 쓰지 않는다 — 「갚기로 한 날 다음 날부터」는 조문에 없다.
    @Default('') String note,

    /// 해당하는 사람에게만 보인다.
    ///
    /// 제174조(최고)는 **내용증명을 보낸 사람에게만**. 안 보낸 사람에게
    /// 「6개월」은 겁만 준다.
    JsonMap? showIf,
    required LegalBasis legalBasis,
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,
    required Verification verification,
  }) = _LimitationRule;

  factory LimitationRule.fromJson(JsonMap json) =>
      _$LimitationRuleFromJson(json);
}
