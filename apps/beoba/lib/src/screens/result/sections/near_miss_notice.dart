import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/section_card.dart';

/// 경계를 **아슬아슬하게** 넘겨 못 쓰게 된 절차를 알린다.
///
/// 3,000만원과 3,000만 10원은 밟는 절차가 다르다. 인지대 몇 백 원보다 이게 훨씬
/// 크다. **1,500원 때문에 더 복잡한 절차로 가야 한다는 걸 모르고 진행하면 나중에
/// 되돌릴 수 없다.**
///
/// 이건 유불리 판단이 아니다. 「이 절차는 쓸 수 없습니다」는 조건을 그대로 읽은
/// 사실이고, 어느 쪽이 나은지는 말하지 않는다.
class NearMissNotice extends StatelessWidget {
  const NearMissNotice({required this.misses, super.key});

  final List<NearMiss> misses;

  static const String headline = '경계를 조금 넘었어요';

  /// `「소액사건 소송」은 청구금액이 3,000만원 이하일 때 쓸 수 있어요.`
  ///
  /// 이름이 데이터에서 오므로 조사를 이어 붙일 수 없다. 받침을 보고 고른다.
  static String limitLine(NearMiss miss) =>
      '${withJosa('「${miss.label}」', Josa.topic)} 청구하신 금액이 '
      '${formatWon(miss.threshold)} 이하일 때 쓸 수 있어요.';

  /// `지금은 1,500원 넘어서 쓸 수 없어요.`
  static String excessLine(NearMiss miss) =>
      '지금은 ${formatWon(miss.excess)} 넘어서 쓸 수 없어요.';

  @override
  Widget build(BuildContext context) {
    if (misses.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: SectionCard(
        background: BeobaColors.amberSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 색만으로 알리지 않는다. 아이콘과 한글 라벨을 함께 단다.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.rule,
                  size: 17,
                  color: BeobaColors.severityWarning,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: SafeText(
                    headline,
                    where: 'NearMissNotice.headline',
                    style: theme.labelLarge?.copyWith(
                      color: BeobaColors.severityWarning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (final miss in misses) ...[
              SafeText(
                limitLine(miss),
                where: 'NearMissNotice.limit',
                style: theme.bodyMedium?.copyWith(color: BeobaColors.ink2),
              ),
              const SizedBox(height: 3),
              SafeText(
                excessLine(miss),
                where: 'NearMissNotice.excess',
                style: theme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
