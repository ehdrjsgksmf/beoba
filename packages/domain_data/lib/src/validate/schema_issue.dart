enum IssueSeverity {
  /// 빌드·로드를 중단시킨다.
  error,

  /// 로그만 남긴다.
  warning,
}

/// 검증 결과 한 건.
class SchemaIssue {
  const SchemaIssue({
    required this.path,
    required this.message,
    this.severity = IssueSeverity.error,
  });

  const SchemaIssue.warning({required this.path, required this.message})
      : severity = IssueSeverity.warning;

  /// `debt_recovery.deadlines[0].tests` 형태.
  final String path;
  final String message;
  final IssueSeverity severity;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() =>
      '${severity == IssueSeverity.error ? 'ERROR' : 'WARN '} $path — $message';
}

/// 검증 실패. 로더가 던진다.
class DomainValidationException implements Exception {
  DomainValidationException(this.domainId, this.issues);

  final String domainId;
  final List<SchemaIssue> issues;

  List<SchemaIssue> get errors => issues.where((i) => i.isError).toList();

  @override
  String toString() {
    final buffer = StringBuffer('도메인 "$domainId" 검증 실패:\n');
    for (final issue in issues.where((i) => i.isError)) {
      buffer.writeln('  $issue');
    }
    return buffer.toString();
  }
}
