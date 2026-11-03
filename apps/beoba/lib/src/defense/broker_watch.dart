import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

import '../interview/interview_session.dart';

/// ② 방어 — 걸린 브로커 경보 하나.
///
/// **위기 신호(층①)와 다르다.** 위기는 창구로 보내는 것이고 방어는 **멈춰
/// 세우는 것**이다. 같은 무게로 다루면 둘 다 무뎌진다.
///
/// 그래도 **차단은 아니다.** 브로커를 만났다고 앱을 못 쓰게 하면 그 사람은
/// 브로커에게 돌아간다. 하드스톱이 아니고 전체 화면도 아니다 — 전체 화면은
/// `trg_mental` 하나뿐이라는 규칙이 그대로다.
class BrokerWarning {
  const BrokerWarning({required this.alert});

  final BrokerAlert alert;

  String get id => alert.id;

  /// 화면을 멈춰 세우는가. **법률 위험도가 아니다.**
  ///
  /// 처음에는 `severity == red` 로 골랐는데 red 가 여덟 건이었다. 여덟이 큰
  /// 카드면 큰 카드가 기본이 되고, **기본이 되면 아무것도 못 멈춘다.**
  /// 그래서 축을 나눴다 — `severity` 는 법률 위험도, `display` 는 화면 무게다.
  bool get isStop => alert.display == AlertDisplay.stop;

  /// 붉게 칠할 것인가. 이쪽이 **법률 위험도**다.
  ///
  /// 색과 무게가 다른 축이라 붉지만 안 멈추는 경보가 있다 — 착수금 선입금
  /// 요구가 그렇다. 위험도는 높은데 사용자가 지금 되돌릴 것이 없다.
  bool get isHighRisk => alert.severity == AlertSeverity.red;
}

/// 사용자가 적은 문장에서 브로커의 말을 찾는다.
///
/// `phrase` 는 **브로커가 하는 말**이다. 사용자가 그 말을 적었다는 것은 이미
/// 브로커를 만났다는 뜻이라, 「조심하세요」가 아니라 「이런 말 들으셨나요?」로
/// 걸린다.
///
/// 낱말 검사는 **사용자가 타이핑한 문자열에만** 한다 (`userTypedText`).
/// 선택지 값이나 `setsField` 부산물에 맞추면 우리가 쓴 말이 사용자가 쓴 말로
/// 둔갑한다 — 위기 신호와 같은 규칙이다.
///
/// **걸린 낱말도 문장 원문도 돌려주지 않는다.** 어느 경보인지만 돌려준다.
List<BrokerWarning> detectBrokerAlerts(
  Domain crisis,
  Domain domain,
  CaseFacts facts, {
  Set<String> extraTextFields = const {},
}) {
  final texts =
      userTypedText(domain, facts, extraFields: extraTextFields).toList();
  if (texts.isEmpty) return const [];

  // 공통 목록과 분야 목록을 함께 본다. 브로커는 분야를 가리지 않는다.
  final alerts = [...crisis.brokerAlerts, ...domain.brokerAlerts];
  final warnings = <BrokerWarning>[];
  final seen = <String>{};

  for (final alert in alerts) {
    if (alert.triggers.isEmpty || !seen.add(alert.id)) continue;
    // 좁힌 낱말 · 예외 낱말 · 부정 표현을 한꺼번에 본다. 셋 다 필요하다 —
    // 「통장 빌려준 적 없어요」는 걸리면 안 된다.
    final hit = KeywordMatch.any(
      texts,
      alert.triggers,
      exceptPatterns: alert.exceptTriggers,
    );
    if (hit) warnings.add(BrokerWarning(alert: alert));
  }

  // 멈춰 세우는 것이 먼저고, 그다음이 법률 위험도다. 사진을 보내라는 말과
  // 신용등급 광고를 나란히 둘 수 없다.
  warnings.sort((a, b) {
    final byStop = (b.isStop ? 1 : 0) - (a.isStop ? 1 : 0);
    if (byStop != 0) return byStop;
    return (b.isHighRisk ? 1 : 0) - (a.isHighRisk ? 1 : 0);
  });
  return warnings;
}

/// 세션 기준으로 찾는다. 홈 자유 서술도 함께 본다.
List<BrokerWarning> brokerWarningsFor(
  Domain crisis,
  Domain domain,
  CaseFacts facts,
) =>
    detectBrokerAlerts(
      crisis,
      domain,
      facts,
      extraTextFields: const {InterviewSession.narrativeField},
    );
