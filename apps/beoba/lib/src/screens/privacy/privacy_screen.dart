import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/asset_policy_source.dart';
import '../../providers/policy_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/today_pill.dart';

/// 개인정보처리방침 전문.
///
/// **요약과 다른 화면이다.** `PrivacySheet` 는 홈에서 「자세히」를 눌렀을 때
/// 여섯 줄로 답한다 — 지금 글을 쓰다 말고 읽는 사람에게 맞춘 길이다.
/// 이 화면은 **끝까지 읽으려고 들어온 사람**의 자리다.
///
/// ## 글은 코드에 없다
///
/// 한 글자도 이 파일에 없다. `docs/개인정보처리방침.md` 가 원본이고
/// `build_privacy_page.dart` 가 자산으로 굽는다. 같은 원본에서 스토어에 낼
/// 정적 페이지 한 장도 함께 나온다. **세 곳이 어긋나면 검사 (ah) 가 멈춘다.**
///
/// ## 못 읽으면 못 읽었다고 말한다
///
/// 자산을 못 읽었을 때 빈 화면을 보이지 않는다. 방침은 **안 보여 준 것이
/// 곧 안 알린 것**이 되는 글이라, 실패를 조용히 넘기면 안 된다.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static const String failed = '방침을 불러오지 못했습니다. 인터넷 없이도 열려야 하는 글이라, 이건 앱 문제입니다.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: beobaAppBar(context),
      body: ref.watch(policyBlocksProvider).when(
            // **도는 동그라미를 두지 않는다.** 이 글은 앱 안에 들어 있어서
            // 기다릴 것이 없다. 그리고 끝나지 않는 애니메이션을 한 번 두면
            // 이 화면을 지나는 모든 화면 검사가 그 자리에서 멈춘다.
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const PageBody(
              children: [
                SizedBox(height: 20),
                NoticeBox(text: failed),
              ],
            ),
            data: (blocks) => PageBody(
              children: [
                for (final block in blocks) _PolicyLine(block: block),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );
  }
}

/// 덩어리 하나. **종류마다 크기만 다르다.**
class _PolicyLine extends StatelessWidget {
  const _PolicyLine({required this.block});

  final PolicyBlockData block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    switch (block.kind) {
      case 'title':
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: SafeText(
            block.text,
            where: 'PrivacyScreen.title',
            style: theme.headlineSmall,
          ),
        );
      case 'section':
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: BeobaColors.line),
              const SizedBox(height: 16),
              SafeText(
                block.text,
                where: 'PrivacyScreen.section',
                style: theme.titleMedium?.copyWith(color: BeobaColors.brand),
              ),
            ],
          ),
        );
      case 'strong':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SafeText(
            block.text,
            where: 'PrivacyScreen.strong',
            style: theme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.7,
            ),
          ),
        );
      case 'item':
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.circle,
                  size: 5,
                  color: BeobaColors.ink3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SafeText(
                  block.text,
                  where: 'PrivacyScreen.item',
                  style: theme.bodyLarge?.copyWith(
                    color: BeobaColors.ink2,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SafeText(
            block.text,
            where: 'PrivacyScreen.para',
            style: theme.bodyLarge?.copyWith(
              color: BeobaColors.ink2,
              height: 1.7,
            ),
          ),
        );
    }
  }
}
