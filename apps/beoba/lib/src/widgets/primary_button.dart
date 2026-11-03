import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// 화면의 주 동작.
///
/// 최소 높이는 테마가 보장한다 ([BeobaTapTarget.button] = 52). 타깃 사용자가
/// 소외계층이라 탭 타깃을 넉넉하게 잡는다.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.where = 'PrimaryButton.label',
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final String where;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: SafeText(label, where: where, textAlign: TextAlign.center),
    );
  }
}

/// 보조 동작. 흰 바탕 + 테두리.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.where = 'GhostButton.label',
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String where;

  @override
  Widget build(BuildContext context) {
    final text = SafeText(label, where: where, textAlign: TextAlign.center);

    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, child: text);
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: text,
    );
  }
}

/// 화면 본문 폭을 묶는다. 웹에서 한 줄이 지나치게 길어지지 않게 한다.
class PageBody extends StatelessWidget {
  const PageBody({required this.children, this.bottom, super.key});

  final List<Widget> children;

  /// 화면 아래에 고정할 것 (주 버튼 등).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BeobaSpace.maxContentWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                BeobaSpace.pageH,
                BeobaSpace.pageTop,
                BeobaSpace.pageH,
                BeobaSpace.pageBottom,
              ),
              child: content,
            ),
          ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BeobaSpace.pageH,
                8,
                BeobaSpace.pageH,
                12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: BeobaSpace.maxContentWidth),
                  child: bottom,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
