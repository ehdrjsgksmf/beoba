import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'verification.dart';

part 'fee_schedule.freezed.dart';
part 'fee_schedule.g.dart';

/// 값이 정해진 요금 한 줄. **총액을 만들지 않는다.**
///
/// [CostItem] 과 다른 자리다. 저쪽은 산식이 있어 하나의 숫자가 나오고, 이쪽은
/// **나오지 않는다** — 몇 장을 쓰는지, 무게가 얼마인지를 우리가 모른다.
/// 모르는 것을 더해서 하나의 숫자로 내놓으면 그건 계산이 아니라 짐작이다.
@freezed
abstract class FeePart with _$FeePart {
  const factory FeePart({
    /// 「등기」 · 「내용증명」
    required String label,

    /// 정해진 값. 범위면 비운다.
    int? amount,

    /// 범위의 아래·위. 무게 구간처럼 우리가 못 고르는 자리.
    int? amountFrom,
    int? amountTo,

    /// 「무게에 따라」 · 「등본 1매 초과 매당 650원」
    @Default('') String note,

    /// 함께 할 수도, 안 할 수도 있는 것. 배달증명이 그렇다.
    @Default(false) bool optional,
  }) = _FeePart;

  factory FeePart.fromJson(JsonMap json) => _$FeePartFromJson(json);
}

/// 요금표. **더하지 않고 늘어놓기만 한다.**
///
/// 사다리의 앞쪽 칸(내용증명·공증)은 소송보다 훨씬 싸다. 그 사실이 숫자로
/// 보여야 「법원까지 안 가도 되는 길」이 실제로 있다는 말이 힘을 얻는다.
/// 그런데 총액은 낼 수 없다 — 장수가 우편요금 구간과 등본 매수를 **동시에**
/// 움직인다. 그래서 구성만 보여주고 [totalNote] 로 왜 안 더하는지 말한다.
@freezed
abstract class FeeSchedule with _$FeeSchedule {
  const factory FeeSchedule({
    @Default(<FeePart>[]) List<FeePart> parts,

    /// **총액을 적는 자리가 아니다.** 무엇에 따라 달라지는지 적는다.
    @Default('') String totalNote,
    required Verification verification,
  }) = _FeeSchedule;

  factory FeeSchedule.fromJson(JsonMap json) => _$FeeScheduleFromJson(json);
}
