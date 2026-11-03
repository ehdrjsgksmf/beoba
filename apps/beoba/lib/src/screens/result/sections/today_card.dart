import 'package:domain_data/domain_data.dart' show Procedure;
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/plain_title.dart';
import '../../../widgets/section_card.dart';
import 'deadline_section.dart';

/// 맨 위 한 장. **오늘 뭘 하면 되는지만 답한다.**
///
/// ## 무엇이 오늘 할 일인가
///
/// 기한이 걸려 있으면 그게 오늘 할 일이다 — 날짜가 정해져 있고 넘기면 되돌릴 수
/// 없다. 기한이 하나도 없으면 밟을 수 있는 절차의 **다음 한 칸**이 오늘 할 일이다.
///
/// ## 기한이 없다는 사실을 감추지 않는다
///
/// 지금 이 앱은 대부분의 사용자에게 기한을 하나도 못 보여준다(🔴 확인 목록 —
/// 소멸시효). 그래서 「지금 걸린 기한은 없어요」를 작은 한 줄로 남기고, 언제
/// 생기는지를 데이터가 준 말로 잇는다. **한 줄을 지우면 그 문제가 화면에서
/// 사라지고, 사라지면 아무도 안 고친다.**
///
/// 예전에는 그 자리가 큰 빈 카드였고 정작 쓸모 있는 비용이 맨 아래에 있었다.
/// 이제 이 카드는 기한이 없으면 줄어들고 비용 카드가 곧바로 온다 (DECISIONS 70).
class TodayCard extends StatefulWidget {
  const TodayCard({
    required this.deadlines,
    required this.appearsWhen,
    this.nextStep,
    this.onExplainPeriod,
    super.key,
  });

  /// 엔진이 급한 순으로 정렬해 준 것. 맨 앞이 가장 급하다.
  final List<DeadlineResult> deadlines;

  /// 아직 안 걸린 기한들이 언제 생기는지.
  final List<String> appearsWhen;

  /// 기한이 없을 때의 다음 한 칸.
  final Procedure? nextStep;

  final VoidCallback? onExplainPeriod;

  static const String title = '오늘 할 일';
  static const String due = '까지';
  static const String noStep = '지금 정보로는 무엇부터 할지 추리지 못했어요.';

  /// 「기한 2개 더 보기」 — 나머지 기한은 접어 둔다.
  static const String moreOpen = '다른 기한도 보기';
  static const String moreClose = '접기';

  @override
  State<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<TodayCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final deadlines = widget.deadlines;
    final top = deadlines.isEmpty ? null : deadlines.first;
    final rest = deadlines.length <= 1 ? const <DeadlineResult>[] : deadlines.sublist(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
      child: SectionCard(
        background: BeobaColors.brandSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 19,
                  color: BeobaColors.brand,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: SafeText(
                    TodayCard.title,
                    where: 'TodayCard.title',
                    style: theme.labelSmall?.copyWith(
                      color: BeobaColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (top != null) _DDayBadge(deadline: top),
              ],
            ),
            const SizedBox(height: 8),
            if (top != null)
              _TopDeadline(deadline: top)
            else
              _NextStep(procedure: widget.nextStep),
            const SizedBox(height: 10),
            // 기한이 없다는 사실과 언제 생기는지. 머리글은 카드가 이미 달았다.
            if (top == null)
              DeadlineSection(
                deadlines: const [],
                appearsWhen: widget.appearsWhen,
                showHeader: false,
              ),
            if (top != null && rest.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _open = !_open),
                  child: SafeText(
                    _open ? TodayCard.moreClose : TodayCard.moreOpen,
                    where: 'TodayCard.more',
                  ),
                ),
              ),
              if (_open)
                DeadlineSection(deadlines: rest, showHeader: false),
            ],
            // 버튼은 하나다. 검산할 수 없는 숫자는 믿을 이유도 없다.
            if (top != null && widget.onExplainPeriod != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onExplainPeriod,
                  child: SafeText(
                    DeadlineSection.explainPeriod,
                    where: 'DeadlineSection.explain',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 가장 급한 기한 하나. 이름과 날짜만. **자세한 것은 아래 카드에 있다.**
class _TopDeadline extends StatelessWidget {
  const _TopDeadline({required this.deadline});

  final DeadlineResult deadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    // 라벨이 금지어에 걸려도 날짜는 남긴다 (DECISIONS 26).
    final safeLabel = SafetyFilter.isSafe(deadline.label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (safeLabel)
          PlainTitle(
            label: deadline.label,
            whatIsThis: deadline.whatIsThis,
            where: 'DeadlineResult',
            titleStyle: theme.titleMedium?.copyWith(fontSize: 19),
          )
        else
          SafeText(
            DeadlineCard.labelBlocked,
            where: 'DeadlineCard.labelBlocked',
            style: theme.bodyMedium?.copyWith(color: BeobaColors.ink2),
          ),
        const SizedBox(height: 4),
        SafeText(
          '${formatDateRange(deadline.dueDate, deadline.dueDateLatest)}'
          '${TodayCard.due}',
          where: 'DeadlineResult.dueDate',
          style: theme.titleMedium?.copyWith(
            fontSize: 22,
            fontFeatures: kTabularFigures,
          ),
        ),
      ],
    );
  }
}

/// 기한이 없을 때의 다음 한 칸. **절차 전체는 아래 카드에 있다.**
class _NextStep extends StatelessWidget {
  const _NextStep({required this.procedure});

  final Procedure? procedure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final step = procedure;

    if (step == null) {
      return SafeText(
        TodayCard.noStep,
        where: 'TodayCard.noStep',
        style: theme.bodyMedium?.copyWith(color: BeobaColors.ink2),
      );
    }

    return PlainTitle(
      label: step.label,
      whatIsThis: step.whatIsThis,
      where: 'Procedure',
      titleStyle: theme.titleMedium?.copyWith(fontSize: 19),
    );
  }
}

/// D-day 뱃지. 숫자는 금지어에 걸릴 일이 없다.
class _DDayBadge extends StatelessWidget {
  const _DDayBadge({required this.deadline});

  final DeadlineResult deadline;

  Color get _color => switch (deadline.severity) {
        Severity.critical => BeobaColors.red,
        Severity.warning => BeobaColors.severityWarning,
        Severity.info => BeobaColors.ink3,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeText(
        formatDDay(deadline),
        where: 'DeadlineResult.dDay',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BeobaColors.bg,
              fontWeight: FontWeight.w800,
              fontFeatures: kTabularFigures,
            ),
      ),
    );
  }
}
