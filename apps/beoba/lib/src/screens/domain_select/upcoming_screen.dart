import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../providers/domain_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/crisis_channels.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../bootstrap_gate.dart';

/// 아직 만들지 않은 분야.
///
/// **못 한다고만 말하고 끝내지 않는다.** 우리가 못 하는 일이어도 어디로 가면
/// 되는지는 말할 수 있다 — 차단 화면에 연결처를 넣은 것과 같은 이유다
/// (안전층 ① 위기 연결 · ③ 자원 연결).
///
/// 분야 이름 · 설명 · 창구 목록은 **전부 도메인 JSON 에서 온다.** 코드에는 없다.
class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({required this.domainId, super.key});

  final String domainId;

  static const String title = '아직 준비 중입니다';
  static const String body = '이 분야는 아직 만들고 있어요. 지금은 절차를 안내해 드릴 수 없습니다.';
  static const String channelsTitle = '지금은 이곳에서 도움받으실 수 있습니다';
  static const String noChannels = '연결해 드릴 창구를 아직 확인하지 못했습니다.';
  static const String back = '다른 분야 고르기';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: beobaAppBar(context),
      body: BootstrapGate(
        child: Consumer(
          builder: (context, ref, _) {
            final theme = Theme.of(context).textTheme;
            final bundle = ref.watch(domainBundleProvider).requireValue;
            final domain = bundle.domains[domainId];
            final channels = bundle.channelsOf(domainId);
            final description = domain?.description;

            return PageBody(
              bottom: GhostButton(
                label: back,
                where: 'UpcomingScreen.back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.schedule_outlined,
                  size: 40,
                  color: BeobaColors.ink3,
                ),
                const SizedBox(height: 16),
                if (domain != null)
                  SafeText(
                    domain.name,
                    where: 'Domain.name',
                    style: theme.headlineSmall,
                  ),
                const SizedBox(height: 8),
                SafeText(
                  title,
                  where: 'UpcomingScreen.title',
                  style: theme.titleMedium?.copyWith(color: BeobaColors.ink2),
                ),
                const SizedBox(height: 12),
                SafeText(
                  description ?? body,
                  where: 'Domain.description',
                  style: theme.bodyLarge,
                ),
                if (channels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: NoticeBox(
                      text: noChannels,
                      where: 'UpcomingScreen.noChannels',
                    ),
                  )
                else ...[
                  SectionHeader(
                    channelsTitle,
                    icon: Icons.support_agent_outlined,
                  ),
                  CrisisChannelList(channels: channels),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
