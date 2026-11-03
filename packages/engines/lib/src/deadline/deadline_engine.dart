import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/engine.dart';
import '../core/json_logic.dart';
import '../core/kst_clock.dart';
import 'civil_period.dart';
import 'deadline_result.dart';

/// 기한 계산. 모든 날짜 연산은 KST 자정 기준.
///
/// - `showIf` 를 만족하지 않는 항목은 제외한다
/// - 기산일이 없으면 제외한다 (**에러가 아니다** — 아직 모르는 것뿐)
/// - 정렬: severity DESC → 남은 일수 ASC → id ASC
class DeadlineEngine implements Engine<List<DeadlineResult>> {
  const DeadlineEngine(this.clock, {this.holidays = const WeekendHolidayRule()});

  final KstClock clock;

  /// 민법 제161조 — 말일이 닫힌 날이면 익일로 민다.
  ///
  /// 기본값은 토·일만 본다. 공휴일은 데이터가 있어야 알 수 있고, 모르고 안 민 쪽은
  /// 언제나 진짜 기한보다 **앞**이라 늦지 않는다.
  final HolidayRule holidays;

  @override
  List<DeadlineResult> compute(Domain domain, CaseFacts facts) {
    final data = facts.toJsonLogicData();
    final results = <DeadlineResult>[];

    for (final deadline in domain.deadlines) {
      if (!JsonLogic.test(deadline.showIf, data)) continue;
      final result = computeOne(deadline, facts);
      if (result != null) results.add(result);
    }

    results.sort((a, b) {
      final bySeverity = b.severity.rank.compareTo(a.severity.rank);
      if (bySeverity != 0) return bySeverity;
      final byDays = a.daysRemaining.compareTo(b.daysRemaining);
      if (byDays != 0) return byDays;
      return a.id.compareTo(b.id);
    });
    return results;
  }

  /// 기한 하나만 계산한다. `showIf` 는 보지 않는다 (호출자가 판단).
  /// 기산일이 없으면 null.
  DeadlineResult? computeOne(Deadline deadline, CaseFacts facts) {
    final window = dueWindow(deadline, facts);
    if (window == null) return null;

    // 제161조는 **맨 마지막에** 적용한다. 기간 계산이 끝난 말일을 미는 것이지
    // 계산 중간에 끼어드는 규칙이 아니다.
    //
    // **「그날부터」는 밀지 않는다.** 제161조는 「기간의 말일이 토요일 또는
    // 공휴일에 해당한 때」를 미는 규칙이고, 대항력이 생기는 날은 말일이
    // 아니다. 토요일에 생기면 토요일부터다 — 밀면 실제로 힘이 있던 이틀을
    // 없는 것으로 만든다(DECISIONS 135번).
    final rolls = deadline.kind == DeadlineKind.deadline;
    final due = rolls
        ? CivilPeriod.rollForward(window.earliest, holidays)
        : window.earliest;
    final latest = rolls
        ? CivilPeriod.rollForward(window.latest, holidays)
        : window.latest;

    return DeadlineResult(
      id: deadline.id,
      label: deadline.label,
      kind: deadline.kind,
      whatIsThis: deadline.whatIsThis,
      dueDate: due,
      dueDateLatest: latest,
      // 밀기 전 말일을 남긴다. 정답지가 대조하는 값이고, 화면이 이유를 말할 때도 쓴다.
      statutoryDue: window.earliest,
      statutoryDueLatest: window.latest,
      daysRemaining: due.differenceInDays(clock.today()),
      severity: deadline.severity,
      basis: deadline.legalBasis,
      alsoBasis: deadline.alsoBasis,
      verification: deadline.verification.status,
      notify: deadline.notify,
    );
  }

  /// 만기일. 계산에 필요한 값이 없으면 null.
  ///
  /// 기산일이 정확하면 [dueWindow] 의 양 끝이 같으므로 이 값과 같다.
  KstDate? dueDate(Deadline deadline, CaseFacts facts) =>
      dueWindow(deadline, facts)?.earliest;

  /// 만기일이 놓일 수 있는 **범위**. 계산에 필요한 값이 없으면 null.
  ///
  /// 기산일이 「2023년 3월」처럼 어림이면 만기일도 하나로 정해지지 않는다.
  /// **거기서 하나를 고르는 순간 앱이 사실을 만든다.** 그래서 범위 그대로 돌려주고,
  /// 어느 끝을 보여줄지는 화면이 정한다.
  ///
  /// 정확한 기산일이면 `earliest == latest` 라 **기존 동작이 그대로 특수 케이스로
  /// 들어간다.** 정답지 16건이 그걸 증명한다.
  ({KstDate earliest, KstDate latest})? dueWindow(
    Deadline deadline,
    CaseFacts facts,
  ) {
    switch (deadline.calcRule) {
      case CalcRule.fromBasis:
        return _spread(facts.approxDate(deadline.basisField), deadline.offset);

      case CalcRule.fromMonthEnd:
        // **월만 알아도 정확하다.** 말일은 월에만 달려 있고 일에는 안 달려 있다.
        // 어림값이 정확도를 깎기만 하는 것이 아니라는 사례다.
        final basis = facts.approxDate(deadline.basisField);
        if (basis == null) return null;
        if (basis.month != null) {
          final due = _addOffset(basis.earliest.endOfMonth(), deadline.offset);
          return (earliest: due, latest: due);
        }
        // 연도만 알면 1월 말일부터 12월 말일까지 벌어진다.
        return (
          earliest: _addOffset(basis.earliest.endOfMonth(), deadline.offset),
          latest: _addOffset(basis.latest.endOfMonth(), deadline.offset),
        );

      case CalcRule.fromKnownDate:
        final field = deadline.knownDateField ?? deadline.basisField;
        final known =
            facts.approxDate(field) ?? facts.approxDate(deadline.basisField);
        return _spread(known, deadline.offset);

      case CalcRule.fixedAnnual:
        final due = _nextAnnual(deadline);
        return due == null ? null : (earliest: due, latest: due);
    }
  }

  /// 어림 기산일의 양 끝에 같은 offset 을 더한다.
  ({KstDate earliest, KstDate latest})? _spread(ApproxDate? basis, Offset offset) {
    if (basis == null) return null;
    return (
      earliest: _addOffset(basis.earliest, offset),
      latest: _addOffset(basis.latest, offset),
    );
  }

  /// 민법 157·159·160 을 따른다. 제161조는 여기서 적용하지 않는다.
  KstDate _addOffset(KstDate basis, Offset offset) =>
      CivilPeriod.statutoryEnd(basis, offset);

  /// 매년 고정된 월·일 중 오늘 이후로 가장 가까운 날.
  KstDate? _nextAnnual(Deadline deadline) {
    final month = deadline.fixedMonth;
    final day = deadline.fixedDay;
    if (month == null || day == null) return null;

    final today = clock.today();
    final thisYear = KstDate(today.year, month, day);
    return thisYear >= today ? thisYear : KstDate(today.year + 1, month, day);
  }
}
