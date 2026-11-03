import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'cost_formula.dart';
import 'legal_basis.dart';
import 'verification.dart';

part 'cost_item.freezed.dart';
part 'cost_item.g.dart';

/// 비용 항목. 금액은 전부 `int` (원 단위). `double` 금지.
@freezed
abstract class CostItem with _$CostItem implements Verifiable {
  const factory CostItem({
    required String id,
    required String label,

    /// 한 줄 풀이. **비어 있으면 빌드 실패.** 40자 이내(공백 포함).
    ///
    /// 인지대·송달료·지급명령을 아는 사람은 이 앱이 필요 없다.
    /// `Question` 에 `whyAsk` 가 있듯 결과에 나오는 용어에는 이게 있어야 한다.
    @Default('') String whatIsThis,
    @CostFormulaConverter() required CostFormula formula,

    /// **정의된 배열 순서대로** 곱한다.
    @Default(<CostModifier>[]) List<CostModifier> modifiers,
    JsonMap? showIf,
    LegalBasis? legalBasis,

    /// 근거가 하나로 안 끝날 때. [Caution.alsoBasis] 와 같다.
    ///
    /// 인지대가 그렇다 — 산식과 끝수는 인지법에 있고, **10분의 9를 무엇에 곱하는지**는
    /// 예규가 정한다. 계산 순서를 뒷받침하는 조문이 다른 법령에 있는 것이다.
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,
    required Verification verification,

    /// **정답지. 비어 있으면 빌드 실패.**
    @Default(<CostTest>[]) List<CostTest> tests,
  }) = _CostItem;

  factory CostItem.fromJson(JsonMap json) => _$CostItemFromJson(json);
}

@freezed
abstract class CostModifier with _$CostModifier {
  const factory CostModifier({
    required String id,
    required String label,
    required double multiply,
    JsonMap? condition,

    /// 곱한 **뒤** 끝수 처리. **준용 규정이 있는 자리에만 붙인다.**
    ///
    /// 인지법 제7조 제4항은 제2조 제2항을 준용한다고 적혀 있어 붙는다.
    /// 제16조(전자소송 10분의 9)에는 그런 규정이 없어 붙이지 않는다.
    /// 없는 규정을 넣으면 그건 계산이 아니라 판단이다.
    CostRounding? rounding,

    /// 이 배수가 어느 조문에서 나왔는가.
    ///
    /// 항목 전체의 `legalBasis` 에 조문을 이어 붙이면 **어느 조문이 어느 배수를
    /// 만들었는지** 알 수 없다. 배수마다 따로 둬야 계산 근거가 화면에 선다.
    LegalBasis? legalBasis,
  }) = _CostModifier;

  factory CostModifier.fromJson(JsonMap json) => _$CostModifierFromJson(json);
}

/// **사용자가 아직 정하지 않은 갈래**를 나란히 계산하기 위한 가정.
///
/// 지급명령으로 갈지 소송으로 갈지는 사용자가 지금 정한 것이 아니다. 그걸 물으면
/// 답을 모르는 사람에게 답을 요구하게 된다. 그렇다고 한쪽으로 계산하면 다른 쪽
/// 사람에게 **틀린 금액**이 간다 — 실제로 11배까지 벌어졌다.
///
/// 그래서 묻지 않고 **갈래마다 따로 계산해 나란히 보여준다.** 비용이 곧 선택의
/// 근거가 되므로 사용자에게도 이쪽이 쓸모 있다.
///
/// [facts] 는 그 갈래를 가정했을 때의 필드값이다. 사용자가 이미 답한 필드와
/// 어긋나는 시나리오는 버린다 — 나중에 질문이 생기면 답이 이긴다.
@freezed
abstract class CostScenario with _$CostScenario {
  const factory CostScenario({
    required String id,

    /// 갈래 이름. 같은 값을 가진 시나리오가 한 줄로 묶인다.
    required String label,

    /// 갈래 한 줄 풀이. 라벨에 공식 용어가 들어가면 여기에 뜻을 적는다.
    @Default('') String whatIsThis,

    /// 갈래 안의 선택. 없으면 갈래가 한 칸짜리다.
    String? option,

    /// 이 갈래를 가정했을 때의 필드값.
    @Default(<String, dynamic>{}) JsonMap facts,

    /// 이 갈래를 아예 낼 수 없는 경우를 거른다.
    ///
    /// **못 쓰는 절차의 비용을 계산해 보여주면 안 된다.** 지급명령은 민사소송법
    /// 제462조 단서가 「공시송달 외의 방법으로 송달할 수 있는 경우」로 한정한다 —
    /// 상대 주소를 아예 모르면 쓸 수 없다. 그 사람에게 지급명령 금액을 내밀면
    /// 밟을 수 없는 절차를 권하는 것이 된다.
    ///
    /// [facts] 와 다르다. `facts` 는 **아직 안 정한 것을 가정**하는 자리이고
    /// 이것은 **정해진 사실로 갈래를 거르는** 자리다.
    JsonMap? showIf,
  }) = _CostScenario;

  factory CostScenario.fromJson(JsonMap json) => _$CostScenarioFromJson(json);
}

/// `{ "input": { "claimAmount": 100000000 }, "expected": 455000 }`
@freezed
abstract class CostTest with _$CostTest {
  const factory CostTest({
    @Default(<String, dynamic>{}) JsonMap input,
    required int expected,
  }) = _CostTest;

  factory CostTest.fromJson(JsonMap json) => _$CostTestFromJson(json);
}
