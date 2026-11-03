import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show KoreanAmount, Money, parseKoreanWon;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';

/// 금액·수량 입력.
///
/// 값은 반드시 `int` 로 나간다. `CaseFacts.money()` 는 `double` 을 **거부한다** —
/// 금액이 실수로 들어오는 경로를 애초에 만들지 않는다 (DECISIONS.md 4번).
///
/// ## 왜 만원 칸이 기본인가
///
/// 사람은 "오천만원" 이라고 말하지 "50000000원" 이라고 말하지 않는다. 0 을 여덟 개
/// 세는 일에서 오타가 난다. 그래서 **입력만** 만원 단위로 받는다.
///
/// **저장은 원 단위 정수 그대로다.** `Money.fromManwon` 을 지나는 순간 원이 된다.
/// 인지대는 구간이 갈려서 원 단위 정확도를 하나도 잃으면 안 된다.
///
/// ## 숫자 칸 하나뿐이다
///
/// 「한글로 적기」 단추가 있었지만 뺐다. 만원/원 전환이 있으면 한글로 적을 이유가
/// 거의 없고, 자릿수가 헷갈리는 문제는 아래의 **숫자→한글 읽어주기**가 이미
/// 풀고 있다 (DECISIONS 57번).
///
/// 다만 `parseKoreanWon` 은 이 칸의 **읽는 함수로 그대로 남아 있다.** 숫자 키패드로는
/// 한글을 칠 수 없지만 **붙여넣기로는 들어온다** — 카카오톡에서 "오천만원" 을 복사해
/// 오는 사람이 있다. 읽을 수 있는 것을 거절할 이유가 없고, 읽은 결과는 바로 아래에
/// 숫자로 되돌려 보여주므로 사용자가 확인할 수 있다.
class MoneyInput extends StatefulWidget {
  const MoneyInput({
    required this.question,
    required this.value,
    required this.onChanged,
    this.asMoney = true,
    super.key,
  });

  final Question question;
  final int? value;
  final ValueChanged<Object?> onChanged;

  /// 금액이면 만원 칸·한글 읽기·빨리 채우기를 보여준다. 수량이면 숫자 칸이다.
  final bool asMoney;

  static const String manwonSuffix = '만원';
  static const String wonSuffix = '원';
  static const String hint = '숫자로 적어 주세요';

  /// 단위 칩. 지금 어느 단위인지가 **보인다** — 눌러야 알 수 있게 두지 않는다.
  static const String unitManwon = '만원';
  static const String unitWon = '원';

  /// 못 읽었을 때. **되묻는다. 0 으로 만들지 않는다.**
  static const String unreadable = '이 금액을 읽지 못했어요. 숫자로 적어 주세요';

  /// 만원으로 되돌리면 값이 잘리는 경우.
  static const String notRound = '만원으로 딱 떨어지지 않아서 원 단위로 둘게요';

  /// 빨리 채우는 단추. 값은 **만원 단위**다.
  static const List<int> quickAdds = [10, 100, 1000];

  @override
  State<MoneyInput> createState() => _MoneyInputState();
}

class _MoneyInputState extends State<MoneyInput> {
  late final TextEditingController _controller;

  /// 원 단위 칸을 펼쳤는가.
  ///
  /// 처음 들어온 값이 만원으로 딱 떨어지지 않으면 원 단위로 연다 — 접힌 칸이
  /// 자기 답을 반올림해 보여주면 사용자는 앱이 값을 바꿨다고 생각한다.
  late bool _inWon =
      !widget.asMoney || (widget.value != null && widget.value! % Money.manwon != 0);

