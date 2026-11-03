import 'package:domain_data/domain_data.dart';

/// 적용된 배수 하나. **정의된 배열 순서대로** 쌓인다.
class AppliedModifier {
  const AppliedModifier({
    required this.id,
    required this.label,
    required this.multiply,
    required this.beforeRounding,
    required this.amount,
    this.rounding,
    this.basis,
  });

  final String id;

  /// 데이터가 준 말. 코드가 만들지 않는다.
  final String label;
  final double multiply;

  /// 곱하기만 한 값. 끝수를 처리하기 **전**이다.
  final int beforeRounding;

  /// 이 배수까지 반영한 **뒤** 금액. 끝수 처리가 없으면 [beforeRounding] 과 같다.
  final int amount;

  /// 이 자리에 준용 규정이 있으면 그 끝수 규칙. 없으면 null.
  final CostRounding? rounding;

  /// 이 배수의 근거 조문.
  final LegalBasis? basis;

  /// 끝수 처리가 실제로 금액을 바꿨는가.
  bool get roundingChanged => beforeRounding != amount;
}

/// 엔진이 실제로 밟은 계산 단계.
///
/// **화면이 다시 계산하지 않게 하려고 있다.** 두 곳에서 따로 계산하면 언젠가
/// 갈라지고, 갈라지면 어느 쪽이 맞는지 아무도 모른다. 화면은 여기 담긴 숫자를
/// 늘어놓기만 한다.
///
/// 🟢 은 근거가 붙어야 한다는 규칙이 비용에서는 안 지켜지고 있었다. 조문은 있는데
/// **그 조문이 어떻게 이 숫자가 됐는지**가 없었다.
class CostBreakdown {
  const CostBreakdown({
    required this.base,
    required this.amount,
    this.input,
    this.tier,
    this.tierFloor,
    this.rated,
    this.rounding,
    this.beforeRounding,
    this.unitPrice,
    this.units,
    this.modifiers = const [],
  });

  /// 배수를 적용하기 **전** 금액.
  final int base;

  /// 최종 금액.
  final int amount;

  /// 구간식의 입력 금액. 다른 방식이면 null.
  final int? input;

  /// 고른 구간.
  final CostTier? tier;

  /// 고른 구간의 **아래쪽 경계**. 첫 구간이면 0.
  final int? tierFloor;

  /// 요율만 곱한 값. `add` 를 더하기 전이다.
  final int? rated;

  /// 계산식에 붙은 끝수 규칙.
  final CostRounding? rounding;

  /// 끝수를 처리하기 **전** 금액.
  final int? beforeRounding;

  /// 끝수 처리가 실제로 금액을 바꿨는가.
  bool get roundingChanged => beforeRounding != null && beforeRounding != base;

  /// 최저액 규정에 걸려 **올라간** 경우. 버린 경우와 화면에서 말이 달라진다.
  bool get raisedToMinimum {
    final before = beforeRounding;
    final minimum = rounding?.minimum;
    return before != null && minimum != null && before < minimum;
  }

  /// 단가식의 단가·수량.
  final int? unitPrice;
  final int? units;

  final List<AppliedModifier> modifiers;

  /// 보여줄 단계가 있는가. 정액이면 보여줄 것이 없다.
  bool get hasSteps =>
      tier != null || unitPrice != null || modifiers.isNotEmpty;
}

/// 비용 한 줄.
class CostLine {
  const CostLine({
    required this.id,
    required this.label,
    this.whatIsThis = "",
    required this.amount,
    this.amountKnown = true,
    required this.verification,
    this.guidanceFloor,
    this.appliedModifiers = const [],
    this.basis,
    this.alsoBasis = const [],
    this.openPart,
    this.breakdown,
  });

  final String id;
  final String label;
  /// 한 줄 풀이.
  final String whatIsThis;

  /// **조문대로의 금액.** 원 단위, `double` 아님. 정답지가 보는 값이다.
  final int amount;

