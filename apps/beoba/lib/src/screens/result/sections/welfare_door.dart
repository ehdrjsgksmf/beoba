import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';

/// 분야 결과 맨 아래 **한 줄** — 법률에서 복지로 건너가는 자리.
///
/// ## 이 앱만 할 수 있는 자리다
///
/// 복지로는 사용자가 왜 왔는지 모른다. 우리는 안다 — 임금이 밀렸다는 것을
/// 이미 알고 있으니 그 사람에게 걸리는 제도를 바로 놓을 수 있다.
///
/// ## 그래서 더 조심한다
///
/// **조건 없는 약속을 하지 않는다.**
///
/// ```
/// ✘ 임금이 밀렸으면 실업급여도 됩니다
/// ⭕ 이런 제도들이 있고, 해당하는지는 그쪽에서 봅니다
/// ```
///
/// ## 카드가 아니라 줄이다
///
/// 처음엔 홈의 갈래 카드처럼 틴트 상자로 만들었더니 **0.14화면**이 늘었다.
/// 「빚 갚기가 어려울 때」가 4.006화면이라 남은 자리가 0.044뿐인데,
/// 그 자리를 만들려면 개인회생 대상 금액이나 면책 원칙 카드를 접어야 한다.
/// **그 둘은 스스로 자격이 없다고 판단하고 앱을 닫는 것을 막는 카드**라
/// 곁문 하나 만들자고 접을 수 없다(DECISIONS 134번의 순서 그대로다).
///
/// 그래서 링크 줄이다. 건수도 여기 안 적는다 — 적으려면 1.2MB 짜리 복지
/// 자료를 결과 화면에서 읽어야 하는데, **이 화면은 기한을 보는 화면**이다.
/// 건수와 범위는 건너간 뒤 목록 머리에서 말한다.
///
/// [Domain.welfareBridge] 가 없는 분야에는 이 줄이 아예 안 선다 —
/// 이을 근거가 없으면 입구도 없다.
class WelfareDoor extends StatelessWidget {
  const WelfareDoor({required this.domainId, super.key});

  final String domainId;

  /// **한 문장이다.** 형편을 먼저 말하고 묻는다.
  static const String label = '형편이 버거우시면 받을 수 있는 게 있는지 같이 볼까요?';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => context.push(Routes.welfare(domainId)),
      borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      child: Container(
        constraints: const BoxConstraints(minHeight: BeobaTapTarget.linkRow),
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.volunteer_activism_outlined,
              size: 17,
              color: BeobaColors.brand2,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SafeText(
                label,
                where: 'WelfareDoor.label',
                style: theme.labelLarge?.copyWith(
                  color: BeobaColors.brand2,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: BeobaColors.brand2,
            ),
          ],
        ),
      ),
    );
  }
}
