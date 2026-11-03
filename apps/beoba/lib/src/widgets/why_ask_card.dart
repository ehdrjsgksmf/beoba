import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// 왜 묻나요?
///
/// **이게 제품의 차별점이다.** 다른 앱은 묻기만 하고 이유를 말하지 않는다.
/// `Question.whyAsk` 가 비면 도메인 검증기가 빌드를 세운다.
///
/// 위치는 선택지 아래, 다음 버튼 위. 툴팁이 아니라 답하기 직전 마지막으로 읽는 것이다.
///
/// 차별점이라고 해서 크게 그리지는 않는다 — 사용자가 답할 대상은 질문이다.
/// 물러나는 방법은 [BeobaWhyAsk] 에 적어 두었다.
class WhyAskCard extends StatelessWidget {
  const WhyAskCard({required this.whyAsk, super.key});

  final String whyAsk;

  static const String title = '왜 묻나요?';

  @override
  Widget build(BuildContext context) {
    if (whyAsk.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(left: 13),
      // 색면도 테두리도 없다. 왼쪽 선 하나로만 본문과 구분한다.
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: BeobaWhyAsk.accent,
            width: BeobaWhyAsk.accentWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            title,
            where: 'WhyAskCard.title',
            style: theme.labelSmall?.copyWith(
              fontSize: BeobaWhyAsk.titleSize,
              color: BeobaWhyAsk.titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SafeText(
            whyAsk,
            where: 'Question.whyAsk',
            style: theme.bodySmall?.copyWith(
              fontSize: BeobaWhyAsk.bodySize,
              color: BeobaWhyAsk.bodyColor,
              height: BeobaWhyAsk.bodyHeight,
            ),
          ),
        ],
      ),
    );
  }
}
