import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/plain_title.dart';

/// 선택지 한 줄.
///
/// 선택 상태는 **네 가지가 동시에 바뀐다** — 테두리색 · 테두리 두께 · 배경 · 글자 굵기.
/// 색 하나에 기대지 않는다.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.whatIsThis,
    required this.selected,
    required this.onTap,
    required this.multi,
  });

  final String label;
  final String? whatIsThis;
  final bool selected;
  final VoidCallback onTap;
  final bool multi;

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
          constraints:
              const BoxConstraints(minHeight: BeobaTapTarget.choice),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          // 테두리 대신 면. **고른 것은 전경 링으로 한 번 더** — 전경이라 자리를
          // 안 밀어내서 누를 때 줄이 흔들리지 않는다(DECISIONS 286번).
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Marker(selected: selected, multi: multi),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      label,
                      where: 'QuestionOption.label',
                      style: theme.bodyMedium?.copyWith(
                        fontSize: 16,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    // 모르는 말이 든 선택지에만 붙는다. 없으면 아무것도 안 그린다.
                    OptionWhatIsThis(whatIsThis: whatIsThis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.selected, required this.multi});

  final bool selected;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    if (multi) {
      return Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          color: selected ? BeobaColors.brand : BeobaColors.bg,
          border: Border.all(
            color: selected ? BeobaColors.brand : BeobaColors.control,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: BeobaColors.bg)
            : null,
      );
    }

    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? BeobaColors.brand : BeobaColors.control,
          width: selected ? 6 : 2,
        ),
      ),
    );
  }
}

/// 하나만 고른다.
class SingleChoiceInput extends StatelessWidget {
  const SingleChoiceInput({
    required this.question,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Question question;
  final String? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in question.options)
          _ChoiceTile(
            label: option.label,
            whatIsThis: option.whatIsThis,
            selected: option.value == value,
            multi: false,
            onTap: () => onChanged(option.value),
          ),
      ],
    );
  }
}

/// 여러 개를 고른다.
class MultiChoiceInput extends StatelessWidget {
  const MultiChoiceInput({
    required this.question,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Question question;
  final List<String> value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in question.options)
          _ChoiceTile(
            label: option.label,
            whatIsThis: option.whatIsThis,
            selected: value.contains(option.value),
            multi: true,
            onTap: () {
              final next = [...value];
              if (!next.remove(option.value)) next.add(option.value);
              onChanged(next);
            },
          ),
      ],
    );
  }
}
