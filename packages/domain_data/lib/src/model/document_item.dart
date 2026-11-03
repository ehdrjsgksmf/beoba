import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'enums.dart';
import 'missing_guide.dart';
import 'verification.dart';

part 'document_item.freezed.dart';
part 'document_item.g.dart';

/// 준비할 서류.
@freezed
abstract class DocumentItem with _$DocumentItem implements Verifiable {
  const factory DocumentItem({
    required String id,
    required String label,
    @Default('') String whatIsThis,
    @Default(Importance.medium) Importance importance,
    @Default('') String issuedBy,
    @Default(false) bool onlineAvailable,
    String? hint,
    JsonMap? showIf,

    /// **사용자가 이미 갖고 있는가.** [showIf] 와 다른 축이다.
    ///
    /// ```
    /// showIf  이 서류가 **필요한가**
    /// haveIf  사용자가 **이미 갖고 있는가**
    /// ```
    ///
    /// 둘을 안 나누면 이미 있다고 답한 서류를 「준비하세요」로 다시 내민다 —
    /// 실제로 그러고 있었다. 셋을 갈라야 한다: 필요한데 없는 것 · 필요하고
    /// 있는 것 · 필요 없는 것.
    ///
    /// **없어도 된다.** 모든 서류에 대응하는 질문이 있는 것은 아니다.
    /// 화면은 목록에서 지우지 않고 **표시만** 바꾼다 — 지우면 사용자가
    /// 「내가 뭘 냈더라」를 못 본다.
    JsonMap? haveIf,

    /// 없을 때 할 말. **[haveIf] 가 「없다」로 판정한 서류에만 펼친다.**
    ///
    /// 차용증이 없어서 오는 사람이 이 앱에 제일 많다. 목록만 보여주고 끝내면
    /// 그 사람에게 이 화면은 **못 하는 일의 목록**이다.
    MissingGuide? ifMissing,
    required Verification verification,
  }) = _DocumentItem;

  factory DocumentItem.fromJson(JsonMap json) => _$DocumentItemFromJson(json);
}
