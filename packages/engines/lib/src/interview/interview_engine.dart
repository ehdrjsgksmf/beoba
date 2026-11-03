import 'package:domain_data/domain_data.dart';

import '../core/case_facts.dart';
import '../core/engine.dart';
import '../core/json_logic.dart';
import '../core/keyword_match.dart';
import '../core/user_text.dart';

/// 결과 화면을 보여줘도 되는지.
enum Readiness {
  /// 충분히 물었다.
  green,

  /// 부족하지만 보여주되 무엇이 비었는지 함께 알린다.
  yellow,

  /// 결과 화면 대신 되돌아간다.
  red,
}

class InterviewState {
  const InterviewState({
    required this.score,
    required this.maxScore,
    required this.readiness,
    this.nextQuestion,
    this.redirectDomainId,
    this.missingRequiredFields = const [],
    this.triggeredHardStopIds = const [],
  });

  /// null 이면 더 물을 게 없다.
  final Question? nextQuestion;
  final int score;
  final int maxScore;
  final Readiness readiness;

  /// 다른 분야로 이관해야 하면 그 도메인 id.
  final String? redirectDomainId;
  final List<String> missingRequiredFields;
  final List<String> triggeredHardStopIds;

  bool get isComplete => nextQuestion == null;

  @override
  String toString() =>
      '${readiness.name} · $score/$maxScore · 다음: ${nextQuestion?.id ?? '없음'}';
}

/// 인터뷰 진행. **LLM 없이 선택지만으로 동작한다.**
///
/// 질문을 생성하지 않는다. 도메인 JSON 의 `intake` 목록에서 고를 뿐이다.
/// 임계값은 전부 `domain.scoring` 에서 읽는다.
class InterviewEngine implements Engine<InterviewState> {
  const InterviewEngine();

  /// `scoring` 이 없는 도메인의 yellow 기준 (만점 대비 비율).
  static const double defaultYellowRatio = 0.6;

  @override
  InterviewState compute(
    Domain domain,
    CaseFacts facts, {
    Set<String> extraTextFields = const {},
  }) {
    final applicable = applicableQuestions(domain, facts);
    final missing = applicable
        .where((q) => q.isRequired && !facts.has(q.field))
        .map((q) => q.field)
        .toList();

    return InterviewState(
      nextQuestion: next(domain, facts),
      score: score(domain, facts),
      maxScore: maxScore(domain, facts),
      readiness: readiness(domain, facts),
      redirectDomainId: redirectFor(domain, facts),
      missingRequiredFields: missing,
      triggeredHardStopIds: triggeredHardStops(
        domain,
        facts,
        extraTextFields: extraTextFields,
      ),
    );
  }

  /// `showIf` 를 만족하는 질문만. order 순.
  List<Question> applicableQuestions(Domain domain, CaseFacts facts) {
    final data = facts.toJsonLogicData();
    final questions = domain.intake
        .where((q) => JsonLogic.test(q.showIf, data))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return questions;
  }

  /// 다음에 물을 질문. 없으면 null.
  Question? next(Domain domain, CaseFacts facts) {
    for (final question in applicableQuestions(domain, facts)) {
      if (!facts.has(question.field)) return question;
    }
    return null;
  }

  /// 답한 질문의 weight 합.
  int score(Domain domain, CaseFacts facts) => applicableQuestions(domain, facts)
      .where((q) => facts.has(q.field))
      .fold(0, (sum, q) => sum + q.weight);

  /// 지금 조건에서 얻을 수 있는 최대 점수.
  int maxScore(Domain domain, CaseFacts facts) =>
      applicableQuestions(domain, facts).fold(0, (sum, q) => sum + q.weight);

