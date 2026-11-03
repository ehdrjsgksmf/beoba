import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// 카드. **테두리가 없다** — 면의 밝기와 여백으로 나눈다(DECISIONS 286번).
///
/// 예전에는 1px 테두리로 면을 나눴다. 테두리로 칸을 나누는 것은 서식의 문법이라
/// 뺐다. 상태(펼침 · 급함)는 이미 [background] 가 나르고 있었다.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(BeobaSpace.cardPadding),
    this.background,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? BeobaColors.card,
        borderRadius: BorderRadius.circular(BeobaSpace.radius),
      ),
      child: child,
    );
  }
}

/// 구역 제목. 의미색을 줄 수 있다.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.icon, this.color, super.key});

  final String title;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(color: color ?? BeobaColors.ink);

    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: color ?? BeobaColors.ink),
            const SizedBox(width: 7),
          ],
          Expanded(child: SafeText(title, where: 'SectionHeader.title', style: style)),
        ],
      ),
    );
  }
}

/// 회색 안내 상자. 법률 정보가 아닌 보조 문구에 쓴다.
///
/// 면 진함(#F2F4F6)이다 — 카드 안에 들어가는 일이 많아 카드 바탕과 같은 색이면
/// 테두리가 없어진 뒤 상자가 안 보인다.
class NoticeBox extends StatelessWidget {
  const NoticeBox({required this.text, this.where = 'NoticeBox.text', super.key});

  final String text;
  final String where;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BeobaColors.surfaceStrong,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: SafeText(
        text,
        where: where,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
