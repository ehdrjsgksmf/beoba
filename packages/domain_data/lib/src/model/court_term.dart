import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'legal_basis.dart';
import 'verification.dart';

part 'court_term.freezed.dart';
part 'court_term.g.dart';

/// **법원이 지키는 처리기간.** 사용자의 기한이 아니다.
///
/// 이름을 `ProcedureStage` 로 두려다 바꿨다 — `Procedure.stage`
/// (before_court/court)가 이미 그 이름의 enum 이다. 겹친 이름은
/// 나중에 엉뚱한 쪽을 import 하게 만든다.
///
/// ```
/// Deadline            지나면 사용자가 잃는 날            D-day 가 붙고 「오늘 할 일」이 센다
/// Deadline.startsFrom 그날부터 사용자에게 생기는 것      세지 않는다
/// CourtTerm      법원이 움직이는 눈금               둘 다 아니다
/// ```
///
/// 개인파산 예규 제3조·제4조가 그렇다 — 「파산신청일부터 30일 이내에 파산선고
/// 여부를 결정하여야 한다」. **사용자가 할 일이 하나도 없다.** 여기에 D-day 를
/// 붙이면 뭔가 해야 하는 날로 읽히고, 그날 결정이 안 나도 사용자가 잃는 것이
/// 없는데 쫓기게 된다([135번]·[150번](../../../../DECISIONS.md)).
///
/// ## 예외를 함께 낸다
///
/// 눈금만 보여주면 **「가만히 있어도 굴러간다」**로 읽힌다. 예규 제4조는 예외를
/// 다섯 두는데 그중 하나가 「채무자가 절차비용을 예납하지 않은 때」다 —
/// 예납을 안 하면 14일 규칙이 통째로 안 걸린다. 절차가 실제로 멈추는 자리라
/// [exceptWhen] 이 비어 있으면 안 되는 눈금이 있다.
@freezed
abstract class CourtTerm with _$CourtTerm implements Verifiable {
  const factory CourtTerm({
    required String id,

    /// 화면에 나오는 차례.
    required int order,

    /// 「파산선고 여부를 결정해요」 — 법원이 하는 일.
    required String label,

    /// 「파산을 신청한 날부터 30일 안에」 — 언제까지인가.
    ///
    /// **날짜를 계산하지 않는다.** 조문이 말하는 기산점과 일수를 그대로 옮긴다.
    /// 계산해서 날짜를 내면 그건 기한이 되고, 기한이 아니다.
    required String within,

    /// 조문이 적어 둔 예외. 「이 경우에는 이 눈금이 안 걸려요」
    @Default(<String>[]) List<String> exceptWhen,
    JsonMap? showIf,
    LegalBasis? legalBasis,
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,
    required Verification verification,
  }) = _CourtTerm;

  factory CourtTerm.fromJson(JsonMap json) =>
      _$CourtTermFromJson(json);
}
