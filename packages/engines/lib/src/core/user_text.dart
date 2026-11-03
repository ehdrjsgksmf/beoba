import 'package:domain_data/domain_data.dart';

import 'case_facts.dart';

/// 낱말 검사(하드스톱 · 위기 신호)가 볼 수 있는 문자열.
///
/// **사용자가 직접 타이핑한 것만 본다.** `CaseFacts` 전체를 훑으면 우리가 쓴 말이
/// 사용자가 쓴 말로 둔갑한다.
///
/// ```
/// q_debtor_response.options[1]
///   value = "no_money"            ← facts 에 들어가는 것
///   label = "돈이 없다고 합니다"    ← 화면에만 쓰는 것
/// ```
///
/// 지금은 선택지 value 가 전부 ASCII 라 우연히 부딪히지 않는다. 그런데 **그걸
/// 강제하는 장치가 없다.** 다음 분야가 `"value": "돈이 없음"` 이라고 쓰거나
/// `setsField` 로 한글을 넣는 순간, 상대가 돈이 없다고 했다는 답을 고른 채권자에게
/// 긴급복지 창구가 뜬다. 같은 낱말이라도 **누가 썼는지에 따라 뜻이 다르다.**
///
/// 그래서 "우연히 안 부딪힌다" 에 기대지 않고 볼 곳을 처음부터 좁힌다.
Iterable<String> userTypedText(
  Domain domain,
  CaseFacts facts, {
  /// 도메인 질문 밖에서 받은 자유 입력 필드. 홈 화면 서술 등.
  Set<String> extraFields = const {},
}) sync* {
  for (final field in {...freeTextFields(domain), ...extraFields}) {
    final value = facts.values[field];
    if (value is String && value.isNotEmpty) yield value;
  }
}

/// `type: text` 질문이 답을 담는 필드들.
///
/// 선택지·금액·날짜는 사용자가 고르거나 입력한 **값**이지 문장이 아니다.
Set<String> freeTextFields(Domain domain) => {
      for (final question in domain.intake)
        if (question.type == QuestionType.text) question.field,
    };
