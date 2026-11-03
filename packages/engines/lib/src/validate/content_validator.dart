import 'package:domain_data/domain_data.dart';

import '../safety/safety_field_scopes.dart';
import '../safety/safety_filter.dart';

/// 도메인 데이터의 **모든 사용자 노출 문구**를 SafetyFilter 로 검사한다.
///
/// 필드마다 scope 가 다르다 ([kFieldScopes]). 인용문(사기꾼 멘트)은 원문을
/// 그대로 보여줘야 하므로 완화된 패턴만 적용한다.
class ContentValidator {
  const ContentValidator();

  /// 위반 목록. 비어 있으면 통과.
  List<SchemaIssue> validate(Domain domain) {
    final issues = <SchemaIssue>[];

    void check(String typeName, String field, String? text, String path) {
      if (text == null || text.isEmpty) return;
      final violations = SafetyFilter.scan(
        text,
        scope: scopeFor(typeName, field),
        where: path,
      );
      for (final violation in violations) {
        issues.add(
          SchemaIssue(
            path: path,
            message: '법률 판단으로 읽힐 수 있는 표현입니다: "${violation.excerpt}" '
                '(/${violation.pattern}/)',
          ),
        );
      }
    }

    final id = domain.id;
    check('Domain', 'name', domain.name, '$id.name');
    check('Domain', 'description', domain.description, '$id.description');

    // **걸림말도 화면에 나가는 글자다. 예외를 두지 않는다.**
    //
    // 「자진 퇴사」·「보이스피싱」·「환불」은 이름표이지 판정이 아니라서 그대로
    // 통과해야 한다. 여기서 걸리면 예외를 다는 것이 아니라 **그 금지어가 낱말을
    // 막고 있다는 뜻**이고, 문장 단위로 좁혀야 한다(DECISIONS 195번).
    for (final term in domain.searchTerms) {
      check('Domain', 'searchTerms', term, '$id.searchTerms');
    }

    for (final question in domain.intake) {
      final path = '$id.intake.${question.id}';
      check('Question', 'text', question.text, '$path.text');
      check('Question', 'whyAsk', question.whyAsk, '$path.whyAsk');
      for (final option in question.options) {
        check('QuestionOption', 'label', option.label, '$path.${option.value}');
      }
    }

    for (final deadline in domain.deadlines) {
      final path = '$id.deadlines.${deadline.id}';
      check('Deadline', 'label', deadline.label, '$path.label');
      _checkLegalBasis(check, deadline.legalBasis, path);
    }

    for (final cost in domain.costs) {
      final path = '$id.costs.${cost.id}';
      check('CostItem', 'label', cost.label, '$path.label');
      _checkLegalBasis(check, cost.legalBasis, path);
      for (final modifier in cost.modifiers) {
        check('CostModifier', 'label', modifier.label, '$path.${modifier.id}');
      }
    }

    for (final document in domain.documents) {
      final path = '$id.documents.${document.id}';
      check('DocumentItem', 'label', document.label, '$path.label');
      check('DocumentItem', 'hint', document.hint, '$path.hint');
      check('DocumentItem', 'issuedBy', document.issuedBy, '$path.issuedBy');
    }

    for (final procedure in domain.procedures) {
      final path = '$id.procedures.${procedure.id}';
      check('Procedure', 'label', procedure.label, '$path.label');
      check('Procedure', 'whatIsThis', procedure.whatIsThis, '$path.whatIsThis');
      check('Procedure', 'detail', procedure.detail, '$path.detail');
      check('Procedure', 'caution', procedure.caution, '$path.caution');
      check('Procedure', 'whenApplicable', procedure.whenApplicable,
          '$path.whenApplicable');
      check('Procedure', 'noticeToUser', procedure.noticeToUser,
          '$path.noticeToUser');
      _checkLegalBasis(check, procedure.legalBasis, path);
    }

    for (final resource in domain.resources) {
      final path = '$id.resources.${resource.id}';
      check('Resource', 'name', resource.name, '$path.name');
      check('Resource', 'benefit', resource.benefit, '$path.benefit');
      for (final rule in resource.eligibility) {
        check('EligibilityRule', 'label', rule.label, '$path.eligibility');
      }
    }

    for (final alert in domain.brokerAlerts) {
      final path = '$id.brokerAlerts.${alert.id}';
      check('BrokerAlert', 'phrase', alert.phrase, '$path.phrase');
      check('BrokerAlert', 'truth', alert.truth, '$path.truth');
      _checkPenaltyHasBasis(
        issues,
        alert.truth,
        hasBasis: alert.legalBasis != null || alert.alsoBasis.isNotEmpty,
        path: '$path.truth',
      );
      _checkLegalBasis(check, alert.legalBasis, path);
      final action = alert.action;
      if (action != null) {
        check('ActionRef', 'label', action.label, '$path.action');
      }
    }

    for (final checklist in domain.brokerChecklists) {
      final path = '$id.brokerChecklists.${checklist.id}';
      check('BrokerChecklist', 'title', checklist.title, '$path.title');
      check('BrokerChecklist', 'thresholdMessage', checklist.thresholdMessage,
          '$path.thresholdMessage');
      for (final item in checklist.items) {
        check('BrokerChecklist', 'items', item, '$path.items');
      }
      final ask = checklist.askThis;
      if (ask != null) {
        check('ChecklistAsk', 'question', ask.question, '$path.askThis.question');
        check('ChecklistAsk', 'why', ask.why, '$path.askThis.why');
      }
    }

    for (final caution in domain.cautions) {
      final path = '$id.cautions.${caution.id}';
      _checkPenaltyHasBasis(
        issues,
        caution.consequence,
        hasBasis:
            caution.legalBasis != null || caution.alsoBasis.isNotEmpty,
        path: '$path.consequence',
      );
    }

    for (final rule in domain.limitRules) {
      final path = '$id.limitRules.${rule.id}';
      check('LimitRule', 'label', rule.label, '$path.label');
      check('LimitRule', 'message', rule.message, '$path.message');
      for (final input in rule.inputs) {
        check('LimitInput', 'label', input.label, '$path.inputs.${input.field}');
      }
      _checkLegalBasis(check, rule.legalBasis, path);
      final formula = rule.formula;
      if (formula is ThresholdLimitFormula) {
        for (final threshold in formula.thresholds) {
          check('ThresholdRule', 'message', threshold.message, '$path.thresholds');
        }
      }
      rule.verdicts?.forEach((key, value) {
        check('LimitRule', 'verdicts', value, '$path.verdicts.$key');
      });
    }

    for (final hardStop in domain.hardStops) {
      final path = '$id.hardStops.${hardStop.id}';
      check('HardStop', 'title', hardStop.title, '$path.title');
      check('HardStop', 'message', hardStop.message, '$path.message');
      for (final item in hardStop.checklist) {
        check('HardStop', 'checklist', item, '$path.checklist');
      }
    }

    for (final entry in domain.publicChannels) {
      if (entry is! PublicChannelFull) continue;
      final channel = entry.channel;
      final path = '$id.publicChannels.${channel.id}';
      check('PublicChannel', 'label', channel.label, '$path.label');
      check('PublicChannel', 'note', channel.note, '$path.note');
    }

    for (final tool in domain.lookupTools) {
      final path = '$id.lookupTools.${tool.id}';
      check('LookupTool', 'label', tool.label, '$path.label');
      check('LookupTool', 'hint', tool.hint, '$path.hint');
    }

    for (final rule in domain.phoneRiskRules) {
      check('PhoneRiskRule', 'message', rule.message,
          '$id.phoneRiskRules.${rule.id}.message');
    }

    // **쉬운 말도 우리가 하는 말이다.** 금지어를 똑같이 건다.
    //
    // 쉽게 쓰다가 단정으로 흐르는 것을 막는 검사는 `verify_domains` 의 (x)에
    // 따로 있다. 여기서는 원래 문장에 걸던 것을 그대로 건다 — 한 벌이 늘어날
    // 때마다 검사를 다시 붙이지 않아도 되게 **키를 세지 않고 값을 전부** 본다.
    for (final entry in domain.plain.entries) {
      check('Domain', 'plain', entry.value, '$id.plain.${entry.key}');
    }

    return issues;
  }

