import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/converters.dart';
import '../common/json_map.dart';
import '../common/kst_date.dart';
import 'broker.dart';
import 'caution.dart';
import 'channels.dart';
import 'cost_item.dart';
import 'deadline.dart';
import 'document_item.dart';
import 'domain_detect.dart';
import 'empty_section.dart';
import 'enums.dart';
import 'exclusive_group.dart';
import 'hard_stop.dart';
import 'jurisdiction_guide.dart';
import 'jurisdiction_rule.dart';
import 'legal_basis.dart';
import 'limit_rule.dart';
import 'limitation_rule.dart';
import 'procedure.dart';
import 'question.dart';
import 'resource.dart';
import 'welfare_bridge.dart';

part 'domain.freezed.dart';
part 'domain.g.dart';

/// 분야 하나. **분야는 코드가 아니라 데이터다.**
///
/// 분야를 추가할 때는 JSON 파일만 추가한다. 엔진 코드는 건드리지 않는다.
@freezed
abstract class Domain with _$Domain {
  const factory Domain({
    required String id,
    @Default('0.0.0') String version,
    @Default(1) int schemaVersion,
    required String name,
    String? shortName,
    String? icon,
    String? description,

    /// **사람이 실제로 쓰는 낱말들.** 이름의 두 번째 층이다.
    ///
    /// [name] 은 상황을 그리는 우리 말이고(「갑자기 나가라고 했을 때」),
    /// 이것은 사람이 찾을 때 치는 말이다(「부당해고」·「권고사직」).
    /// **한 낱말로 둘을 다 하려 하면 따뜻하지도 않고 찾히지도 않는다**
    /// (DECISIONS 194번).
    ///
    /// 앞의 셋만 화면에 보이고 나머지는 데이터에만 남는다 — 홈이 길어지면
    /// 안내가 아니라 목록이 된다. 보이든 안 보이든 **걸림말로는 전부 쓴다.**
    ///
    /// **여기 있는 낱말은 이름표이지 판정이 아니다.** 「자진 퇴사」는 여기
    /// 있고 우리 문장에는 없어야 한다 — 금지어는 문장을 막는 것이지 낱말을
    /// 막는 것이 아니다(195번).
    @Default(<String>[]) List<String> searchTerms,

    /// 홈 목록에서의 자리. **작을수록 위다.**
    ///
    /// 기준은 하나 — **되돌릴 수 없는 것이 위로.** 다만 그 기준을 화면에
    /// 적지 않는다. 「급한 순서예요」라고 쓰면 자기 것이 아래에 있는 사람이
    /// 덜 급한 줄로 읽는다(196번).
    @Default(100) int homeOrder,
    @Default(DomainStatus.active) DomainStatus status,

    /// 마지막 검수일. 180일이 지나면 앱 시작 시 경고.
    @KstDateConverter() KstDate? lastVerifiedAt,
    String? verifiedBy,
    String? note,

    /// **비어 있는 절이 왜 비었는지.** 열쇠는 그 절의 이름이다 —
    /// `deadlines` · `documents` · `costs` · `jurisdiction`.
    ///
    /// 「원래 없다」와 「우리가 아직 안 했다」를 가르는 자리다. 없으면
    /// 화면과 글이 안전한 쪽(「아직 정리하지 못했어요」)으로 나간다 —
    /// 틀리지는 않지만 정확하지도 않다. [EmptySection] 을 보라.
    @Default(<String, EmptySection>{}) Map<String, EmptySection> emptySections,
    ScoringConfig? scoring,
    @Default(<Question>[]) List<Question> intake,
    @Default(<Deadline>[]) List<Deadline> deadlines,

    /// 한 번에 하나만 맞아야 하는 항목 묶음. 겹침·빠짐을 검사기가 막는다.
    @Default(<ExclusiveGroup>[]) List<ExclusiveGroup> exclusiveGroups,

    /// 「이런 일이 있었으면 달라질 수 있다」는 안내. **계산하지 않는다.**
    @Default(<Caution>[]) List<Caution> cautions,

    /// **기간을 어떻게 세는지**의 근거 조문.
    ///
    /// 답변서 30일 · 이의신청 2주 · 소멸시효가 전부 같은 규칙을 받는데, 그 규칙
    /// 자체(민법 157·159·160·161)를 근거로 갖는 항목이 없었다. 기한마다 붙이면
    /// 같은 조문이 여러 번 나오므로 **분야에 한 번** 둔다.
    ///
    /// 분야마다 다를 수 있어서 공용이 아니라 분야 소속이다 — 행정 기간은 민법이
    /// 아니라 다른 법이 정한다.
    @Default(<LegalBasis>[]) List<LegalBasis> periodRules,

    /// 소멸시효. **계산하지 않고 갈래로 낸다.**
    @Default(<LimitationRule>[]) List<LimitationRule> limitationRules,
    @Default(<DocumentItem>[]) List<DocumentItem> documents,
    @Default(<CostItem>[]) List<CostItem> costs,

    /// 비용을 **갈래마다 따로** 계산하기 위한 가정. 비어 있으면 한 벌만 낸다.
    @Default(<CostScenario>[]) List<CostScenario> costScenarios,
    @Default(<JurisdictionRule>[]) List<JurisdictionRule> jurisdiction,

    /// 어디에 내는가. 3층 그대로 담는다. 법원 이름은 우리가 단정하지 않는다.
    JurisdictionGuide? jurisdictionGuide,

    /// 자유 입력에서 이 분야를 알아채는 규칙. 없으면 알아채지 않는다.
    DomainDetect? detect,

    /// 이 분야가 드는 묶음의 id. **칸이 하나뿐이다.**
    ///
    /// 한 분야는 한 묶음에만 든다. 묶음 쪽에 분야 목록을 적으면 같은 분야가
    /// 두 군데 실릴 수 있고, 그러면 **사람이 목록을 안 믿는다.** 칸을 하나만
    /// 두면 중복이 구조로 불가능하다 — 검사로 막는 것보다 못 만들게 하는
    /// 쪽이 낫다.
    ///
    /// 「그럼 못 찾으면 어떡하나」는 홈의 자유 입력이 받는다. 걸림말
    /// (`searchTerms`)이 이미 거기 있다.
    String? group,

    /// **법률과 복지가 만나는 자리.** 없으면 이 분야에는 복지 입구가 안 선다.
    ///
    /// 복지로는 사용자가 왜 왔는지 모른다. 우리는 안다 — 임금이 밀렸다는 것을
    /// 이미 알고 있으니 그 사람에게 걸리는 제도를 바로 놓을 수 있다.
    ///
    /// **다만 짐작으로 잇지 않는다.** 잇는 기준은 제도 쪽 근거법령
    /// (`baslawList`)과 여기 적은 법령 이름이 맞는가 하나뿐이다.
    /// 주제가 비슷해 보인다는 이유로는 안 잇는다 — 그건 우리가 만든 안내가 된다.
    WelfareBridge? welfareBridge,
    @Default(<Procedure>[]) List<Procedure> procedures,
    @Default(<Resource>[]) List<Resource> resources,
    @Default(<BrokerAlert>[]) List<BrokerAlert> brokerAlerts,
    @Default(<BrokerChecklist>[]) List<BrokerChecklist> brokerChecklists,
    @Default(<LookupTool>[]) List<LookupTool> lookupTools,
    @Default(<LimitRule>[]) List<LimitRule> limitRules,
    @Default(<HardStop>[]) List<HardStop> hardStops,
    @PublicChannelEntryConverter()
    @Default(<PublicChannelEntry>[])
    List<PublicChannelEntry> publicChannels,

    /// 아직 어느 길로 갈지 못 정한 사람에게 보여줄 창구 id.
    ///
    /// 결과 화면 갈림길의 세 번째가 이걸 쓴다. **둘만 두면 못 정한 사람이 갈
    /// 곳이 없고, 그 사람이 이 앱에 제일 많이 온다.**
    ///
    /// 위기 신호(`autoTriggers`)와 다르다 — 저쪽은 낱말이 걸려야 뜨고, 이쪽은
    /// **아무 일이 없어도** 뜬다. 창구를 코드에 적지 않으려고 여기 둔다.
    @Default(<String>[]) List<String> askFirstChannels,
    @Default(<AutoTrigger>[]) List<AutoTrigger> autoTriggers,
    @Default(<PhoneRiskRule>[]) List<PhoneRiskRule> phoneRiskRules,

    /// **쉬운 한국어 한 벌.** 없으면 원래 문장이 그대로 나간다.
    ///
    /// 키는 그 문장이 사는 자리다 — `cautions.ct_x.consequence` 처럼
    /// [ContentValidator] 가 쓰는 경로와 같은 꼴이고, 값이 그 자리를 대신할
    /// 쉬운 문장이다.
    ///
    /// **한 벌로 모아 두는 이유** — 문장마다 `xxxPlain` 을 달면 쉬운 말이
    /// 분야 전체에 흩어져서 한눈에 못 읽는다. 검수하는 사람은 원래 문장과
    /// 쉬운 문장을 **나란히 놓고** 봐야 하고, 그러려면 한 벌이 한 자리에
    /// 있어야 한다. 켜고 끄는 것도 통째로 된다.
    ///
    /// ★ **조문 원문은 이 벌에 들어올 수 없다.** `legalBasis.text` 같은
    /// 자리를 가리키는 키는 `SchemaValidator` 가 막는다. 기관 이름과 서식
    /// 이름도 마찬가지다 — 창구에서 그 말을 그대로 써야 한다.
    @Default(<String, String>{}) Map<String, String> plain,

    /// ★ **40자 규칙을 그 자리에서만 놓아 주는 곳.** 키는 [plain] 의 키이고
    /// 값은 **왜 놓아 주는지**다.
    ///
    /// 40자는 수단이지 목적이 아니다. 목적은 「한국어가 서툰 분이 읽을 수
    /// 있게」이고 거기서 주범은 어려운 낱말이다. 열거를 담은 문장은 40자
    /// 아래로 쪼개려면 서술어를 되풀이해야 해서 **쪼갤수록 길어진다** —
    /// 수단을 지키려다 목적을 잃는 자리다(DECISIONS 265번).
    ///
    /// **이유가 비어 있으면 실패한다.** 일부러 놓아 준 것과 그냥 긴 것은
    /// 데이터에서 똑같이 생겼다 — 한 줄을 요구해야 그 둘이 갈린다
    /// (`expectsEveryDomain` 의 `skipped` 와 같은 꼴이다).
    @Default(<String, String>{}) Map<String, String> plainLongOk,
  }) = _Domain;

