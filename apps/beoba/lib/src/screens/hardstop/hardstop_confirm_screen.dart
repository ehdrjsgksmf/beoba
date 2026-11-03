import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/interview_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';

/// 키워드로 **추정된** 하드스톱을 확인한다.
///
/// 키워드 트리거는 자유 입력에 대한 부분 문자열 스캔이다. 확신이 없다.
///
/// ```
/// "빌려준 돈을 안 갚아서 고소하겠다고 했더니 연락이 끊겼습니다"
///                       ↑ 명백한 민사인데 '고소' 하나로 튕겨나간다
/// ```
///
/// 과잉 차단은 도움이 필요한 사람을 쫓아낸다. 그래서 한 번 묻는다.
/// 선택지를 골라 **확정된** 하드스톱은 이 화면을 거치지 않는다.
class HardStopConfirmScreen extends ConsumerWidget {
  const HardStopConfirmScreen({required this.domainId, super.key});

  final String domainId;

  static const String title = '확인 부탁드립니다';
  static const String yes = '네, 맞습니다';
  static const String no = '아니요, 계속 진행할게요';
  static const String hint = '맞다면 도움받을 수 있는 곳을 알려 드리고, 아니라면 그대로 진행합니다.';

  /// 확인 단계의 문구. **사건 종류를 특정하지 않는다.**
  ///
  /// 하드스톱의 `title`(예: "형사 사건은 다루지 않습니다")을 여기서 그대로 되물으면
  /// 낱말 하나로 사건을 규정하게 된다. 아직 **추정 단계**이므로 이 앱이 다루지
  /// 않는다는 사실만 말한다. 종류를 밝히는 것은 사용자가 "네" 를 누른 뒤 차단 화면의
  /// 몫이다.
  static const String prompt = '적어 주신 내용에 이 앱이 다루지 않는 문제가 섞여 있는 것 같습니다.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final triggered = ref.watch(hardStopsProvider(domainId));

    // 더 이상 걸리지 않으면 되물을 것도 없다.
    if (triggered.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.interview(domainId));
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final screen = triggered.first.stop.screen;

    return Scaffold(
      appBar: beobaAppBar(context),
      body: PageBody(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: yes,
              where: 'HardStopConfirmScreen.yes',
              onPressed: () => context.go(Routes.hardStop(domainId)),
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: no,
              where: 'HardStopConfirmScreen.no',
              onPressed: () {
                ref
                    .read(interviewSessionProvider(domainId).notifier)
                    .dismissHardStops(_sameKind(ref, screen));
                context.go(Routes.interview(domainId));
              },
            ),
          ],
        ),
        children: [
          const SizedBox(height: 30),
          const Icon(
            Icons.help_outline,
            size: 40,
            color: BeobaColors.legalMaybe,
          ),
          const SizedBox(height: 16),
          SafeText(
            title,
            where: 'HardStopConfirmScreen.title',
            style: theme.headlineSmall,
          ),
          const SizedBox(height: 12),
          SectionCard(
            background: BeobaColors.amberSoft,
                  child: SafeText(
              prompt,
              where: 'HardStopConfirmScreen.prompt',
              style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),
          const NoticeBox(text: hint, where: 'HardStopConfirmScreen.hint'),
        ],
      ),
    );
  }

  /// 지금 걸려 있는 키워드 하드스톱 중 **같은 종류**의 id 들.
  ///
  /// 같은 화면(`screen`)을 가리키면 사용자에게는 같은 질문이다. 한 번에 정리한다.
  Set<String> _sameKind(WidgetRef ref, String screen) {
    return {
      for (final stop in ref.read(hardStopsProvider(domainId)))
        if (stop.needsConfirmation && stop.stop.screen == screen) stop.id,
    };
  }
}
