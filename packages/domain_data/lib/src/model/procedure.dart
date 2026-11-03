import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'fee_schedule.dart';
import 'legal_basis.dart';
import 'court_term.dart';
import 'verification.dart';

part 'procedure.freezed.dart';
part 'procedure.g.dart';

/// 이 절차가 사다리의 어디쯤인가.
///
/// **순서를 권하려고 두는 것이 아니다.** 「먼저 내용증명, 안 되면 조정」은 그
/// 사건에 대한 판단이다([72번](../../../../DECISIONS.md) · 75번과 같은 자리).
/// 이건 결과 화면의 갈림길이 **「법원까지 가기 전에 할 수 있는 것」과 「법원을
/// 거치는 방법」을 갈라 보여주기 위한** 표시다.
enum ProcedureStage {
  /// 법원에 안 가고 할 수 있는 것. 요구·증거·내용증명·공정증서.
  @JsonValue('before_court')
  beforeCourt,

  /// 법원을 거치는 것. 조정·제소전화해·지급명령·소송·집행.
  @JsonValue('court')
  court,
}

/// **창구에서 그대로 보여 줄 한국어 이름.**
///
/// 한국어를 못 읽는 사람에게 진짜 필요한 것은 번역이 아니라 「한국어로 뭐라고
/// 말해야 하는가」다. 번역문은 검수자가 없으면 못 내지만([233번](../../../../DECISIONS.md)),
/// **이름을 크게 보여 주는 것은 번역이 아니라 표시라서 오역이 날 자리가 없다.**
/// 화면을 창구에 그대로 내밀 수 있다.
///
/// ★ **이름을 지어내지 않는다.** 여기 적는 말은 그 절차가 이미 들고 있는
/// 글(`label`·`whatIsThis`·`detail`·조문 원문) 안에 **글자 그대로** 있어야 한다.
/// 없으면 이 칸을 비운다 — 비면 카드가 안 선다. `verify_domains` 가 본다.
@freezed
abstract class SayThis with _$SayThis {
  const factory SayThis({
    /// 어디로 가는지. 기관 이름.
    required String agency,

    /// 무엇을 내는지. 서식·신청 이름. 확인 안 됐으면 비운다.
    String? form,
  }) = _SayThis;

  factory SayThis.fromJson(JsonMap json) => _$SayThisFromJson(json);
}

/// 절차 한 단계.
@freezed
abstract class Procedure with _$Procedure implements Verifiable {
  const factory Procedure({
    required String id,
    required int step,
    required String label,
    @Default('') String whatIsThis,

    /// 기본은 `court` 다. **넓게 잡는 쪽이 아니라 좁게 잡는 쪽이 안전하다** —
    /// 새 절차를 적으면서 표시를 빠뜨렸을 때 「법원 안 가고 할 수 있어요」
    /// 목록이 저절로 길어지면 안 된다.
    @Default(ProcedureStage.court) ProcedureStage stage,
    String? detail,

    /// 언제 쓰는 절차인지.
    String? whenApplicable,

    /// 주의할 점.
    String? caution,

    /// "저희는 대신 써드리지 않습니다" 같은 고지.
    String? noticeToUser,

    /// 빈 양식 템플릿 id. **AI가 내용을 생성하지 않는다.**
    String? templateId,
    JsonMap? showIf,

    /// showIf 의 숫자 경계를 **이만큼 이하로** 넘었으면 알린다. 원 단위.
    ///
    /// 3,000만원과 3,000만 10원은 밟는 절차가 다르다. 1,500원 때문에 더 복잡한
    /// 절차로 가야 한다는 걸 모르고 진행하면 나중에 되돌릴 수 없다.
    ///
    /// **얼마나 가까워야 가까운 것인지는 분야가 정한다.** 코드에 적으면 분야가
    /// 늘 때마다 코드를 고쳐야 한다. 없으면 알리지 않는다.
    int? nearMissWithin,
    @Default(<String>[]) List<String> costRefs,
    @Default(<String>[]) List<String> deadlineRefs,
    @Default(<String>[]) List<String> documentRefs,
    @Default(<LinkRef>[]) List<LinkRef> officialLinks,

    /// 이 절차에 드는 돈의 **구성**. 총액이 아니다.
    ///
    /// `costRefs` 와 다르다 — 저쪽은 엔진이 계산해 하나의 숫자를 내고,
    /// 이쪽은 **낼 수 없는 것**이다. 우편요금은 무게 구간을, 내용증명은 등본
    /// 매수를 우리가 모른다.
    FeeSchedule? fees,
    LegalBasis? legalBasis,

    /// 창구에서 그대로 보여 줄 한국어 이름. 없으면 그 카드는 안 선다.
    SayThis? sayThis,

    /// 근거가 하나로 안 끝날 때 이어 붙이는 조문 ([Caution.alsoBasis] 와 같다).
    ///
    /// **요건이 든 조문과 돈이 든 조문이 갈라져 있다.** 지급명령을 쓸 수 있는가는
    /// 민사소송법 제462조가 정하고, 이의가 들어와 소송으로 넘어갈 때 인지를 두 번
    /// 내지 않는다는 것은 인지법 제7조 제3항이 정한다. 하나만 달면 나머지는
    /// 화면에서도 법령 매니페스트에서도 사라진다.
    /// **법원이 지키는 처리기간.** 사용자의 기한이 아니라서 [Deadline] 이
    /// 아니다 — D-day 도 「오늘 할 일」도 붙지 않는다(DECISIONS 150번).
    ///
    /// 「언제쯤 답이 오나」는 실제로 사람이 제일 많이 묻는 것이고, 조문에
    /// 적혀 있는데 안 보여주면 우리가 감춘 것이 된다.
    @Default(<CourtTerm>[]) List<CourtTerm> courtTerms,
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,

    /// **이 길을 만드는 법.** [legalBasis] 가 그 법이 아닐 때만 적는다.
    ///
    /// [legalBasis] 는 두 뜻으로 쓰이고 있었다 — 「이 카드의 문장이 기대는
    /// 조문」과 「이 길을 만드는 법」. 대개 같지만 항상은 아니다. 제소전화해
    /// 카드는 인지 5분의 1 을 말하므로 근거가 인지법인데, 제소전화해라는 길을
    /// 만드는 법은 민사소송법이다. **화면에 안 나가던 칸이라 아무도 못
    /// 봤다**(DECISIONS 280번).
    ///
    /// 비어 있으면 [legalBasis] 의 법을 쓴다. 다만 **비어 있는 것이 「같다」는
    /// 판정인지 「안 봤다」인지는 데이터가 모른다** — 그래서 사람이 판정한
    /// 목록을 `review/path_law.json` 에 두고 검사가 맞대 본다. 목록에 없으면
    /// 실패한다.
    LegalBasis? pathLaw,

    /// **이 길을 만드는 법이 없을 때 그 이유.** [Caution.noBasis] 와 같은 꼴이다.
    ///
    /// 빈 문자열은 실패다. 이유가 안 써지면 이유가 아니라 찾을 일이다 —
    /// 「근거 없음 넷」 중 셋은 법이 없는 게 아니라 **우리가 인용을 안 했던
    /// 것**이었다(DECISIONS 281번).
    String? noPathLaw,
    required Verification verification,
  }) = _Procedure;

  factory Procedure.fromJson(JsonMap json) => _$ProcedureFromJson(json);
}
