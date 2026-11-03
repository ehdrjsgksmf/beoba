import 'package:domain_data/domain_data.dart' show FeePart, FeeSchedule;
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../format/formatters.dart';
import '../safety/safe_text.dart';
import 'section_card.dart';
import 'verification_badge.dart';

/// 요금 구성. **더하지 않는다.**
///
/// 사다리의 앞쪽 칸(내용증명)은 소송보다 훨씬 싸다. 그 사실이 숫자로 보여야
/// 「법원까지 안 가도 되는 길」이 실제로 있다는 말이 힘을 얻는다.
///
/// 그런데 총액은 낼 수 없다 — 장수가 우편요금 구간과 등본 매수를 **동시에**
/// 움직인다. 모르는 것을 더해 하나의 숫자로 내놓으면 그건 계산이 아니라
/// 짐작이다. 그래서 줄만 늘어놓고 **왜 안 더하는지 말한다.**
class FeeScheduleView extends StatelessWidget {
  const FeeScheduleView({required this.fees, super.key});

  final FeeSchedule fees;

  static const String title = '드는 돈의 구성';
  static const String optionalMark = '고르시면';

  @override
  Widget build(BuildContext context) {
    if (fees.parts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SectionCard(
        background: BeobaColors.surfaceSoft,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeText(
              title,
              where: 'FeeScheduleView.title',
              style: theme.labelSmall?.copyWith(
                color: BeobaColors.ink3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final part in fees.parts) _PartRow(part: part),
            if (fees.totalNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              SafeText(
                fees.totalNote,
                where: 'FeeSchedule.totalNote',
                style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
              ),
            ],
            VerificationBadge(status: fees.verification.status),
          ],
        ),
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.part});

  final FeePart part;

  /// `470원 ~ 590원` · `2,400원`
  ///
  /// **범위를 하나로 줄이지 않는다.** 무게 구간을 우리가 못 고른다.
  String get _amount {
    final exact = part.amount;
    if (exact != null) return formatWon(exact);
    final from = part.amountFrom;
    final to = part.amountTo;
    if (from != null && to != null) return '${formatWon(from)} ~ ${formatWon(to)}';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SafeText(
                  part.optional
                      ? '${part.label} (${FeeScheduleView.optionalMark})'
                      : part.label,
                  where: 'FeePart.label',
                  style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
                ),
              ),
              SafeText(
                _amount,
                where: 'FeePart.amount',
                style: theme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
          if (part.note.isNotEmpty)
            SafeText(
              part.note,
              where: 'FeePart.note',
              style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
            ),
        ],
      ),
    );
  }
}
