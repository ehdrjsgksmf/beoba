import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// 결과에 나오는 항목의 제목과 부제. **예외 없이 이 구조다.**
///
/// ```
/// 지급명령 (독촉절차)
/// 재판 없이 법원을 통해 갚으라고 요구하는 일이에요
///
/// 인지대                                        20,700원
/// 법원에 소송을 낼 때 내는 수수료예요
/// ```
///
/// **제목은 언제나 공식 용어다.** 쉬운 말로 바꾸지 않는다 — 사용자는 이 이름을
/// 전자소송 화면에서, 법원 창구에서, 받은 서류에서 다시 찾아야 한다. 거기 적힌
/// 이름을 앱에서 배우지 못하면 절차를 끝까지 따라갈 수 없다 (DECISIONS 40번).
///
/// 쉬운 말은 **부제 자리**에 둔다. 이름이 아니라 설명이기 때문이다.
///
/// 탭해서 펼치지 않는다. 툴팁도 쓰지 않는다 — 모르는 사람은 그게 눌린다는 것을
/// 모른다. 항상 보이는 것만 읽힌다.
class PlainTitle extends StatelessWidget {
  const PlainTitle({
    required this.label,
    required this.whatIsThis,
    this.where = 'PlainTitle',
    this.titleStyle,
    this.trailing,
    super.key,
  });

  /// 공식 용어 그대로. **바꾸지 않는다.**
  final String label;

  /// 바로 아래 붙는 한 줄 풀이.
  final String whatIsThis;

  final String where;
  final TextStyle? titleStyle;

  /// 제목 줄 오른쪽 (금액 등).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SafeText(
                label,
                where: '$where.label',
                style: titleStyle ?? theme.titleMedium,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
        if (whatIsThis.isNotEmpty) ...[
          const SizedBox(height: 3),
          SafeText(
            whatIsThis,
            where: '$where.whatIsThis',
            style: theme.labelMedium,
          ),
        ],
      ],
    );
  }
}

/// 선택지에 붙는 한 줄 풀이. **선택 사항이라 없으면 아무것도 그리지 않는다.**
class OptionWhatIsThis extends StatelessWidget {
  const OptionWhatIsThis({required this.whatIsThis, super.key});

  final String? whatIsThis;

  @override
  Widget build(BuildContext context) {
    final text = whatIsThis;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: SafeText(
        text,
        where: 'QuestionOption.whatIsThis',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: BeobaColors.ink3,
            ),
      ),
    );
  }
}
