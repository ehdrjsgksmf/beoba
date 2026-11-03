import 'package:domain_data/domain_data.dart'
    show MissingGuide, Procedure;
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';
import 'fee_schedule_view.dart';
import 'legal_basis_card.dart';
import 'section_card.dart';
import 'verification_badge.dart';

/// 자료가 없을 때. **그 자리에서 펼친다.**
///
/// 원칙이 둘이고 이 위젯은 그 사이에 있다.
///
/// ```
/// 「자료가 없으면 안 됩니다」로 끝내지 않는다   → 그건 앱이 문을 닫는 것
/// 「이렇게 하면 됩니다」로 단정하지 않는다      → 그건 우리 선을 넘는 것
/// ```
///
/// 별도 화면으로 보내지 않는다 — **없는 사람이 한 번 더 이동하면 나간다.**
class MissingGuideView extends StatelessWidget {
  const MissingGuideView({
    required this.guide,
    required this.documentId,
    this.seeAlso,
    super.key,
  });

  final MissingGuide guide;
  final String documentId;

  /// `seeProcedure` 가 가리키는 절차. **같은 말을 두 번 하지 않으려고** 여기서
  /// 문구를 만들지 않고 그 절차가 들고 있는 것을 그대로 보여준다.
  final Procedure? seeAlso;

  static const String altTitle = '대신 쓸 수 있는 것';
  static const String howTitle = '구하는 법';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final procedure = seeAlso;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SectionCard(
        background: BeobaColors.surfaceSoft,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (guide.alternatives.isNotEmpty) ...[
              _Heading(altTitle),
              for (final alternative in guide.alternatives)
                _Row(
                  label: alternative.label,
                  note: alternative.whatIsThis,
                  where: 'MissingAlternative',
                ),
            ],
            if (guide.howToGet.isNotEmpty) ...[
              if (guide.alternatives.isNotEmpty) const SizedBox(height: 10),
              _Heading(howTitle),
              for (final source in guide.howToGet)
                _Row(
                  label: source.label,
                  note: source.where,
                  where: 'MissingSource',
                ),
            ],
            if (guide.ifNoneAtAll.isNotEmpty) ...[
              const SizedBox(height: 12),
              SafeText(
                guide.ifNoneAtAll,
                where: 'MissingGuide.ifNoneAtAll',
                style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
              ),
            ],
            // 가리킨 절차의 **조건**을 그대로 데려온다. 여기서 새로 쓰지 않는다.
            if (procedure != null) ...[
              const SizedBox(height: 10),
              SafeText(
                procedure.label,
                where: 'Procedure.label',
                style: theme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (procedure.caution case final String warning)
                SafeText(
                  warning,
                  where: 'Procedure.caution',
                  style: theme.labelSmall
                      ?.copyWith(color: BeobaColors.severityWarning),
                ),
              // 드는 돈도 그 절차가 들고 있다 — **요금표를 두 벌로 만들지
              // 않는다.** 우체국 요금이 오르면 고칠 자리가 한 곳이어야 한다.
              if (procedure.fees case final fees?) FeeScheduleView(fees: fees),
              if (procedure.legalBasis case final basis?) ...[
                const SizedBox(height: 10),
                LegalBasisCard(
                  basis: basis,
                  where: 'MissingGuide.$documentId.seeAlso',
                ),
              ],
            ],
            VerificationBadge(status: guide.verification.status),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SafeText(
          text,
          where: 'MissingGuideView.heading',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BeobaColors.ink3,
                fontWeight: FontWeight.w800,
              ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.note, required this.where});

  final String label;
  final String note;
  final String where;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 5, color: BeobaColors.ink3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  label,
                  where: '$where.label',
                  style: theme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (note.isNotEmpty)
                  SafeText(
                    note,
                    where: '$where.note',
                    style:
                        theme.labelSmall?.copyWith(color: BeobaColors.ink3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
