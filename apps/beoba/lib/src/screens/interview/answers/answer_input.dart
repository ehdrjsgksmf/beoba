import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';

import 'choice_input.dart';
import 'date_input.dart';
import 'money_input.dart';
import 'text_input.dart';

/// 질문 타입에 맞는 입력 위젯을 고른다.
///
/// 타입이 늘어나면 여기만 손댄다. 화면은 타입을 모른다.
class AnswerInput extends StatelessWidget {
  const AnswerInput({
    required this.question,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Question question;

  /// 이전에 답한 값. 되돌아왔을 때 그대로 채워진다.
  final Object? value;

  /// 값이 바뀔 때마다 부른다. 확정은 "다음" 버튼이 한다.
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return switch (question.type) {
      QuestionType.single => SingleChoiceInput(
          question: question,
          value: value as String?,
          onChanged: onChanged,
        ),
      QuestionType.multi => MultiChoiceInput(
          question: question,
          value: _asStringList(value),
          onChanged: onChanged,
        ),
      QuestionType.money => MoneyInput(
          question: question,
          value: value as int?,
          onChanged: onChanged,
        ),
      QuestionType.number => MoneyInput(
          question: question,
          value: value as int?,
          onChanged: onChanged,
          asMoney: false,
        ),
      QuestionType.date => DateInput(
          question: question,
          value: _asApproxDate(value),
          onChanged: onChanged,
        ),
      QuestionType.text => FreeTextInput(
          question: question,
          value: value as String?,
          onChanged: onChanged,
        ),
    };
  }

  /// 저장된 날짜는 [ApproxDate] 이지만, 예전 답이나 테스트 값이 [KstDate] 로 올 수
  /// 있다. 정확한 날짜는 어림값의 특수 케이스라 그대로 감싼다.
  static ApproxDate? _asApproxDate(Object? value) => switch (value) {
        final ApproxDate a => a,
        final KstDate d => ApproxDate.exact(d),
        final String s => ApproxDate.tryParse(s),
        _ => null,
      };

  static List<String> _asStringList(Object? value) => switch (value) {
        final List<dynamic> list => list.map((e) => '$e').toList(),
        final String single => [single],
        _ => const [],
      };
}

/// 답이 채워졌는가. "다음" 버튼을 열지 결정한다.
bool hasAnswer(Question question, Object? value) => switch (value) {
      null => false,
      final String text => text.trim().isNotEmpty,
      final List<dynamic> list => list.isNotEmpty,
      _ => true,
    };
