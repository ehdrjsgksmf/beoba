import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// 글자를 클립보드로 넘겨 주는 자리. **막히면 고를 수 있게 띄운다.**
///
/// ## 왜 되돌림이 필요한가
///
/// 웹에서는 클립보드가 **`navigator.clipboard` 하나뿐**이다. 엔진의 웹 구현
/// (`lib/web_ui/lib/src/engine/clipboard.dart`)이 그것을 못 찾으면
/// `StateError('Clipboard is not available in the context.')` 를 던지고
/// 채널이 `copy_fail` 로 돌아온다. **옛날에 있던 `execCommand` 되돌림이 이
/// 판에는 없다.**
///
/// ```
/// 안 되는 자리   https 가 아닌 곳 (localhost 는 된다)
///                아주 낡은 브라우저
/// ```
///
/// 예전에는 예외를 아무도 안 잡아서 **눌렀는데 아무 일도 안 일어나는 화면**이
/// 됐다. 성공인지 실패인지 사람이 알 수가 없었다.
///
/// 그래서 둘을 한다 — **실패했다고 말하고**, 글자를 **고를 수 있게 띄운다.**
/// 버튼이 있는데 안 되는 것보다 처음부터 고를 수 있는 편이 낫다.
///
/// ★ **스낵바로 안 낸다.** 2초 뒤 사라지는데 사람이 해야 할 일은 그 뒤에
/// 남아 있다. 자리를 차지하고 계속 있어야 한다.
class CopyBlock extends StatefulWidget {
  const CopyBlock({
    required this.text,
    required this.where,
    this.label = copy,
    super.key,
  });

  /// 넘겨 줄 글자. 되돌림에서 고르게 되는 것도 이것이다.
  final String text;
  final String where;
  final String label;

  static const String copy = '복사';
  static const String copied = '복사했어요';

  /// 복사가 막혔을 때. **「실패했어요」로 끝내지 않고 길을 준다.**
  static const String blocked = '이 화면에서는 복사가 안 돼요. '
      '아래 글자를 직접 골라서 가져가실 수 있어요.';

  @override
  State<CopyBlock> createState() => _CopyBlockState();
}

class _CopyBlockState extends State<CopyBlock> {
  /// 한 번 막히면 계속 막힌다. 다시 눌러 보게 하지 않는다.
  bool _blocked = false;

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
    } on Object {
      // **무슨 예외인지로 가르지 않는다.** 사람에게 필요한 것은 예외 이름이
      // 아니라 「지금 이 화면에서는 안 되고, 대신 이렇게 하면 된다」다.
      if (mounted) setState(() => _blocked = true);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: SafeText(CopyBlock.copied, where: '${widget.where}.copied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (!_blocked) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: SafeText(widget.label, where: '${widget.where}.copy'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeText(
          CopyBlock.blocked,
          where: '${widget.where}.blocked',
          style: theme.labelMedium?.copyWith(color: BeobaColors.brandInk),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
          ),
          // **손댄 것이 섞이면 안 된다.** 사람이 끌어가는 글자 그대로다.
          child: SafeText.forField(
            widget.text,
            typeName: 'SayThis',
            fieldName: 'agency',
            selectable: true,
            style: theme.bodyMedium?.copyWith(color: BeobaColors.ink),
          ),
        ),
      ],
    );
  }
}
