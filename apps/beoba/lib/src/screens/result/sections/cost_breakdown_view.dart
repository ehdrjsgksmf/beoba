import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';

/// 「어떻게 나온 금액인가요」 — 엔진이 밟은 단계를 그대로 늘어놓는다.
///
/// **여기서 계산하지 않는다.** 숫자는 전부 [CostBreakdown] 에서 온다. 화면이 다시
/// 계산하면 두 곳이 갈라지고, 갈라지면 어느 쪽이 맞는지 아무도 모른다.
///
/// 🟢 은 근거가 붙어야 한다는 규칙이 비용에서는 안 지켜지고 있었다. 조문은 있는데
/// **그 조문이 어떻게 이 숫자가 됐는지**가 없었다. 사용자가 검산할 수 없으면
/// 근거가 있다고 말할 수 없다.
///
/// 펼침으로 둔 이유 — 급한 사람은 금액만 보고 나가고, 직접 하려는 사람은 열어서
/// 끝까지 본다. **한 화면에 다 넣으면 둘 다 잃는다.** 툴팁 금지 규칙에 걸리지
/// 않는다. 툴팁은 "눌리는 줄 모른다" 가 문제였고 이건 눌릴 것으로 보이는 줄이다.
class CostBreakdownView extends StatefulWidget {
  const CostBreakdownView({required this.line, super.key});

  final CostLine line;

  static const String open = '어떻게 나온 금액인가요';
  static const String close = '접기';

  /// 단계 이름. **법률 용어를 쓰지 않는다** — 「소가」·「인지액」은 검사에 걸린다.
  static const String inputLabel = '청구하신 금액';
  static const String tierLabel = '적용 구간';
  static const String calcLabel = '계산';
  static const String roundLabel = '버림';
  static const String minimumLabel = '가장 적은 금액';
  static const String unitLabel = '단가';
  static const String countLabel = '횟수';
  static const String resultLabel = '이 항목 금액';

  /// 조문대로의 값과 안내할 값이 갈리는 자리. **그 사실을 숨기지 않는다.**
  static const String guidanceLabel = '안내하는 금액';
  static const String guidanceNote = '법이 정한 가장 적은 금액이 있어서 그 아래로는 '
      '안내하지 않아요. 실제로는 더 적게 낼 수도 있어요.';

  @override
  State<CostBreakdownView> createState() => _CostBreakdownViewState();
}

