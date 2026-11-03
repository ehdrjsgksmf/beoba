import 'dart:convert';

import 'package:meta/meta.dart';

import '../common/json_map.dart';
import '../common/kst_date.dart';
import '../model/amount_variant.dart';
import '../model/broker.dart';
import '../model/caution.dart';
import '../model/channels.dart';
import '../model/cost_item.dart';
import '../model/deadline.dart';
import '../model/document_item.dart';
import '../model/domain.dart';
import '../model/enums.dart';
import '../model/hard_stop.dart';
import '../model/jurisdiction_rule.dart';
import '../model/legal_basis.dart';
import '../model/limit_rule.dart';
import '../model/procedure.dart';
import '../model/court_term.dart';
import '../model/question.dart';
import '../model/resource.dart';
import '../model/verification.dart';
import '../validate/schema_issue.dart';
import '../validate/schema_validator.dart';
import 'load_report.dart';

/// `unverified` 항목을 어떻게 다룰지.
enum VerificationPolicy {
  /// 기본값. 로더에서 제거한다. **UI 도달 금지.**
  dropUnverified,

  /// 제거하지 않는다. `tests[]` 골든 하네스처럼 계산 정확성만 볼 때 쓴다.
  ///
  /// **화면 코드에서 쓰면 검수되지 않은 법률 정보가 사용자에게 도달한다.**
  /// 테스트·검증 도구 밖에서 쓰면 분석기가 경고한다.
  @visibleForTesting
  keepAll,
}

/// 도메인 JSON → [Domain].
///
/// 순서가 곧 안전장치다:
/// 1. 파싱 전 원본 검사 (필수 필드 누락을 알아볼 수 있는 메시지로)
/// 2. 파싱
/// 3. **`unverified` 제거**
/// 4. 끊긴 참조 정리
/// 5. 남은 항목 검증 (critical 은 verified 여야 함)
class DomainLoader {
  DomainLoader({
    this.policy = VerificationPolicy.dropUnverified,
    this.validator = const SchemaValidator(),
    this.today,
  });

  final VerificationPolicy policy;
  final SchemaValidator validator;

  /// 있으면 `lastVerifiedAt` 경과 경고를 함께 낸다.
  final KstDate? today;

  LoadReport? _lastReport;

  /// 마지막 [loadFromMap] 결과 기록.
  LoadReport get lastReport {
    final report = _lastReport;
    if (report == null) {
      throw StateError('아직 로드하지 않았습니다');
    }
    return report;
  }

