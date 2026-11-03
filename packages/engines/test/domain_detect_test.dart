import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/asset_paths.dart';
import 'support/fixtures.dart';

/// 자유 입력에서 분야를 알아챈다.
///
/// **고르는 게 아니라 후보를 좁히는 것이다.** 걸렸다고 바로 넘기지 않는다.
String _read(String domainId) {
  for (final file in domainAssetFiles()) {
    if (domainIdOf(file) == domainId) return file.readAsStringSync();
  }
  throw StateError('$domainId.json 을 찾지 못했습니다');
}

void main() {
  const engine = DomainDetectEngine();

  final loader = DomainLoader(today: const KstDate(2026, 8, 15));

  /// 아래 「걸린 개수로 갈린다」 · 「미리 채우기」가 보는 분야 넷. 그 시험들은
  /// 「둘이 걸린다」처럼 **개수를 잠그므로** 분야가 늘면 뜻이 흔들린다.
  final domains = [
    for (final id in const [
      'debt_recovery',
      'deposit_return',
      'wage_theft',
      'inheritance',
    ])
      loader.loadFromJsonString(_read(id)),
  ];

  /// ★★ **정답지는 열다섯 분야를 전부 읽는다.** 예전에는 위 넷만 읽어서
  /// 예문 80건 중 23건만 돌았다 — 나머지 57건은 아무도 안 돌렸고, 그 틈에
  /// 틀린 예문이 초록으로 남아 있었다.
  ///
  /// `_` 로 시작하는 파일은 분야가 아니다(공용 위기 자료).
  final allDomains = [
    for (final file in domainAssetFiles())
      if (!domainIdOf(file).startsWith('_'))
        loader.loadFromJsonString(file.readAsStringSync()),
  ];

  List<String> idsFor(String text) =>
      engine.detect(domains, text).map((d) => d.domainId).toList();

  /// 정답지는 **전부 켜 둔 채로** 본다 — 실제 앱이 그렇다.
  List<String> allIdsFor(String text) =>
      engine.detect(allDomains, text).map((d) => d.domainId).toList();

  group('정답지 — 데이터가 스스로 시험한다', () {
    test('열다섯 분야를 전부 읽는다', () {
      expect(allDomains, hasLength(15));
      final probes = allDomains
          .map((d) => d.detect?.tests.length ?? 0)
          .fold(0, (a, b) => a + b);
      // ignore: avoid_print
      print('정답지 예문 $probes건 · 분야 ${allDomains.length}개');
      expect(probes, greaterThanOrEqualTo(80));
    });

    for (final domain in allDomains) {
      final detect = domain.detect;
      if (detect == null) continue;
      for (final probe in detect.tests) {
        test('${domain.id} — "${probe.text}"', () {
          expect(
            allIdsFor(probe.text).contains(domain.id),
            probe.expected,
            reason: probe.expected
                ? '알아채야 하는데 못 알아챘습니다'
                : '알아채면 안 되는데 알아챘습니다',
          );
        });
      }
    }
  });

  group('걸린 개수로 갈린다', () {
    test('하나만 걸린다', () {
      expect(idsFor('사장이 월급을 두 달째 안 줍니다'), ['wage_theft']);
    });

    test('둘 이상 걸리면 둘 다 돌려준다 — 우리가 고르지 않는다', () {
      // 「전세보증금 때문에 돈을 빌려줬어요」가 이 경우다.
      final both = idsFor('전세 보증금이 필요하다고 해서 빌려준 돈이에요');
      expect(both, containsAll(['debt_recovery', 'deposit_return']));
      expect(both.length, greaterThan(1));
    });

    test('하나도 안 걸리면 빈 목록', () {
      expect(idsFor('무슨 일인지 잘 모르겠어요'), isEmpty);
      expect(idsFor(''), isEmpty);
      expect(idsFor('   '), isEmpty);
    });
  });

  group('미리 채우기', () {
    Map<String, Object?> prefillFor(String text) => engine
        .detect(domains, text)
        .firstWhere((d) => d.domainId == 'debt_recovery')
        .prefill;

    test('받을 쪽으로 읽는다', () {
      expect(prefillFor('빌려준 돈을 안 갚아요')['q_role'], 'creditor');
    });

    test('갚을 쪽으로 읽는다', () {
      expect(prefillFor('지급명령을 받았습니다')['q_role'], 'debtor');
    });

    test('금액이 하나면 채운다', () {
      // not-a-legal-number: 테스트 입력값
      expect(prefillFor('오백만원을 빌려줬어요')['q_amount'], 5000000);
      expect(prefillFor('빌려준 3,000만원을 못 받았어요')['q_amount'], 30000000);
    });

    test('금액이 둘이면 채우지 않는다 — 우리가 고르면 짐작이다', () {
      final filled = prefillFor('빌려준 5,000만원 중 300만원만 받았어요');
      expect(filled.containsKey('q_amount'), isFalse);
    });

    test('단위 글자가 없는 숫자는 금액이 아니다', () {
      final filled = prefillFor('3월에 빌려준 돈이에요');
      expect(filled.containsKey('q_amount'), isFalse);
    });

    test('★ 날짜는 어떤 경우에도 안 채운다', () {
      // 금액을 잘못 채우면 화면에서 보고 고친다. **날짜를 잘못 채우면
      // 사람이 그걸 믿고 안 움직인다**(DECISIONS 130번).
      final filled = prefillFor('2026년 8월 1일에 지급명령을 받았습니다');
      for (final key in filled.keys) {
        expect(key, isNot(contains('date')));
        expect(key, isNot(contains('Date')));
      }
    });
  });

  test('선택지에 없는 값은 채우지 않는다', () {
    final domain = domainFixture(
      intake: [questionFixture(id: 'q1', order: 1, field: 'claimType')],
      detect: const DomainDetect(
        patterns: ['테스트말'],
        prefill: [PrefillRule(questionId: 'q1', value: '없는값')],
      ),
    );

    expect(engine.detect([domain], '테스트말이 들어간 문장').single.prefill, isEmpty);
  });
}
