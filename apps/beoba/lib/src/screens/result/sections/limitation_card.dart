import 'package:domain_data/domain_data.dart'
    show LimitationKind, LimitationRule;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/expandable_card.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/verification_badge.dart';

/// 「언제까지 요구할 수 있나요」.
///
/// ## 계산하지 않는다. 갈래로 낸다
///
/// 몇 년인지가 사건마다 달라서 **우리가 고르면 틀릴 수 있다.** 그래서
/// 날짜를 세지 않고 법에 어떻게 쓰여 있는지를 나란히 낸다 — 비용에서
/// 이미 하고 있는 것과 같다([DECISIONS 75](#75)).
///
/// 「확인 안 됨」 배지를 달지 않는다. **안 정한 것이지 못 정한 것이 아니다.**
///
/// ## 채무자에게는 이 카드를 그리지 않는다
///
/// 같은 문장이 역할에 따라 정반대로 작동한다.
///
/// ```
/// 받을 사람에게   「시효가 지났을 수 있어요」  → 포기한다
/// 갚으라는 요구를 받은 사람에게 같은 말        → 대응을 안 한다
///                                             → 그대로 판결이 난다
/// ```
///
/// 그 사람에게는 답변서·이의신청 기한이 이미 맨 위에 있고 그게 급하다.
/// 시효는 그 자리에서 꺼낼 이야기가 아니다. 판정은 `result_screen` 이 한다.
class LimitationCard extends StatelessWidget {
  const LimitationCard({required this.rules, super.key});

  final List<LimitationRule> rules;

  static const String title = '언제까지 요구할 수 있나요';

  /// **「못 해요」로 끝내지 않는다.** 맨 아래에 [outro] 가 온다.
  static const String intro = '이건 날짜로 계산해 드리지 못해요. '
      '몇 년인지가 사건마다 달라서, 저희가 정하면 틀릴 수 있거든요. '
      '대신 법에 어떻게 쓰여 있는지 다 보여드릴게요.';
  static const String outro = '내 경우가 몇 년인지 정확히 알고 싶으시면, '
      '아래 창구에서 무료로 물어보실 수 있어요.';

  static const String branchTitle = '몇 년인가요';
  static const String startTitle = '언제부터 세나요';
  static const String interruptTitle = '멈추는 일이 있어요';

  static String titleOf(LimitationKind kind) => switch (kind) {
        LimitationKind.branch => branchTitle,
        LimitationKind.start => startTitle,
        LimitationKind.interrupt => interruptTitle,
      };

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return ExpandableCard(
      title: title,
      where: 'LimitationCard',
      icon: Icons.hourglass_empty,
      summary: SafeText(
        intro,
        where: 'LimitationCard.intro',
        style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final kind in LimitationKind.values)
            if (rules.any((r) => r.kind == kind)) ...[
              SafeText(
                titleOf(kind),
                where: 'LimitationCard.groupTitle',
                style: theme.labelSmall?.copyWith(
                  color: BeobaColors.ink3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              for (final rule in rules.where((r) => r.kind == kind))
                _Rule(rule: rule),
              const SizedBox(height: 14),
            ],
          SafeText(
            outro,
            where: 'LimitationCard.outro',
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
          ),
        ],
      ),
    );
  }
}

/// 갈래 하나. **어느 하나를 고르지 않으므로 강조도 하지 않는다.**
class _Rule extends StatelessWidget {
  const _Rule({required this.rule});

  final LimitationRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeText(
            rule.label,
            where: 'LimitationRule.label',
            style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (rule.note.isNotEmpty) ...[
            const SizedBox(height: 3),
            SafeText(
              rule.note,
              where: 'LimitationRule.note',
              style: theme.labelMedium,
            ),
          ],
          const SizedBox(height: 8),
          LegalBasisCard(
            basis: rule.legalBasis,
            where: 'LimitationRule.${rule.id}',
          ),
          for (final also in rule.alsoBasis) ...[
            const SizedBox(height: 7),
            LegalBasisCard(
              basis: also,
              where: 'LimitationRule.${rule.id}.also',
            ),
          ],
          VerificationBadge(status: rule.verification.status),
        ],
      ),
    );
  }
}

/// 갚으라는 요구를 받은 사람에게 대신 나가는 한 줄.
///
/// **시효를 지칭하지 않으면서 길은 연다.** 「시효를 주장할 수 있어요」라고
/// 쓰지 않는다 — 법원에서 그 말을 해야 하는지 아닌지를 우리가 조문으로
/// 댈 수 없다. 그 사람에게 급한 것은 답변서·이의신청 기한이고 그건 이미
/// 맨 위에 있다.
class LimitationForDebtor extends StatelessWidget {
  const LimitationForDebtor({super.key});

  static const String line = '기한을 지키는 것 말고도 다툴 수 있는 사유가 있는지는 '
      '창구에서 물어보실 수 있어요.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.support_agent_outlined,
              size: 17,
              color: BeobaColors.ink3,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SafeText(
              line,
              where: 'LimitationForDebtor.line',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: BeobaColors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
