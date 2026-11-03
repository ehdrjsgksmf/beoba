import 'package:domain_data/domain_data.dart';

import 'civil_period.dart';

/// 받아 둔 공휴일 표로 판정한다. 토·일에 **더해서** 본다.
///
/// ## 안전 방향이 뒤집힌다 — 이게 제일 중요하다
///
/// ```
/// 공휴일을 적게 알면      → 덜 민다 → 기한이 이르다 → 안전
/// 공휴일을 **잘못 넣으면** → 더 민다 → 기한이 늦다  → 위험
/// ```
///
/// [WeekendHolidayRule] 만 쓰던 동안에는 「안 민 쪽이 언제나 진짜 기한보다
/// 앞」이라 늦을 일이 없었다(DECISIONS 68). 데이터를 넣는 순간 그 보장이
/// 사라진다. **틀린 날을 넣느니 빼는 게 맞다.**
///
/// ## 데이터가 없는 해
///
/// [years] 밖의 날짜는 **토·일만 본다.** 조용히 그러지 않는다 —
/// 화면이 「어디까지 반영했는지」를 말한다([covers] 를 쓴다).
class TableHolidayRule implements HolidayRule {
  TableHolidayRule(Iterable<HolidayCalendar> calendars)
      : years = {for (final c in calendars) c.year},
        _closed = {
          for (final calendar in calendars)
            for (final day in calendar.days) day.date,
        };

  /// 표가 있는 해. 여기 없는 해는 토·일만 민다.
  final Set<int> years;
  final Set<KstDate> _closed;

  /// 표에 실린 쉬는 날 수. 비어 있으면 표가 없는 것과 같다.
  int get length => _closed.length;

  /// 이 해의 공휴일을 아는가.
  bool covers(int year) => years.contains(year);

  /// 화면이 「몇 년까지 반영했는지」 말할 때 쓴다. 표가 없으면 null.
  int? get lastCoveredYear =>
      years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b);

  @override
  bool isClosed(KstDate date) {
    // 토·일은 달력에서 나온다. 표가 없는 해에도 이건 그대로 본다.
    if (date.isWeekend) return true;
    // **표가 없는 해는 공휴일을 모른다고 둔다.** 모르는 것을 아는 척하면
    // 기한이 뒤로 밀리고, 그쪽이 위험한 방향이다.
    if (!covers(date.year)) return false;
    return _closed.contains(date);
  }
}
