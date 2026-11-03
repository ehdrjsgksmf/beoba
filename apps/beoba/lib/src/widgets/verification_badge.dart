import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../safety/safe_text.dart';

/// 🟡 확인이 필요한 정보입니다.
///
/// `needs_check` 항목은 배지와 문구를 **항상 함께** 단다. 색만으로 알리지 않는다.
/// `unverified` 는 로더가 이미 제거하므로 여기까지 오지 않는다.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({required this.status, this.openPart, super.key});

  final VerificationStatus status;

  /// 항목의 **일부만** 확인 전일 때 그 조각의 이름.
  ///
  /// 「확인이 필요한 정보입니다」만 달면 확정된 부분까지 못 믿을 것으로 읽힌다.
  /// 송달료는 회차를 예규 원문으로 대조했는데 1회 금액 하나가 열려 있었다.
  /// 무엇이 열려 있는지 말해야 나머지를 믿을 수 있다.
  final String? openPart;

  static const String message = '확인이 필요한 정보입니다';

  /// 「확인이 필요한 정보입니다 — 1회 송달료 금액」
  static String messageFor(String? openPart) =>
      openPart == null || openPart.isEmpty ? message : '$message — $openPart';

  @override
  Widget build(BuildContext context) {
    if (status != VerificationStatus.needsCheck) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BeobaColors.amberSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.help_outline,
            size: 15,
            color: BeobaColors.legalMaybe,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: SafeText(
              messageFor(openPart),
              where: 'VerificationBadge.message',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: BeobaColors.legalMaybe,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
