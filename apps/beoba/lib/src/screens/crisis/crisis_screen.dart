import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/crisis_providers.dart';
import '../../providers/interview_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/crisis_channels.dart';
import '../../widgets/primary_button.dart';

/// 최우선 위기 안내. 다른 무엇보다 먼저 전체 화면으로 덮는다.
///
/// **차단이 아니다.** 하드스톱과 다르다 — `PopScope` 도 없고 닫기 버튼도 있다.
/// 하던 일을 계속할 수 있어야 한다. 우리가 할 일은 막는 것이 아니라 곁에 두는 것이다.
///
/// 다만 닫아도 **없어지지는 않는다.** 상단 고정 줄로 남는다
/// (`CrisisPinnedBar`). 급해서 닫은 사람과 필요 없어서 닫은 사람을 구분할 수 없다.
class CrisisScreen extends ConsumerWidget {
  const CrisisScreen({required this.domainId, super.key});

  final String domainId;

  static const String title = '잠깐 이것부터 보셨으면 합니다';
  static const String body = '지금 바로 이야기 나눌 수 있는 곳이 있습니다. 24시간 열려 있고 무료입니다.';
  static const String close = '괜찮습니다, 계속할게요';
  static const String stays = '닫으셔도 화면 위에 연락처는 남겨 두겠습니다.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    // 아직 안 닫은 신호가 있으면 **가드가 밀어 넣은** 전체 화면이다.
    // 없는데 여기 있다면 상단 고정 줄을 눌러 **사용자가 직접 열어 본** 것이다.
    final pushed = ref.watch(priorityCrisisSignalProvider(domainId));
    final signal = pushed ?? ref.watch(pinnedCrisisSignalProvider(domainId));

    if (signal == null) {
      // 이미 닫혔거나 더 이상 걸리지 않는다. 조용히 물러난다.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: PageBody(
        bottom: GhostButton(
          label: close,
          where: 'CrisisScreen.close',
          onPressed: () {
            ref
                .read(interviewSessionProvider(domainId).notifier)
                .dismissSignal(signal.id);

            // 가드가 밀어 넣은 화면은 pop 할 자리가 없다 — 원래 가려던 곳이
            // 열리기 전에 덮였기 때문이다. "하던 일" 은 인터뷰다.
            if (pushed != null) {
              context.go(Routes.interview(domainId));
              return;
            }
            if (context.canPop()) context.pop();
          },
        ),
        children: [
          const SizedBox(height: 30),
          const Icon(
            Icons.favorite_outline,
            size: 40,
            color: BeobaColors.brand,
          ),
          const SizedBox(height: 16),
          SafeText(title, where: 'CrisisScreen.title', style: theme.headlineSmall),
          const SizedBox(height: 10),
          SafeText(body, where: 'CrisisScreen.body', style: theme.bodyLarge),
          const SizedBox(height: 22),
          CrisisChannelList(channels: signal.channels),
          const SizedBox(height: 6),
          SafeText(
            stays,
            where: 'CrisisScreen.stays',
            style: theme.labelMedium,
          ),
        ],
      ),
    );
  }
}
