import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/converters.dart';
import '../common/json_map.dart';
import '../common/kst_date.dart';

part 'holiday.freezed.dart';
part 'holiday.g.dart';

/// 쉬는 날 하나. **우리가 세지 않는다. 받아 적는다.**
@freezed
abstract class Holiday with _$Holiday {
  const factory Holiday({
    @RequiredKstDateConverter() required KstDate date,

    /// 「삼일절」 · 「대체공휴일(삼일절)」
    required String name,

    /// 법정공휴일인지 대체공휴일인지.
    ///
    /// **이름으로 갈랐다. 그건 표기이지 규정이 아니다** — 재계산 대조는
    /// 규정 제3조로 따로 한다.
    required String kind,
  }) = _Holiday;

  factory Holiday.fromJson(JsonMap json) => _$HolidayFromJson(json);
}

/// 한 해의 쉬는 날. `assets/holidays/YYYY.json` 하나에 대응한다.
///
/// **앱은 API 를 부르지 않는다.** 네트워크가 끊긴 사람에게 기한이 안 나오면
/// 안 된다. 커밋된 JSON 이 진짜 데이터다.
@freezed
abstract class HolidayCalendar with _$HolidayCalendar {
  const factory HolidayCalendar({
    required int year,

    /// 어디서 받았는가. 매니페스트의 `source` 와 같은 자리다.
    @Default('') String source,

    /// **언제 받았는가.** 임시공휴일은 국무회의로 그때그때 정해져 늦게 받을수록
    /// 정확하다. 이 날짜가 곧 「어디까지 아는가」다.
    @KstDateConverter() KstDate? fetchedAt,
    @Default(<Holiday>[]) List<Holiday> days,
  }) = _HolidayCalendar;

  factory HolidayCalendar.fromJson(JsonMap json) =>
      _$HolidayCalendarFromJson(json);
}
