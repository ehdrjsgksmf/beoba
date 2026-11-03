import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'verification.dart';

part 'resource.freezed.dart';
part 'resource.g.dart';

/// ③ 자원 — 공적 지원제도. 사다리 단계 [tier] 가 낮을수록 먼저 권한다.
@freezed
abstract class Resource with _$Resource implements Verifiable {
  const factory Resource({
    required String id,
    @Default(0) int tier,
    required String name,
    @Default('') String org,
    String? phone,
    String? url,

    /// 원 단위. 0 = 무료.
    @Default(0) int cost,
    @Default(<EligibilityRule>[]) List<EligibilityRule> eligibility,
    @Default('') String benefit,
    required Verification verification,
  }) = _Resource;

  factory Resource.fromJson(JsonMap json) => _$ResourceFromJson(json);
}

@freezed
abstract class EligibilityRule with _$EligibilityRule {
  const factory EligibilityRule({
    required String label,
    JsonMap? condition,
  }) = _EligibilityRule;

  factory EligibilityRule.fromJson(JsonMap json) => _$EligibilityRuleFromJson(json);
}
