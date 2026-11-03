import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/converters.dart';
import '../common/json_map.dart';
import '../common/kst_date.dart';

part 'welfare.freezed.dart';
part 'welfare.g.dart';

/// **네 번째 층 — 「기관이 알려 준 것」.**
///
/// 🟢 법에 있는 내용 · 🟡 적용될 가능성 · 🔴 확인 안 된 것, 그 셋 **어디에도
/// 들어가지 않는다.** 조문이 아니기 때문이다. 복지제도의 지원대상·금액·신청방법은
/// 법령에도 근거가 있지만 우리가 손에 쥔 것은 조문이 아니라 **기관이 정리해 준
/// 안내문**이다. 원문 대조를 하지 않았고 할 수도 없다.
///
/// 이걸 🟢 옆에 두면 그 자리에서 「법에 적힌 것만 말한다」가 깨진다. 사용자는 두
/// 카드를 같은 무게로 읽는다. 그래서 층을 따로 판다.
///
/// [sentence] 를 화면에 **반드시** 함께 낸다. 이 층에서 출처와 날짜를 빼면
/// 남는 것은 근거 없는 단정이다.
@freezed
abstract class AgencyNotice with _$AgencyNotice {
  const AgencyNotice._();

  const factory AgencyNotice({
    /// 알려 준 기관. 공공은 소관부처명, 민간은 그 기관 이름.
    required String agency,

    /// 마지막 확인일. **우리가 확인한 날이 아니라 기관이 고친 날**이다.
    @RequiredKstDateConverter() required KstDate checkedAt,

    /// [checkedAt] 이 이 항목의 날짜인가, 자료 전체의 날짜인가.
    required NoticeDateScope dateScope,

    /// 자료 이름. 「한국사회보장정보원_복지서비스정보」.
    required String dataset,
  }) = _AgencyNotice;

  factory AgencyNotice.fromJson(JsonMap json) => _$AgencyNoticeFromJson(json);

  /// 화면에 반드시 함께 나가는 한 줄.
  ///
  /// **문장을 여기서만 만든다.** 화면마다 조립하면 어느 화면이 날짜를 빼먹었는지
  /// 알 수 없게 된다 — `YellowBlock` 에서 이미 겪은 일이다.
  ///
  /// **`switch` 로 쓴다.** 예전에는 삼항이라 [NoticeDateScope] 에 값을 더하면
  /// 새 값이 조용히 「자료 전체 기준」으로 떨어졌다. 값이 늘 때 컴파일이
  /// 멈춰야 한다.
  String get sentence => switch (dateScope) {
        NoticeDateScope.record => '법에 적힌 게 아니라 $agency에서 알려 준 '
            '내용이에요. 마지막 확인 ${checkedAt.toIso()}.',
        NoticeDateScope.dataset => '법에 적힌 게 아니라 $agency에서 알려 준 '
            '내용이에요. 마지막 확인 ${checkedAt.toIso()} (자료 전체 기준).',
        NoticeDateScope.visited => '법에 적힌 게 아니라 $agency에서 알려 준 '
            '내용이에요. ${checkedAt.toIso()}에 저희가 보고 옮겼어요.',
      };
}

/// [AgencyNotice.checkedAt] 이 무엇의 날짜인가.
///
/// **둘을 같은 말로 쓰지 않는다.** 공공 자료는 행마다 최종수정일이 따로 있고,
/// 민간 자료에는 그런 칸이 아예 없어 자료를 내려받은 날 하나뿐이다. 없는 칸을
/// 있는 것처럼 적으면 「이 사업은 그날 확인됐다」는 거짓이 된다.
enum NoticeDateScope {
  /// 이 항목의 날짜. 공공 자료의 `최종수정일`.
  @JsonValue('record')
  record,

  /// 자료 전체의 날짜. 민간 자료에는 항목별 날짜가 없다.
  @JsonValue('dataset')
  dataset,

  /// **우리가 그 안내를 보고 옮긴 날.**
  ///
  /// 기관 홈페이지의 안내문에는 「기관이 고친 날」이 아예 없는 것이 많다.
  /// 신용회복위원회 채무조정 안내가 그렇다 — 페이지에 날짜가 없다.
  /// 없는 칸을 있는 것처럼 적을 수 없으니 **우리가 본 날**을 적고, 그것이
  /// 우리가 본 날이라는 것도 함께 적는다.
  ///
  /// **[record]·[dataset] 과 뜻이 다르다.** 저 둘은 기관 쪽 날짜이고
  /// 이것은 우리 쪽 날짜다. 같은 칸에 넣되 말은 갈라 둔다.
  @JsonValue('visited')
  visited,
}

