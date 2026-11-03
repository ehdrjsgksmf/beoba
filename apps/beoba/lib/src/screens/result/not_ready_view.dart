import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../layers/legal_layer.dart';
import '../../safety/safe_text.dart';
import '../../widgets/layer_block.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';

/// `readiness == red` 일 때 결과 대신 보여준다.
///
/// **부실한 결과를 보여주느니 안 보여주는 게 낫다.** 절반만 아는 상태로 기한과
/// 비용을 늘어놓으면 사용자는 그게 맞는 줄 안다.
class NotReadyView extends StatelessWidget {
  const NotReadyView({
    required this.state,
    required this.missing,
    required this.onFix,
    super.key,
  });

  final InterviewState state;

  /// 빠진 필수 항목 → 되돌아갈 질문.
  final List<RedBlock> missing;

  final void Function(String questionId) onFix;

  static const String title = '아직 모르는 것이 있어 정리해 드릴 수 없어요';
  static const String body =
      '빠진 내용이 있어 기한과 비용을 계산하면 틀린 답이 나옵니다. 아래를 채워 주시면 바로 정리해 드립니다.';
  static const String noDetail = '무엇이 빠졌는지 확인하지 못했어요. 처음부터 다시 답해 주시겠어요?';
  static const String backToInterview = '인터뷰로 돌아가기';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return PageBody(
      bottom: PrimaryButton(
        label: backToInterview,
        where: 'NotReadyView.back',
        onPressed: () => onFix(
          missing.isEmpty ? '' : missing.first.questionId,
        ),
      ),
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.error_outline, size: 40, color: BeobaColors.red),
        const SizedBox(height: 16),
        SafeText(title, where: 'NotReadyView.title', style: theme.headlineSmall),
        const SizedBox(height: 10),
        SafeText(body, where: 'NotReadyView.body', style: theme.bodyLarge),
        const SizedBox(height: 20),
        if (missing.isEmpty)
          const NoticeBox(text: noDetail, where: 'NotReadyView.noDetail')
        else
          for (final block in missing)
            RedBlockView(block: block, onFix: onFix),
      ],
    );
  }
}
