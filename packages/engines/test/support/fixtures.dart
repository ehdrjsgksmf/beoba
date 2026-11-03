import 'package:domain_data/domain_data.dart';

/// 합성 픽스처. 도메인 JSON 과 무관하게 엔진 동작만 본다.
const Verification verifiedFixture = Verification(
  status: VerificationStatus.verified,
  checkedBy: CheckedBy.self,
);

const Verification needsCheckFixture = Verification(
  status: VerificationStatus.needsCheck,
);

const LegalBasis basisFixture = LegalBasis(
  law: '테스트법',
  article: '제1조',
  text: '테스트용 근거 조문입니다.',
);

Deadline deadlineFixture({
  required String id,
  String label = '테스트 기한',
  Severity severity = Severity.critical,
  String basisField = 'basisDate',
  String? knownDateField,
  int offsetValue = 14,
  TimeUnit offsetUnit = TimeUnit.day,
  CalcRule calcRule = CalcRule.fromBasis,
  int? fixedMonth,
  int? fixedDay,
  JsonMap? showIf,
  List<DeadlineTest> tests = const [],
}) =>
    Deadline(
      id: id,
      label: label,
      severity: severity,
      basisField: basisField,
      knownDateField: knownDateField,
      offset: Offset(value: offsetValue, unit: offsetUnit),
      calcRule: calcRule,
      fixedMonth: fixedMonth,
      fixedDay: fixedDay,
      showIf: showIf,
      legalBasis: basisFixture,
      verification: verifiedFixture,
      tests: tests,
    );

CostItem costFixture({
  required String id,
  String label = '테스트 비용',
  required CostFormula formula,
  List<CostModifier> modifiers = const [],
  JsonMap? showIf,
}) =>
    CostItem(
      id: id,
      label: label,
      formula: formula,
      modifiers: modifiers,
      showIf: showIf,
      verification: verifiedFixture,
      tests: const [CostTest(input: {}, expected: 0)],
    );

DocumentItem documentFixture({
  required String id,
  String label = '테스트 서류',
  Importance importance = Importance.medium,
  JsonMap? showIf,
}) =>
    DocumentItem(
      id: id,
      label: label,
      importance: importance,
      issuedBy: '테스트 기관',
      showIf: showIf,
      verification: verifiedFixture,
    );

JurisdictionRule jurisdictionFixture({
  required String id,
  String inputField = 'debtorAddress',
  String lookupTable = 'court_by_district',
}) =>
    JurisdictionRule(
      id: id,
      label: '관할 법원',
      inputField: inputField,
      lookupTable: lookupTable,
      rule: '채무자 주소지 관할',
      verification: verifiedFixture,
    );

Question questionFixture({
  required String id,
  required int order,
  required String field,
  int weight = 2,
  bool isRequired = true,
  QuestionType type = QuestionType.single,
  JsonMap? showIf,
  List<QuestionOption> options = const [],
}) =>
    Question(
      id: id,
      order: order,
      text: '$field 를 알려주세요',
      whyAsk: '절차를 고르는 데 필요합니다.',
      type: type,
      field: field,
      weight: weight,
      isRequired: isRequired,
      showIf: showIf,
      options: options,
    );

Domain domainFixture({
  String id = 'test_domain',
  List<Question> intake = const [],
  List<Deadline> deadlines = const [],
  List<CostItem> costs = const [],
  List<DocumentItem> documents = const [],
  List<JurisdictionRule> jurisdiction = const [],
  List<LimitRule> limitRules = const [],
  List<HardStop> hardStops = const [],
  ScoringConfig? scoring,
  DomainDetect? detect,
}) =>
    Domain(
      id: id,
      name: '테스트 분야',
      intake: intake,
      deadlines: deadlines,
      costs: costs,
      documents: documents,
      jurisdiction: jurisdiction,
      limitRules: limitRules,
      hardStops: hardStops,
      scoring: scoring,
      detect: detect,
    );
