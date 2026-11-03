import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

import '../interview/interview_session.dart';

/// 위기 신호 하나.
///
/// **하드스톱과 다르다. 차단이 아니다.** 안내를 보여주고, 닫으면 하던 일을
/// 계속할 수 있다. 이 앱이 못 하는 일을 대신 해 줄 곳을 알려줄 뿐이다.
class CrisisSignal {
  const CrisisSignal({required this.trigger, required this.channels});

  final AutoTrigger trigger;

  /// `show` 가 가리키는 공적 창구들. 원본은 `_shared_crisis` 가 소유한다.
  final List<PublicChannel> channels;

  String get id => trigger.id;

  /// 다른 무엇보다 먼저, 전체 화면으로.
  bool get isPriority => trigger.priority;
}

/// 걸린 위기 신호를 찾는다.
///
/// 낱말 검사는 **사용자가 타이핑한 문자열에만** 한다 ([userTypedText]).
/// 선택지 값이나 `setsField` 부산물로 위기 안내가 뜨면, 상대가 돈이 없다고 했다는
/// 답을 고른 채권자에게 긴급복지 창구가 뜬다.
///
/// **걸린 낱말도, 문장 원문도 반환하지 않는다.** 어느 트리거인지와 어디로
/// 연결할지만 돌려준다. 위기 신호가 걸린 문장에는 사람의 가장 사적인 말이 들어 있고,
/// 그건 화면 밖 어디에도 남으면 안 된다 (`SafetyReporter` 와 같은 규칙).
List<CrisisSignal> detectCrisisSignals(
  Domain crisis,
  Domain domain,
  CaseFacts facts, {
  Set<String> extraTextFields = const {},
}) {
  final texts = userTypedText(
    domain,
    facts,
    extraFields: extraTextFields,
  ).toList();
  if (texts.isEmpty) return const [];

  final byId = {for (final channel in crisis.resolvedChannels) channel.id: channel};
  final signals = <CrisisSignal>[];

  for (final trigger in crisis.autoTriggers) {
    // 좁힌 패턴 · 예외 낱말 · 부정 표현을 한꺼번에 본다. 셋 다 필요하다 —
    // 그냥 contains 로 훑으면 "근무일수를 계산해주세요" 가 사채 안내를 띄운다.
    final hit = KeywordMatch.any(
      texts,
      trigger.patterns,
      exceptPatterns: trigger.exceptPatterns,
    );
    if (!hit) continue;

    signals.add(
      CrisisSignal(
        trigger: trigger,
        channels: [
          for (final id in trigger.show)
            if (byId[id] != null) byId[id]!,
        ],
      ),
    );
  }

  // priority 가 먼저다. 죽고 싶다는 사람에게 빚 상담을 먼저 보여줄 수는 없다.
  signals.sort((a, b) {
    if (a.isPriority == b.isPriority) return 0;
    return a.isPriority ? -1 : 1;
  });
  return signals;
}

/// 세션 기준으로 신호를 찾는다.
List<CrisisSignal> crisisSignalsFor(
  Domain crisis,
  Domain domain,
  InterviewSession session,
  CaseFacts facts,
) =>
    detectCrisisSignals(
      crisis,
      domain,
      facts,
      extraTextFields: const {InterviewSession.narrativeField},
    );