  /// 금액을 아는가. **모르는 줄도 줄이다.**
  ///
  /// 조문이 예납·비용 항목으로 못박았는데 금액표를 우리가 못 가진 자리가 있다.
  /// 그 줄을 빼면 화면이 「이게 전부」로 읽힌다(DECISIONS 155번). 줄은 내고,
  /// 화면이 금액 대신 「아직 확인 못 했어요」를 낸다. [amount] 는 0 이고
  /// **합계에도 0 으로 들어간다** — 모르는 값을 짐작해서 더하지 않는다.
  final bool amountKnown;

  /// 안내할 때 이 아래로 내려가지 않는 값. 없으면 null.
  final int? guidanceFloor;

  /// **화면에 낼 금액.** 조문 해석([amount])에 안전 여유를 더한 값이다.
  ///
  /// 둘을 한 필드에 합치지 않는다. 합치면 나중에 어느 쪽이 조문이었는지
  /// 알 수 없게 된다. 화면은 이쪽을, 정답지는 저쪽을 본다.
  int get guidedAmount {
    final floor = guidanceFloor;
    return floor != null && amount < floor ? floor : amount;
  }

  /// 안내 값이 조문대로의 값보다 올라갔는가. 화면이 그 사실을 말해야 한다.
  bool get raisedForGuidance => guidedAmount != amount;

  /// 적용된 modifier id. **정의된 배열 순서대로** 들어간다.
  final List<String> appliedModifiers;
  final LegalBasis? basis;

  /// 근거가 하나로 안 끝날 때 이어지는 조문.
  final List<LegalBasis> alsoBasis;
  final VerificationStatus verification;

  /// 이 항목에서 **아직 확인 전인 조각**의 이름. 배지가 이걸 가리킨다.
  final String? openPart;

  /// 엔진이 밟은 계산 단계. 화면은 이걸 늘어놓기만 한다.
  final CostBreakdown? breakdown;

  @override
  String toString() => '$label $amount원';
}

class CostResult {
  const CostResult({required this.lines, required this.total});

  final List<CostLine> lines;

  /// 원 단위 합계. **조문대로의 값을 더한 것이다.**
  final int total;

  /// 화면에 낼 합계. [CostLine.guidedAmount] 를 더한다.
  ///
  /// 화면이 줄마다 올림한 값을 보여주면서 합계만 조문대로면 **더해도 안 맞는다.**
  /// 검산하는 사람이 제일 먼저 부딪히는 자리다.
  int get guidedTotal =>
      lines.fold<int>(0, (sum, line) => sum + line.guidedAmount);

  static const CostResult empty = CostResult(lines: [], total: 0);

  CostLine? lineById(String id) {
    for (final line in lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  @override
  String toString() => '${lines.join(' · ')} = $total원';
}

/// 갈래 하나의 비용 한 벌.
///
/// **화면이 이걸 다시 계산하지 않는다.** 갈래마다 엔진이 처음부터 걸어간 결과이고,
/// [CostLine.breakdown] 에 밟은 단계가 그대로 들어 있다.
class ScenarioCostResult {
  const ScenarioCostResult({
    required this.id,
    required this.label,
    required this.assumed,
    required this.result,
    this.whatIsThis = '',
    this.option,
  });

  /// 시나리오가 없는 분야는 빈 문자열이다.
  final String id;

  /// 갈래 이름. 같은 값끼리 한 줄로 묶인다.
  final String label;

  /// 갈래 한 줄 풀이.
  final String whatIsThis;

  /// 갈래 안의 선택. 없으면 한 칸짜리다.
  final String? option;

  /// 이 결과가 **가정한** 값. 사용자가 답한 것이 아니다.
  final Map<String, Object?> assumed;

  final CostResult result;

  bool get isAssumption => assumed.isNotEmpty;

  @override
  String toString() =>
      '${[label, if (option != null) option].join(' · ')} = ${result.total}원';
}
