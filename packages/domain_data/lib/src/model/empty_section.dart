import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';

part 'empty_section.freezed.dart';
part 'empty_section.g.dart';

/// **비어 있는 절이 왜 비었는가.**
///
/// ## 왜 필요한가
///
/// `documents: []` 하나가 두 가지를 뜻하고 있었다.
///
/// ```
/// 이 절차에는 따로 챙길 서류가 없다     → 「따로 챙기실 서류는 없어요」
/// 우리가 아직 정리하지 못했다           → 「저희가 아직 정리하지 못했어요」
/// ```
///
/// 데이터가 똑같이 빈 배열이라 화면은 둘을 못 가린다. 안전한 쪽(뒤엣것)으로
/// 내면 **틀리지는 않지만 우리를 실제보다 못하게 보이게 하고**, 사람에게도
/// 쓸모가 없다 — 「없다」를 알면 그걸로 끝인데 「모른다」로 읽히면 계속 찾는다.
///
/// ★ **[Verification.status] 와 같은 성질이다.** 거기서도 「모른다」와
/// 「아니다」를 가른다 — `needsCheck` 는 값이 틀렸다는 뜻이 아니라 **아직
/// 대조를 못 했다**는 뜻이고, 그래서 배지를 달아 그렇다고 말한다.
/// 여기도 같다. **모르는 것을 없다고 하지 않는다.**
@freezed
abstract class EmptySection with _$EmptySection {
  const factory EmptySection({
    required EmptySectionKind kind,

    /// 사람에게 그대로 나가는 한 줄. **비면 빌드 실패.**
    required String why,
  }) = _EmptySection;

  factory EmptySection.fromJson(JsonMap json) => _$EmptySectionFromJson(json);
}

/// 빈 까닭 두 갈래.
enum EmptySectionKind {
  /// **조문에 없다.** 이 절차에는 원래 그것이 없다.
  ///
  /// 이렇게 적으려면 **조문을 보고 없다는 것을 확인했어야 한다.** 안 찾아본
  /// 것을 여기 적으면 그 순간 거짓이 된다.
  @JsonValue('none')
  none,

  /// **우리 쪽 사정이다.** 기본값이다 — 안전한 쪽이 기본이어야 한다.
  ///
  /// 두 가지를 함께 담는다. 갈라 두지 않는 이유는 **화면이 하는 일이 같기
  /// 때문**이다 — 절을 남기고 [EmptySection.why] 를 그대로 낸다.
  ///
  /// ```
  /// 아직 안 채웠다        나중에 채운다. 서류가 대개 그렇다
  /// 우리가 못 센다        채울 계획이 없다. 기한이 그렇다
  ///                      (243·248·250번 — 조문이 그렇게 생겼다)
  /// ```
  ///
  /// **어느 쪽인지는 [EmptySection.why] 가 말한다.** 사람이 읽는 것도 그
  /// 문장이지 이 이름이 아니다.
  @JsonValue('notYet')
  notYet,
}
