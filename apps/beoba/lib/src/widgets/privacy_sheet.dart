import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// 「자세히」를 누르면 열리는 시트.
///
/// **용어 시트가 아니다.** 법 이야기가 아니라 우리가 무엇을 하고 무엇을 안
/// 하는지에 대한 이야기라 🟢/🟡 배지를 달지 않는다.
///
/// ## 마지막 줄이 이 시트의 이유다
///
/// 자판이 스스로 기억하는 것은 우리가 못 막는다. `enableSuggestions: false`
/// 로도 못 막고(제안 표시가 꺼질 뿐이다) 급하고 당황한 사람의 자판만
/// 어려워진다. **못 막는 것은 못 막는다고 말하고, 어디서 지우는지 알려준다.**
/// 겁만 주고 끝내면 안내가 아니라 면피다.
class PrivacySheet extends StatelessWidget {
  const PrivacySheet({super.key});

  static const String title = '적어주신 내용은 어떻게 되나요?';
  static const String closeLabel = '닫기';

  /// **여섯 줄로 끝나지 않는 사람의 자리다.**
  ///
  /// 요약만 두면 「더 있는데 안 보여 준다」가 됩니다. 전문은 앱 안에 있고
  /// 인터넷 없이도 열린다.
  static const String fullLabel = '전문 보기';

  /// 앞의 셋은 **코드가 지키는 것**, 가운데 둘은 **나가는 것과 남는 것**,
  /// 마지막 하나는 **못 지키는 것**이다.
  ///
  /// 첫 줄이 「인터넷으로 보내지 않아요」였다. 집계를 넣으면서 그 말이
  /// 넷째 줄과 부딪혔다 — **정확한 말로 고쳤다.** 나가지 않는 것은 적으신
  /// 글이고, 나가는 것은 분야와 어디까지 보셨는지다(DECISIONS 136번).
  ///
  /// **「일부는 보관합니다」 같은 애매한 말을 쓰지 않는다.** 무엇을 보내고
  /// 무엇을 안 보내는지 각각 말한다.
  static const List<(IconData, String)> lines = [
    (Icons.cloud_off_outlined, '적으신 글은 나가지 않아요. 이 기기 안에만 있어요.'),
    (Icons.save_outlined, '앱이 따로 저장하지 않아요. 껐다 켜면 남지 않아요.'),
    (Icons.history_toggle_off_outlined, '브라우저 뒤로 가기에도 남지 않아요.'),
    (
      Icons.bar_chart_outlined,
      '어떤 분야를 보셨는지만 세어요. 적으신 내용·금액·날짜는 보내지 않아요. '
          '세지 않기를 고르셨다면 그것도 안 보내요.',
    ),
    (
      Icons.check_circle_outline,
      '세도 되는지 답하신 것과 쉬운 말로 볼지 고르신 것만 기기에 남겨요. '
          '매번 여쭤보지 않으려고요.',
    ),
    (
      Icons.keyboard_outlined,
      '다만 휴대폰 자판이 자주 쓰는 말을 스스로 기억할 수 있어요. '
          '그건 저희가 아니라 자판 설정에서 지우실 수 있어요.',
    ),
  ];

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: BeobaColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BeobaSpace.radius),
          ),
        ),
        builder: (_) => const PrivacySheet(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 17,
                    color: BeobaColors.ink2,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: SafeText(
                      title,
                      where: 'PrivacySheet.title',
                      style: theme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final (icon, line) in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(icon, size: 17, color: BeobaColors.ink3),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SafeText(
                          line,
                          where: 'PrivacySheet.line',
                          style: theme.bodyMedium?.copyWith(
                            color: BeobaColors.ink2,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: BeobaTapTarget.button,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    GoRouter.of(context).push(Routes.privacy);
                  },
                  child: SafeText(
                    fullLabel,
                    where: 'PrivacySheet.fullLabel',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: BeobaTapTarget.button,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: SafeText(
                    closeLabel,
                    where: 'PrivacySheet.closeLabel',
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
