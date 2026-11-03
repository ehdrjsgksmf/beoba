import 'package:engines/engines.dart' show SafetyScope;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../safety/safe_text.dart';

/// 고르는 줄 하나. 인터뷰의 선택지와 **같은 규칙**으로 그린다 —
/// 테두리색 · 두께 · 배경 · 글자 굵기 넷이 동시에 바뀐다. 색 하나에 안 기댄다.
class WelfareChoiceRow extends StatelessWidget {
  const WelfareChoiceRow({
    required this.label,
    required this.where,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String where;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusButton),
        child: Container(
          constraints: const BoxConstraints(minHeight: BeobaTapTarget.choice),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? BeobaColors.brandSoft : BeobaColors.card,
            borderRadius: BorderRadius.circular(BeobaSpace.radiusButton),
          ),
          foregroundDecoration: selected
              ? BoxDecoration(
                  border: Border.all(color: BeobaColors.brand, width: 2),
                  borderRadius: BorderRadius.circular(BeobaSpace.radiusButton),
                )
              : null,
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? BeobaColors.brand : BeobaColors.control,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: SafeText(
                  label,
                  where: where,
                  style: theme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 축 이름 칩 여러 개. **이름은 자료에서 온다** — 여기서 목록을 안 적는다.
///
/// 고른 것이 없으면 그 축으로 안 거른다. 그래서 아무것도 안 고른 상태가
/// 「아무것도 못 찾음」이 아니라 **제일 넓은 상태**다.
///
/// ## 2026-09-16 — 알약 칩 (DECISIONS 289번)
///
/// ```
/// 안 고른 것   면 #F2F4F6 · 글자 #4E5968 · 앞에 「+」
/// 고른 것      면 #0A67ED · 흰 글자 · 「+」 없음
/// 크기         높이 최소 48 · 상하 11 · 좌우 14 · 14px/700 · 알약 · 사이 8
/// ```
///
/// ★ **흑백에서도 갈린다** — 두 면의 밝기 차이 4.56:1. 「+」가 둘째 신호다.
/// `welfare_chip_test` 가 실제로 그려서 잰다.
///
/// ★ **누르면 순서가 안 바뀐다.** 고른 것을 앞으로 옮기면 손가락 밑에서 칩이
/// 도망간다. 물결도 없다 — 대신 누르는 동안 0.97배로 작아지고, 색은 140ms 에
/// 바뀐다. 기기의 「동작 줄이기」가 켜져 있으면 둘 다 끈다.
class WelfareChipRow extends StatelessWidget {
  const WelfareChipRow({
    required this.names,
    required this.picked,
    required this.where,
    required this.onToggle,
    this.counts,
    super.key,
  });

  final List<String> names;
  final Set<String> picked;

  /// 이름별 건수 — **그 이름이 달린 제도가 몇 개인가.**
  ///
  /// 움직임을 말하지 않는다. 몇 개를 골라도 그 칩에 달린 제도 수는 그대로
  /// 참이다. (예전 주석은 「누르기 전에 얼마나 줄어드는지」였는데, 주제는
  /// 둘째부터 넓히므로 거짓이었다 — DECISIONS 289번.)
  /// 안 넘기면 건수 없이 이름만 그린다.
  final Map<String, int>? counts;

  /// 어느 필드에서 온 이름인가. 차단 기록에 남는다.
  final String where;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in names)
          WelfareChip(
            label: name,
            count: counts?[name],
            where: where,
            selected: picked.contains(name),
            onTap: () => onToggle(name),
          ),
      ],
    );
  }
}

/// 알약 칩 하나.
class WelfareChip extends StatefulWidget {
  const WelfareChip({
    required this.label,
    required this.where,
    required this.selected,
    required this.onTap,
    this.count,
    super.key,
  });

  final String label;
  final int? count;
  final String where;
  final bool selected;
  final VoidCallback onTap;

  /// 안 고른 칩 앞의 표시. **스크린리더는 안 읽는다** — 「더하기」로 읽히면
  /// 뜻이 틀린다. 상태는 [Semantics.selected] 가 말한다.
  static const String plusMark = '+';

  static const Duration colorDuration = Duration(milliseconds: 140);
  static const Duration pressDuration = Duration(milliseconds: 100);
  static const double pressedScale = 0.97;

  @override
  State<WelfareChip> createState() => _WelfareChipState();
}

