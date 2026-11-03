import 'package:domain_data/domain_data.dart';

/// 계산된 기한 하나.
class DeadlineResult {
  const DeadlineResult({
    required this.id,
    required this.label,
    this.kind = DeadlineKind.deadline,
    this.whatIsThis = "",
    required this.dueDate,
    KstDate? dueDateLatest,
    KstDate? statutoryDue,
    KstDate? statutoryDueLatest,
    required this.daysRemaining,
    required this.severity,
    required this.basis,
    this.alsoBasis = const [],
    required this.verification,
    this.notify = const [],
  })  : _latest = dueDateLatest,
        _beforeRoll = statutoryDue,
        _beforeRollLatest = statutoryDueLatest;

  /// 생성자가 받은 늦은 끝. 없으면 정확한 기한이다. 읽을 때는 [dueDateLatest].
  final KstDate? _latest;

  final String id;
  final String label;

  /// 기한인가, 「그날부터」인가. 화면이 카드를 가르는 기준이다.
  final DeadlineKind kind;
  /// 한 줄 풀이.
  final String whatIsThis;

  /// 기한이 놓일 수 있는 **가장 이른 날**. `DateTime` 은 `dueDate.toUtcMidnight()`.
  ///
  /// 기산일이 정확하면 [dueDateLatest] 와 같다.
  ///
  /// **왜 이른 쪽인가** — 불확실할 때는 사용자에게 불리한 쪽을 기준으로 잡는다.
  /// 가장 이른 날에 맞춰 움직이면 어느 해석에서도 늦지 않는다. 늦은 쪽을 기준으로
  /// 하면 절반의 경우에 기한을 놓친다. `daysRemaining`·`dDay`·알림이 전부
  /// 이 날짜를 쓴다.
  final KstDate dueDate;

  /// 기한이 놓일 수 있는 가장 늦은 날. 기산일이 정확하면 [dueDate] 와 같다.
  KstDate get dueDateLatest => _latest ?? dueDate;

  /// 기산일이 어림이라 기한이 범위로만 나오는가.
  ///
  /// 이 값이 참이면 화면은 **날짜를 단정하지 않는다.** 확신에 찬 거짓이
  /// 가장 나쁜 결과다.
  bool get isApproximate => dueDateLatest != dueDate;

  /// 민법 제161조로 밀기 **전** 말일. 정답지가 대조하는 값이다.
  ///
  /// 정답지는 157·159·160 의 답을 담는다. 제161조를 섞으면 정답지가 달력에 따라
  /// 흔들리고 조문 대조를 할 수 없게 된다.
  KstDate get statutoryDue => _beforeRoll ?? dueDate;
  KstDate get statutoryDueLatest => _beforeRollLatest ?? dueDateLatest;

  /// 생성자가 받은 제161조 적용 전 값. 읽을 때는 [statutoryDue] · [statutoryDueLatest].
  final KstDate? _beforeRoll;
  final KstDate? _beforeRollLatest;

  /// 밀렸으면 밀리기 전 날짜. 안 밀렸으면 null.
  ///
  /// 화면이 「토요일이라 다음 평일로 밀렸어요」 라고 말할 수 있어야 한다.
  /// 아무 설명 없이 날짜만 바뀌면 사용자는 계산이 틀렸다고 생각한다.
  KstDate? get rolledFrom => statutoryDue == dueDate ? null : statutoryDue;

  bool get wasRolled => rolledFrom != null;

  /// 음수면 이미 지났다.
  final int daysRemaining;
  final Severity severity;

  /// 근거 조문. 없으면 만들 수 없다.
  final LegalBasis basis;

  /// 근거가 하나로 안 끝날 때 이어지는 조문.
  ///
  /// 기간이 든 조문과 **그 기간을 늘려주지 않는다는 조문**이 갈라져 있는
  /// 자리가 있다(DECISIONS 160번). 하나만 보여주면 「사정을 말하면 되겠지」가
  /// 그대로 남는다.
  final List<LegalBasis> alsoBasis;
  final VerificationStatus verification;

  /// 며칠 전에 알릴지.
  final List<int> notify;

  bool get isOverdue => daysRemaining < 0;

  bool get isToday => daysRemaining == 0;

  /// "D-14" · "D-DAY" · "D+3"
  String get dDay {
    if (daysRemaining == 0) return 'D-DAY';
    return daysRemaining > 0 ? 'D-$daysRemaining' : 'D+${-daysRemaining}';
  }

  @override
  String toString() => '$label ${dueDate.toIso()} ($dDay)';
}