/// 중앙부처 복지서비스 한 건. **목록과 링크까지만이다.**
///
/// 이 자료에는 나이·지역·소득 같은 **매칭 축이 없다.** 서비스명·한 줄 요약·
/// 복지로 링크가 전부다. 그래서 우리는 「당신은 대상입니다」를 말할 수 없고,
/// 말하지 않는다 — 이름을 보여주고 복지로로 보낸다.
@freezed
abstract class PublicWelfareService with _$PublicWelfareService {
  const factory PublicWelfareService({
    /// 원자료의 서비스아이디. `WLF00000022`.
    required String id,
    required String name,

    /// 한 줄 요약. 원문 그대로.
    required String summary,

    /// 복지로 상세 링크.
    required String url,

    /// 소관부처명.
    required String ministry,

    /// 소관조직명.
    @Default('') String org,

    /// 원자료의 `사이트` 칸. **기관 이름과 주소가 붙어 있는 채로 온다** —
    /// 「근로복지공단https://www.comwel.or.kr」. 갈라 놓지 않았다. 가르려면
    /// 문장을 고쳐 쓰는 셈이고, 어디까지가 이름인지 자료가 말해 주지 않는다.
    @Default('') String site,

    /// 원자료의 `대표문의` 칸. [site] 와 같은 이유로 붙어 있는 채로 둔다.
    @Default('') String contact,

    /// 기준연도.
    required int baseYear,
    required AgencyNotice notice,
  }) = _PublicWelfareService;

  factory PublicWelfareService.fromJson(JsonMap json) =>
      _$PublicWelfareServiceFromJson(json);
}

/// 민간 복지서비스 한 건. 지원대상·지원내용·신청방법·제출서류가 있다.
///
/// ## 빈 축을 「해당 없음」으로 읽지 않는다
///
/// 세 축([lifeStages] · [households] · [topics]) 은 자주 비어 있다. 비어 있는
/// 것은 **그 기관이 안 적었다**는 뜻이지 「아무에게도 해당 없다」가 아니다.
/// 빈 축을 불일치로 처리하면 축을 하나만 골라도 목록의 3분의 1이 사라진다 —
/// 사라지는 쪽은 대상을 좁게 적지 않은 기관, 즉 **누구나 신청해 볼 수 있는
/// 사업**들이다. 그래서 [matches] 는 빈 축을 통과시킨다.
///
/// 대신 [unstatedAxes] 에 안 적힌 축의 이름을 남긴다. 화면은 「이 기관은
/// 대상 나이를 적지 않았어요」라고 말할 수 있어야 한다.
@freezed
abstract class PrivateWelfareService with _$PrivateWelfareService {
  const PrivateWelfareService._();

  const factory PrivateWelfareService({
    /// `기관명|사업명` 에서 만든 고정 id. 자료의 줄 순서에 기대지 않는다.
    required String id,
    required String org,
    required String name,
    @Default('') String purpose,
    @Default('') String target,
    @Default('') String benefit,
    @Default('') String howToApply,
    @Default('') String documents,
    @Default('') String etc,

    /// 사업시작일·사업종료일. **문자열 그대로 둔다.**
    ///
    /// 종료일에 `2099-12-31` · `9999-12-31` 이 섞여 있다. 자료가 「상시」를
    /// 그렇게 적은 것인데, 우리가 그렇게 읽어서 「상시 모집」이라고 바꿔 적으면
    /// 그건 해석이다. 날짜 계산에 쓰지 않으므로 [KstDate] 로 만들지도 않는다.
    @Default('') String periodFrom,
    @Default('') String periodTo,
    @Default(<String>[]) List<String> lifeStages,
    @Default(<String>[]) List<String> households,
    @Default(<String>[]) List<String> topics,

    /// 기관이 안 적은 축의 이름. `["생애주기", "가구상황"]`.
    @Default(<String>[]) List<String> unstatedAxes,
    required AgencyNotice notice,
  }) = _PrivateWelfareService;

  factory PrivateWelfareService.fromJson(JsonMap json) =>
      _$PrivateWelfareServiceFromJson(json);