  /// 만원으로 되돌리려다 값이 잘려서 막은 적이 있는가.
  bool _blockedRounding = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText());
  }

  String _initialText() {
    final value = widget.value;
    if (value == null) return '';
    return _inWon ? value.toString() : (value ~/ Money.manwon).toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 칸의 단위. 만원 칸이면 10000, 원 칸이면 1.
  int get _unit => _inWon || !widget.asMoney ? 1 : Money.manwon;

  /// 지금 적힌 것을 읽은 결과. 못 읽으면 null.
  KoreanAmount? get _parsed => parseKoreanWon(_controller.text, unit: _unit);

  /// 원 단위 값. 저장되는 것은 언제나 이것이다.
  int? get _won {
    final parsed = _parsed;
    if (parsed == null) return null;
    if (parsed.won > Money.maxBase) return null;
    return parsed.won;
  }

  /// 적었는데 못 읽은 상태인가. 비어 있는 것과 다르다.
  bool get _isUnreadable => _controller.text.trim().isNotEmpty && _won == null;

  void _emit() {
    setState(() => _blockedRounding = false);
    widget.onChanged(_won);
  }

  void _add(int manwon) {
    final next = (_won ?? 0) + Money.fromManwon(manwon);
    final capped = next > Money.maxBase ? Money.maxBase : next;
    _controller.text = (_inWon ? capped : capped ~/ Money.manwon).toString();
    _emit();
  }

  /// 단위를 고른다. **양쪽 모두 열려 있다.** 한쪽으로만 열린 문은 사용자를 가둔다.
  ///
  /// 다만 만원으로 되돌릴 때 끝자리가 잘리면 **바꾸지 않는다.** 금액이 조용히
  /// 달라지는 것보다 칸을 그대로 두고 이유를 말하는 쪽이 낫다.
  void _selectUnit({required bool inWon}) {
    if (inWon == _inWon) return;
    final won = _won;
    if (!inWon && won != null && won % Money.manwon != 0) {
      setState(() => _blockedRounding = true);
      return;
    }

    setState(() {
      _inWon = inWon;
      _blockedRounding = false;
      _controller.text =
          won == null ? '' : (_inWon ? won : won ~/ Money.manwon).toString();
    });
    widget.onChanged(_won);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final won = _won;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          // 숫자 키패드 하나뿐이다. 한글은 붙여넣기로만 들어온다.
          keyboardType: TextInputType.number,
          style: theme.bodyMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFeatures: kTabularFigures,
          ),
          decoration: InputDecoration(
            hintText: MoneyInput.hint,
            suffixText: !widget.asMoney
                ? null
                : (_inWon ? MoneyInput.wonSuffix : MoneyInput.manwonSuffix),
            errorText: _isUnreadable ? MoneyInput.unreadable : null,
            errorMaxLines: 3,
          ),
          onChanged: (_) => _emit(),
        ),
        if (widget.asMoney && won != null) ...[
          const SizedBox(height: 9),
          // **읽은 결과를 숫자로 되돌려 보여준다.** 잘못 읽으면 인지대가 틀린다.
          SafeText(
            formatWon(won),
            where: 'MoneyInput.readBack',
            style: theme.bodyMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: BeobaColors.brand2,
              fontFeatures: kTabularFigures,
            ),
          ),
          const SizedBox(height: 3),
          // 0 개수를 세지 않고도 자릿수를 알아볼 수 있게 소리 내어 읽어 준다.
          SafeText(
            formatWonKorean(won),
            where: 'MoneyInput.korean',
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink3),
          ),
        ],
        if (_blockedRounding) ...[
          const SizedBox(height: 8),
          SafeText(
            MoneyInput.notRound,
            where: 'MoneyInput.notRound',
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
          ),
        ],
        if (widget.asMoney && !_inWon) ...[
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final step in MoneyInput.quickAdds)
                _QuickAdd(manwon: step, onTap: () => _add(step)),
            ],
          ),
        ],
        if (widget.asMoney) ...[
          const SizedBox(height: 12),
          // 단위 칩. 예외를 위한 문이라 본문과 경쟁하면 안 된다.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _UnitChip(
                label: MoneyInput.unitManwon,
                selected: !_inWon,
                onTap: () => _selectUnit(inWon: false),
              ),
              _UnitChip(
                label: MoneyInput.unitWon,
                selected: _inWon,
                onTap: () => _selectUnit(inWon: true),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 단위 칩. 지금 어느 단위인지가 눌러 보지 않아도 보인다.
///
/// 선택 상태는 **색 하나에 기대지 않는다** — 테두리색·두께·배경·굵기가 함께 바뀐다.
class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, BeobaTapTarget.minimum),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor:
            selected ? BeobaColors.brandSoft : BeobaColors.surfaceStrong,
        foregroundColor: selected ? BeobaColors.brand : BeobaColors.ink2,
        side: selected
            ? const BorderSide(color: BeobaColors.brand, width: 2)
            : BorderSide.none,
      ),
      child: SafeText(
        label,
        where: 'MoneyInput.unitChip',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? BeobaColors.brand : BeobaColors.ink2,
            ),
      ),
    );
  }
}

/// `+10만` 처럼 눌러서 더하는 단추.
class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.manwon, required this.onTap});

  final int manwon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, BeobaTapTarget.minimum),
        padding: const EdgeInsets.symmetric(horizontal: 15),
      ),
      child: SafeText(
        '+$manwon만',
        where: 'MoneyInput.quickAdd',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
      ),
    );
  }
}
