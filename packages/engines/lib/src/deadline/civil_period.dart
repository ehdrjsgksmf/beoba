import 'package:domain_data/domain_data.dart';

/// 기간의 말일이 「법원이 닫은 날」인지 판정한다.
///
/// 민법 제161조가 말일이 토요일·공휴일이면 익일로 미루라고 한다. 토·일은 달력에서
/// 나오지만 **공휴일은 데이터가 있어야 안다** — 「관공서의 공휴일에 관한 규정」이
/// 필요하고 설·추석은 음력이라 매년 바뀐다.
abstract interface class HolidayRule {
  bool isClosed(KstDate date);
}

/// 토·일만 본다. **공휴일은 모른다.**
///
/// 공휴일을 안 미루면 **실제보다 이른 날짜**가 나온다. 제161조는 기한을 뒤로만
/// 미루므로, 모르고 안 미룬 쪽은 언제나 진짜 기한보다 앞이다. 그 날에 맞춰
/// 움직이면 늦지 않는다 — [ApproxDate] 에서 가장 이른 날을 기준으로 잡은 것과
/// 같은 방향이다.
///
/// 그래도 정확하지는 않다. 공휴일 데이터는 🔴 확인 목록에 있다.
class WeekendHolidayRule implements HolidayRule {
  const WeekendHolidayRule();

  @override
  bool isClosed(KstDate date) => date.isWeekend;
}

/// 아무 날도 안 닫는다. 기간 계산만 따로 보고 싶을 때 쓴다.
class OpenEveryDayRule implements HolidayRule {
  const OpenEveryDayRule();

  @override
  bool isClosed(KstDate date) => false;
}

/// 민법 총칙의 기간 계산.
///
/// ```
/// 제157조  기간의 초일은 산입하지 아니한다
/// 제159조  기간말일의 종료로 기간이 만료한다
/// 제160조② 최후의 주·월·연에서 그 기산일에 해당한 날의 전일로 만료
/// 제160조③ 최종의 월에 해당일이 없는 때에는 그 월의 말일로 만료
/// 제161조  말일이 토요일 또는 공휴일이면 그 익일로 만료
/// ```
///
/// **답변서 30일 · 이의신청 2주 · 소멸시효가 전부 이 규칙을 받는다.**
/// 여기가 틀리면 이 앱이 내놓는 모든 날짜가 틀린다.
abstract final class CivilPeriod {
  /// 제157조 — 초일은 안 센다. 세기 시작하는 날은 다음 날이다.
  static KstDate startOf(KstDate basis) => basis.addDays(1);

  /// 제161조를 **적용하기 전** 만료일.
  ///
  /// 일·주는 `기준일 + n` 과 같다. 기산일이 `기준일 + 1` 이고 n일째가
  /// `기산일 + (n-1)` 이므로 결국 `기준일 + n` 이다 — **초일불산입이니 하루 더해야
  /// 한다는 생각은 틀렸다.**
  ///
  /// 월·연은 다르다. `기준일 + n개월` 로 계산하면 **기준일이 그 달의 말일일 때
  /// 어긋난다** — 2019-02-28 에서 1년은 2020-02-29 인데(기산일 3월 1일의 전일)
  /// 단순 가산은 2020-02-28 을 준다. 그래서 기산일에서 세고 전일을 잡는다.
  static KstDate statutoryEnd(KstDate basis, Offset offset) {
    switch (offset.unit) {
      case TimeUnit.day:
        return basis.addDays(offset.value);
      case TimeUnit.week:
        return basis.addWeeks(offset.value);
      case TimeUnit.month:
        return _byCalendar(basis, offset.value);
      case TimeUnit.year:
        return _byCalendar(basis, offset.value * 12);
    }
  }

  /// 제160조② · ③ — 기산일에 해당한 날의 전일. 해당일이 없으면 그 달의 말일.
  static KstDate _byCalendar(KstDate basis, int months) {
    final start = startOf(basis);
    final total = start.year * 12 + (start.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = KstDate.daysInMonth(year, month);

    // 해당일이 없다 — 그 달의 말일로 만료한다. **전일을 잡지 않는다.**
    if (start.day > lastDay) return KstDate(year, month, lastDay);
    return KstDate(year, month, start.day).addDays(-1);
  }

  /// 제161조 — 말일이 닫힌 날이면 열리는 날까지 민다.
  ///
  /// 미는 것은 **뒤로만** 한다. 앞으로 당기면 사용자가 늦는다.
  static KstDate rollForward(KstDate due, HolidayRule holidays) {
    var day = due;
    // 한 해를 통째로 닫는 달력은 없다. 무한 반복만 막는다.
    for (var guard = 0; guard < 366 && holidays.isClosed(day); guard++) {
      day = day.addDays(1);
    }
    return day;
  }
}
