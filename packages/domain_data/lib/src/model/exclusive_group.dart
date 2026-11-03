import 'package:freezed_annotation/freezed_annotation.dart';

part 'exclusive_group.freezed.dart';
part 'exclusive_group.g.dart';

/// **한 번에 하나만 맞아야 하는 항목들의 묶음.**
///
/// 소멸시효가 그렇다. 채권 종류마다 시효가 다른데, 종류를 가르는 `showIf` 가
/// 겹치면 **소멸시효 카드가 두 장** 뜬다. 짧은 쪽이 실제 답인데 나란히 보여주면
/// 사용자는 긴 쪽을 믿는다. 반대로 어느 것도 안 맞으면 **시효가 조용히 사라진다.**
///
/// 둘 다 지금 아무도 막지 않고 있었다. 이 묶음이 그 자리다.
///
/// ```json
/// { "id": "statute", "field": "claimType", "unknownValues": ["other"] }
/// ```
///
/// [field] 는 이 묶음이 **무엇을 기준으로 갈리는지**다. 그 필드를 묻는 질문의
/// 선택지를 전부 덮었는지 검사기가 확인한다.
///
/// [unknownValues] 는 **아직 확인하지 못한 값**을 대놓고 적는 자리다. 빠뜨린 것과
/// 모른다고 적은 것은 다르다 — 빠뜨리면 빌드가 깨지고, 적어 두면 화면이
/// 「이 경우는 아직 확인하지 못했어요」라고 말할 수 있다.
@freezed
abstract class ExclusiveGroup with _$ExclusiveGroup {
  const factory ExclusiveGroup({
    required String id,

    /// 이 묶음이 갈리는 기준 필드. `CaseFacts` 의 키이자 어떤 질문의 `field`.
    required String field,

    /// 아직 어느 항목도 맡지 않는 값들. **모른다고 적는 것은 빠뜨린 것이 아니다.**
    @Default(<String>[]) List<String> unknownValues,

    /// 그 값일 때 화면이 할 말. 비어 있으면 화면이 기본 문구를 쓴다.
    @Default('') String unknownNote,
  }) = _ExclusiveGroup;

  factory ExclusiveGroup.fromJson(Map<String, dynamic> json) =>
      _$ExclusiveGroupFromJson(json);
}
