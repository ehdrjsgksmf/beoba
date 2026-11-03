import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interview/hard_stops.dart';
import '../interview/interview_session.dart';
import 'domain_providers.dart';

/// 홈에서 적은 문장을 분야 선택 화면까지 들고 간다. **메모리에만 둔다.**
///
/// 예전에는 go_router 의 `extra` 로 넘겼다. 그런데 `extraCodec` 을 주지 않으면
/// go_router 가 `json.encode` 로 라우트 상태에 실어 버리고, 웹에서는 그것이
/// 그대로 **브라우저 히스토리 state** 로 들어간다. 주소창에는 안 보여도
/// 뒤로·앞으로에 남고 세션 복원으로 디스크까지 간다.
///
/// 홈 화면이 「어디에도 남지 않습니다」라고 **약속**한다.
/// **화면이 하는 약속은 코드가 먼저 지킨 뒤에 쓴다.**
class PendingNarrative extends Notifier<String> {
  @override
  String build() => '';

  void hold(String text) => state = text;

  /// ## 인터뷰가 시작돼도 비우지 않는다
  ///
  /// 여기에는 「인터뷰로 넘어가면 즉시 비운다」는 `clear()` 가 있었다.
  /// **아무도 부르지 않았다.** 부를 수도 없었다 — 분야 목록으로 되돌아간
  /// 사람에게 알아챈 분야를 다시 보여 주려면 그 문장이 있어야 한다
  /// (`detectedDomainsProvider`).
  ///
  /// 그래서 지웠다. **못 지키는 약속을 코드에 적어 두면 다음 사람이 그것을
  /// 사실로 읽는다.** 사실은 이렇다 — 이 문장은 앱을 닫을 때까지 메모리에
  /// 남고, 디스크·주소창·집계 어디로도 가지 않는다. 방침 2절이 약속한 것도
  /// 「저장하지 않는다」이지 「즉시 잊는다」가 아니다.
}

final pendingNarrativeProvider =
    NotifierProvider<PendingNarrative, String>(PendingNarrative.new);

/// 분야 하나의 인터뷰 진행 상태.
///
/// 답을 넣고 빼는 일만 한다. **어느 질문을 보고 있는지는 여기 없다** — 그건 라우트가
/// 안다. 커서를 상태로 들고 있으면 브라우저·하드웨어 뒤로가기와 어긋난다.
class InterviewController extends Notifier<InterviewSession> {
  /// riverpod 3 의 family 는 인자를 **생성자로** 넘긴다 (`FamilyNotifier` 는 없어졌다).
  InterviewController(this.domainId);

  final String domainId;

  static const InterviewEngine _engine = InterviewEngine();

  @override
  InterviewSession build() => const InterviewSession();

  Domain get _domain => requireBundle(ref).byId(domainId);

  /// 홈에서 받은 자유 입력. 인터뷰를 처음부터 다시 시작한다.
  /// 알아챈 답을 미리 채운다. **되돌릴 수 없는 것은 여기 안 온다** —
  /// 날짜와 기한에 닿는 필드는 검증기가 데이터에서 막는다(DECISIONS 130번).
  void prefill(Map<String, Object?> answers) {
    answers.forEach(answer);
  }

  void start(String narrative) {
    state = InterviewSession(narrative: narrative.trim());
  }

  /// 답 하나를 넣는다. 이미 답한 질문이면 값을 갈아끼운다.
  ///
  /// 값을 갈아끼운 뒤에는 **뒤따르던 답 중 가지가 닫힌 것이 저절로 사라진다** —
  /// 리플레이가 처음부터 다시 접기 때문이다.
  void answer(String questionId, Object? value) {
    final existing = state.stepFor(questionId);
    final steps = [...state.steps];

    if (existing == null) {
      steps.add(AnsweredStep(questionId: questionId, value: value));
    } else {
      steps[steps.indexOf(existing)] = existing.withValue(value);
    }

    _commit(state.copyWith(steps: steps));
  }

  /// 키워드 하드스톱 확인 화면에서 "아니요" 를 눌렀다.
  ///
  /// **같은 종류를 한꺼번에 내린다.** 같은 낱말이 분야 도메인과 공용 위기 데이터
  /// 양쪽에 걸리는 일이 흔한데(`고소` → `hs_criminal` · `hs_criminal_fraud`),
  /// 하나씩 물으면 사용자는 같은 질문을 두 번 받는다. 그건 차단과 다를 바 없다.
  void dismissHardStops(Set<String> stopIds) {
    if (stopIds.isEmpty) return;
    state = state.copyWith(
      dismissedStopIds: {...state.dismissedStopIds, ...stopIds},
    );
  }

