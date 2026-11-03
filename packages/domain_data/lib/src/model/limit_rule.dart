import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'legal_basis.dart';
import 'limit_formula.dart';
import 'verification.dart';
import 'welfare.dart';

part 'limit_rule.freezed.dart';
part 'limit_rule.g.dart';

/// ② 방어 — 상대가 요구한 금액이 법정 상한을 넘는지 대조한다.
@freezed
abstract class LimitRule with _$LimitRule implements Verifiable {
  const factory LimitRule({
    required String id,
    required String label,

    /// 필요한 입력들. 필드명과 **화면에 쓸 한글 라벨**을 함께 담는다.
    @Default(<LimitInput>[]) List<LimitInput> inputs,

    /// true 면 입력과 무관하게 위법. 법정 상한 자체가 0원이다.
    @Default(false) bool alwaysIllegal,
    @LimitFormulaConverter() LimitFormula? formula,

    /// [alwaysIllegal] 이거나 고정 안내가 필요한 경우의 문구.
    String? message,

    /// 판정별 표시 문구. `over` / `at` / `zero`
    Map<String, String?>? verdicts,
    LegalBasis? legalBasis,
    /// **기관이 알려 준 것이면 딱지를 단다** — 네 번째 층([AgencyNotice]).
    ///
    /// 조문이 아닌 금액·절차가 여기 있을 수 있다. 신용회복위원회 채무조정
    /// 신청비가 그렇다 — 법령이 아니라 기관 공지다. 그 사실 자체가 이 항목의
    /// 정보이므로 숨기지 않고 **어디서 왔는지 적는다.**
    ///
    /// 검사 (aa)가 이 딱지를 본다 — 딱지가 있으면 그 금액을 조문 인용 대신
    /// 「기관 이름 + 확인한 날」로 견준다.
    AgencyNotice? notice,
    ActionRef? action,
    required Verification verification,
    @Default(<LimitTest>[]) List<LimitTest> tests,
  }) = _LimitRule;

  factory LimitRule.fromJson(JsonMap json) => _$LimitRuleFromJson(json);
}

/// 상한 계산에 넣는 입력 하나.
///
/// 라벨이 **데이터에** 있어야 한다. 코드에 두면 `engines` 가 분야 어휘를 알게 되고,
/// 제도가 바뀔 때 앱 심사 없이 못 고친다 (CONTRIBUTING.md 규칙 9).
@freezed
abstract class LimitInput with _$LimitInput {
  const factory LimitInput({
    /// `CaseFacts` 에서 값을 꺼낼 키.
    required String field,

    /// 화면·리포트에 그대로 쓰는 한글 이름.
    required String label,
  }) = _LimitInput;

  factory LimitInput.fromJson(JsonMap json) => _$LimitInputFromJson(json);
}

@freezed
abstract class LimitTest with _$LimitTest {
  const factory LimitTest({
    @Default(<String, dynamic>{}) JsonMap input,
    required LimitExpectation expected,
  }) = _LimitTest;

  factory LimitTest.fromJson(JsonMap json) => _$LimitTestFromJson(json);
}

@freezed
abstract class LimitExpectation with _$LimitExpectation {
  const factory LimitExpectation({
    int? legalMax,
    required String verdict,
    int? excess,
  }) = _LimitExpectation;

  factory LimitExpectation.fromJson(JsonMap json) =>
      _$LimitExpectationFromJson(json);
}
