import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../format/formatters.dart';
import '../../providers/domain_providers.dart';
import '../../providers/interview_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/crisis_banner.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../bootstrap_gate.dart';

/// 사건 정리 카드.
///
/// **이 앱에서 정확도를 고칠 수 있는 유일한 지점이다.** 그래서 "틀린 내용 고치기" 를
/// 눈에 띄게 둔다. 사용자가 여기서 바로잡지 않으면 뒤의 계산이 전부 틀린다.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({required this.domainId, super.key});

  final String domainId;

  static const String title = '이렇게 이해했어요';
  static const String fixTitle = '틀린 내용 고치기';
  static const String fixBody = '잘못 이해한 곳이 있으면 눌러서 고쳐 주세요. 여기서 고친 내용이 결과에 그대로 반영됩니다.';
  static const String fixRow = '고치기';
  /// 도착지에 무엇이 있는지 말한다. "결과 보기" 는 아무것도 알려주지 않는다.
  static const String next = '기한과 비용 보기';
  static const String emptyValue = '답하지 않음';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: beobaAppBar(context),
      body: BootstrapGate(
        child: Consumer(
          builder: (context, ref, _) {
            final theme = Theme.of(context).textTheme;
            final domain = ref.watch(domainBundleProvider).requireValue
                .byId(domainId);
            final session = ref.watch(interviewSessionProvider(domainId));

            return PageBody(
              bottom: PrimaryButton(
                label: next,
                where: 'SummaryScreen.next',
                onPressed: () => context.push(Routes.result(domainId)),
              ),
              children: [
                SafeText(
                  title,
                  where: 'SummaryScreen.title',
                  style: theme.headlineSmall,
                ),
                const SizedBox(height: 14),
                const _FixBanner(),
                const SizedBox(height: 18),
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final step in session.steps)
                        _SummaryRow(
                          question: domain.questionById(step.questionId),
                          value: step.value,
                          last: step == session.steps.last,
                          onFix: () => _fix(context, ref, step.questionId),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CrisisFooter(domainId: domainId),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 그 질문의 순번으로 간다.
  ///
  /// **질문 id 는 주소에 넣지 않는다.** 순번만 넣는다.
  ///
  /// "정리 카드에서 왔다" 는 표시는 질의 문자열로 나른다 — `extra` 는 웹에서
  /// 히스토리 state 로 가기 때문이다(DECISIONS 101번).
  void _fix(BuildContext context, WidgetRef ref, String questionId) {
    final questions = ref.read(applicableQuestionsProvider(domainId));
    final index = questions.indexWhere((q) => q.id == questionId);
    if (index < 0) return;

    context.push('${Routes.interview(domainId, index + 1)}?$kFromSummary=1');
  }
}

class _FixBanner extends StatelessWidget {
  const _FixBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SectionCard(
      background: BeobaColors.brandSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_outlined, size: 21, color: BeobaColors.brand),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  SummaryScreen.fixTitle,
                  where: 'SummaryScreen.fixTitle',
                  style: theme.titleMedium?.copyWith(color: BeobaColors.brand),
                ),
                const SizedBox(height: 5),
                SafeText(
                  SummaryScreen.fixBody,
                  where: 'SummaryScreen.fixBody',
                  style: theme.bodySmall?.copyWith(color: BeobaColors.brandInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.question,
    required this.value,
    required this.last,
    required this.onFix,
  });

  final Question? question;
  final Object? value;
  final bool last;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final q = question;
    if (q == null) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: BeobaColors.line2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: SafeText(
              q.text,
              where: 'Question.text',
              style: theme.bodySmall?.copyWith(color: BeobaColors.ink3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: SafeText(
              _display(q, value),
              where: 'SummaryScreen.value',
              // 사용자가 고른 선택지의 라벨이다. 인용으로 본다.
              style: theme.bodySmall?.copyWith(
                color: BeobaColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _FixButton(onPressed: onFix),
        ],
      ),
    );
  }

  /// 저장된 값을 사람이 읽는 말로 바꾼다.
  ///
  /// 선택지는 **라벨을 데이터에서** 가져온다. 코드가 `loan` 을 "빌려준 돈" 으로
  /// 번역하지 않는다 — 그러면 화면이 분야 어휘를 알게 된다.
  static String _display(Question question, Object? value) =>
      formatAnswer(question, value, empty: SummaryScreen.emptyValue);

}

class _FixButton extends StatelessWidget {
  const _FixButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, BeobaTapTarget.minimum),
        ),
        child: SafeText(
          SummaryScreen.fixRow,
          where: 'SummaryScreen.fixRow',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: BeobaColors.brand2,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
