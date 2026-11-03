import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show SafetyScope;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/agency_notice_line.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// 「이런 일이 있었으면 달라질 수 있어요」 — **물음으로 낸다.**
///
/// **날짜를 바꾸지 않는다.** 계산된 기한은 그대로 두고 주의만 붙인다.
/// 중단됐는지 판단하는 것은 사실관계 평가라 이 앱의 선을 넘는다.
///
/// ## 왜 물음인가
///
/// 넷을 펼쳐 놓으면 해당 없는 사람도 넷을 다 지나쳐 내려가야 한다. 폰에서는
/// 그게 화면 두 장이다. 자기에게 해당하는 것만 눌러 보게 한다.
///
/// 물음은 `Caution.question` 에서 온다. 조건절(`condition`)을 버튼에 그대로 넣지
/// 않는다 — 조각 문장이라 물음이 되지 않고, 화면이 어미를 붙이면
/// 「하셨다면라면」이 다시 나온다 (DECISIONS 78).
///
/// **물음은 상태를 단정하지 않는다.** 「대부업자이신가요?」가 아니라 「빌려주는
/// 일을 업으로 하시나요?」다. 대부업자인지는 판단이고, 그 판단은 하지 않는다.
class CautionSection extends StatelessWidget {
  const CautionSection({required this.cautions, super.key});

  final List<Caution> cautions;

  static const String title = '달라질 수 있는 것';
  static const String hint = '해당하는 것만 눌러 보세요.';

  @override
  Widget build(BuildContext context) {
    if (cautions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title, icon: Icons.help_outline),
        SafeText(
          hint,
          where: 'CautionSection.hint',
          style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
        ),
        const SizedBox(height: 8),
        for (final caution in cautions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CautionQuestion(caution: caution),
          ),
      ],
    );
  }
}

/// 물음 하나. 눌러야 답이 나온다.
class CautionQuestion extends StatefulWidget {
  const CautionQuestion({required this.caution, super.key});

  final Caution caution;

  @override
  State<CautionQuestion> createState() => _CautionQuestionState();
}

class _CautionQuestionState extends State<CautionQuestion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final caution = widget.caution;
    final basis = caution.legalBasis;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      background: _open ? BeobaColors.amberSoft : BeobaColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: BeobaTapTarget.minimum),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: SafeText(
                        caution.question,
                        where: 'Caution.question',
                        style: theme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: BeobaColors.ink3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            // 조건절은 그대로 둔다. 물음은 「~하시나요?」이고 답은 「~하셨다면
            // 이렇게 됩니다」라 둘이 하는 일이 다르다.
            SafeText(
              caution.condition,
              where: 'Caution.condition',
              style: theme.labelSmall?.copyWith(
                color: BeobaColors.legalMaybe,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            SafeText(
              caution.consequence,
              where: 'Caution.consequence',
              style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
            ),
            // **조문이 각 호로 나눠 둔 것은 줄로 낸다.** 우리가 어느 칸인지
            // 못 고르는 자리라 묻지 않고 그대로 편다. 구분은 조문의 말이고
            // 값이 그 아래에 온다 — 둘을 붙여 한 문단으로 만들면 개정이 났을 때
            // 어느 쪽이 조문이었는지 알 수 없게 된다.
            for (final variant in caution.variants) ...[
              const SizedBox(height: 10),
              _VariantRow(variant: variant),
            ],
            if (basis != null) ...[
              const SizedBox(height: 10),
              LegalBasisCard(basis: basis, where: 'Caution.${caution.id}'),
            ],
            // 근거가 둘 이상인 자리가 있다. 숫자가 든 조문과 그래서 어떻게 된다는
            // 조문이 갈라져 있으면 **하나만 보여줘서는 검산이 안 된다** —
            // 연 60% 는 시행령에 있고 계약이 무효라는 말은 법률 본문에 있다.
            for (final (index, also) in caution.alsoBasis.indexed) ...[
              const SizedBox(height: 10),
              LegalBasisCard(
                basis: also,
                where: 'Caution.${caution.id}.also$index',
              ),
            ],
            // **조문이 없는 자리를 기관 안내가 대신한다.** 조문 뒤에 놓는다 —
            // 🟢 옆이 아니라 아래다(DECISIONS 274번).
            if (caution.notice case final notice?) ...[
              const SizedBox(height: 10),
              AgencyNoticeLine(notice: notice),
            ],
            VerificationBadge(status: caution.verification.status),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// 각 호 한 줄. **구분은 조문의 말, 값은 우리 말.**
///
/// 구분을 위에 흐리게 두고 값을 아래에 진하게 둔다 — 사람이 찾는 것은
/// 「내 지역이 어디냐」이고, 찾고 나서 읽는 것이 금액이다.
class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant});

  final AmountVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: BeobaColors.surfaceStrong,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            variant.label,
            where: 'AmountVariant.label',
            scope: SafetyScope.quote,
            style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
          ),
          const SizedBox(height: 3),
          SafeText(
            variant.detail,
            where: 'AmountVariant.detail',
            style: theme.labelMedium?.copyWith(
              color: BeobaColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
