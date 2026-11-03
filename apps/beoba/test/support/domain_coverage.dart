/// **전 분야를 도는 테스트가 자기 분모를 낸다.**
///
/// ## 왜 코드 모양을 쫓지 않는가
///
/// 분야 목록을 손으로 적어 둔 탓에 **네 번 깨졌다.**
///
/// ```
/// ① 열한 번째(산재)   result_scale_test 에 처음부터 안 들어감
/// ② 열세 번째(양육비) result_density_test · result_scale_test 둘 다 빠짐
/// ③ 쉬운 말          plain_density_test 는 열셋 중 둘만 쟀음
/// ④ 중고거래         welfare_bridge_test 의 어느 목록에도 없음
/// ```
///
/// ★ **④는 성질이 다르다.** 앞의 셋은 「한 목록에서 빠졌다」인데, 넷째는
/// 분야를 **두 갈래로 나눠 갖는** 목록에서 양쪽 어디에도 없었다. 그러면
/// 다리가 끊어져도 생겨도 양쪽 다 아무 말을 안 한다 — 어느 쪽도 자기 일이
/// 아니기 때문이다. 그래서 보는 것은 **합집합이 전부인가**다.
///
/// 처음에는 「테스트 코드에 분야 id 가 리터럴로 적혀 있으면 빨간불」을
/// 생각했다. 그런데 **그건 진다** — 리터럴을 막으면 상수로 새고
/// (`kDebtRecoveryDomainId` 가 그렇다), 상수까지 막으면 또 다른 모양으로
/// 샌다. 코드 모양을 쫓는 검사는 계속 뒤따라간다.
///
/// 그래서 오늘 분모에서 배운 것을 그대로 쓴다 — **몇 개를 돌았는지 세어
/// 데이터와 맞댄다.** id 가 리터럴로 적혔든 상수로 적혔든 상관없다. 열셋을
/// 안 돌면 걸린다(DECISIONS 247번).
///
/// ## 일부러 좁힌 것은 좁혔다고 말한다
///
/// 「일부러 좁힌 것」과 「적다가 빠뜨린 것」은 코드에서 똑같이 생겼다.
/// [skipped] 에 **이유 한 줄**을 요구하면 그 둘이 갈린다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo.dart';

/// 데이터에 있는 분야 id 전부. **손으로 적지 않는다.**
///
/// `_shared_crisis` 는 분야가 아니라 공통 조각이라 뺀다 —
/// `verify_domains.dart` 의 `_checkHandover` 가 세는 법과 같다.
List<String> allDomainIds() {
  final dir = Directory(
    '${repoRoot().path}/packages/domain_data/assets/domains',
  );
  return (dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.json') && !name.startsWith('_'))
          .map((name) => name.substring(0, name.length - '.json'.length))
          .toList())
    ..sort();
}

/// [covered] 와 [skipped] 를 합치면 데이터의 분야 전부여야 한다.
///
/// [where] 는 걸렸을 때 어느 테이블을 고쳐야 하는지 가리키는 이름이다.
void expectsEveryDomain(
  String where,
  Iterable<String> covered, {
  Map<String, String> skipped = const {},
}) {
  final all = allDomainIds().toSet();
  final ran = covered.toSet();

  expect(
    all,
    isNotEmpty,
    reason: '$where — 분야를 하나도 못 읽었습니다. 분모가 0이면 이 검사는 '
        '돌아도 아무것도 안 봅니다',
  );

  final unknown = {...ran, ...skipped.keys}.difference(all);
  expect(
    unknown,
    isEmpty,
    reason: '$where — 없는 분야를 적었습니다: ${unknown.join(', ')}. '
        '이름이 바뀌었거나 오타입니다',
  );

  for (final entry in skipped.entries) {
    expect(
      entry.value.trim(),
      isNotEmpty,
      reason: '$where — "${entry.key}" 를 왜 뺐는지 적어 주세요. '
          '이유가 없으면 일부러 뺀 것과 빠뜨린 것이 구별되지 않습니다',
    );
  }

  final missing = all.difference(ran).difference(skipped.keys.toSet());
  expect(
    missing,
    isEmpty,
    reason: '$where — 분야 ${all.length}개 중 ${ran.length}개만 돌았습니다. '
        '빠진 것: ${missing.join(', ')}. 표에 넣거나, 못 넣는 이유를 '
        'skipped 에 한 줄 적으세요',
  );
}
