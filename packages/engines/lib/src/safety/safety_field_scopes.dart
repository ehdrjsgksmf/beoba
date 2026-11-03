import 'safety_filter.dart';

/// 어느 필드가 어느 scope 로 검사되는지. **코드에 고정한다.**
///
/// JSON 에서 안전장치를 끌 수 없어야 하므로 데이터에 두지 않는다.
/// 여기 없는 필드는 전부 [SafetyScope.strict].
///
/// `quote` 는 사기꾼 멘트를 원문 그대로 보여주기 위한 최소한의 면제이고,
/// `SchemaValidator` 가 해당 항목에 `verification` 을 강제한다.
const Map<String, SafetyScope> kFieldScopes = <String, SafetyScope>{
  // ② 방어 — 상대가 하는 말과 그에 대한 사실 확인
  'BrokerAlert.phrase': SafetyScope.quote,
  'BrokerAlert.truth': SafetyScope.quote,
  'BrokerChecklist.items': SafetyScope.quote,
  'BrokerChecklist.thresholdMessage': SafetyScope.quote,
  'ChecklistAsk.why': SafetyScope.quote,

  // 법정 상한 안내문 — 법이 정한 결과를 그대로 옮긴다
  'LimitRule.message': SafetyScope.quote,
  'ThresholdRule.message': SafetyScope.quote,

  // 근거 조문 원문 — 법률 조문을 고쳐 쓸 수는 없다
  'LegalBasis.text': SafetyScope.quote,

  // 창구에서 그대로 보여 줄 이름. **우리가 지은 말이 아니다.**
  //
  // 기관 이름과 서식 이름은 그 기관이 붙인 이름이라 인용이다. 쉬운 말로도
  // 안 바꾸고 금지어로도 안 고친다 — 창구에서 그 말을 그대로 써야 한다.
  // 면제가 아니다. 인용에서도 막는 말은 그대로 막는다.
  'SayThis.agency': SafetyScope.quote,
  'SayThis.form': SafetyScope.quote,

  // ④ 기관이 알려 준 것 — 복지제도 안내문.
  //
  // 조문이 아니라 **기관이 정리해 준 말**이라 원문 그대로 옮긴다. 「중위소득
  // 100% 이하」가 그렇다 — `100%` 는 strict 금지어지만 여기서는 소득 기준이지
  // 성공률 단정이 아니다. 그래서 `quote` 다.
  //
  // **면제가 아니다.** 인용에서도 막는 말은 그대로 막는다. 실제로 한 건이
  // 걸려서 안 들어왔다 (DECISIONS 199번).
  'PublicWelfareService.name': SafetyScope.quote,
  'PublicWelfareService.summary': SafetyScope.quote,
  'PublicWelfareService.org': SafetyScope.quote,
  'PublicWelfareService.site': SafetyScope.quote,
  'PublicWelfareService.contact': SafetyScope.quote,
  'PrivateWelfareService.org': SafetyScope.quote,
  'PrivateWelfareService.name': SafetyScope.quote,
  'PrivateWelfareService.purpose': SafetyScope.quote,
  'PrivateWelfareService.target': SafetyScope.quote,
  'PrivateWelfareService.benefit': SafetyScope.quote,
  'PrivateWelfareService.howToApply': SafetyScope.quote,
  'PrivateWelfareService.documents': SafetyScope.quote,
  'PrivateWelfareService.etc': SafetyScope.quote,
  'CentralWelfareService.name': SafetyScope.quote,
  'CentralWelfareService.summary': SafetyScope.quote,
  'CentralWelfareService.org': SafetyScope.quote,
  'CentralWelfareService.contact': SafetyScope.quote,
  'CentralWelfareService.target': SafetyScope.quote,
  'CentralWelfareService.criteria': SafetyScope.quote,
  'CentralWelfareService.benefit': SafetyScope.quote,
  'CentralWelfareService.ministry': SafetyScope.quote,
  'CentralWelfareService.cycle': SafetyScope.quote,
  'CentralWelfareService.provision': SafetyScope.quote,
  // 신청방법·문의처·홈페이지·구비서식 한 줄. 이름도 값도 기관이 적은 말이다.
  'WelfareLink.name': SafetyScope.quote,
  'WelfareLink.value': SafetyScope.quote,
  // 「○○에서 알려 준 내용이에요」의 기관 이름. 우리 문장 안에 들어가지만
  // 낱말 자체는 기관이 붙인 이름이다.
  'AgencyNotice.agency': SafetyScope.quote,
};

SafetyScope scopeFor(String typeName, String fieldName) =>
    kFieldScopes['$typeName.$fieldName'] ?? SafetyScope.strict;
