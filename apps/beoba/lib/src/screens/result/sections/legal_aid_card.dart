import 'package:domain_data/domain_data.dart' show Caution;
import 'package:flutter/material.dart';

import '../../../safety/safe_text.dart';
import '../../../widgets/expandable_card.dart';
import '../../../widgets/legal_basis_card.dart';

/// **돈이 없어서 온 사람에게 금액만 내밀면 그건 벽이다.**
///
/// 비용 카드 바로 아래, 접힌 채로 온다. 금액을 먼저 보고 나서 「그런데 지금
/// 안 내는 길도 있다」를 읽는 순서다 — 위에 두면 아직 얼마인지도 모르는
/// 사람에게 구조 이야기를 먼저 하게 된다.
///
/// ## 「면제」가 아니라 「유예」다
///
/// 민사소송법 제129조 제1항 제1호는 「재판비용의 **납입유예**」다. 미루는
/// 것이고, 제132조 제1항이 나중에 상대에게서 받을 수 있다고 정하고, 규칙
/// 제27조 제2항은 형편이 나아지면 신고 의무까지 둔다. 면제는 제3호(담보면제)
/// 뿐이고 우리 화면의 인지대·송달료는 제1호다(DECISIONS 133번).
class LegalAidCard extends StatelessWidget {
  const LegalAidCard({required this.aid, super.key});

  final Caution aid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ExpandableCard(
      title: aid.question,
      where: 'LegalAidCard',
      icon: Icons.lightbulb_outline,
      // 요약은 두지 않는다. 접힌 제목이 이미 할 말을 다 한다.
      summary: const SizedBox.shrink(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeText(
            aid.consequence,
            where: 'Caution.consequence',
            style: theme.bodyMedium?.copyWith(height: 1.62),
          ),
          if (aid.legalBasis case final basis?) ...[
            const SizedBox(height: 11),
            LegalBasisCard(basis: basis, where: 'Caution.${aid.id}'),
          ],
          for (final also in aid.alsoBasis) ...[
            const SizedBox(height: 8),
            LegalBasisCard(basis: also, where: 'Caution.${aid.id}.also'),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
