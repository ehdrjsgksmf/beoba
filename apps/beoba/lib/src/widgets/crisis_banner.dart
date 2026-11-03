import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../crisis/crisis_signal.dart';
import '../providers/crisis_providers.dart';
import '../providers/interview_providers.dart';
import '../safety/safe_text.dart';
import 'crisis_channels.dart';
import 'section_card.dart';

/// 위기 안내 배너 (priority 아닌 신호).
///
/// **차단이 아니다.** 닫으면 하던 일을 계속한다. 닫아도 결과·정리 카드 하단에는
/// 남는다 — 급할 때 닫았다가 나중에 찾는 사람이 있다.
class CrisisBanners extends ConsumerWidget {
  const CrisisBanners({required this.domainId, super.key});

  final String domainId;

  static const String heading = '이런 곳에서 도움받으실 수 있습니다';
  static const String close = '닫기';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signals = ref.watch(bannerCrisisSignalsProvider(domainId));
    if (signals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final signal in signals)
          Padding(
            padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
            child: _Banner(domainId: domainId, signal: signal),
          ),
      ],
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({required this.domainId, required this.signal});

  final String domainId;
  final CrisisSignal signal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;

    return SectionCard(
      background: BeobaColors.surfaceSoft,
      padding: const EdgeInsets.fromLTRB(15, 12, 8, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.volunteer_activism_outlined,
                size: 19,
                color: BeobaColors.ink2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SafeText(
                  CrisisBanners.heading,
                  where: 'CrisisBanners.heading',
                  style: theme.labelLarge?.copyWith(color: BeobaColors.ink2),
                ),
              ),
              IconButton(
                tooltip: CrisisBanners.close,
                icon: const Icon(Icons.close, size: 20),
                color: BeobaColors.ink3,
                onPressed: () => ref
                    .read(interviewSessionProvider(domainId).notifier)
                    .dismissSignal(signal.id),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: CrisisChannelList(channels: signal.channels, compact: true),
          ),
        ],
      ),
    );
  }
}

/// 닫힌 priority 신호가 남는 자리. **닫기 버튼이 없다.**
///
/// 자살 신호를 세션에 한 번만 보여주고 마는 것은 위험하다. 급해서 닫은 사람과
/// 필요 없어서 닫은 사람을 구분할 방법이 없다. 전체 화면은 물러나되 한 줄은 남는다.
class CrisisPinnedBar extends ConsumerWidget {
  const CrisisPinnedBar({required this.domainId, super.key});

  final String domainId;

  static const String label = '힘드시면 언제든 여기로 연락하세요';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signal = ref.watch(pinnedCrisisSignalProvider(domainId));
    if (signal == null || signal.channels.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context).textTheme;
    final channel = signal.channels.first;
    final phone = channel.phone ?? '';

    return Material(
      color: BeobaColors.brandSoft,
      child: InkWell(
        onTap: () => context.push(Routes.crisis(domainId)),
        child: Container(
          constraints: const BoxConstraints(minHeight: BeobaTapTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.favorite_outline,
                size: 18,
                color: BeobaColors.brand,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: SafeText(
                  label,
                  where: 'CrisisPinnedBar.label',
                  style: theme.labelMedium?.copyWith(color: BeobaColors.brandInk),
                ),
              ),
              const SizedBox(width: 8),
              SafeText(
                phone,
                where: 'PublicChannel.phone',
                style: theme.labelLarge?.copyWith(
                  color: BeobaColors.brand,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 결과·정리 카드 하단. **닫은 것도 여기엔 남는다.**
class CrisisFooter extends ConsumerWidget {
  const CrisisFooter({required this.domainId, super.key});

  final String domainId;

  static const String heading = '도움받을 수 있는 곳';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signals = ref.watch(allCrisisSignalsProvider(domainId));
    if (signals.isEmpty) return const SizedBox.shrink();

    // 같은 창구가 여러 신호에 걸릴 수 있다. 한 번만 보여준다.
    final seen = <String>{};
    final channels = [
      for (final signal in signals)
        for (final channel in signal.channels)
          if (seen.add(channel.id)) channel,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(heading, icon: Icons.volunteer_activism_outlined),
        CrisisChannelList(channels: channels, compact: true),
      ],
    );
  }
}