class _CostBreakdownViewState extends State<CostBreakdownView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final steps = widget.line.breakdown;
    if (steps == null || !steps.hasSteps) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, BeobaTapTarget.minimum),
            ),
            icon: Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              size: 19,
            ),
            label: SafeText(
              _open ? CostBreakdownView.close : CostBreakdownView.open,
              where: 'CostBreakdown.toggle',
            ),
          ),
        ),
        if (_open) _Steps(steps: steps, line: widget.line),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps, required this.line});

  final CostBreakdown steps;
  final CostLine line;

  @override
  Widget build(BuildContext context) {
    final tier = steps.tier;
    final rows = <Widget>[];

    if (steps.input != null) {
      rows.add(_Row(CostBreakdownView.inputLabel, formatWon(steps.input!)));
    }

    if (tier != null) {
      rows
        ..add(_Row(CostBreakdownView.tierLabel, _tierText(tier)))
        ..add(
          _Row(
            CostBreakdownView.calcLabel,
            '${formatWon(steps.input!)} × ${formatRate(tier.rate)}'
            ' = ${formatWon(steps.rated!)}',
          ),
        );
      if (tier.add > 0) {
        rows.add(
          _Row('', '+ ${formatWon(tier.add)} = ${formatWon(steps.beforeRounding!)}'),
        );
      }
      final rounded = _roundingRow(steps.rounding, steps.beforeRounding, steps.base);
      if (rounded != null) rows.add(rounded);
    }

    if (steps.unitPrice != null) {
      rows
        ..add(_Row(CostBreakdownView.unitLabel, formatWon(steps.unitPrice!)))
        ..add(_Row(CostBreakdownView.countLabel, '${steps.units}'))
        ..add(
          _Row(
            CostBreakdownView.calcLabel,
            '${formatWon(steps.unitPrice!)} × ${steps.units}'
            ' = ${formatWon(steps.base)}',
          ),
        );
    }

    // 배수는 **밟은 순서대로**. 말은 데이터가 준 것을 그대로 쓴다.
    for (final modifier in steps.modifiers) {
      rows.add(
        _Row(
          modifier.label,
          '× ${formatMultiplier(modifier.multiply)}'
          ' = ${formatWon(modifier.beforeRounding)}',
        ),
      );
      // 준용 규정이 있는 자리에서만 끝수가 다시 처리된다. 그 단계를 숨기면
      // 사용자가 검산하다가 금액이 안 맞는 지점을 만난다.
      final rounded = _roundingRow(
        modifier.rounding,
        modifier.beforeRounding,
        modifier.amount,
      );
      if (rounded != null) rows.add(rounded);
      // 이 배수가 어느 조문에서 나왔는지. 항목 전체 근거에 이어 붙이면
      // 어느 조문이 어느 숫자를 만들었는지 알 수 없다.
      final citation = modifier.basis?.citation;
      if (citation != null) rows.add(_Row('', citation));
    }

    rows.add(_Row(CostBreakdownView.resultLabel, formatWon(steps.amount),
        emphasis: !line.raisedForGuidance));

    // 조문대로의 값과 안내할 값이 갈렸다. **어느 쪽이 조문인지 보이게 둔다.**
    if (line.raisedForGuidance) {
      rows
        ..add(
          _Row(
            CostBreakdownView.guidanceLabel,
            formatWon(line.guidedAmount),
            emphasis: true,
          ),
        )
        ..add(_Row('', CostBreakdownView.guidanceNote));
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BeobaColors.surfaceSoft,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  /// 끝수 처리 한 줄. **올린 것과 버린 것은 말이 다르다.**
  ///
  /// 「100원 미만 버림」이라고 적어 놓고 금액이 올라가 있으면 사용자는 검산을
  /// 포기한다. 금액이 안 바뀐 단계는 아예 적지 않는다.
  Widget? _roundingRow(CostRounding? rounding, int? before, int after) {
    if (rounding == null || before == null || before == after) return null;

    final minimum = rounding.minimum;
    if (minimum != null && before < minimum) {
      return _Row(
        CostBreakdownView.minimumLabel,
        '${formatWon(before)} → ${formatWon(after)}',
      );
    }

    final unit = rounding.roundDown;
    if (unit == null || unit <= 1) return null;
    return _Row(
      '${formatWon(unit)} 미만 ${CostBreakdownView.roundLabel}',
      '→ ${formatWon(after)}',
    );
  }

  /// `1,000만원 초과 ~ 1억원 이하` — 구간의 두 끝을 그대로 읽는다.
  ///
  /// 경계 숫자는 데이터가 준 것이고, 여기서는 **표기만** 한다.
  String _tierText(CostTier tier) {
    final floor = steps.tierFloor ?? 0;
    final max = tier.max;
    final from = floor == 0 ? '' : '${formatWon(floor)} 초과 ';
    final to = max == null ? '그 위' : '${formatWon(max)} 이하';
    return '$from$to';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = theme.labelMedium?.copyWith(
      color: emphasis ? BeobaColors.ink : BeobaColors.ink2,
      fontWeight: emphasis ? FontWeight.w800 : FontWeight.w400,
      fontFeatures: kTabularFigures,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: SafeText(
              label,
              where: 'CostBreakdown.label',
              style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SafeText(value, where: 'CostBreakdown.value', style: style),
          ),
        ],
      ),
    );
  }
}