  /// 형벌을 말하는 문장. **징역·벌금·처벌은 조문 없이 말하지 않는다.**
  ///
  /// 이 앱은 근거 없는 법률 수치를 안 내보내기로 했는데 **형벌이 근거 없이
  /// 나가고 있었다.** 「적발 시 부정수급액의 최대 5배 환수와 10년 이하 징역」이
  /// `legalBasis` 없이 화면에 있었고, 「돈을 받으면 사기, 서류를 꾸미면
  /// 문서위조입니다」도 그랬다.
  ///
  /// 숫자를 막는 검사(`제N조` · 5자리 리터럴)는 **코드**를 보고, 문구 검사는
  /// 금지 표현을 본다. 그 사이에 「조문 없이 형벌을 말하는 데이터」가 있었다.
  static final RegExp _penaltyWords =
      RegExp('징역|벌금|처벌|형사처벌|과태료|환수|몰수');

  /// 근거가 없으면 **문장에서 그 절을 내린다.** 남길 것은 손해와 창구다.
  /// 그건 조문이 없어도 말할 수 있다.
  void _checkPenaltyHasBasis(
    List<SchemaIssue> issues,
    String? text, {
    required bool hasBasis,
    required String path,
  }) {
    if (text == null || text.isEmpty || hasBasis) return;
    final hit = _penaltyWords.firstMatch(text);
    if (hit == null) return;

    issues.add(
      SchemaIssue(
        path: path,
        message: '근거 조문 없이 형벌을 말합니다: "${hit.group(0)}". '
            'legalBasis 를 붙이거나, 그 절을 문장에서 내리세요 — '
            '손해와 창구는 조문이 없어도 말할 수 있습니다',
      ),
    );
  }

  void _checkLegalBasis(
    void Function(String, String, String?, String) check,
    LegalBasis? basis,
    String path,
  ) {
    if (basis == null) return;
    check('LegalBasis', 'text', basis.text, '$path.legalBasis.text');
  }
}
