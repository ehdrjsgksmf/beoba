import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/engine.dart';
import '../core/json_logic.dart';
import 'court_lookup_table.dart';

enum JurisdictionStatus {
  /// 법원을 찾았다.
  resolved,

  /// 주소를 아직 모른다.
  missingInput,

  /// 조회표가 없다. **판단하지 않고 그대로 알린다.**
  tableUnavailable,
}

class JurisdictionResult {
  const JurisdictionResult({
    required this.id,
    required this.label,
    this.whatIsThis = "",
    required this.rule,
    required this.status,
    required this.verification,
    this.court,
    this.address,
  });

  final String id;
  final String label;
  /// 한 줄 풀이.
  final String whatIsThis;

  /// 사용자에게 보여줄 규칙 설명.
  final String rule;
  final JurisdictionStatus status;
  final String? court;
  final String? address;
  final VerificationStatus verification;

  @override
  String toString() => switch (status) {
        JurisdictionStatus.resolved => '$label: $court',
        JurisdictionStatus.missingInput => '$label: (주소 미입력)',
        JurisdictionStatus.tableUnavailable => '$label: (조회표 없음)',
      };
}

/// 관할 법원 찾기. 조회표는 주입받는다.
class JurisdictionEngine implements Engine<List<JurisdictionResult>> {
  const JurisdictionEngine({this.tables = const []});

  final List<CourtLookupTable> tables;

  @override
  List<JurisdictionResult> compute(Domain domain, CaseFacts facts) {
    final data = facts.toJsonLogicData();
    final results = <JurisdictionResult>[];

    for (final rule in domain.jurisdiction) {
      if (!JsonLogic.test(rule.showIf, data)) continue;
      results.add(computeOne(rule, facts));
    }
    return results;
  }

  JurisdictionResult computeOne(JurisdictionRule rule, CaseFacts facts) {
    final address = facts.text(rule.inputField);
    final table = tableNamed(rule.lookupTable);

    if (table == null) {
      return JurisdictionResult(
        id: rule.id,
        label: rule.label,
        whatIsThis: rule.whatIsThis,
        rule: rule.rule,
        status: JurisdictionStatus.tableUnavailable,
        verification: rule.verification.status,
        address: address,
      );
    }
    if (address == null || address.trim().isEmpty) {
      return JurisdictionResult(
        id: rule.id,
        label: rule.label,
        whatIsThis: rule.whatIsThis,
        rule: rule.rule,
        status: JurisdictionStatus.missingInput,
        verification: rule.verification.status,
      );
    }

    final court = table.courtFor(address);
    return JurisdictionResult(
      id: rule.id,
      label: rule.label,
      whatIsThis: rule.whatIsThis,
      rule: rule.rule,
      status: court == null
          ? JurisdictionStatus.missingInput
          : JurisdictionStatus.resolved,
      court: court,
      address: address,
      verification: rule.verification.status,
    );
  }

  CourtLookupTable? tableNamed(String name) {
    for (final table in tables) {
      if (table.name == name) return table;
    }
    return null;
  }
}
