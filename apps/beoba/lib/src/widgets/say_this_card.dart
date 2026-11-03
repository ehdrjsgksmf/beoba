import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';
import 'copy_block.dart';

/// 「이 말을 그대로 보여 주세요」 — 기관 이름과 서식 이름을 한국어 그대로, 크게.
///
/// ★ **번역이 아니라 표시다.** 한국어를 못 읽는 사람에게 진짜 필요한 것은
/// 번역문이 아니라 **「한국어로 뭐라고 말해야 하는가」**다. 창구에서 화면을
/// 그대로 내밀 수 있으면 그것으로 끝난다. 검수자 없는 번역문은 못 내지만
/// (DECISIONS 233번) 이건 오역이 날 자리 자체가 없다.
///
/// ★ **쉬운 말 모드에서도 이 이름은 안 바뀐다.** 「요양급여 신청서」를 쉬운
/// 말로 풀어 쓰면 창구에서 그 말을 못 쓴다. `kPlainTargets` 에 이 자리가
/// 없어서 구조적으로 못 바꾼다.
///
/// 이름이 없는 절차에는 이 카드를 세우지 않는다. 지어낸 이름을 크게 보여
/// 주는 것이 아무것도 안 보여 주는 것보다 나쁘다.
/// ## 복사가 안 되는 화면이 있다
///
/// 웹에서는 클립보드가 **`navigator.clipboard` 하나뿐**이다. 엔진의 웹 구현
/// (`lib/web_ui/lib/src/engine/clipboard.dart`)이 그것을 못 찾으면
/// `StateError('Clipboard is not available in the context.')` 를 던지고,
/// 채널이 `copy_fail` 로 돌아온다. **옛날에 있던 `execCommand` 되돌림이 이
/// 판에는 없다.**
///
/// ```
/// 안 되는 자리   https 가 아닌 곳 (localhost 는 된다)
///                아주 낡은 브라우저
/// ```
///
/// 예전에는 이 예외를 아무도 안 잡아서 **눌렀는데 아무 일도 안 일어나는
/// 화면**이 됐다. 성공인지 실패인지 사람이 알 수가 없었다.
///
/// 그래서 둘을 한다 — **실패했다고 말하고**, 글자를 **고를 수 있게 띄운다.**
/// 버튼이 있는데 안 되는 것보다 처음부터 고를 수 있는 편이 낫다.
class SayThisCard extends StatelessWidget {
  const SayThisCard({required this.say, required this.where, super.key});

  final SayThis say;
  final String where;

  static const String title = '이 말을 그대로 보여 주세요';
  static const String agencyLabel = '어디로 가는지';
  static const String formLabel = '무엇을 내는지';

  /// 복사 자리의 문구는 [CopyBlock] 이 갖는다. **한 벌만 둔다** —
  /// 정리해서 가져가는 글도 같은 되돌림을 쓴다.
  static const String copy = CopyBlock.copy;
  static const String copied = CopyBlock.copied;
  static const String copyBlocked = CopyBlock.blocked;

  String get _all =>
      say.form == null ? say.agency : '${say.agency}\n${say.form}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 9),
      decoration: BoxDecoration(
        color: BeobaColors.brandSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pan_tool_alt_outlined,
                  size: 15, color: BeobaColors.brand),
              const SizedBox(width: 5),
              Flexible(
                child: SafeText(
                  title,
                  where: 'SayThisCard.title',
                  style: theme.labelSmall?.copyWith(
                    color: BeobaColors.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Name(
            label: agencyLabel,
            name: say.agency,
            where: '$where.agency',
            field: 'agency',
          ),
          if (say.form case final String form) ...[
            const SizedBox(height: 10),
            _Name(
              label: formLabel,
              name: form,
              where: '$where.form',
              field: 'form',
            ),
          ],
          CopyBlock(text: _all, where: 'SayThisCard'),
        ],
      ),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name({
    required this.label,
    required this.name,
    required this.where,
    required this.field,
  });

  final String label;
  final String name;
  final String where;
  final String field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeText(
          label,
          where: 'SayThisCard.$field',
          style: theme.labelSmall?.copyWith(color: BeobaColors.brandInk),
        ),
        const SizedBox(height: 2),
        // **크게.** 창구 너머에서도 읽혀야 하는 글자다.
        SafeText.forField(
          name,
          typeName: 'SayThis',
          fieldName: field,
          style: theme.headlineSmall?.copyWith(
            color: BeobaColors.ink,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
