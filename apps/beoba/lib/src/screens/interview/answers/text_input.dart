import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';

/// 자유 서술 입력.
///
/// 사용자가 쓴 문장은 `SafeText` 로 되비추지 않는다. 금지어 검사는 **앱이 만든
/// 문구**를 막기 위한 것이지 사용자의 말을 검열하려는 것이 아니다.
class FreeTextInput extends StatefulWidget {
  const FreeTextInput({
    required this.question,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Question question;
  final String? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<FreeTextInput> createState() => _FreeTextInputState();
}

class _FreeTextInputState extends State<FreeTextInput> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  static const String hint = '있는 그대로 적어 주세요';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 3,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: const InputDecoration(hintText: hint),
      onChanged: (raw) => widget.onChanged(raw.trim().isEmpty ? null : raw),
    );
  }
}
