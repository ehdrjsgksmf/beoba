import 'kst_date.dart';

/// 날짜를 어디까지 아는가.
enum DatePrecision {
  /// 며칠인지까지 안다.
  day,

  /// 몇 월인지까지 안다.
  month,

  /// 몇 년인지만 안다.
  year,
}

/// **정밀도를 값이 직접 들고 다니는 날짜.**
///
/// 사람은 날짜를 "날" 이 아니라 "월" 로 기억한다. "3월쯤이었나…" 를 정확한 날짜로
/// 강요하면 사용자는 아무 날이나 찍고, 그 날짜에서 나온 기한이 확신에 찬 얼굴로
/// 나온다. **확신에 찬 거짓이 가장 나쁜 결과다.**
///
/// 그래서 「정확히 모른다」를 정식 입력값으로 받는다. 그리고 **보정하지 않는다** —
/// 월 중간이나 월말로 채워 넣으면 앱이 사실을 만든다. `2023-03` 은 끝까지
/// `2023-03` 으로 남고, [earliest]·[latest] 는 계산할 때 파생될 뿐이다.
///
/// ## 저장 형식은 ISO 축약
///
/// ```
/// 2023-03-15   day
/// 2023-03      month
/// 2023         year
/// ```
///
/// 표준이고, 문자열이라 `CaseFacts` 와 JSONLogic 을 그대로 통과하며, 자릿수만 보면
/// 정밀도를 알 수 있다.
///
/// ## 연도는 반드시 안다
///
/// [year] 는 nullable 이 아니다. 연도를 모르면 어떤 계산도 못 한다 —
/// 그건 어림값이 아니라 **답하지 않은 것**이다.
class ApproxDate implements Comparable<ApproxDate> {
  const ApproxDate(this.year, [this.month, this.day])
      : assert(month != null || day == null, '월을 모르는데 일을 알 수는 없다');

  /// 정확히 아는 날짜.
  ApproxDate.exact(KstDate date) : this(date.year, date.month, date.day);

  final int year;

  /// 모르면 null.
  final int? month;

  /// 모르면 null.
  final int? day;

  /// `"2023"` · `"2023-03"` · `"2023-03-15"` 를 읽는다. 형식이 어긋나면 null.
  static ApproxDate? tryParse(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();

    final full = KstDate.tryParse(trimmed);
    if (full != null) return ApproxDate.exact(full);

    final monthMatch = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(trimmed);
    if (monthMatch != null) {
      final year = int.parse(monthMatch.group(1)!);
      final month = int.parse(monthMatch.group(2)!);
      if (month < 1 || month > 12) return null;
      return ApproxDate(year, month);
    }

    final yearMatch = RegExp(r'^(\d{4})$').firstMatch(trimmed);
    if (yearMatch != null) return ApproxDate(int.parse(yearMatch.group(1)!));

    return null;
  }

  DatePrecision get precision {
    if (day != null) return DatePrecision.day;
    if (month != null) return DatePrecision.month;
    return DatePrecision.year;
  }

  bool get isExact => precision == DatePrecision.day;

  /// 정확할 때만 값이 있다. **어림값을 날짜인 척 내주지 않는다.**
  KstDate? get exact => isExact ? KstDate(year, month!, day!) : null;

  /// 이 값이 가리킬 수 있는 가장 이른 날.
  KstDate get earliest => KstDate(year, month ?? 1, day ?? 1);

  /// 이 값이 가리킬 수 있는 가장 늦은 날.
  KstDate get latest {
    if (day != null) return KstDate(year, month!, day!);
    if (month != null) {
      return KstDate(year, month!, KstDate.daysInMonth(year, month!));
    }
    return KstDate(year, 12, 31);
  }

  /// 저장·전송 형식. [tryParse] 의 역이다.
  String toIso() {
    final y = year.toString().padLeft(4, '0');
    if (month == null) return y;
    final m = month!.toString().padLeft(2, '0');
    if (day == null) return '$y-$m';
    return '$y-$m-${day!.toString().padLeft(2, '0')}';
  }

  /// 정밀도를 낮춘다. 되돌릴 수 없다 — 낮춘 값에서 원래 날짜를 알 수 없다.
  ApproxDate coarsen(DatePrecision to) => switch (to) {
        DatePrecision.day => this,
        DatePrecision.month => ApproxDate(year, month),
        DatePrecision.year => ApproxDate(year),
      };

  /// 이른 쪽부터. 같은 시작이면 넓은 쪽이 뒤에 온다.
  @override
  int compareTo(ApproxDate other) {
    final byStart = earliest.compareTo(other.earliest);
    if (byStart != 0) return byStart;
    return latest.compareTo(other.latest);
  }

  @override
  bool operator ==(Object other) =>
      other is ApproxDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
