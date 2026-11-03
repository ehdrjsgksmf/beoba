import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../providers/domain_providers.dart';
import '../safety/safe_text.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

/// 도메인 로드가 끝나야 화면을 연다.
///
/// 이 뒤로는 `requireValue` 가 안전하다. 로드가 실패하면 화면을 열지 않는다 —
/// **부실한 결과를 보여주느니 안 보여주는 게 낫다.**
class BootstrapGate extends ConsumerWidget {
  const BootstrapGate({required this.child, super.key});

  final Widget child;

  static const String loading = '법률 정보를 불러오는 중입니다';
  static const String failedTitle = '법률 정보를 불러오지 못했습니다';
  static const String failedBody =
      '데이터가 검증을 통과하지 못했습니다. 잘못된 정보를 보여드릴 수 없어 여기서 멈춥니다.';
  static const String retry = '다시 시도';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(domainBundleProvider).when(
          data: (_) => child,
          loading: () => const _Loading(),
          error: (error, _) => _Failed(
            error: error,
            onRetry: () => ref.invalidate(domainBundleProvider),
          ),
        );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          SafeText(
            BootstrapGate.loading,
            where: 'BootstrapGate.loading',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return PageBody(
      bottom: PrimaryButton(
        label: BootstrapGate.retry,
        where: 'BootstrapGate.retry',
        onPressed: onRetry,
      ),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 40, color: BeobaColors.red),
        const SizedBox(height: 16),
        SafeText(
          BootstrapGate.failedTitle,
          where: 'BootstrapGate.failedTitle',
          style: theme.headlineSmall,
        ),
        const SizedBox(height: 10),
        SafeText(
          BootstrapGate.failedBody,
          where: 'BootstrapGate.failedBody',
          style: theme.bodyLarge,
        ),
        const SizedBox(height: 18),
        if (error is DomainValidationException) _Details(error: error),
      ],
    );
  }
}

/// 개발 중 원인을 바로 볼 수 있게. 사용자에게는 위의 안내가 본문이다.
class _Details extends StatelessWidget {
  const _Details({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    // 검증기가 낸 원본 메시지. 어느 항목이 왜 걸렸는지 바로 볼 수 있게 남긴다.
    return NoticeBox(text: '$error', where: 'BootstrapGate.details');
  }
}