  Readiness readiness(Domain domain, CaseFacts facts) {
    final applicable = applicableQuestions(domain, facts);
    final required = applicable.where((q) => q.isRequired).toList();
    final answeredRequired = required.where((q) => facts.has(q.field)).length;
    final currentScore = score(domain, facts);

    final scoring = domain.scoring;
    // **문턱은 지금 갈래에서 딸 수 있는 점수를 넘지 못한다.**
    //
    // 문턱이 절대값이라 `showIf` 로 갈라지는 분야에서 그대로 두면 짧은 갈래는
    // **영영 red 다.** 채무자는 묻는 문항이 넷인데 문턱이 14였고, 다 답해도
    // 8점이라 결과 화면이 열리지 않았다. 사람이 답을 다 했는데 「정보가
    // 모자랍니다」가 뜨는 것은 데이터가 아니라 셈의 잘못이다(DECISIONS 120번).
    final ceiling = maxScore(domain, facts);
    final green = scoring == null
        ? ceiling
        : scoring.greenThreshold.clamp(0, ceiling);
    final yellow = scoring == null
        ? (ceiling * defaultYellowRatio).ceil()
        : scoring.yellowThreshold.clamp(0, ceiling);
    final requiredRatio = scoring?.requiredFieldRatio ?? 0.7;

    final allRequiredAnswered =
        required.isEmpty || answeredRequired == required.length;
    if (allRequiredAnswered && currentScore >= green) return Readiness.green;

    final ratio = required.isEmpty ? 1.0 : answeredRequired / required.length;
    if (ratio >= requiredRatio && currentScore >= yellow) return Readiness.yellow;

    return Readiness.red;
  }

  /// 답을 기록한다. 선택지의 `setsField` 도 함께 반영한다.
  CaseFacts answer(
    Domain domain,
    CaseFacts facts,
    String questionId,
    Object? value,
  ) {
    final question = domain.questionById(questionId);
    if (question == null) {
      throw ArgumentError.value(questionId, 'questionId', '없는 질문입니다');
    }

    final patch = <String, Object?>{question.field: value};
    for (final option in _selectedOptions(question, value)) {
      final sets = option.setsField;
      if (sets != null) patch.addAll(sets);
    }
    return facts.merge(patch);
  }

  /// 다른 분야로 넘겨야 하면 그 도메인 id.
  String? redirectFor(Domain domain, CaseFacts facts) {
    for (final question in domain.intake) {
      final value = facts.values[question.field];
      if (value == null) continue;
      for (final option in _selectedOptions(question, value)) {
        if (option.redirect != null) return option.redirect;
      }
    }
    return null;
  }

  /// 지금까지의 답만으로 발동하는 하드스톱.
  /// 걸린 하드스톱 id 들.
  ///
  /// 키워드 검사는 **사용자가 직접 타이핑한 문자열에만** 한다 ([userTypedText]).
  /// [extraTextFields] 로 도메인 질문 밖의 자유 입력 필드를 더할 수 있다.
  List<String> triggeredHardStops(
    Domain domain,
    CaseFacts facts, {
    Set<String> extraTextFields = const {},
  }) {
    final triggered = <String>[];
    final texts = userTypedText(
      domain,
      facts,
      extraFields: extraTextFields,
    ).toList();

    for (final hardStop in domain.hardStops) {
      final trigger = hardStop.trigger;
      switch (trigger) {
        case FieldHardStopTrigger(:final field, :final equalsValue):
          if (facts.values[field] == equalsValue) triggered.add(hardStop.id);
        case KeywordHardStopTrigger(:final patterns, :final exceptPatterns):
          final hit = KeywordMatch.any(
            texts,
            patterns,
            exceptPatterns: exceptPatterns,
          );
          if (hit) triggered.add(hardStop.id);
      }
    }
    return triggered;
  }

  Iterable<QuestionOption> _selectedOptions(Question question, Object? value) {
    final selected = value is List ? value.map((v) => v.toString()).toSet() : {
      value.toString(),
    };
    return question.options.where((o) => selected.contains(o.value));
  }

}
