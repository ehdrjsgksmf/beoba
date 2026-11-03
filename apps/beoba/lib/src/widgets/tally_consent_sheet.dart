import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../providers/tally_providers.dart';
import '../safety/safe_text.dart';

/// 세도 되는지 **묻고 켠다.**
///
/// 개인을 알아볼 수 없는 집계라 법적으로는 안 물어도 될 여지가 있다. 그래도
/// 묻는다 — 안 물으면 「저장하지 않아요」와 부딪히는 것처럼 보인다
/// (DECISIONS 137번).
///
/// **두 버튼이 같은 무게다.** 「세지 마세요」를 고르면 아무것도 안 보내고
/// 기능 차이도 없다. 기본값을 「괜찮아요」로 두지 않는다.
class TallyConsentSheet extends ConsumerWidget {
  const TallyConsentSheet({super.key});

  static const String title = '어떤 문제로 많이 찾아오시는지만 세어 봐도 될까요?';
  static const String body = '적으신 내용이나 금액·날짜는 보지 않아요. '
      '세는 것은 어느 분야인지와 어디까지 보셨는지뿐이에요.';
  static const String yes = '괜찮아요';
  static const String no = '세지 마세요';

  /// 첫 실행 때 한 번. **이미 답하셨으면 열지 않는다.**
  static Future<void> openIfUnanswered(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // **기다렸다가 본다.** `.value` 는 읽는 동안 null 이라, 이미 답하신
    // 분에게도 시트가 한 번 뜬다.
    final answered = await ref.read(tallyConsentProvider.future);
    if (answered != null) return;
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 답하기 전에는 닫지 못한다. 물어보고 켜는 것이 요점이다.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: BeobaColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BeobaSpace.radius),
        ),
      ),
      builder: (_) => const TallyConsentSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;

    Future<void> answer({required bool allowed}) async {
      await ref.read(tallyConsentProvider.notifier).answer(allowed: allowed);
      if (context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeText(
              title,
              where: 'TallyConsentSheet.title',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SafeText(
              body,
              where: 'TallyConsentSheet.body',
              style: theme.bodyMedium?.copyWith(
                color: BeobaColors.ink2,
                height: 1.62,
              ),
            ),
            const SizedBox(height: 20),
            // **같은 무게다.** 한쪽만 크게 만들지 않는다.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => answer(allowed: false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(BeobaTapTarget.button),
                    ),
                    child: SafeText(no, where: 'TallyConsentSheet.no'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => answer(allowed: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(BeobaTapTarget.button),
                    ),
                    child: SafeText(yes, where: 'TallyConsentSheet.yes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
