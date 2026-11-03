import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';
import 'agency_notice_line.dart';

/// 공적 창구 하나. **문구도 번호도 전부 JSON 에서 온다.**
///
/// 번호를 링크로만 두지 않는다. 데스크톱 웹에서 `tel:` 은 아무 일도 안 일어나거나
/// 앱 선택 창만 뜬다. 그러면 PC 사용자는 번호를 옮겨 적을 수조차 없다.
/// `label` · `org` · `phone` 셋 다 글자로 보이고, 번호가 탭 영역이 된다.
class CrisisChannelTile extends StatelessWidget {
  const CrisisChannelTile({required this.channel, this.compact = false, super.key});

  final PublicChannel channel;

  /// 하단 목록처럼 좁은 자리에서 쓴다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final phone = channel.phone;
    final org = channel.org;
    final note = channel.note;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 13 : 15),
      decoration: BoxDecoration(
        color: BeobaColors.surfaceStrong,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            channel.label,
            where: 'PublicChannel.label',
            style: theme.titleMedium,
          ),
          if (org != null && org.isNotEmpty) ...[
            const SizedBox(height: 3),
            SafeText(
              org,
              where: 'PublicChannel.org',
              style: theme.labelMedium,
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            SizedBox(height: compact ? 8 : 10),
            _PhoneButton(phone: phone, label: channel.label),
          ],
          if (!compact && note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            SafeText(
              note,
              where: 'PublicChannel.note',
              style: theme.labelMedium,
            ),
          ],
          // **조문이 아닌 것에는 조문 딱지를 안 단다.** 창구 안내에 금액이
          // 섞여 있을 수 있고, 그건 기관 공지에서 온다(DECISIONS 245).
          if (!compact)
            if (channel.notice case final notice?) ...[
              const SizedBox(height: 8),
              AgencyNoticeLine(notice: notice),
            ],
        ],
      ),
    );
  }
}

/// 번호 자체가 탭 영역.
class _PhoneButton extends StatelessWidget {
  const _PhoneButton({required this.phone, required this.label});

  final String phone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$label $phone',
      child: InkWell(
        onTap: () => _dial(phone),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: BeobaTapTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call, size: 20, color: BeobaColors.brand),
              const SizedBox(width: 9),
              // **번호는 접히더라도 잘리지 않는다.** 배율 2.0 에서 116px 이
              // 오른쪽으로 사라졌고, 사라진 자리가 하필 전화번호였다.
              // 위기 화면에서 번호의 뒷자리가 없는 것보다 두 줄이 낫다.
              Flexible(
                child: SafeText(
                  phone,
                  where: 'PublicChannel.phone',
                  style: theme.titleMedium?.copyWith(
                    fontSize: 21,
                    color: BeobaColors.brand,
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 걸리지 않아도 화면의 번호는 그대로 남는다. 실패를 사용자에게 떠넘기지 않는다.
  Future<void> _dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll('-', ''));
    await launchUrl(uri).catchError((_) => false);
  }
}

/// 창구 여러 개를 세로로.
class CrisisChannelList extends StatelessWidget {
  const CrisisChannelList({
    required this.channels,
    this.compact = false,
    super.key,
  });

  final List<PublicChannel> channels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final channel in channels)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : BeobaSpace.blockGap),
            child: CrisisChannelTile(channel: channel, compact: compact),
          ),
      ],
    );
  }
}
