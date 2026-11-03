/// KST(한국 표준시, UTC+9) 기준 **달력 날짜**.
///
/// 시각(시·분·초)도 타임존도 담지 않는다. "2026년 8월 15일" 이라는 사실만 담는다.
/// 모든 기한 계산은 이 타입 위에서 일어난다.
///
/// `DateTime` 을 직접 쓰지 않는 이유:
/// 로컬 타임존에 따라 같은 코드가 다른 날짜를 내놓는 사고를 원천 차단하기 위함.
/// `DateTime` 이 필요한 곳(알림 스케줄러 등)은 [toUtcMidnight] 을 쓴다.
class KstDate implements Comparable<KstDate> {
  const KstDate(this.year, this.month, this.day);

  /// 실제 UTC 시각을 KST 달력 날짜로 바꾼다. `SystemKstClock` 전용.
  factory KstDate.fromUtcInstant(DateTime utcInstant) {
    final kst = utcInstant.toUtc().add(const Duration(hours: kstOffsetHours));
    return KstDate(kst.year, kst.month, kst.day);
  }

  /// `"2026-08-15"` 를 파싱한다. 형식이 어긋나면 [FormatException].
  factory KstDate.parse(String iso) {
    final parsed = tryParse(iso);
    if (parsed == null) {
      throw FormatException('날짜 형식이 YYYY-MM-DD 가 아닙니다', iso);
    }
    return parsed;
  }

  /// UTC 자정으로 표현된 달력 날짜를 되읽는다. ([toUtcMidnight] 의 역)
  const KstDate._calendar(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const int kstOffsetHours = 9;

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// 파싱 실패 시 null. `null` 입력도 `null` 을 돌려준다.
  static KstDate? tryParse(String? iso) {
    if (iso == null) return null;
    final match = _isoPattern.firstMatch(iso.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > daysInMonth(year, month)) return null;
    return KstDate(year, month, day);
  }

  /// 해당 연·월의 일수. 윤년 판정 포함.
  static int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

  KstDate addDays(int days) {
    final shifted = DateTime.utc(year, month, day + days);
    return KstDate._calendar(shifted.year, shifted.month, shifted.day);
  }

  KstDate addWeeks(int weeks) => addDays(weeks * 7);

  /// 월 단위 가산. **말일을 넘기면 그 달의 말일로 클램프한다.**
  ///
  /// 2026-01-31 + 1개월 → 2026-02-28 (2026-03-03 이 아니다)
  KstDate addMonths(int months) {
    final totalMonths = year * 12 + (month - 1) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = totalMonths % 12 + 1;
    final lastDay = daysInMonth(targetYear, targetMonth);
    return KstDate(targetYear, targetMonth, day < lastDay ? day : lastDay);
  }

  /// 연 단위 가산. 2024-02-29 + 1년 → 2025-02-28 (클램프).
  KstDate addYears(int years) => addMonths(years * 12);

  KstDate endOfMonth() => KstDate(year, month, daysInMonth(year, month));

  KstDate startOfMonth() => KstDate(year, month, 1);

  /// 올해의 [month]월 [day]일. `fixed_annual` 계산용.
  KstDate withMonthDay(int month, int day) => KstDate(year, month, day);

  /// `this - other` (일 단위). 미래일수록 양수.
  /// 요일. `DateTime.monday`(1) ~ `DateTime.sunday`(7).
  ///
  /// 민법 제161조가 말일이 토요일이면 익일로 미루라고 하므로 필요하다.
  /// **달력 날짜에서만 나오는 값이라 타임존과 무관하다.**
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// 토요일이나 일요일인가.
  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  int differenceInDays(KstDate other) =>
      toUtcMidnight().difference(other.toUtcMidnight()).inDays;

  /// KST 달력 날짜의 결정적 표현. 타임존 영향을 받지 않는다.
  DateTime toUtcMidnight() => DateTime.utc(year, month, day);

  /// 실제 KST 자정에 해당하는 UTC 시각 (= 전날 15:00Z). 알림 스케줄용.
  DateTime toUtcInstantAtMidnight() =>
      DateTime.utc(year, month, day).subtract(const Duration(hours: kstOffsetHours));

  String toIso() => '${_pad(year, 4)}-${_pad(month, 2)}-${_pad(day, 2)}';

  static String _pad(int value, int width) => value.toString().padLeft(width, '0');

  @override
  int compareTo(KstDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool operator <(KstDate other) => compareTo(other) < 0;
  bool operator <=(KstDate other) => compareTo(other) <= 0;
  bool operator >(KstDate other) => compareTo(other) > 0;
  bool operator >=(KstDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is KstDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
