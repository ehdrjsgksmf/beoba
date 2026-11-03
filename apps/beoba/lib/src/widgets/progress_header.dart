import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../format/formatters.dart';
import '../safety/safe_text.dart';

/// 진행바 + 판단가능성 점수.
///
/// `maxScore` 는 `showIf` 가지에 따라 **움직인다.** 답을 고치면 진행률이 뒤로 갈 수
/// 있는데 그게 맞다 — 물어야 할 질문이 늘어난 것이다.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    required this.answered,
    required this.total,
    required this.state,
    super.key,
  });

  final int answered;
  final int total;
  final InterviewState state;

  static const String scoreLabel = '판단가능성';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : (answered / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **`Row` 가 아니라 `Wrap` 이다.** 배율 2.0 에서 진행 표시와
        // 판단가능성이 한 줄에 안 들어가 79px 이 오른쪽으로 잘렸다.
        // `Wrap` 은 자리가 모자라면 아래로 내려보낸다 — 한 줄에 들어갈
        // 때의 모습은 그대로다.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 4,
          children: [
            SafeText(
              formatProgress(answered, total),
              where: 'ProgressHeader.progress',
              style: theme.labelSmall?.copyWith(
                fontWeight: FontWeight.w400,
                fontFeatures: kTabularFigures,
              ),
            ),
            _ReadinessChip(state: state),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: ratio, minHeight: 6),
        ),
      ],
    );
  }
}

/// 판단가능성 — 점수와 신호를 함께 보여준다. 색만으로 알리지 않는다.
class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({required this.state});

  final InterviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final (color, icon) = switch (state.readiness) {
      Readiness.green => (BeobaColors.green, Icons.check_circle_outline),
      Readiness.yellow => (BeobaColors.legalMaybe, Icons.help_outline),
      Readiness.red => (BeobaColors.red, Icons.error_outline),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        SafeText(
          ProgressHeader.scoreLabel,
          where: 'ProgressHeader.scoreLabel',
          style: theme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 5),
        SafeText(
          formatProgress(state.score, state.maxScore),
          where: 'ProgressHeader.score',
          style: theme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: kTabularFigures,
          ),
        ),
      ],
    );
  }
}
