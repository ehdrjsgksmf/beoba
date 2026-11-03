import 'package:engines/engines.dart' show SafetyScope;
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../layers/legal_layer.dart';
import '../safety/safe_text.dart';
import 'layer_style.dart';
import 'legal_basis_card.dart';

/// 층 하나를 감싸는 상자.
///
/// **층은 배지가 나른다.** 예전에는 상자 전체를 층 색으로 칠하고 1px 테두리를
/// 둘렀는데, 옅은 노랑 배지가 옅은 노랑 상자 위에 서면 배지가 안 보인다.
/// 상자는 카드 면으로 두고 층은 배지 하나로 말한다(DECISIONS 286번).
class LayerTile extends StatelessWidget {
  const LayerTile({required this.layer, required this.child, super.key});

  final LegalLayer layer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = LayerStyle.of(layer);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BeobaSpace.tierGap),
      padding: const EdgeInsets.symmetric(
        vertical: BeobaSpace.tierPaddingV,
        horizontal: BeobaSpace.tierPaddingH,
      ),
      decoration: BoxDecoration(
        color: BeobaColors.card,
        borderRadius: BorderRadius.circular(BeobaSpace.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayerBadge(style: style, where: 'LayerTile.label'),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// 🟢 조문 원문 + 근거.
class GreenBlockView extends StatelessWidget {
  const GreenBlockView({required this.block, super.key});

  final GreenBlock block;

  @override
  Widget build(BuildContext context) {
    return LayerTile(
      layer: LegalLayer.statute,
      child: LegalBasisCard(
        basis: block.basis,
        where: 'GreenBlock.${block.id}',
      ),
    );
  }
}

/// 🟡 조건절 + 근거 칩.
///
/// 칩이 "🟡 는 🟢 없이 존재할 수 없다" 를 화면에 드러낸 것이다.
class YellowBlockView extends StatelessWidget {
  const YellowBlockView({
    required this.block,
    required this.greenTitles,
    super.key,
  });

  final YellowBlock block;

  /// 🟢 블록 id → 표시할 조문명.
  final Map<String, String> greenTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final reference = greenTitles[block.greenRefId];

    // 참조가 죽었으면 그리지 않는다. SPEC §8.1 의 렌더링 차단.
    assert(reference != null, '🟡 가 없는 🟢 를 참조합니다: ${block.greenRefId}');
    if (reference == null) return const SizedBox.shrink();

    return LayerTile(
      layer: LegalLayer.likely,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            renderYellow(block),
            where: 'YellowBlock.sentence',
            style: theme.bodyMedium,
          ),
          const SizedBox(height: 10),
          _BasisChips(titles: [reference]),
        ],
      ),
    );
  }
}

class _BasisChips extends StatelessWidget {
  const _BasisChips({required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SafeText(
          '근거',
          where: '_BasisChips.prefix',
          style: theme.labelMedium,
        ),
        for (final title in titles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: BeobaColors.greenSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gavel, size: 13, color: BeobaColors.green),
                const SizedBox(width: 4),
                // **긴 법령명은 칩 안에서 줄을 바꾼다.** 배율 1.3 부터 이름이
                // 칩 폭을 넘어 오른쪽으로 잘렸다. 잘린 글자는 화면에 안 보이고
                // 예외만 났다 — 근거를 보여주는 칩에서 근거가 잘린 것이다.
                // Flexible 이 없으면 Row 가 제 크기를 고집한다.
                Flexible(
                  child: SafeText(
                    title,
                    where: '_BasisChips.title',
                    scope: SafetyScope.quote,
                    style: theme.labelMedium?.copyWith(
                      color: BeobaColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 🔴 확인 안 된 것. 항상 되돌아갈 링크로 끝난다.
class RedBlockView extends StatelessWidget {
  const RedBlockView({required this.block, required this.onFix, super.key});

  final RedBlock block;
  final void Function(String questionId) onFix;

  static const String action = '이 질문으로 돌아가기';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return LayerTile(
      layer: LegalLayer.unknown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            block.label,
            where: 'RedBlock.label',
            style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => onFix(block.questionId),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              foregroundColor: BeobaColors.red,
              minimumSize: const Size(0, BeobaTapTarget.minimum),
            ),
            child: SafeText(
              action,
              where: 'RedBlock.action',
              style: theme.labelLarge?.copyWith(
                color: BeobaColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 세 층을 순서대로 그린다. 섞지 않는다.
class LayerSection extends StatelessWidget {
  const LayerSection({required this.blocks, required this.onFix, super.key});

  final LayerBlocks blocks;
  final void Function(String questionId) onFix;

  @override
  Widget build(BuildContext context) {
    final greenTitles = {
      for (final block in blocks.green) block.id: block.title,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks.green) GreenBlockView(block: block),
        for (final block in blocks.renderableYellow)
          YellowBlockView(block: block, greenTitles: greenTitles),
        for (final block in blocks.red)
          RedBlockView(block: block, onFix: onFix),
      ],
    );
  }
}
