import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/engine.dart';
import '../core/json_logic.dart';

/// 그 서류를 갖고 있는가. **셋이다.**
///
/// ```
/// have     갖고 있다고 답했다
/// missing  없다고 답했다        → 없을 때 할 말을 펼친다
/// unknown  아직 안 물었거나 안 답했다
/// ```
///
/// **「모른다」와 「없다」를 같이 다루면 안 된다.** 아직 답을 안 한 사람에게
/// 「없으시군요」로 시작하는 안내를 펼치는 것은 그 자체로 틀린 말이다.
enum DocumentHave { unknown, have, missing }

/// 준비할 서류 하나.
class DocumentResult {
  const DocumentResult({
    required this.id,
    required this.label,
    this.whatIsThis = "",
    required this.importance,
    required this.issuedBy,
    required this.onlineAvailable,
    required this.verification,
    this.hint,
    this.have = DocumentHave.unknown,
    this.ifMissing,
  });

  final String id;
  final String label;
  /// 한 줄 풀이.
  final String whatIsThis;
  final Importance importance;

  /// 어디서 떼는지.
  final String issuedBy;

  /// 온라인으로 발급되는지.
  final bool onlineAvailable;
  final String? hint;
  final VerificationStatus verification;

  /// 갖고 있는가 · 없는가 · 모르는가.
  ///
  /// 목록에서 빼지 않는다. 「준비하세요」가 아니라 「있다고 하셨어요」로
  /// 표시만 바뀐다 — 빼면 사용자가 자기가 뭘 갖고 있는지 못 본다.
  final DocumentHave have;

  /// 없을 때 할 말. **[have] 가 `missing` 일 때만 화면에 펼친다.**
  final MissingGuide? ifMissing;

  bool get alreadyHave => have == DocumentHave.have;

  /// 없다고 **답한** 것. 아직 안 답한 것은 여기 안 들어온다.
  bool get isMissing => have == DocumentHave.missing;

  @override
  String toString() => label;
}

/// 서류 목록. `showIf` 로 거르고 중요도 순으로 정렬한다.
class DocumentEngine implements Engine<List<DocumentResult>> {
  const DocumentEngine();

  @override
  List<DocumentResult> compute(Domain domain, CaseFacts facts) {
    final data = facts.toJsonLogicData();
    final results = <DocumentResult>[];

    for (final document in domain.documents) {
      if (!JsonLogic.test(document.showIf, data)) continue;
      results.add(_toResult(document, have: _have(document, facts, data)));
    }

    // 중요도 DESC → JSON 정의 순서 (안정 정렬이므로 원래 순서가 유지된다)
    mergeSortByImportance(results);
    return results;
  }

  /// **답을 안 한 것과 없다고 답한 것을 가른다.**
  ///
  /// `haveIf` 가 보는 필드가 아직 안 채워져 있으면 「모른다」다. 조건이
  /// 거짓이라는 것만으로 「없다」로 읽으면, 인터뷰를 중간에 그만둔 사람 전원이
  /// 「아무것도 없는 사람」이 된다.
  DocumentHave _have(
    DocumentItem document,
    CaseFacts facts,
    Map<String, dynamic> data,
  ) {
    final rule = document.haveIf;
    if (rule == null) return DocumentHave.unknown;
    for (final field in _varsIn(rule)) {
      if (!facts.has(field)) return DocumentHave.unknown;
    }
    return JsonLogic.test(rule, data)
        ? DocumentHave.have
        : DocumentHave.missing;
  }

  /// 조건이 보는 필드 이름들.
  static Set<String> _varsIn(Object? node) {
    final found = <String>{};
    void walk(Object? value) {
      if (value is Map) {
        final variable = value['var'];
        if (variable is String) found.add(variable);
        value.values.forEach(walk);
      } else if (value is List) {
        value.forEach(walk);
      }
    }

    walk(node);
    return found;
  }

  DocumentResult _toResult(
    DocumentItem document, {
    required DocumentHave have,
  }) =>
      DocumentResult(
        id: document.id,
        label: document.label,
        whatIsThis: document.whatIsThis,
        importance: document.importance,
        issuedBy: document.issuedBy,
        onlineAvailable: document.onlineAvailable,
        hint: document.hint,
        verification: document.verification.status,
        have: have,
        ifMissing: document.ifMissing,
      );

  /// `List.sort` 는 안정 정렬이 아니다. 정의 순서를 지키려면 직접 묶는다.
  static void mergeSortByImportance(List<DocumentResult> results) {
    final byImportance = <Importance, List<DocumentResult>>{};
    for (final result in results) {
      byImportance.putIfAbsent(result.importance, () => []).add(result);
    }
    results
      ..clear()
      ..addAll([
        ...?byImportance[Importance.high],
        ...?byImportance[Importance.medium],
        ...?byImportance[Importance.low],
      ]);
  }
}