  Domain loadFromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('도메인 JSON 의 최상위는 객체여야 합니다');
    }
    return loadFromMap(Map<String, dynamic>.from(decoded));
  }

  Domain loadFromMap(JsonMap json) {
    final domainId = json['id'] as String? ?? '(unknown)';
    final report = LoadReport(domainId: domainId);
    _lastReport = report;

    final rawIssues = validator.validateRaw(json);
    _throwIfErrors(domainId, rawIssues, report);

    final parsed = Domain.fromJson(json);
    final filtered = _dropUnverified(parsed, report);
    final pruned = _freeze(_pruneDanglingRefs(filtered, report));

    // 묶음 검사는 **거르기 전** 데이터에 돌린다. unverified 를 걷어낸 뒤에 보면
    // 아직 확인 안 된 항목이 빠뜨린 항목으로 둔갑한다.
    final issues = validator.checkExclusiveGroups(parsed);
    issues.addAll(validator.validate(
      pruned,
      today: today,
      enforceCriticalVerified: policy == VerificationPolicy.dropUnverified,
    ));
    _throwIfErrors(domainId, issues, report);

    return pruned;
  }

  void _throwIfErrors(String domainId, List<SchemaIssue> issues, LoadReport report) {
    report.warnings.addAll(issues.where((i) => !i.isError));
    if (issues.any((i) => i.isError)) {
      throw DomainValidationException(domainId, issues);
    }
  }

  // ── 3. unverified 제거 ─────────────────────────────────────────────

  Domain _dropUnverified(Domain domain, LoadReport report) {
    if (policy == VerificationPolicy.keepAll) return domain;

    List<T> keep<T extends Verifiable>(List<T> items, String listName) =>
        _filterVerifiable(items, listName, report);

    return domain.copyWith(
      intake: domain.intake.where((question) {
        final status = question.verification?.status;
        if (status == VerificationStatus.unverified) {
          report.removed.add(
            RemovedItem(list: 'intake', id: question.id, reason: 'unverified'),
          );
          return false;
        }
        return true;
      }).toList(),
      deadlines: keep<Deadline>(domain.deadlines, 'deadlines'),
      documents: keep<DocumentItem>(domain.documents, 'documents'),
      costs: keep<CostItem>(domain.costs, 'costs'),
      jurisdiction: keep<JurisdictionRule>(domain.jurisdiction, 'jurisdiction'),
      procedures: keep<Procedure>(domain.procedures, 'procedures'),
      resources: keep<Resource>(domain.resources, 'resources'),
      brokerAlerts: keep<BrokerAlert>(domain.brokerAlerts, 'brokerAlerts'),
      brokerChecklists:
          keep<BrokerChecklist>(domain.brokerChecklists, 'brokerChecklists'),
      lookupTools: keep<LookupTool>(domain.lookupTools, 'lookupTools'),
      limitRules: keep<LimitRule>(domain.limitRules, 'limitRules'),
      publicChannels: domain.publicChannels.where((entry) {
        if (entry is PublicChannelFull &&
            entry.channel.verification.status == VerificationStatus.unverified) {
          report.removed.add(
            RemovedItem(
              list: 'publicChannels',
              id: entry.id,
              reason: 'unverified',
            ),
          );
          return false;
        }
        return true;
      }).toList(),
    );
  }

  List<T> _filterVerifiable<T extends Verifiable>(
    List<T> items,
    String listName,
    LoadReport report,
  ) {
    final kept = <T>[];
    for (final item in items) {
      if (item.verification.status == VerificationStatus.unverified) {
        report.removed.add(
          RemovedItem(list: listName, id: item.id, reason: 'unverified'),
        );
        continue;
      }
      kept.add(item);
    }
    return kept;
  }

  // ── 4. 끊긴 참조 정리 ──────────────────────────────────────────────

  Domain _pruneDanglingRefs(Domain domain, LoadReport report) {
    if (policy == VerificationPolicy.keepAll) return domain;

    final costIds = domain.costs.map((c) => c.id).toSet();
    final deadlineIds = domain.deadlines.map((d) => d.id).toSet();
    final documentIds = domain.documents.map((d) => d.id).toSet();

    final procedures = domain.procedures.map((procedure) {
      final costRefs = _prune(procedure.costRefs, costIds, report,
          'procedures.${procedure.id}.costRefs');
      final deadlineRefs = _prune(procedure.deadlineRefs, deadlineIds, report,
          'procedures.${procedure.id}.deadlineRefs');
      final documentRefs = _prune(procedure.documentRefs, documentIds, report,
          'procedures.${procedure.id}.documentRefs');
      return procedure.copyWith(
        costRefs: costRefs,
        deadlineRefs: deadlineRefs,
        documentRefs: documentRefs,
      );
    }).toList();

    return domain.copyWith(procedures: procedures);
  }

  // ── 5. 컬렉션 잠그기 ──────────────────────────────────────────────

  /// 로드가 끝난 도메인의 컬렉션을 수정 불가로 만든다.
  ///
  /// freezed 설정(`make_collections_unmodifiable: false`)과 무관하게 여기서 보장한다.
  /// 화면 코드가 모델을 들고 다니다 실수로 `add`·`remove` 하는 것을 런타임에 막는다.
  /// 자세한 배경은 `DECISIONS.md` 1번.
  Domain _freeze(Domain domain) => domain.copyWith(
        searchTerms: List<String>.unmodifiable(domain.searchTerms),
        intake: List<Question>.unmodifiable(
          domain.intake.map(
            (q) => q.copyWith(options: List<QuestionOption>.unmodifiable(q.options)),
          ),
        ),
        deadlines: List<Deadline>.unmodifiable(
          domain.deadlines.map(
            (d) => d.copyWith(
              notify: List<int>.unmodifiable(d.notify),
              tests: List<DeadlineTest>.unmodifiable(d.tests),
              alsoBasis: List<LegalBasis>.unmodifiable(d.alsoBasis),
            ),
          ),
        ),
        documents: List<DocumentItem>.unmodifiable(domain.documents),
        costs: List<CostItem>.unmodifiable(
          domain.costs.map(
            (c) => c.copyWith(
              modifiers: List<CostModifier>.unmodifiable(c.modifiers),
              tests: List<CostTest>.unmodifiable(c.tests),
            ),
          ),
        ),
        costScenarios: List<CostScenario>.unmodifiable(domain.costScenarios),
        jurisdiction: List<JurisdictionRule>.unmodifiable(domain.jurisdiction),
        procedures: List<Procedure>.unmodifiable(
          domain.procedures.map(
            (p) => p.copyWith(
              costRefs: List<String>.unmodifiable(p.costRefs),
              deadlineRefs: List<String>.unmodifiable(p.deadlineRefs),
              documentRefs: List<String>.unmodifiable(p.documentRefs),
              officialLinks: List<LinkRef>.unmodifiable(p.officialLinks),
              alsoBasis: List<LegalBasis>.unmodifiable(p.alsoBasis),
              courtTerms: List<CourtTerm>.unmodifiable(p.courtTerms),
            ),
          ),
        ),
        resources: List<Resource>.unmodifiable(
          domain.resources.map(
            (r) => r.copyWith(
              eligibility: List<EligibilityRule>.unmodifiable(r.eligibility),
            ),
          ),
        ),
        cautions: List<Caution>.unmodifiable(
          domain.cautions.map(
            (c) => c.copyWith(
              checklist: List<String>.unmodifiable(c.checklist),
              variants: List<AmountVariant>.unmodifiable(c.variants),
              channels: List<String>.unmodifiable(c.channels),
              alsoBasis: List<LegalBasis>.unmodifiable(c.alsoBasis),
            ),
          ),
        ),
        brokerAlerts: List<BrokerAlert>.unmodifiable(
          domain.brokerAlerts.map(
            (a) => a.copyWith(
              triggers: List<String>.unmodifiable(a.triggers),
              exceptTriggers: List<String>.unmodifiable(a.exceptTriggers),
              tests: List<KeywordTest>.unmodifiable(a.tests),
              alsoBasis: List<LegalBasis>.unmodifiable(a.alsoBasis),
            ),
          ),
        ),
        brokerChecklists: List<BrokerChecklist>.unmodifiable(
          domain.brokerChecklists.map(
            (c) => c.copyWith(items: List<String>.unmodifiable(c.items)),
          ),
        ),
        lookupTools: List<LookupTool>.unmodifiable(domain.lookupTools),
        limitRules: List<LimitRule>.unmodifiable(
          domain.limitRules.map(
            (r) => r.copyWith(
              inputs: List<LimitInput>.unmodifiable(r.inputs),
              tests: List<LimitTest>.unmodifiable(r.tests),
              verdicts: r.verdicts == null
                  ? null
                  : Map<String, String?>.unmodifiable(r.verdicts!),
            ),
          ),
        ),
        hardStops: List<HardStop>.unmodifiable(
          domain.hardStops.map(
            (h) => h.copyWith(
              checklist: List<String>.unmodifiable(h.checklist),
              channels: List<String>.unmodifiable(h.channels),
              tests: List<KeywordTest>.unmodifiable(h.tests),
            ),
          ),
        ),
        publicChannels:
            List<PublicChannelEntry>.unmodifiable(domain.publicChannels),
        autoTriggers: List<AutoTrigger>.unmodifiable(
          domain.autoTriggers.map(
            (t) => t.copyWith(
              patterns: List<String>.unmodifiable(t.patterns),
              exceptPatterns: List<String>.unmodifiable(t.exceptPatterns),
              show: List<String>.unmodifiable(t.show),
              tests: List<KeywordTest>.unmodifiable(t.tests),
            ),
          ),
        ),
        phoneRiskRules: List<PhoneRiskRule>.unmodifiable(
          domain.phoneRiskRules.map(
            (r) => r.copyWith(context: List<String>.unmodifiable(r.context)),
          ),
        ),
        plain: Map<String, String>.unmodifiable(domain.plain),
        plainLongOk: Map<String, String>.unmodifiable(domain.plainLongOk),
      );

  List<String> _prune(
    List<String> refs,
    Set<String> known,
    LoadReport report,
    String path,
  ) {
    final kept = <String>[];
    for (final ref in refs) {
      if (known.contains(ref)) {
        kept.add(ref);
        continue;
      }
      report.warnings.add(
        SchemaIssue.warning(
          path: '${report.domainId}.$path',
          message: '"$ref" 가 제거되었거나 존재하지 않아 참조에서 뺐습니다',
        ),
      );
    }
    return kept;
  }
}
