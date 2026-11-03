

import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/asset_paths.dart';

/// 도메인 JSON 의 낱말 정답지를 전부 돌린다 (CONTRIBUTING.md 규칙 8).
///
/// **음성 사례가 양성보다 많은 것이 정상이다.** 문자열 매칭은 놓치는 것보다
/// 잘못 잡는 것이 더 나쁘고, 오탐은 사람이 문장을 실제로 써 보기 전에는 드러나지
/// 않는다. 그래서 "걸리지 않아야 하는 문장" 을 데이터에 남기고 여기서 돌린다.
///
/// 실제로 이 방식이 잡은 것들 — 고치기 전에는 전부 발동했다:
/// ```
/// "근무일수를 계산해주세요"     → 사채 안내      (일수)
/// "참기름이 고소한 냄새가 납니다" → 형사 차단      (고소)
/// "혼자살고있어요"              → 자살 위기 화면  (자살)
/// "협박한 적은 없습니다"         → 불법추심 안내   (협박)
/// ```
void main() {
  // keepAll 은 검증 전용이다. 화면에 안 나가는 항목의 낱말도 확인해야 한다.
  // ignore: invalid_use_of_visible_for_testing_member
  final loader = DomainLoader(policy: VerificationPolicy.keepAll);

  for (final file in domainAssetFiles()) {
    final name = file.uri.pathSegments.last;
    final domain = loader.loadFromJsonString(file.readAsStringSync());

    group('$name — 낱말 정답지', () {
      for (final trigger in domain.autoTriggers) {
        _runCases(
          label: 'autoTriggers.${trigger.id}',
          patterns: trigger.patterns,
          exceptPatterns: trigger.exceptPatterns,
          tests: trigger.tests,
        );
      }

      for (final stop in domain.hardStops) {
        final trigger = stop.trigger;
        if (trigger is! KeywordHardStopTrigger) continue;
        _runCases(
          label: 'hardStops.${stop.id}',
          patterns: trigger.patterns,
          exceptPatterns: trigger.exceptPatterns,
          tests: stop.tests,
        );
      }

      for (final alert in domain.brokerAlerts) {
        if (alert.triggers.isEmpty) continue;
        _runCases(
          label: 'brokerAlerts.${alert.id}',
          patterns: alert.triggers,
          exceptPatterns: alert.exceptTriggers,
          tests: alert.tests,
        );
      }
    });
  }

  group('브로커 경보 — 분야를 가로질러 본다', () {
    _crossCheck([
      for (final file in domainAssetFiles())
        ...loader.loadFromJsonString(file.readAsStringSync()).brokerAlerts,
    ]);
  });

  test('정답지가 실제로 존재한다', () {
    var total = 0;
    var negatives = 0;
    for (final file in domainAssetFiles()) {
      final domain = loader.loadFromJsonString(file.readAsStringSync());
      for (final trigger in domain.autoTriggers) {
        total += trigger.tests.length;
        negatives += trigger.tests.where((t) => !t.expected).length;
      }
      for (final stop in domain.hardStops) {
        if (stop.trigger is! KeywordHardStopTrigger) continue;
        total += stop.tests.length;
        negatives += stop.tests.where((t) => !t.expected).length;
      }
      for (final alert in domain.brokerAlerts) {
        if (alert.triggers.isEmpty) continue;
        total += alert.tests.length;
        negatives += alert.tests.where((t) => !t.expected).length;
      }
    }

    expect(total, greaterThan(0));
    // 잘못 잡는 쪽이 더 나쁘다. 음성이 절반은 넘어야 한다.
    expect(
      negatives * 2,
      greaterThanOrEqualTo(total),
      reason: '음성 사례가 $negatives / $total 뿐입니다. '
          '오탐은 걸릴 문장만 적어서는 드러나지 않습니다',
    );
  });
}

