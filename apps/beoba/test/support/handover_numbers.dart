/// **인수인계에 적힌 숫자를 그 값을 낼 수 있는 곳이 센다.**
///
/// 대부분은 `verify_domains.dart` 가 커밋된 JSON 을 읽어 셀 수 있다. 그런데
/// **복지 다리의 입구 합과 서로 다른 제도 수는 못 센다** — `matchWelfare` 가
/// 앱 코드(`apps/beoba/lib`)에 있고 검사기는 순수 Dart 도구라 거기까지
/// 못 간다. 그렇다고 세는 법을 검사기에 한 벌 더 쓰면 **두 숫자가 갈린다**
/// (DECISIONS 126번에서 실제로 그랬다).
///
/// 그래서 **셀 수 있는 쪽이 문서를 본다.** 여기서 문서를 읽고 맞댄다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo.dart';

/// 인수인계 문서 전문.
String handoverText() {
  final file = File('${repoRoot().path}/docs/현황_인수인계.md');
  if (!file.existsSync()) {
    throw StateError('인수인계 문서를 못 찾았습니다: ${file.path}');
  }
  return file.readAsStringSync();
}

/// [pattern] 이 잡는 **모든 곳**의 숫자가 [actual] 과 같아야 한다.
///
/// **첫 곳만 보지 않는다.** 같은 사실이 여러 곳에 적히면 한 곳만 고쳐지고
/// 나머지가 낡는다 — 복지 다리 표가 실제로 그랬다.
void expectHandoverNumber(String what, RegExp pattern, int actual) {
  final text = handoverText();
  final found = pattern.allMatches(text).toList();
  expect(
    found,
    isNotEmpty,
    reason: 'docs/현황_인수인계.md — 「$what」 이 한 번도 안 적혀 있습니다. '
        '세는 자리를 지웠으면 이 검사도 같이 지우세요',
  );
  for (final match in found) {
    expect(
      int.parse(match.group(1)!),
      actual,
      reason: 'docs/현황_인수인계.md — $what 가 실제로는 $actual인데 '
          '${match.group(1)}이라고 적힌 곳이 있습니다',
    );
  }
}
