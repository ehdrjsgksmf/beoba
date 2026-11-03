import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'caution.dart';
import 'legal_basis.dart';
import 'verification.dart';

part 'jurisdiction_guide.freezed.dart';
part 'jurisdiction_guide.g.dart';

/// 어디에 내는가. **3층 그대로 담는다.**
///
/// ```
/// 🟢 basis       조문 원문. 우리가 해석한 것이 하나도 없다
/// 🟡 branches    조건 + 결과. 조문을 이 사건에 대어 본 것
/// 🔴 notDecided  우리가 정하지 않는 것. 빈칸으로 두지 않고 이유를 적는다
/// ```
///
/// **법원 이름을 우리가 단정하지 않는다.** 「○○지방법원 △△지원」까지 가려면
/// 관할구역 데이터가 있어야 하고 우리는 그걸 검증하지 않았다. 화면에는
/// 「상대 주소지 또는 내 주소지 관할 법원」까지만 쓰고, 실제 법원은 공식 안내에서
/// 확인하도록 보낸다.
@freezed
abstract class JurisdictionGuide with _$JurisdictionGuide {
  const factory JurisdictionGuide({
    /// 🟢 조문 원문. 요약하지 않는다 — 인용은 손대는 순간 인용이 아니다.
    /// 이 안내를 낼 갈래. **역할이 갈리면 안내도 갈린다** — 갚을 쪽에게
    /// 「어느 법원에 내나요」는 낼 것이 없는 사람에게 하는 말이다.
    JsonMap? showIf,
    @Default(<LegalBasis>[]) List<LegalBasis> basis,

    /// 🟡 조건 + 결과. 자유 문장이 아니라 [Caution] 과 같은 틀이다.
    @Default(<Caution>[]) List<Caution> branches,

    /// 🔴 우리가 정하지 않는 것. **명시적으로 남긴다.**
    @Default(<String>[]) List<String> notDecided,

    /// 실제 법원을 어디서 확인하는지. 주소는 아직 검증 전이라 문구만 둔다.
    @Default('') String lookupNote,

    /// 확인 링크. **검증 전에는 비워 둔다.**
    JsonMap? lookupLink,
    required Verification verification,
  }) = _JurisdictionGuide;

  factory JurisdictionGuide.fromJson(JsonMap json) =>
      _$JurisdictionGuideFromJson(json);
}
