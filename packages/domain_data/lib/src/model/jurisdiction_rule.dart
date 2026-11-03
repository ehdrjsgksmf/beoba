import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'verification.dart';

part 'jurisdiction_rule.freezed.dart';
part 'jurisdiction_rule.g.dart';

/// 관할 법원을 찾는 규칙. **표는 코드에 없다.** `lookupTable` 이름으로 주입받는다.
@freezed
abstract class JurisdictionRule with _$JurisdictionRule implements Verifiable {
  const factory JurisdictionRule({
    required String id,
    required String label,
    @Default('') String whatIsThis,

    /// 주소가 담긴 `CaseFacts` 필드명.
    required String inputField,

    /// 조회표 이름. 예: `court_by_district`
    required String lookupTable,

    /// 사용자에게 보여줄 규칙 설명.
    @Default('') String rule,
    JsonMap? showIf,
    required Verification verification,
  }) = _JurisdictionRule;

  factory JurisdictionRule.fromJson(JsonMap json) => _$JurisdictionRuleFromJson(json);
}
