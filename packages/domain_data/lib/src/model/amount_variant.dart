import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'amount_variant.freezed.dart';
part 'amount_variant.g.dart';

/// 조문이 **각 호로 나눠 둔 갈래** 하나.
///
/// ## 왜 문장이 아니라 줄인가
///
/// 소액임차인 금액이 그렇다. 주택임대차보호법 시행령 제10조 제1항과 제11조가
/// **각 호의 구분 문언을 글자 하나까지 똑같이** 적어 두고, 한쪽은 「그중 얼마를
/// 먼저 받는가」를, 다른 쪽은 「보증금이 얼마 이하인 사람인가」를 정한다.
///
/// 이걸 한 문단으로 풀어 쓰면 구분이 **두 벌**이 된다. 개정이 나서 한쪽만
/// 고치면 아무도 못 잡는다. 그래서 [label] 을 한 곳에 두고 두 조문이 같은 것을
/// 가리키게 한다.
///
/// ## label 은 조문 원문이다
///
/// 「과밀억제권역(서울특별시는 제외한다)」처럼 어렵더라도 **줄이지 않는다.**
/// 이 문언이 곧 어느 칸인지를 정하는 규칙이고, 우리가 다듬는 순간 그건 우리가
/// 만든 구분이 된다. 쉬운 말은 [detail] 쪽이다.
///
/// 그리고 검증기가 이 [label] 을 읽는다 — 구분의 이름이 **다른 법령에서 온
/// 것**이면(「수도권정비계획법」에 따른 …) 그 법령을 갖고 있어야 금액이
/// 화면에 나간다(DECISIONS 152번).
@freezed
abstract class AmountVariant with _$AmountVariant {
  const factory AmountVariant({
    /// 「1호」·「2호」. 조문에서 부르는 이름.
    required String key,

    /// 이 갈래를 가리키는 **조문의 말.** 원문 그대로.
    required String label,

    /// 화면에 낼 한 줄. 금액이 여기 들어 있다.
    ///
    /// **두 조문을 짝으로 낸다** — 「보증금이 ○○ 이하면, 그중 △△까지」.
    /// 한쪽만 내면 자격을 못 보거나 받을 금액을 못 본다.
    required String detail,
  }) = _AmountVariant;

  factory AmountVariant.fromJson(JsonMap json) =>
      _$AmountVariantFromJson(json);
}
