import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';
import 'section_card.dart';

/// 접힌 카드. **기본이 접힘이다.**
///
/// ## 왜
///
/// 결과 화면이 답해야 하는 물음은 「오늘 뭘 하면 되나」 하나인데, 섹션이 펼쳐진
/// 채로 쌓이면 그 답이 세 번 스크롤 아래로 간다. 폰에서 재어 보니 정작 제일
/// 쓸모 있는 비용이 맨 아래에 있었다.
///
/// 그래서 카드마다 **질문형 제목 + 핵심 한 줄**만 두고 나머지는 접는다.
/// 자기에게 필요한 것만 펼치게 한다.
///
/// ## 접힌 것과 없는 것은 다르다
///
/// [summary] 는 접혀도 보인다. 접힘이 「이 카드에 뭐가 있는지 모르게 하는 것」이
/// 되면 사용자는 그 정보가 있다는 사실 자체를 모른다 — 송달료가 줄째로 사라져
/// 있던 것과 같은 실패다.
class ExpandableCard extends StatefulWidget {
  const ExpandableCard({
    required this.title,
    required this.where,
    required this.summary,
    required this.child,
    this.icon,
    this.initiallyOpen = false,
    super.key,
  });

  /// 질문형 제목. 「얼마나 드나요」
  final String title;
  final String where;
  final IconData? icon;

  /// 접혀도 보이는 핵심. **없는 카드를 만들지 않는다.**
  final Widget summary;

  /// 눌러야 보이는 것.
  final Widget child;

  /// 첫 화면에서는 **언제나 접힘**이다. 위젯 시험에서만 쓴다.
  final bool initiallyOpen;

  static const String expand = '자세히 보기';
  static const String collapse = '접기';

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(15, 4, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 19, color: BeobaColors.ink2),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: SafeText(
                          widget.title,
                          where: '${widget.where}.title',
                          style: theme.titleMedium?.copyWith(fontSize: 17),
                        ),
                      ),
                      SafeText(
                        _open
                            ? ExpandableCard.collapse
                            : ExpandableCard.expand,
                        where: 'ExpandableCard.action',
                        style: theme.labelSmall?.copyWith(
                          color: BeobaColors.brand2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: BeobaColors.brand2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            widget.summary,
            if (_open) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: BeobaColors.line2),
              ),
              widget.child,
            ],
          ],
        ),
      ),
    );
  }
}