/// 한 경보의 정답지는 **그 경보의 낱말만** 본다. 그런데 브로커 경보는
/// `_shared_crisis` 에 모여 있어 **모든 분야가 같은 목록을 쓴다** — 한 분야에서
/// 자연스러운 문장이 옆 경보에 걸릴 수 있고, 그건 항목별 정답지로는 안 잡힌다.
///
/// 그래서 문장 하나를 **경보 전부**에 대어 본다.
void _crossCheck(List<BrokerAlert> alerts) {
  /// 걸리면 안 되는 문장. 전부 이 앱에 실제로 올 사람의 말이다.
  ///
  /// **분야를 늘릴 때마다 그 분야 사람이 첫 화면에 적을 문장을 여기 넣는다.**
  /// 경보 목록은 `_shared_crisis` 하나이고 모든 분야가 같은 것을 쓴다 —
  /// 「떼인 돈 받기」만 보고 낱말을 고르면 전세·임금 사용자에게 터진다.
  const mustNotFire = <String>[
    // 떼인 돈 받기
    '장기간 못 받고 있어요',
    '일해서 갚겠다고 했어요',
    '통장에 입금이 안 됐어요',
    '차용증을 사진으로 찍어 뒀어요',
    '휴대폰으로 문자 보냈어요',
    '체크카드로 이체한 내역이 있어요',
    '변호사 착수금이 얼마나 드나요',
    '전자소송 앱 설치하면 되나요',
    '기록이 남으면 증거가 되나요',
    '전자금융거래법 위반인지 궁금해요',
    // 전세·월세 보증금
    '전세보증금을 못 받고 있어요',
    '집주인이 보증금을 안 돌려줘요',
    '부동산 중개수수료는 누가 내나요',
    // 임금체불
    '일당 삼십만원 받기로 했는데 안 줘요',
    '월급이 두 달째 밀렸어요',
    '심부름 값을 아직 못 받았어요',
    // 빚 정리
    '개인회생을 알아보고 있어요',
    '신용회복위원회에 직접 신청했어요',
    '신용등급이 떨어졌어요',
    // 어간까지 줄인 낱말이 물어 오는 것들. 줄인 만큼 여기가 늘어야 한다.
    '서류 맞춰 준비하는 데 얼마나 걸리나요',
    '서류 맞춰 주말까지 내려고 해요',
    '기록이 남으면 안심이 되나요',
    '택배를 동생이 대신 받아 갔어요',
    '내용증명을 가족이 대신 받아 뒀어요',
    // 부정문 — 낱말은 그대로 있고 뜻만 반대다.
    '통장 빌려준 적 없어요',
    '고액 알바를 한 적 없어요',
    '사진 보내준 적 없어요',
    '대신 받아준다고 한 적 없어요',
  ];

  /// 걸려야 하는 문장 → 걸려야 할 경보 id.
  const mustFire = <String, String>{
    '돈을 대신 받아준다는 사람이 있어요': 'ba_debt_collection',
    '사진 한 장만 주면 된대요': 'ba_photo_extortion_loan',
    '통장 빌려주면 돈 준대요': 'ba_account_lend',
  };

  test('걸리면 안 되는 문장은 어느 경보에도 안 걸린다', () {
    for (final text in mustNotFire) {
      for (final alert in alerts) {
        if (alert.triggers.isEmpty) continue;
        expect(
          KeywordMatch.any(
            [text],
            alert.triggers,
            exceptPatterns: alert.exceptTriggers,
          ),
          isFalse,
          reason: '"$text" 가 ${alert.id} 에 걸립니다',
        );
      }
    }
  });

  test('걸려야 하는 문장은 그 경보에 걸린다', () {
    final byId = {for (final alert in alerts) alert.id: alert};
    mustFire.forEach((text, id) {
      final alert = byId[id];
      expect(alert, isNotNull, reason: '$id 가 없습니다');
      expect(
        KeywordMatch.any(
          [text],
          alert!.triggers,
          exceptPatterns: alert.exceptTriggers,
        ),
        isTrue,
        reason: '"$text" 가 $id 에 안 걸립니다',
      );
    });
  });

  test('멈춰 세우는 경보는 셋을 넘지 않는다', () {
    // 카드 다섯 장 규칙과 같은 종류의 잠금이다. 안 잠그면 다음 사람이
    // 「이것도 중요한데」로 하나씩 늘리고, **기본이 되면 아무것도 못 멈춘다.**
    final stops = alerts.where((a) => a.display == AlertDisplay.stop).toList();
    expect(
      stops.length,
      lessThanOrEqualTo(3),
      reason: 'display: stop 이 ${stops.map((a) => a.id).join(' · ')} 입니다',
    );
  });

  test('경보마다 걸리는 문장이 하나는 있다', () {
    // 낱말을 좁히다 보면 **아무 문장도 안 걸리는 경보**가 생긴다.
    // 그건 화면에 영영 안 나오는 경보이고, 없는 것과 같다.
    for (final alert in alerts) {
      if (alert.triggers.isEmpty) continue;
      expect(
        alert.tests.any((t) => t.expected),
        isTrue,
        reason: '${alert.id} 에 걸리는 문장이 정답지에 없습니다',
      );
    }
  });
}

void _runCases({
  required String label,
  required List<String> patterns,
  required List<String> exceptPatterns,
  required List<KeywordTest> tests,
}) {
  test(label, () {
    for (final testCase in tests) {
      final hit = KeywordMatch.any(
        [testCase.text],
        patterns,
        exceptPatterns: exceptPatterns,
      );
      expect(
        hit,
        testCase.expected,
        reason: testCase.expected
            ? '"${testCase.text}" 는 걸려야 하는데 안 걸립니다'
            : '"${testCase.text}" 는 걸리면 안 되는데 걸립니다',
      );
    }
  });
}