  factory Domain.fromJson(JsonMap json) => _$DomainFromJson(json);
}

/// 인터뷰 판정 임계값. **코드에 박지 않는다. JSON에서 읽는다.**
@freezed
abstract class ScoringConfig with _$ScoringConfig {
  const factory ScoringConfig({
    required int greenThreshold,
    required int yellowThreshold,

    /// 필수 항목 확보 비율 (yellow 판정 기준).
    @Default(0.7) double requiredFieldRatio,
  }) = _ScoringConfig;

  factory ScoringConfig.fromJson(JsonMap json) => _$ScoringConfigFromJson(json);
}

extension DomainLookup on Domain {
  /// `_shared_crisis.json` 처럼 전체 객체로 들어온 창구만 모은다.
  Iterable<PublicChannel> get resolvedChannels =>
      publicChannels.whereType<PublicChannelFull>().map((e) => e.channel);

  PublicChannel? channelById(String id) {
    for (final entry in publicChannels) {
      if (entry is PublicChannelFull && entry.channel.id == id) {
        return entry.channel;
      }
    }
    return null;
  }

  Deadline? deadlineById(String id) => _firstOrNull(deadlines, (d) => d.id == id);
  CostItem? costById(String id) => _firstOrNull(costs, (c) => c.id == id);
  DocumentItem? documentById(String id) =>
      _firstOrNull(documents, (d) => d.id == id);
  Question? questionById(String id) => _firstOrNull(intake, (q) => q.id == id);

  static T? _firstOrNull<T>(List<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
