import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/plain_title.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// 관할 법원.
///
/// **조회표가 아직 없다.** 모든 규칙이 `tableUnavailable` 로 나온다.
/// 그 사실을 숨기지 않고 그대로 적는다 — 없는 것을 있는 척하지 않는다.
class JurisdictionSection extends StatelessWidget {
  const JurisdictionSection({
    required this.results,
    this.showHeader = true,
    super.key,
  });

  final List<JurisdictionResult> results;

  /// 머리글을 그릴지. **접힌 카드 안에 들어갈 때는 끈다** — 카드가 이미 제목을
  /// 달고 있어서 머리글이 둘이 되면 카드 하나가 두 장으로 보인다.
  final bool showHeader;

  static const String title = '어느 법원으로 가나요';
  static const String empty = '이 사건에 적용할 관할 규칙이 없어요.';
  static const String tableUnavailable = '조회표를 아직 못 받아서 법원을 찾아 드릴 수 없어요.';
  static const String missingInput = '주소를 알려 주시면 관할 법원을 찾아 드려요.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          const SectionHeader(title, icon: Icons.account_balance_outlined),
        if (results.isEmpty)
          const NoticeBox(text: empty, where: 'JurisdictionSection.empty')
        else
          for (final result in results)
            Padding(
              padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
              child: _JurisdictionCard(result: result),
            ),
      ],
    );
  }
}

class _JurisdictionCard extends StatelessWidget {
  const _JurisdictionCard({required this.result});

  final JurisdictionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SectionCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlainTitle(
            label: result.label,
            whatIsThis: result.whatIsThis,
            where: 'JurisdictionResult',
          ),
          if (result.rule.isNotEmpty) ...[
            const SizedBox(height: 6),
            SafeText(
              result.rule,
              where: 'JurisdictionResult.rule',
              style: theme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          _Status(result: result),
          VerificationBadge(status: result.verification),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.result});

  final JurisdictionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final court = result.court;

    return switch (result.status) {
      JurisdictionStatus.resolved when court != null => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 19,
              color: BeobaColors.brand,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SafeText(
                court,
                where: 'JurisdictionResult.court',
                style: theme.titleMedium?.copyWith(color: BeobaColors.brand),
              ),
            ),
          ],
        ),
      JurisdictionStatus.missingInput => const NoticeBox(
          text: JurisdictionSection.missingInput,
          where: 'JurisdictionSection.missingInput',
        ),
      _ => const NoticeBox(
          text: JurisdictionSection.tableUnavailable,
          where: 'JurisdictionSection.tableUnavailable',
        ),
    };
  }
}
