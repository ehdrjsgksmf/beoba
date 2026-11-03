import 'package:domain_data/domain_data.dart' show DomainStatus;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/domain_providers.dart';
import '../../providers/interview_providers.dart';
import '../domain_select/domain_select_screen.dart';
import '../../safety/safe_text.dart';
import '../../widgets/crisis_channels.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';

/// 고른 답이 다른 분야에 속한다.
///
/// **아무것도 못 해 주더라도 틀린 걸 해 주지는 않는다.** 보증금 반환에는
/// 임차권등기명령 같은 전용 절차가 있어서 `debt_recovery` 로 끝까지 안내하면
/// 틀린 절차를 알려주게 된다. 그래서 여기서 흐름을 끊는다.
///
/// 끊되 **어디로 가면 되는지는 말한다** — 넘겨야 할 분야의 공적 창구를 그대로
/// 보여준다. 선택지를 잘못 골랐다면 앞 질문으로 돌아갈 수 있다.
class RedirectNotice extends ConsumerWidget {
  const RedirectNotice({
    required this.domainId,
    required this.targetDomainId,
    super.key,
  });

  final String domainId;
  final String targetDomainId;

  static const String title = '이 문제는 다른 분야입니다';

  /// **분야가 다 열렸다.** 예전에는 넘겨줄 곳이 없어 창구로만 보냈는데,
  /// 이제는 그 분야가 실제로 있다. 「준비된 분야에서 다루지 않습니다」는
  /// 틀린 말이 됐다(DECISIONS 143번).
  static const String body =
      '고르신 내용은 여기가 아니라 다른 분야에서 다뤄요. 잘못 고르셨다면 앞 질문으로 돌아가 고쳐 주세요.';

  /// 아직 안 연 분야로 넘길 때. 그때는 창구가 전부다.
  static const String comingSoonBody =
      '고르신 내용은 지금 준비된 분야에서 다루지 않습니다. 잘못 고르셨다면 앞 질문으로 돌아가 고쳐 주세요.';

  static String goTo(String name) => '$name(으)로 가기';
  static const String channelsTitle = '지금은 이곳에서 도움받으실 수 있습니다';
  static const String noChannels = '연결해 드릴 창구를 아직 확인하지 못했습니다.';
  static const String back = '앞 질문으로 돌아가기';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final bundle = ref.watch(domainBundleProvider).requireValue;
    final target = bundle.domains[targetDomainId];
    final channels = bundle.channelsOf(targetDomainId);

    // **그 분야가 실제로 있으면 데려다준다.** 막다른 길로 두지 않는다.
    final open = target != null && target.status == DomainStatus.active;

    return PageBody(
      bottom: open
          ? PrimaryButton(
              label: goTo(target.name),
              where: 'RedirectNotice.goTo',
              onPressed: () => startDomain(
                context,
                ref,
                targetDomainId,
                ref.read(pendingNarrativeProvider),
              ),
            )
          : PrimaryButton(
              label: back,
              where: 'RedirectNotice.back',
              // 라우트가 질문 단위라 그냥 한 칸 뒤로 가면 된다.
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.domains),
            ),
      children: [
        const SizedBox(height: 30),
        const Icon(
          Icons.alt_route_outlined,
          size: 40,
          color: BeobaColors.legalMaybe,
        ),
        const SizedBox(height: 16),
        SafeText(
          title,
          where: 'RedirectNotice.title',
          style: theme.headlineSmall,
        ),
        if (target != null) ...[
          const SizedBox(height: 8),
          SafeText(
            target.name,
            where: 'Domain.name',
            style: theme.titleMedium?.copyWith(color: BeobaColors.ink2),
          ),
        ],
        const SizedBox(height: 12),
        SafeText(
          open ? body : comingSoonBody,
          where: 'RedirectNotice.body',
          style: theme.bodyLarge,
        ),
        if (open) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.domains),
              child: SafeText(back, where: 'RedirectNotice.back'),
            ),
          ),
        ],
        if (channels.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: NoticeBox(text: noChannels, where: 'RedirectNotice.noChannels'),
          )
        else ...[
          SectionHeader(channelsTitle, icon: Icons.support_agent_outlined),
          CrisisChannelList(channels: channels),
        ],
      ],
    );
  }
}
