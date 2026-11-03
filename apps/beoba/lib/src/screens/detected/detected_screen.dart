import 'package:domain_data/domain_data.dart' show Question;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../format/formatters.dart';
import '../../providers/domain_providers.dart';
import '../../providers/interview_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';

/// 「이렇게 이해했어요」 — 알아챈 것을 확인받는다.
///
/// **고르는 게 아니라 후보를 좁히는 것이다.** 자유 입력에서 분야가 하나만
/// 걸렸을 때, 바로 인터뷰로 넘기지 않고 여기서 한 번 확인받는다. 틀렸으면
/// 사용자가 고친다.
///
/// **경보가 먼저다.** 위기 신호와 하드스톱은 이 화면보다 앞에서 걸린다 —
/// 홈이 세션을 열자마자 보고, 가드가 이 경로도 덮는다.
class DetectedScreen extends ConsumerWidget {
  const DetectedScreen({required this.domainId, super.key});

  final String domainId;

  static const String title = '이렇게 이해했어요';
  static const String hint = '맞으면 계속하기, 틀리면 눌러서 고쳐 주세요.';
  static const String fix = '바꾸기';
  static const String next = '맞아요, 계속하기';
  static const String otherDomain = '다른 분야를 고를게요';
  static const String domainRow = '분야';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final bundle = ref.watch(domainBundleProvider).requireValue;
    final domain = bundle.domains[domainId];
    if (domain == null) return const SizedBox.shrink();

    final answers = ref.watch(interviewSessionProvider(domainId)).steps;
    final questions = ref.watch(applicableQuestionsProvider(domainId));

    return PageBody(
      bottom: PrimaryButton(
        label: next,
        where: 'DetectedScreen.next',
        onPressed: () => context.push(Routes.interview(domainId)),
      ),
      children: [
        SafeText(title, where: 'DetectedScreen.title', style: theme.headlineSmall),
        const SizedBox(height: 8),
        SafeText(
          hint,
          where: 'DetectedScreen.hint',
          style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row(
                label: domainRow,
                value: domain.name,
                onFix: () => context.push(Routes.domains),
              ),
              for (final step in answers)
                if (_questionFor(questions, step.questionId) case final q?)
                  _Row(
                    label: q.text,
                    value: _valueText(q, step.value),
                    onFix: () => context.push(
                      Routes.interview(domainId, _stepOf(questions, q.id)),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.push(Routes.domains),
            child: SafeText(otherDomain, where: 'DetectedScreen.otherDomain'),
          ),
        ),
      ],
    );
  }
}

/// 확인 카드의 한 줄. 라벨 · 값 · 바꾸기.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onFix});

  final String label;
  final String value;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText.forField(
                  label,
                  typeName: 'Question',
                  fieldName: 'text',
                  style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
                ),
                const SizedBox(height: 2),
                SafeText.forField(
                  value,
                  typeName: 'Question',
                  fieldName: 'text',
                  style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onFix,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, BeobaTapTarget.minimum),
            ),
            child: SafeText(DetectedScreen.fix, where: 'DetectedScreen.fix'),
          ),
        ],
      ),
    );
  }
}

Question? _questionFor(List<Question> questions, String id) {
  for (final question in questions) {
    if (question.id == id) return question;
  }
  return null;
}

int _stepOf(List<Question> questions, String id) {
  final at = questions.indexWhere((question) => question.id == id);
  return at < 0 ? 1 : at + 1;
}

/// 화면에 낼 답. **금액은 포매터를 거친다** — 화면이 다시 셈하지 않는다.
String _valueText(Question question, Object? value) {
  if (value is int) return formatWon(value);
  for (final option in question.options) {
    if (option.value == value) return option.label;
  }
  return '$value';
}
