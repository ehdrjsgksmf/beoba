import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'verification.dart';

part 'missing_guide.freezed.dart';
part 'missing_guide.g.dart';

/// 그 서류 대신 쓸 수 있는 것.
///
/// **「이것들이면 충분합니다」로 쓰지 않는다.** 증거로 인정되는지는 법원이
/// 정한다 — 우리가 할 수 있는 말은 「자료가 될 수 있어요」까지다.
@freezed
abstract class MissingAlternative with _$MissingAlternative implements Verifiable {
  const factory MissingAlternative({
    required String id,
    required String label,
    @Default('') String whatIsThis,
    required Verification verification,
  }) = _MissingAlternative;

  factory MissingAlternative.fromJson(JsonMap json) =>
      _$MissingAlternativeFromJson(json);
}

/// 그 서류를 구하는 법. **절차 사실만 적는다.**
///
/// 「은행에서 발급받을 수 있어요」는 사실이고, 「그러면 증거가 됩니다」는 판단이다.
@freezed
abstract class MissingSource with _$MissingSource implements Verifiable {
  const factory MissingSource({
    required String id,
    required String label,

    /// 어디서. 「거래하신 은행」
    @Default('') String where,
    required Verification verification,
  }) = _MissingSource;

  factory MissingSource.fromJson(JsonMap json) => _$MissingSourceFromJson(json);
}

/// **자료가 없을 때 할 말.**
///
/// 원칙이 둘이고 이 안내는 그 사이에 있다.
///
/// ```
/// 「자료가 없으면 안 됩니다」로 끝내지 않는다   → 그건 앱이 문을 닫는 것
/// 「이렇게 하면 됩니다」로 단정하지 않는다      → 그건 우리 선을 넘는 것
/// ```
///
/// **「없다」로 판정된 서류에만 펼친다.** 아직 답을 안 한 사람에게 없다고
/// 단정하는 것은 그 자체로 틀린 말이다 — 그래서 「모른다」에는 안 펼친다.
@freezed
abstract class MissingGuide with _$MissingGuide {
  const factory MissingGuide({
    @Default(<MissingAlternative>[]) List<MissingAlternative> alternatives,
    @Default(<MissingSource>[]) List<MissingSource> howToGet,

    /// 하나도 없을 때. **「어렵습니다」는 쓰되 「못 받습니다」로 끝내지 않는다.**
    @Default('') String ifNoneAtAll,

    /// [ifNoneAtAll] 이 가리키는 절차 id.
    ///
    /// **같은 말을 두 번 하지 않는다.** 공정증서의 조건(「상대가 동의해야」·
    /// 「강제집행을 승낙한다는 취지가 적혀 있어야」)은 그 절차가 이미 들고 있다.
    /// 여기서는 가리키기만 하고 화면이 그 절차의 `caution` 을 그대로 보여준다.
    String? seeProcedure,

    /// [ifNoneAtAll] 과 이 안내 전체의 바닥값.
    required Verification verification,
  }) = _MissingGuide;

  factory MissingGuide.fromJson(JsonMap json) => _$MissingGuideFromJson(json);
}
