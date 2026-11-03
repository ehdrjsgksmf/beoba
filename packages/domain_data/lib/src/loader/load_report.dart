import '../validate/schema_issue.dart';

/// 로더가 제거한 항목 한 건.
class RemovedItem {
  const RemovedItem({
    required this.list,
    required this.id,
    required this.reason,
  });

  /// `deadlines`, `jurisdiction` 처럼 어느 목록에서 빠졌는지.
  final String list;
  final String id;
  final String reason;

  @override
  String toString() => '$list.$id ($reason)';
}

/// 로드 결과 기록. 무엇이 왜 화면에 도달하지 못했는지 남긴다.
class LoadReport {
  LoadReport({required this.domainId});

  final String domainId;
  final List<RemovedItem> removed = [];
  final List<SchemaIssue> warnings = [];

  bool get isClean => removed.isEmpty && warnings.isEmpty;

  String summary() {
    if (isClean) return '$domainId — 제거·경고 없음';
    final buffer = StringBuffer('$domainId — ');
    if (removed.isNotEmpty) {
      buffer.write('제거됨: ${removed.join(', ')}');
    }
    if (warnings.isNotEmpty) {
      if (removed.isNotEmpty) buffer.write(' · ');
      buffer.write('경고 ${warnings.length}건');
    }
    return buffer.toString();
  }
}
