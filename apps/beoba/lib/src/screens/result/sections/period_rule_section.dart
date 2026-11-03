import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';

/// 기간을 세는 법. 민법 157·159·160·161.
///
/// ## 왜 맨 아래인가
///
/// 3층 맨 위에 뒀더니 조문 네 줄이 화면 첫머리를 차지하고 **이 사건의 🟢 이 아래로
/// 밀렸다.** 결과를 보러 온 사람이 알고 싶은 것은 「언제까지 뭘 해야 하나」이지
/// 「기간은 어떻게 세는가」가 아니다.
///
/// 그렇다고 지우지는 않는다 — 이 앱이 내놓는 모든 날짜가 이 규칙에서 나오고,
/// **검산할 수 없는 숫자는 믿을 이유도 없다.** 궁금한 사람이 찾아올 수 있는 자리에
/// 둔다.
///
/// 🟢 다. 조문 원문 그대로이고 우리가 해석한 것이 하나도 없다.
class PeriodRuleSection extends StatelessWidget {
  const PeriodRuleSection({required this.rules, this.lastCoveredYear, super.key});

  final List<LegalBasis> rules;

  /// 쉬는 날 표를 **몇 년까지** 갖고 있는가. null 이면 표가 없다.
  final int? lastCoveredYear;

  static const String title = '날짜를 세는 법';

  /// 표가 있을 때. 공휴일도 민다.
  static const String intro = '이 화면의 모든 날짜는 아래 조문대로 셌어요. '
      '첫날은 세지 않고, 마지막 날이 토요일·일요일이나 쉬는 날이면 다음 평일로 밀려요.';

  /// 표가 없을 때. **조용히 토·일만 밀지 않는다.**
  static const String introWeekendOnly = '이 화면의 모든 날짜는 아래 조문대로 셌어요. '
      '첫날은 세지 않고, 마지막 날이 토요일이나 일요일이면 다음 평일로 밀려요.';

  /// 어디까지 반영했는지. **없는 것을 말하는 자리다.**
  ///
  /// 「2027년까지의 쉬는 날만 반영했어요. 그 뒤 날짜는 토요일·일요일만 넘겼으니,
  ///  실제 기한은 이 날짜보다 늦어질 수는 있어도 빨라지지는 않아요.」
  static String coverage(int year) => '$year년까지의 쉬는 날만 반영했어요. '
      '그 뒤 날짜는 토요일·일요일만 넘겼으니, 실제 기한은 이 날짜보다 '
      '늦어질 수는 있어도 빨라지지는 않아요.';

  /// **데이터를 넣은 뒤에도 남긴다.**
  ///
  /// 규정 제2조 제11호의 임시공휴일은 국무회의로 그때그때 정해져 **미래는
  /// 영영 모른다.** 이미 지정된 것은 표에 들어오지만, 우리가 표를 받은 시점
  /// 이후에 정해지는 것은 알 길이 없다.
  ///
  /// 안 민 쪽이 언제나 진짜 기한보다 앞이라 **늦지는 않는다.** 그래서 지금
  /// 상태로 내보내되, 사용자가 여유를 두도록 그 사실을 말한다.
  static const String caveat = '쉬는 날이 갑자기 생기면 기한이 하루 더 밀릴 수 있어요. '
      '실제 기한은 여기 적힌 날짜보다 늦어질 수는 있어도 빨라지지는 않으니, '
      '여유를 두고 준비하세요.';

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title, icon: Icons.calculate_outlined),
        SectionCard(
          background: BeobaColors.greenSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeText(
                lastCoveredYear == null ? introWeekendOnly : intro,
                where: 'PeriodRuleSection.intro',
                style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
              ),
              const SizedBox(height: 8),
              SafeText(
                lastCoveredYear == null
                    ? caveat
                    : '${coverage(lastCoveredYear!)} $caveat',
                where: 'PeriodRuleSection.caveat',
                style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
              ),
              const SizedBox(height: 12),
              for (final rule in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LegalBasisCard(
                    basis: rule,
                    where: 'Domain.periodRules',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