  /// 고른 축에 걸리는가. **빈 축은 통과시킨다** (위 설명 참조).
  bool matches({
    Set<String> lifeStages = const {},
    Set<String> households = const {},
    Set<String> topics = const {},
  }) =>
      welfareAxisHits(this.lifeStages, lifeStages) &&
      welfareAxisHits(this.households, households) &&
      welfareAxisHits(this.topics, topics);
}

/// 축 한 칸이 고른 것에 걸리는가. **빈 축은 통과시킨다** (DECISIONS 200번).
///
/// **두 자료가 같은 규칙을 써야 한다.** 민간과 중앙부처가 각자 판단하면
/// 어느 한쪽만 빈 축을 걸러 내게 되고, 그러면 같은 화면에서 「안 적힌 것」이
/// 자료에 따라 다르게 취급된다.
///
/// ```
/// picked 가 비었다   거르지 않는다 — 사용자가 그 축을 안 골랐다
/// mine 이 비었다     통과시킨다 — 기관이 안 적었다. 「해당 없음」이 아니다
/// 둘 다 있다         겹치는 이름이 하나라도 있으면 통과
/// ```
bool welfareAxisHits(List<String> mine, Set<String> picked) =>
    picked.isEmpty || mine.isEmpty || mine.any(picked.contains);

/// 구워진 복지 자료 한 벌. **두 자료를 한 목록으로 합치지 않는다.**
///
/// 공공은 링크까지만이고 민간은 축이 있다. 합치면 화면이 둘을 같은 것으로
/// 그리게 되고, 그 순간 「목록뿐인 것」과 「조건이 적힌 것」의 차이가 사라진다.
@freezed
abstract class PublicWelfareCatalog with _$PublicWelfareCatalog {
  const factory PublicWelfareCatalog({
    required String dataset,
    required String source,

    /// 자료를 내려받은 판본의 날짜. 파일 이름에 적힌 날이다.
    @RequiredKstDateConverter() required KstDate releasedAt,

    /// **아직 안 들여온 조각의 이름.** 있는 그대로 적어 둔다.
    String? openPart,

    /// **물러난 자료다. 화면에 한 줄도 안 그린다.**
    ///
    /// 중앙부처 API 목록이 이 자료를 대신한다 — 겹치는 362건은 API 가 상세를
    /// 갖고 있어서 API 가 이긴다. 그런데 **CSV 에만 있는 5건은 지울 수 없다.**
    /// 없어진 제도인지 API 목록이 빠뜨린 것인지 확인할 방법이 없고, 지우면
    /// 후자일 때 영영 잃는다(DECISIONS 235번).
    ///
    /// 표시를 데이터에 두는 이유는 하나다 — **파일이 살아 있기 때문**이다.
    /// 살아 있는 목록을 다음 사람이 보면 화면에 올리고 싶어진다.
    @Default(false) bool retired,

    /// 물러난 이유. 화면에 안 나간다. 데이터를 읽는 사람에게 쓴다.
    String? retiredWhy,
    @Default(<PublicWelfareService>[]) List<PublicWelfareService> services,
    @Default(<WelfareExclusion>[]) List<WelfareExclusion> excluded,
  }) = _PublicWelfareCatalog;

  factory PublicWelfareCatalog.fromJson(JsonMap json) =>
      _$PublicWelfareCatalogFromJson(json);
}

@freezed
abstract class PrivateWelfareCatalog with _$PrivateWelfareCatalog {
  const factory PrivateWelfareCatalog({
    required String dataset,
    required String source,
    @RequiredKstDateConverter() required KstDate releasedAt,
    String? openPart,
    @Default(<PrivateWelfareService>[]) List<PrivateWelfareService> services,
    @Default(<WelfareExclusion>[]) List<WelfareExclusion> excluded,
  }) = _PrivateWelfareCatalog;

  factory PrivateWelfareCatalog.fromJson(JsonMap json) =>
      _$PrivateWelfareCatalogFromJson(json);
}

/// 구울 때 뺀 항목. **뺐다는 사실을 자료 안에 남긴다.**
///
/// 콘솔에만 찍고 넘어가면 다음 사람은 367건이 다 들어온 줄 안다.
@freezed
abstract class WelfareExclusion with _$WelfareExclusion {
  const factory WelfareExclusion({
    required String id,
    required String name,
    required String field,
    required String reason,
  }) = _WelfareExclusion;

  factory WelfareExclusion.fromJson(JsonMap json) =>
      _$WelfareExclusionFromJson(json);
}

