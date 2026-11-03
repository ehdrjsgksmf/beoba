import 'package:engines/engines.dart' show DeadlineResult;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// **기한이 아니라 「언제부터」다.**
///
/// 답변서 30일은 지나면 잃는 날이다. 대항력이 생긴 날은 그 반대 — 그날부터
/// 힘이 생긴 날이다. 같은 카드에 넣으면 「D-13」이 붙고, 사람이 쫓길 일이
/// 아닌 것에 쫓긴다(DECISIONS 135번).
///
/// 그래서 D-day 도 빨간색도 없다. 날짜와 조문만 나란히 놓는다.
class StartsFromCard extends StatelessWidget {
  const StartsFromCard({required this.results, super.key});

  final List<DeadlineResult> results;

  static const String title = '언제부터 생겼나요';
  static const String from = '부터';

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: SectionCard(
        background: BeobaColors.greenSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: BeobaColors.green,
                ),
                const SizedBox(width: 7),
                SafeText(
                  title,
                  where: 'StartsFromCard.title',
                  style: theme.labelLarge?.copyWith(
                    color: BeobaColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            for (final result in results) ...[
              const SizedBox(height: 12),
              SafeText.forField(
                result.label,
                typeName: 'Deadline',
                fieldName: 'label',
                style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              // **D-day 를 붙이지 않는다.** 세는 날이 아니다.
              SafeText(
                '${formatKstDate(result.dueDate)}$from',
                where: 'StartsFromCard.date',
                style: theme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (result.whatIsThis.isNotEmpty) ...[
                const SizedBox(height: 3),
                SafeText.forField(
                  result.whatIsThis,
                  typeName: 'Deadline',
                  fieldName: 'whatIsThis',
                  style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
                ),
              ],
              const SizedBox(height: 9),
              LegalBasisCard(basis: result.basis, where: 'Deadline.${result.id}'),
              VerificationBadge(status: result.verification),
            ],
          ],
        ),
      ),
    );
  }
}
