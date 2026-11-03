import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/plain_title.dart';
import 'cost_breakdown_view.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// 비용. 엔진이 계산한 금액을 **다시 더하지 않는다.**
///
/// 갈래마다 한 벌씩 받는다. 지급명령으로 갈지 소송으로 갈지, 종이로 낼지
/// 전자소송으로 낼지는 사용자가 아직 정하지 않은 것이라 묻지 않고 나란히 놓는다.
/// 한쪽으로만 계산하면 다른 쪽 사람에게 **틀린 금액**이 간다.
class CostSection extends StatelessWidget {
  const CostSection({
    required this.scenarios,
    this.showHeader = true,
    super.key,
  });

  final List<ScenarioCostResult> scenarios;

  /// 머리글을 그릴지. **접힌 카드 안에 들어갈 때는 끈다** — 카드가 이미 제목을
  /// 달고 있어서 머리글이 둘이 되면 카드 하나가 두 장으로 보인다.
  final bool showHeader;

  static const String title = '비용';
  static const String empty = '금액을 계산할 만한 정보가 아직 없어요.';
  static const String total = '합계';
  /// 조문이 항목으로 못박았는데 금액표를 우리가 못 가진 자리.
  /// **줄을 빼지 않는다** — 빼면 화면이 「이게 전부」로 읽힌다.
  static const String amountUnknown = '아직 확인 못 했어요';

  static const String noBasis = '근거 조문을 아직 확인하지 못했어요.';

  /// **가정이라는 사실을 먼저 말한다.** 사용자가 고른 것이 아니다.
  ///
  /// 예전에는 「어느 쪽으로 하실지 아직 정하지 않으셨으니 갈래마다 따로
  /// 계산했습니다. 고르시는 데 참고하세요.」였다. 다 맞는 말인데 47자다.
  /// 읽어야 할 것은 그 아래 숫자 넷이고, 앞말이 길면 숫자가 뒤로 밀린다.
  static const String assumption = '아직 안 정하신 갈래라 나란히 계산했어요.';

  @override
  Widget build(BuildContext context) {
    final priced = scenarios.where((s) => s.result.lines.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          const SectionHeader(title, icon: Icons.calculate_outlined),
        if (priced.isEmpty)
          const NoticeBox(text: empty, where: 'CostSection.empty')
        else ...[
          if (priced.any((s) => s.isAssumption))
            const NoticeBox(text: assumption, where: 'CostSection.assumption'),
          for (final scenario in priced)
            Padding(
              padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
              child: _ScenarioCard(scenario: scenario),
            ),
        ],
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario});

  final ScenarioCostResult scenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final option = scenario.option;

    return SectionCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scenario.label.isNotEmpty)
            PlainTitle(
              label: option == null
                  ? scenario.label
                  : '${scenario.label} · $option',
              whatIsThis: scenario.whatIsThis,
              where: 'CostScenario',
              trailing: SafeText(
                formatWon(scenario.result.guidedTotal),
                where: 'CostScenario.total',
                style: theme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: BeobaColors.brand,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
          for (final line in scenario.result.lines)
            _CostLineView(line: line, scenarioId: scenario.id),
        ],
      ),
    );
  }
}

class _CostLineView extends StatelessWidget {
  const _CostLineView({required this.line, required this.scenarioId});

  final CostLine line;
  final String scenarioId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final basis = line.basis;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlainTitle(
            label: line.label,
            whatIsThis: line.whatIsThis,
            where: 'CostLine',
            trailing: SafeText(
              // **조문대로의 값이 아니라 안내할 값이다.** 둘은 다른 층이다.
              // 모르는 금액은 0원이 아니라 모른다고 쓴다 — 0원이라고 쓰면
              // 「안 든다」가 되고, 그건 우리가 모르는 것이다.
              line.amountKnown
                  ? formatWon(line.guidedAmount)
                  : CostSection.amountUnknown,
              where: 'CostLine.amount',
              style: theme.titleMedium?.copyWith(
                fontSize: line.amountKnown ? 17 : 14,
                color: line.amountKnown ? null : BeobaColors.ink3,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          // 왜 그 숫자인지 여기서 펼쳐 본다. 적용된 배수도 이 안에 들어 있다.
          CostBreakdownView(
            line: line,
            // 같은 항목이 갈래마다 나오므로 열림 상태가 섞이면 안 된다.
            key: ValueKey('$scenarioId.${line.id}'),
          ),
          const SizedBox(height: 4),
          // 근거가 없으면 법률 정보 위젯을 만들지 않는다. null 을 억지로 채우지 않는다.
          if (basis != null)
            LegalBasisCard(basis: basis, where: 'CostItem.${line.id}')
          else
            const NoticeBox(
              text: CostSection.noBasis,
              where: 'CostSection.noBasis',
            ),
          // 산식은 법률에 있고 계산 순서는 예규가 정한다. 하나만 보여주면
          // 사용자가 검산하다 순서에서 막힌다.
          for (final (index, also) in line.alsoBasis.indexed) ...[
            const SizedBox(height: 10),
            LegalBasisCard(basis: also, where: 'CostItem.${line.id}.also$index'),
          ],
          VerificationBadge(
            status: line.verification,
            openPart: line.openPart,
          ),
        ],
      ),
    );
  }
}
