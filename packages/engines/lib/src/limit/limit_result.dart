import 'package:domain_data/domain_data.dart';

enum LimitVerdict {
  /// 법정 상한을 넘는다.
  over,

  /// 상한 이내다.
  within,

  /// 금액과 무관하게 위법이다.
  alwaysIllegal,

  /// 약정 전체가 무효다. 예: 연 60% 초과 이자.
  voidAll,

  /// 판단할 입력이 부족하다. **추측하지 않는다.**
  unknown,
}

/// 법정 상한 대조 결과. **판단이 아니라 대조다.**
class LimitResult {
  const LimitResult({
    required this.ruleId,
    required this.label,
    required this.verdict,
    required this.message,
    required this.verification,
    this.legalMax,
    this.requested,
    this.excess,
    this.basis,
    this.action,
    this.inputs = const {},
  });

  final String ruleId;
  final String label;
  final LimitVerdict verdict;

  /// 법이 허용하는 최대 금액. 원 단위.
  final int? legalMax;

  /// 상대가 요구한 금액.
  final int? requested;

  /// 초과분. `requested - legalMax`.
  final int? excess;
  final String message;
  final LegalBasis? basis;
  final ActionRef? action;
  final VerificationStatus verification;

  /// 이 판정에 **실제로 쓰인** 입력값. field → value.
  ///
  /// 무엇을 넣어서 이 답이 나왔는지 보여주기 위한 것이다.
  /// 계산에 쓰이지 않은 입력은 담지 않는다.
  final Map<String, Object?> inputs;

  bool get isProblem =>
      verdict == LimitVerdict.over ||
      verdict == LimitVerdict.alwaysIllegal ||
      verdict == LimitVerdict.voidAll;

  @override
  String toString() => '$label: ${verdict.name}'
      '${legalMax != null ? ' (상한 $legalMax원)' : ''}';
}
