import 'package:engines/engines.dart' show DeadlineResult;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// **신청 기한이 아니라 받는 기간이다.**
///
/// 이 앱의 다른 기한은 전부 「그 안에 신청해야 한다」다 — 넘기면 신청할
/// 권리를 잃는다. 구직급여의 12개월은 다르다. **그 안에 다 받아야 하는
/// 기간**이라, 늦게 신청하면 신청 자체가 막히는 것이 아니라 **아직 안 받은
/// 날짜가 그만큼 사라진다**(고용보험법 제48조 제1항).
///
/// 같은 카드로 그리면 「그날까지 신청하면 다 받는다」로 읽힌다. 그래서
/// 「오늘 할 일」에도 안 넣고 D-day 도 안 붙인다 — 대신 **지나면 무엇이
/// 사라지는지**를 카드가 스스로 말한다(DECISIONS 189번).
///
/// 「빨리 신청하세요」라고 쓰지 않는다. 재촉이 아니라 셈이다.
class ReceiveWindowCard extends StatelessWidget {
  const ReceiveWindowCard({required this.results, super.key});

  final List<DeadlineResult> results;

  static const String title = '언제까지 받을 수 있나요';
  static const String until = '까지';

  /// **이 카드의 핵심 한 줄.** 다른 기한 카드에는 없는 문장이다.
  static const String shrinks =
      '이 날짜가 지나면, 아직 못 받은 날짜가 남아 있어도 더는 못 받아요. '
      '늦어지는 만큼 받을 수 있는 날이 줄어들어요.';

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: SectionCard(
        background: BeobaColors.amberSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom_outlined,
                  size: 18,
                  color: BeobaColors.severityWarning,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: SafeText(
                    title,
                    where: 'ReceiveWindowCard.title',
                    style: theme.labelLarge?.copyWith(
                      color: BeobaColors.severityWarning,
                      fontWeight: FontWeight.w800,
                    ),
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
              // **D-day 를 붙이지 않는다.** 세는 날이 아니라 닫히는 창이다.
              SafeText(
                '${formatKstDate(result.dueDate)}$until',
                where: 'ReceiveWindowCard.date',
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
              const SizedBox(height: 7),
              SafeText(
                shrinks,
                where: 'ReceiveWindowCard.shrinks',
                style: theme.bodyMedium?.copyWith(color: BeobaColors.ink2),
              ),
              const SizedBox(height: 9),
              LegalBasisCard(basis: result.basis, where: 'Deadline.${result.id}'),
              for (final also in result.alsoBasis)
                LegalBasisCard(basis: also, where: 'Deadline.${result.id}.also'),
              VerificationBadge(status: result.verification),
            ],
          ],
        ),
      ),
    );
  }
}