/// 이름과 링크 한 쌍. 신청방법·문의처·홈페이지·구비서식이 다 이 모양으로 온다.
///
/// **[value] 를 링크라고 부르지 않는다.** 원자료의 칸 이름은 `servSeDetailLink`
/// 인데, 실제로 들어오는 것은 주소일 때도 있고 전화번호일 때도 있고
/// 「거주지 읍/면/동 주민센터에서 신청」 같은 **문장**일 때도 있다. 링크라고
/// 이름 붙이면 화면이 그걸 눌러야 하는 것으로 그린다.
@freezed
abstract class WelfareLink with _$WelfareLink {
  const WelfareLink._();

  const factory WelfareLink({
    required String name,
    @Default('') String value,
  }) = _WelfareLink;

  factory WelfareLink.fromJson(JsonMap json) => _$WelfareLinkFromJson(json);

  /// 눌러서 갈 수 있는 자리인가.
  bool get isUrl => value.startsWith('http://') || value.startsWith('https://');
}

/// 중앙부처 복지서비스 한 건. **API 로 받은 것이라 CSV 판보다 깊다.**
///
/// CSV(`PublicWelfareService`)에는 이름과 요약과 링크뿐이었다. 상세 API 에는
/// 지원대상·선정기준·지원내용·신청방법·구비서식, 그리고 **근거법령**이 있다.
/// 그래서 모델을 따로 둔다 — 같은 자료의 다음 판이 아니라 **다른 깊이**다.
@freezed
abstract class CentralWelfareService with _$CentralWelfareService {
  const CentralWelfareService._();

  const factory CentralWelfareService({
    /// 원자료의 `servId`. `WLF00000024`.
    required String id,
    required String name,

    /// 한 줄 요약 (`servDgst`).
    @Default('') String summary,

    /// 복지로 상세 링크 (`servDtlLink`).
    @Default('') String url,

    /// 소관부처 (`jurMnofNm`) · 소관조직 (`jurOrgNm`).
    required String ministry,
    @Default('') String org,
    @Default('') String contact,

    /// **상세를 받았는가.** 안 받았으면 이름·요약·복지로 링크까지만 있다.
    ///
    /// 목록 API 는 한 번에 다 받지만 상세는 건마다 한 번씩 불러야 하고,
    /// 한도가 창당 100회다. 그래서 **우리 사용자에게 닿는 주제부터**
    /// 받는다([priority]). 상세가 없는 건은 **지운 것이 아니라 아직 안
    /// 받은 것**이고, 화면은 요약과 링크까지만 낸다.
    @Default(false) bool detailFetched,

    /// 받는 차례. 1 · 2 · 0(맨 뒤). **자료가 아니라 우리 판단이다.**
    ///
    /// 어느 주제가 우리 사용자에게 닿느냐는 자료가 말해 주지 않는다.
    /// 적어 두면 나중에 「왜 이건 상세가 없지」를 자료만 보고 알 수 있다.
    @Default(0) int priority,

    /// 지원대상 (`tgtrDtlCn`) · 선정기준 (`slctCritCn`) · 지원내용 (`alwServCn`).
    @Default('') String target,
    @Default('') String criteria,
    @Default('') String benefit,
    @Default(<WelfareLink>[]) List<WelfareLink> howToApply,
    @Default(<WelfareLink>[]) List<WelfareLink> inquiries,
    @Default(<WelfareLink>[]) List<WelfareLink> homepages,
    @Default(<WelfareLink>[]) List<WelfareLink> forms,

    /// **근거법령 이름** (`baslawList`). 우리 매니페스트와 이어질 자리다.
    ///
    /// 지금은 이름만 담는다. 잇는 것은 다음 일이다 — 표기가 달라 못 맞춘 것이
    /// 몇 건인지부터 세어야 한다(`CentralWelfareCatalog.unmatchedLaws`).
    @Default(<String>[]) List<String> laws,

    /// **이 건의 기준연도** (`crtrYr`). 제도마다 다르다.
    int? baseYear,

    /// 지원주기 (`sprtCycNm`) · 제공유형 (`srvPvsnNm`).
    @Default('') String cycle,
    @Default('') String provision,

    /// 온라인 신청이 되는가 (`onapPsbltYn`).
    ///
    /// **주민센터에 못 가는 사람에게는 이것이 갈림길이다.** 몸이 아프거나
    /// 일을 못 빼거나 아이를 맡길 데가 없는 사람에게 「집에서 되는가」는
    /// 다른 어떤 축보다 실제적이다.
    @Default(false) bool onlineApply,

    /// 복지로에서 이 제도를 몇 번 봤는가 (`inqNum`).
    ///
    /// **우리가 매긴 점수가 아니다.** 사람들이 실제로 많이 찾아본 순서이고,
    /// 기준연도는 대부분 같아서 「최신순」으로는 목록이 안 갈린다.
    /// 이걸로 세울 때는 **무엇으로 세웠는지 화면에 적는다** — 안 적으면
    /// 왜 이 순서인지 아무도 모른다.
    @Default(0) int views,
    @Default(<String>[]) List<String> lifeStages,
    @Default(<String>[]) List<String> households,
    @Default(<String>[]) List<String> topics,
    @Default(<String>[]) List<String> unstatedAxes,
    required AgencyNotice notice,
  }) = _CentralWelfareService;

