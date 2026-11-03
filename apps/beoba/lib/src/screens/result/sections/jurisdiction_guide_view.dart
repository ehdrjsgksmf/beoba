import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// 어디에 내는가. **3층 그대로 그린다.**
///
/// 🟢 조문 원문 → 🟡 이 사건에 대어 본 것 → 🔴 우리가 정하지 않는 것.
///
/// **법원 이름을 단정하지 않는다.** 「○○지방법원 △△지원」까지 가려면 관할구역
/// 자료가 있어야 하고 우리는 그걸 검증하지 않았다.
class JurisdictionGuideView extends StatelessWidget {
  const JurisdictionGuideView({
    required this.guide,
    this.showHeader = true,
    super.key,
  });

  final JurisdictionGuide? guide;

  /// 머리글을 그릴지. **접힌 카드 안에 들어갈 때는 끈다** — 카드가 이미 제목을
  /// 달고 있어서 머리글이 둘이 되면 카드 하나가 두 장으로 보인다.
  final bool showHeader;

  static const String title = '어디에 내나요';
  static const String branchTitle = '이렇게 갈려요';
  static const String branchHint = '해당하는 쪽을 보세요.';
  static const String notDecidedTitle = '이건 제가 정하지 못해요';

  @override
  Widget build(BuildContext context) {
    final data = guide;
    if (data == null) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          const SectionHeader(title, icon: Icons.account_balance_outlined),

        // 🟡 먼저다. 사용자가 알고 싶은 것은 「나는 어디에 내나」이고,
        // 조문 원문은 그 답을 확인하려는 사람이 아래에서 읽는다.
        if (data.branches.isNotEmpty) ...[
          SafeText(
            branchHint,
            where: 'JurisdictionGuide.branchHint',
            style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
          ),
          const SizedBox(height: 8),
          for (final branch in data.branches)
            Padding(
              padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
              child: _Branch(branch: branch),
            ),
        ],

        if (data.lookupNote.isNotEmpty) ...[
          SectionCard(
            background: BeobaColors.surfaceSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.travel_explore, size: 17, color: BeobaColors.ink3),
                const SizedBox(width: 8),
                Expanded(
                  child: SafeText(
                    data.lookupNote,
                    where: 'JurisdictionGuide.lookupNote',
                    style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BeobaSpace.blockGap),
        ],

        // 🔴 빈칸으로 두지 않는다. 못 하는 것을 적는 것도 답이다.
        if (data.notDecided.isNotEmpty) ...[
          SectionCard(
            background: BeobaColors.redSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: BeobaColors.red,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: SafeText(
                        notDecidedTitle,
                        where: 'JurisdictionGuide.notDecidedTitle',
                        style: theme.labelSmall?.copyWith(
                          color: BeobaColors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                for (final line in data.notDecided)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SafeText(
                      line,
                      where: 'JurisdictionGuide.notDecided',
                      style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: BeobaSpace.blockGap),
        ],

        // 🟢 조문 원문. 우리가 해석한 것이 하나도 없다.
        for (final basis in data.basis)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LegalBasisCard(
              basis: basis,
              where: 'JurisdictionGuide.basis',
            ),
          ),
        VerificationBadge(status: data.verification.status),
      ],
    );
  }
}

/// 갈래 하나. 🟡 이라 `condition` + `consequence` 구조 그대로다.
class _Branch extends StatelessWidget {
  const _Branch({required this.branch});

  final Caution branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final basis = branch.legalBasis;

    return SectionCard(
      background: BeobaColors.amberSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.help_outline,
                  size: 17,
                  color: BeobaColors.legalMaybe,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // 어미를 붙이지 않는다. `CautionSection` 과 같은 이유다.
                child: SafeText(
                  branch.condition,
                  where: 'JurisdictionGuide.condition',
                  style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SafeText(
            branch.consequence,
            where: 'JurisdictionGuide.consequence',
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
          ),
          if (basis != null) ...[
            const SizedBox(height: 10),
            LegalBasisCard(basis: basis, where: 'JurisdictionGuide.${branch.id}'),
          ],
          // 갈래 하나가 조문 하나로 안 끝난다 — 「어느 법원이 맡는가」(제2조)와
          // 「보통재판적이 어디인가」(제3조·제5조)가 갈라져 있다.
          // **하나만 걸어 두면 나머지가 화면에서도 매니페스트에서도 사라진다.**
          for (final (index, also) in branch.alsoBasis.indexed) ...[
            const SizedBox(height: 10),
            LegalBasisCard(
              basis: also,
              where: 'JurisdictionGuide.${branch.id}.also$index',
            ),
          ],
          VerificationBadge(status: branch.verification.status),
        ],
      ),
    );
  }
}