  /// 위기 안내를 닫았다. **제거가 아니라 강등이다** — 남는 자리는 화면이 정한다.
  void dismissSignal(String signalId) {
    state = state.copyWith(
      dismissedSignalIds: {...state.dismissedSignalIds, signalId},
    );
  }

  /// 가지가 닫혀 버려진 답을 세션에서도 지운다.
  void _commit(InterviewSession next) {
    final replayed = replayInterview(_domain, next, engine: _engine);
    state =
        replayed.dropped.isEmpty ? next : next.copyWith(steps: replayed.kept);
  }
}

final interviewSessionProvider = NotifierProvider.family<InterviewController,
    InterviewSession, String>(InterviewController.new);

/// 리플레이 결과. 화면이 보는 사실은 전부 여기서 나온다.
final replayProvider = Provider.family<ReplayResult, String>((ref, domainId) {
  final domain = requireBundle(ref).byId(domainId);
  final session = ref.watch(interviewSessionProvider(domainId));
  return replayInterview(domain, session);
});

final caseFactsProvider = Provider.family<CaseFacts, String>(
  (ref, domainId) => ref.watch(replayProvider(domainId)).facts,
);

final interviewStateProvider = Provider.family<InterviewState, String>(
  (ref, domainId) => const InterviewEngine().compute(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
    extraTextFields: const {InterviewSession.narrativeField},
  ),
);

/// 지금 조건에서 물어야 할 질문들. `showIf` 가지에 따라 **움직인다.**
///
/// 라우트의 순번은 이 목록의 위치다. 답을 고쳐 목록이 바뀌면 순번이 가리키는 질문도
/// 바뀌는데, 라우터 가드가 유효한 자리로 되돌리므로 깨진 화면은 나오지 않는다.
final applicableQuestionsProvider =
    Provider.family<List<Question>, String>((ref, domainId) {
  return const InterviewEngine().applicableQuestions(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  );
});

/// 지금 답해야 할 질문의 **1부터 시작하는 순번**. 다 답했으면 null.
final currentStepProvider = Provider.family<int?, String>((ref, domainId) {
  final questions = ref.watch(applicableQuestionsProvider(domainId));
  final facts = ref.watch(caseFactsProvider(domainId));

  for (var i = 0; i < questions.length; i++) {
    if (!facts.has(questions[i].field)) return i + 1;
  }
  return null;
});

/// 순번으로 질문을 찾는다. 범위를 벗어나면 null.
Question? questionAtStep(List<Question> questions, int step) =>
    step < 1 || step > questions.length ? null : questions[step - 1];

/// 걸린 하드스톱. 분야 도메인 + 공용 위기 데이터를 함께 본다.
final hardStopsProvider =
    Provider.family<List<TriggeredHardStop>, String>((ref, domainId) {
  final bundle = requireBundle(ref);
  return hardStopsFor(
    [bundle.byId(domainId), bundle.crisis],
    ref.watch(interviewSessionProvider(domainId)),
    ref.watch(caseFactsProvider(domainId)),
  );
});

/// 다른 분야로 넘겨야 하는 답을 골랐는가. M1 에는 옮겨 갈 분야가 없어 안내로 끝낸다.
final redirectDomainProvider = Provider.family<String?, String>(
  (ref, domainId) => ref.watch(interviewStateProvider(domainId)).redirectDomainId,
);

/// 자유 입력에서 알아챈 분야들. **고르는 게 아니라 후보를 좁힌다.**
///
/// 홈에서 적은 글만 본다. 인터뷰에서 고른 답은 보지 않는다 — 답을 고치는
/// 순간 분야가 흔들리면 사용자는 자기가 무엇을 하고 있는지 알 수 없게 된다.
final detectedDomainsProvider = Provider<List<DetectedDomain>>((ref) {
  final narrative = ref.watch(pendingNarrativeProvider);
  if (narrative.trim().isEmpty) return const [];

  final bundle = ref.watch(domainBundleProvider).value;
  if (bundle == null) return const [];

  return const DomainDetectEngine().detect(bundle.domains.values, narrative);
});
