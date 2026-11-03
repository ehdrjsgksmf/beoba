import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

/// 인터뷰에서 답 하나.
class AnsweredStep {
  const AnsweredStep({required this.questionId, required this.value});

  final String questionId;
  final Object? value;

  AnsweredStep withValue(Object? next) =>
      AnsweredStep(questionId: questionId, value: next);

  @override
  bool operator ==(Object other) =>
      other is AnsweredStep &&
      other.questionId == questionId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(questionId, value);

  @override
  String toString() => 'AnsweredStep($questionId = $value)';
}

/// 인터뷰의 **유일한 진실**은 [steps] 다. `CaseFacts` 는 매번 여기서 다시 만든다.
///
/// 왜 이렇게 하는가 — `InterviewEngine.answer` 는 `CaseFacts.merge` 로 필드를
/// 덮어쓸 뿐이고 되돌리지 못한다. 선택지의 `setsField` 부산물은 더더욱 그렇다.
///
/// ```
/// q_court_document = payment_order   → hasCourtDocument, hasPaymentOrder 가 켜진다
/// q_court_document = none 으로 수정   → merge 로는 hasPaymentOrder 가 남는다
/// ```
///
/// 남은 `hasPaymentOrder` 는 있지도 않은 지급명령 이의 기한을 결과 화면에 띄운다.
/// 사건 정리 카드의 "틀린 내용 고치기" 가 정확히 이 경로다. 그래서 커서를 되감는
/// 대신 **처음부터 다시 접는다.** 12개짜리 리플레이는 비용이 없다.
class InterviewSession {
  const InterviewSession({
    this.narrative = '',
    this.steps = const [],
    this.dismissedStopIds = const {},
    this.dismissedSignalIds = const {},
  });

  /// 홈 화면의 자유 입력. 저장하지 않고 사건 분류에만 쓴다.
  final String narrative;

  final List<AnsweredStep> steps;

  /// 확인 화면에서 "아니요" 를 누른 키워드 하드스톱.
  ///
  /// 리플레이해도 같은 것을 다시 묻지 않는다. 한 번 아니라고 한 것을 계속 묻는 건
  /// 차단하는 것과 다를 바 없다.
  final Set<String> dismissedStopIds;

  /// 닫은 위기 신호.
  ///
  /// **닫기는 제거가 아니라 강등이다.** 전체 화면·배너로 다시 밀지 않을 뿐,
  /// priority 신호는 상단 고정 줄로 남고 나머지는 결과·정리 카드 하단에 남는다.
  /// 급해서 닫은 사람과 필요 없어서 닫은 사람을 구분할 방법이 없다.
  final Set<String> dismissedSignalIds;

  /// 자유 입력이 담기는 `CaseFacts` 키.
  ///
  /// 도메인 질문의 `field` 와 겹치지 않는 이름이어야 한다.
  static const String narrativeField = 'userNarrative';

  InterviewSession copyWith({
    String? narrative,
    List<AnsweredStep>? steps,
    Set<String>? dismissedStopIds,
    Set<String>? dismissedSignalIds,
  }) =>
      InterviewSession(
        narrative: narrative ?? this.narrative,
        steps: steps ?? this.steps,
        dismissedStopIds: dismissedStopIds ?? this.dismissedStopIds,
        dismissedSignalIds: dismissedSignalIds ?? this.dismissedSignalIds,
      );

  AnsweredStep? stepFor(String questionId) {
    for (final step in steps) {
      if (step.questionId == questionId) return step;
    }
    return null;
  }

  bool get isEmpty => steps.isEmpty && narrative.isEmpty;
}

/// 리플레이 결과.
class ReplayResult {
  const ReplayResult({
    required this.facts,
    required this.kept,
    required this.dropped,
  });

  final CaseFacts facts;

  /// 살아남은 답. 세션에 그대로 써 넣는다.
  final List<AnsweredStep> kept;

  /// 버려진 답 — 가지가 닫혔거나 질문이 사라졌다.
  final List<AnsweredStep> dropped;
}

/// [InterviewSession.steps] 를 처음부터 접어 `CaseFacts` 를 만든다.
///
/// 접는 도중 `showIf` 로 더 이상 해당 없어진 질문의 답은 버린다. 그 답이 켰던
/// `setsField` 값도 함께 사라진다 — 애초에 다시 쓰지 않기 때문이다.
ReplayResult replayInterview(
  Domain domain,
  InterviewSession session, {
  InterviewEngine engine = const InterviewEngine(),
}) {
  var facts = session.narrative.isEmpty
      ? const CaseFacts()
      : CaseFacts({InterviewSession.narrativeField: session.narrative});

  final kept = <AnsweredStep>[];
  final dropped = <AnsweredStep>[];

  for (final step in session.steps) {
    final question = domain.questionById(step.questionId);
    if (question == null) {
      // 도메인이 갱신돼 질문이 사라졌다. 답을 붙일 곳이 없다.
      dropped.add(step);
      continue;
    }
    if (!JsonLogic.test(question.showIf, facts.toJsonLogicData())) {
      // 앞선 답을 고쳐서 이 가지가 닫혔다.
      dropped.add(step);
      continue;
    }

    facts = engine.answer(domain, facts, step.questionId, step.value);
    kept.add(step);
  }

  return ReplayResult(facts: facts, kept: kept, dropped: dropped);
}