  factory CentralWelfareService.fromJson(JsonMap json) =>
      _$CentralWelfareServiceFromJson(json);

  /// 고른 축에 걸리는가. [PrivateWelfareService.matches] 와 **같은 규칙**이다.
  bool matches({
    Set<String> lifeStages = const {},
    Set<String> households = const {},
    Set<String> topics = const {},
  }) =>
      welfareAxisHits(this.lifeStages, lifeStages) &&
      welfareAxisHits(this.households, households) &&
      welfareAxisHits(this.topics, topics);
}

/// 중앙부처 자료 한 벌.
@freezed
abstract class CentralWelfareCatalog with _$CentralWelfareCatalog {
  const CentralWelfareCatalog._();

  const factory CentralWelfareCatalog({
    required String dataset,
    required String source,

    /// **자료를 받은 날.** 이 API 에는 항목별 최종수정일 칸이 없다.
    @RequiredKstDateConverter() required KstDate releasedAt,

    /// 어느 오퍼레이션에서 받았나. **키는 안 적는다.**
    @Default(<String>[]) List<String> operations,

    /// 목록 API 가 말한 전체 건수. [services] 는 이만큼 다 담는다.
    @Default(0) int totalCount,

    /// 그중 **상세까지 받은** 건수. 나머지는 이름·요약·링크까지만 있다.
    @Default(0) int detailFetchedCount,
    String? openPart,
    @Default(<CentralWelfareService>[]) List<CentralWelfareService> services,
    @Default(<WelfareExclusion>[]) List<WelfareExclusion> excluded,

    /// **안 받기로 한 법령 이름.** 「받아야 할 목록」이 아니다.
    ///
    /// 매니페스트에 없는 이름들인데, 대부분은 표기가 달라서가 아니라
    /// **애초에 우리 분야가 아니어서** 없다 — 기초연금법·노인복지법 같은
    /// 복지 전용 법령은 받아도 우리 법률 분야와 안 이어진다. 139개가
    /// 200개가 되면 **매주 판본 대조가 무너진다**(DECISIONS 205번).
    ///
    /// 버리지는 않는다. 버리면 몇 건이 새는지 아무도 모른다.
    @Default(<String>[]) List<String> lawsNotTaken,

    /// 왜 안 받는가. 목록만 남기면 다음 사람이 「받아야 하나」로 읽는다.
    @Default('') String lawsNotTakenWhy,

    /// 매니페스트에 이미 있는 법령 이름. **우리 분야와 복지가 만나는 자리다.**
    ///
    /// 임금채권보장법 · 법률구조법 · 서민의 금융생활 지원에 관한 법률이
    /// 그렇다. 경계에 있는 법이고, 이어 붙일 자리도 거기부터다.
    @Default(<String>[]) List<String> matchedLaws,
  }) = _CentralWelfareCatalog;

  factory CentralWelfareCatalog.fromJson(JsonMap json) =>
      _$CentralWelfareCatalogFromJson(json);

  /// 목록 머리에 나가는 한 줄. **기관 이름을 하나로 못 적는다.**
  ///
  /// 이 자료는 건마다 소관부처가 다르다 — 461건에 112곳이다. 머리에 한 곳을
  /// 적으면 나머지 111곳이 그 이름으로 덮인다. 그래서 「각 기관」이라고 적고,
  /// **건마다의 이름은 각 항목의 [AgencyNotice] 가 말한다.**
  ///
  /// [AgencyNotice.sentence] 와 마찬가지로 문장은 여기서만 만든다.
  String get sentence => '법에 적힌 게 아니라 각 기관이 알려 준 내용이에요. '
      '자료 받은 날 ${releasedAt.toIso()}.';
}
