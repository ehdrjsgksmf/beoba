import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/json_map.dart';
import 'amount_variant.dart';
import 'enums.dart';
import 'legal_basis.dart';
import 'verification.dart';
import 'welfare.dart';

part 'caution.freezed.dart';
part 'caution.g.dart';

/// **「이런 일이 있었으면 달라질 수 있다」는 안내.** 계산하지 않는다.
///
/// 시효 중단이 그렇다. 내용증명을 보냈는지, 그것이 최고에 해당하는지, 6개월 안에
/// 다음 조치를 했는지 — 전부 **사실관계 평가**라 이 앱이 하지 않기로 한 종류의
/// 판단이다.
///
/// 틀리는 방향도 비대칭이다. 「중단됐습니다」가 틀리면 사용자는 안심하고 기다리다
/// **권리를 영구히 잃는다.**
///
/// 그런데 우리는 이미 유혹의 재료를 다 갖고 있다 — `q_demanded` · `q_demand_date`.
/// 재료가 있으니 **선을 데이터 구조로 박아 둔다.** 이 항목은 날짜를 바꾸지 못한다.
/// 할 수 있는 것은 조건을 보고 한 줄 띄우는 것뿐이다.
///
/// ## 자유 문장이 아니다
///
/// [condition] 과 [consequence] 로 나눠 받는다. 🟡 를 자유 문장으로 두지 않기로 한
/// 규칙 그대로다 — 자유 문자열로 조립하는 경로가 없으면 「단정하지 마라」를 정규식으로
/// 검사할 필요가 없다.
@freezed
abstract class Caution with _$Caution implements Verifiable {
  const factory Caution({
    required String id,

    /// 언제 띄울지. `showIf` 와 같은 것이지 판단이 아니다 —
    /// 요구한 적 없는 사람에게 요구 얘기를 안 하는 것뿐이다.
    JsonMap? showIf,

    /// 화면에서의 무게. 기본은 그 자리에 얹는 것이다.
    ///
    /// **[AlertDisplay.stop] 은 되돌릴 수 없는 자리에만 쓴다.** 상속에서
    /// 고인의 통장에 손대면 단순승인으로 볼 수 있고, 그건 되돌릴 수 없다
    /// (민법 제1026조 제1호). 물음 버튼 뒤에 접어 두면 누르지 않은 사람이
    /// 그대로 저지른다.
    ///
    /// 브로커 경보와 **같은 enum 을 쓴다** — 화면에서의 무게는 같은 축이다.
    @Default(AlertDisplay.inline) AlertDisplay display,

    /// 「내용증명을 보내셨나요?」 — 화면의 물음 버튼에 그대로 쓴다.
    ///
    /// 예전에는 [condition] 을 그대로 펼쳐 놓아서, 해당 없는 사람도 모든 안내를
    /// 지나쳐 내려가야 했다. 자기에게 해당하는 것만 눌러 보게 한다.
    ///
    /// **조각 문장을 버튼에 넣지 않는다.** [condition] 은 조건절이라 그대로
    /// 물음이 되지 않고, 화면이 어미를 붙이면 「하셨다면라면」이 다시 나온다.
    ///
    /// **상태를 단정하지 않는다.** 「대부업자이신가요?」가 아니라 「빌려주는 일을
    /// 업으로 하시나요?」다 — 위기 문구 규칙과 같다. 대부업자인지는 판단이다.
    ///
    /// `cautions[]` 에서는 **비면 빌드가 깨진다**(`schema_validator`).
    /// `jurisdictionGuide.branches` 는 물음이 아니라 갈래라서 요구하지 않는다.
    @Default('') String question,

    /// 「내용증명을 보내셨다면」
    required String condition,

    /// 「그것만으로는 …할 수 있어요. 아래 창구에서 확인해 보세요.」
    ///
    /// **단정하지 않는다. 날짜를 바꾸지 않는다. 창구로 보낸다.**
    required String consequence,

    /// **서류에서 눈으로 확인할 것.** 우리가 못 세는 값이다.
    ///
    /// 하드스톱에 있던 것을 그대로 물려받았다. 사건번호도 원고·피고도 종이에만
    /// 있고 우리는 묻지 않는다 — 「확인하세요」가 우리가 할 수 있는 전부다.
    /// 기한처럼 **셀 수 있는 것은 여기 두지 않는다.** 세어서 위에 낸다.
    @Default(<String>[]) List<String> checklist,

    /// **조문이 각 호로 나눠 둔 갈래.** 표로 내고 본인이 찾게 한다.
    ///
    /// 지역·유형에 따라 금액이 갈리는데 **우리가 어느 칸인지 못 고르는**
    /// 자리가 있다. 소액임차인이 그렇다 — 과밀억제권역이 동·읍면으로
    /// 갈려서 시·군 답 하나로는 칸이 안 정해진다(DECISIONS 149번).
    ///
    /// 그때 묻지 않고 네 줄을 그대로 낸다. 압류 금액에서 「월급을 묻지 말고
    /// 표로 내라」고 한 것과 같은 자리다.
    @Default(<AmountVariant>[]) List<AmountVariant> variants,

    /// 이어 볼 공적 창구 id.
    @Default(<String>[]) List<String> channels,
    LegalBasis? legalBasis,

    /// 근거가 하나로 안 끝날 때 이어 붙이는 조문.
    ///
    /// **숫자가 든 조문과 효과가 든 조문이 갈라져 있는 경우가 흔하다.** 연 60% 는
    /// 대부업법 시행령에 있고, 그래서 계약이 무효가 된다는 말은 대부업법 본문에
    /// 있다. 하나만 달면 나머지는 `verification.source` 로 내려가고 **법령
    /// 매니페스트에서 사라진다** — 개정이 나도 아무도 모른다.
    ///
    /// 순서는 사람이 읽을 순서다. [legalBasis] 가 먼저 나오고 이것이 뒤따른다.
    @Default(<LegalBasis>[]) List<LegalBasis> alsoBasis,

    /// **기관이 알려 준 것.** 조문이 없는 자리를 이것이 대신한다.
    ///
    /// 우리가 조문으로 못 닫는 것을 기관은 아는 경우가 있다. 전세사기 특별법
    /// 부칙 제20956호 제2조의 「이 법」이 특별법 전체인지 그 개정분인지가
    /// 그렇다 — 조문만으로 안 닫히고, 국토교통부는 안다.
    ///
    /// ★ **이 층은 🟢 옆에 서지 않는다.** 조문을 대조한 적이 없고 대조할 원문도
    /// 우리에게 없다. 화면에서 회색 딱지([AgencyNoticeLine])로 나가고 문장은
    /// [AgencyNotice.sentence] 한 곳에서만 만든다.
    ///
    /// `BrokerAlert` · `PublicChannel` · `LimitRule` 이 이미 갖고 있던 칸을
    /// 여기에도 연 것이다(DECISIONS 274번).
    AgencyNotice? notice,

    /// **법에 대해 아무 말도 안 하는 카드**라고 적는 자리. 값은 **왜 그런지**다.
    ///
    /// 카드는 [legalBasis] · [alsoBasis] · [notice] 가운데 하나는 있어야 한다.
    /// 셋 다 없으면 남는 것은 **근거 없는 단정**이다. 그런데 그 셋이 다 필요
    /// 없는 카드가 실제로 있다 — 「법원 서류를 받았는데 어떻게 하나요?」처럼
    /// **창구로 보내기만 하는 카드**다. 그런 카드는 법에 대해 아무 주장도 안 한다.
    ///
    /// ★ **이유가 비어 있으면 실패한다.** 일부러 비운 것과 빠뜨린 것은 데이터에서
    /// 똑같이 생겼다(`plainLongOk` 와 같은 꼴이다).
    ///
    /// ★★ **이것을 적고 법 이야기를 하면 실패한다.** 「법에」·「조문」·「적혀
    /// 있어요」 같은 말이 우리 문장에 있으면, 그 카드는 법에 대해 말하는 것이고
    /// 근거가 있어야 한다. 이유를 지어내서 통과시키는 길을 막는다(272번).
    String? noBasis,
    required Verification verification,
  }) = _Caution;

  factory Caution.fromJson(JsonMap json) => _$CautionFromJson(json);
}