class _WelfareChipState extends State<WelfareChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final selected = widget.selected;
    // 기기의 「동작 줄이기」. 켜져 있으면 움직임을 끈다.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final ink = selected ? BeobaColors.bg : BeobaColors.ink2;
    final style = theme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 1.3,
    );

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          // 화면을 잘 못 보는 분께 제일 확실한 「눌렸다」. 웹에서는 아무 일도
          // 안 한다 — 막을 방법이 없다.
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed && !still ? WelfareChip.pressedScale : 1,
          duration: still ? Duration.zero : WelfareChip.pressDuration,
          child: AnimatedContainer(
            duration: still ? Duration.zero : WelfareChip.colorDuration,
            curve: Curves.easeOut,
            constraints:
                const BoxConstraints(minHeight: BeobaTapTarget.minimum),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? BeobaColors.brand : BeobaColors.surfaceStrong,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ★ 고르면 「+」를 **감추되 자리는 남긴다.** 칩 폭이 바뀌면
                // 뒤 칩이 다음 줄로 밀려 손가락 밑에서 도망간다.
                ExcludeSemantics(
                  child: Visibility(
                    visible: !selected,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: SafeText(
                      WelfareChip.plusMark,
                      where: 'WelfareChip.plusMark',
                      style: style,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: SafeText(
                    widget.label,
                    where: widget.where,
                    // 축 이름은 자료의 낱말이다.
                    scope: SafetyScope.quote,
                    style: style,
                  ),
                ),
                if (widget.count != null) ...[
                  const SizedBox(width: 5),
                  SafeText(
                    '${widget.count}',
                    where: '${widget.where}.count',
                    style: style?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: selected ? BeobaColors.bg : BeobaColors.ink3,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「먼저 볼 것 325건 · 아래에 접어 둔 것 136건」 (DECISIONS 289번).
///
/// ★ 단위는 「건」이다 — 복지 목록의 다른 개수 여섯 자리가 전부 「건」이었다.
///
/// ★★ **움직임을 정직하게 말한다.** 가구상황은 거르지 않고 접는다(287) — 그래서
/// 칩을 누르면 **앞 숫자가 늘고 뒤 숫자가 준다.** 「좁혀 드려요」라고 쓰면
/// 거짓이다. 설명 문장 대신 두 숫자가 「누르면 내 것이 앞으로 온다」를 가르친다.
///
/// **한 줄에 양쪽이 다 있다.** 「먼저」만 있으면 「먼저」가 무슨 말인지 모른다.
/// 이름이 앞, 숫자가 뒤라서 숫자가 바뀌어도 이름 자리는 안 움직인다.
///
/// ★ 전체 건수와 합을 쓰지 않는다 — 태어난 해를 넣으면 나이에 안 맞는 제도가
/// 빠져서 둘을 더해도 전체가 안 된다.
///
/// 관심주제 칩에는 이 줄을 안 단다. 주제는 둘째부터 넓히므로 같은 모양의 줄이
/// 반대로 움직이게 된다.
class WelfareSplitLine extends StatelessWidget {
  const WelfareSplitLine({
    required this.first,
    required this.folded,
    this.style,
    super.key,
  });

  final int first;
  final int folded;
  final TextStyle? style;

  static const String firstLabel = '먼저 볼 것';
  static const String foldedLabel = '아래에 접어 둔 것';
  static const String unit = '건';

  /// 한 줄로 읽은 말. 시험과 스크린리더가 같은 문장을 본다.
  static String sentence(int first, int folded) =>
      '$firstLabel $first$unit · $foldedLabel $folded$unit';

  /// 숫자만 바뀐다. 줄 전체가 튀지 않게 이 시간 안에 끝난다.
  static const Duration numberDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final base = style ??
        Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BeobaColors.ink2,
              fontWeight: FontWeight.w700,
            );
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget number(int value, String key) => AnimatedSwitcher(
          duration: still ? Duration.zero : numberDuration,
          child: SafeText(
            '$value$unit',
            key: ValueKey('$key$value'),
            where: 'WelfareSplitLine.$key',
            style: base?.copyWith(fontFeatures: kTabularFigures),
          ),
        );

    // 스크린리더는 한 문장으로 읽는다. 바뀌면 다시 읽어 준다.
    return Semantics(
      liveRegion: true,
      label: sentence(first, folded),
      child: ExcludeSemantics(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SafeText('$firstLabel ', where: 'WelfareSplitLine.first', style: base),
            number(first, 'firstCount'),
            SafeText(' · $foldedLabel ',
                where: 'WelfareSplitLine.folded', style: base),
            number(folded, 'foldedCount'),
          ],
        ),
      ),
    );
  }
}
