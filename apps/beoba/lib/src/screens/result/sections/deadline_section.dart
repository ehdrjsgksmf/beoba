import 'package:engines/engines.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../format/formatters.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/plain_title.dart';
import '../../../widgets/legal_basis_card.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/verification_badge.dart';

/// 기한 목록. 엔진이 정렬까지 끝낸 것을 그대로 그린다.
class DeadlineSection extends StatelessWidget {
  const DeadlineSection({
    required this.deadlines,
    this.appearsWhen = const [],
    this.onExplainPeriod,
    this.showHeader = true,
    super.key,
  });

  final List<DeadlineResult> deadlines;

  /// 아직 안 걸린 기한들이 **언제 생기는지.** 데이터가 준 말이다.
  final List<String> appearsWhen;

  /// 「이 날짜는 어떻게 셌나요?」 를 누르면 갈 곳. 없으면 링크를 안 그린다.
  final VoidCallback? onExplainPeriod;

  /// 「기한」 머리글을 그릴지. **오늘 할 일 카드 안에 들어갈 때는 끈다** —
  /// 카드가 이미 제목을 달고 있어 머리글이 둘이 되면 카드 하나가 두 장으로 보인다.
  final bool showHeader;

  static const String title = '기한';
  static const String empty = '지금 걸린 기한은 없어요.';
  static const String emptyWhen = '이런 때에 기한이 생겨요';
  static const String emptyNone = '이 분야에서 걸릴 수 있는 기한이 아직 정리되지 않았어요.';

  /// 검산할 수 없는 숫자는 믿을 이유도 없다. 규칙을 볼 길은 열어 둔다.
  static const String explainPeriod = '이 날짜는 어떻게 셌나요?';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) const SectionHeader(title, icon: Icons.event_outlined),
        if (deadlines.isEmpty)
          _EmptyState(appearsWhen: appearsWhen)
        else
          for (final deadline in deadlines)
            Padding(
              padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
              child: DeadlineCard(deadline: deadline),
            ),
        if (deadlines.isNotEmpty && onExplainPeriod != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onExplainPeriod,
              child: SafeText(explainPeriod, where: 'DeadlineSection.explain'),
            ),
          ),
      ],
    );
  }
}

/// 기한 하나.
///
/// **critical 기한은 어떤 경우에도 숨기지 않는다.** 라벨이 SafetyFilter 에 걸려도
/// 날짜 · D-day · 근거 조문은 그대로 남긴다. 문구 하나 지키자고 사용자가
/// 지급명령 이의신청 2주를 놓치게 할 수는 없다.
class DeadlineCard extends StatelessWidget {
  const DeadlineCard({required this.deadline, super.key});

  final DeadlineResult deadline;

  /// critical 인데 라벨을 못 그릴 때 그 자리에 놓는 말.
  static const String labelBlocked = '이 항목의 설명을 보여드릴 수 없어요. 아래 근거 조문을 확인해 주세요.';

  static const String rolledPrefix = '원래 ';
  static const String rolledSuffix = '인데 그날이 쉬는 날이라 다음 평일로 밀렸어요.';

  /// 「원래 2026년 8월 29일인데 그날이 쉬는 날이라 다음 평일로 밀렸어요.」
  static String _rolledNote(KstDate from) =>
      '$rolledPrefix${formatKstDate(from)}$rolledSuffix';

  bool get _isCritical => deadline.severity == Severity.critical;

  /// 라벨이 금지어에 걸리는가. 걸려도 기한 자체는 그린다.
  bool get _labelBlocked => !SafetyFilter.isSafe(deadline.label);

  (Color, IconData, String) get _severityStyle => switch (deadline.severity) {
        Severity.critical => (BeobaColors.red, Icons.priority_high, '꼭 지켜야 합니다'),
        Severity.warning => (
            BeobaColors.severityWarning,
            Icons.schedule,
            '주의하세요',
          ),
        Severity.info => (BeobaColors.ink3, Icons.info_outline, '참고하세요'),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final (color, icon, severityLabel) = _severityStyle;

    return SectionCard(
      background: _isCritical ? BeobaColors.redSoft : BeobaColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 색만으로 심각도를 전하지 않는다. 아이콘과 한글 라벨을 함께 단다.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              SafeText(
                severityLabel,
                where: 'DeadlineCard.severity',
                style: theme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_labelBlocked && _isCritical)
            SafeText(
              labelBlocked,
              where: 'DeadlineCard.labelBlocked',
              style: theme.bodyMedium?.copyWith(color: BeobaColors.ink2),
            )
          else
            PlainTitle(
              label: deadline.label,
              whatIsThis: deadline.whatIsThis,
              where: 'DeadlineResult',
              titleStyle: theme.titleMedium?.copyWith(fontSize: 18),
            ),
          const SizedBox(height: 10),
          _DueRow(deadline: deadline, color: color),
          // 기산일이 어림이면 **날짜를 단정하지 않는다.** 확신에 찬 거짓이
          // 가장 나쁜 결과다. 심각도는 낮추지 않는다 — 심각도는 결과의 무게이지
          // 확실성이 아니다.
          if (deadline.isApproximate) ...[
            const SizedBox(height: 10),
            const _ApproximateNote(),
          ],
          // 아무 설명 없이 날짜만 밀리면 사용자는 계산이 틀렸다고 생각한다.
          if (deadline.rolledFrom case final KstDate from) ...[
            const SizedBox(height: 8),
            SafeText(
              _rolledNote(from),
              where: 'DeadlineCard.rolled',
              style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
            ),
          ],
          const SizedBox(height: 12),
          LegalBasisCard(
            basis: deadline.basis,
            where: 'Deadline.${deadline.id}',
          ),
          // 기간이 든 조문과 **그 기간을 늘려주지 않는다는 조문**이 갈라져
          // 있는 자리가 있다. 하나만 보여주면 「사정을 말하면 되겠지」가
          // 그대로 남는다(DECISIONS 160번).
          for (final (index, also) in deadline.alsoBasis.indexed) ...[
            const SizedBox(height: 10),
            LegalBasisCard(
              basis: also,
              where: 'Deadline.${deadline.id}.also$index',
            ),
          ],
          VerificationBadge(status: deadline.verification),
        ],
      ),
    );
  }
}

/// 날짜와 D-day. 숫자는 금지어에 걸릴 일이 없으므로 언제나 보인다.
class _DueRow extends StatelessWidget {
  const _DueRow({required this.deadline, required this.color});

  final DeadlineResult deadline;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SafeText(
          formatDateRange(deadline.dueDate, deadline.dueDateLatest),
          where: 'DeadlineResult.dueDate',
          style: theme.titleMedium?.copyWith(
            fontSize: 17,
            fontFeatures: kTabularFigures,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeText(
            formatDDay(deadline),
            where: 'DeadlineResult.dDay',
            style: theme.labelSmall?.copyWith(
              color: BeobaColors.bg,
              fontWeight: FontWeight.w800,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
      ],
    );
  }
}

/// 기산일이 어림이라 기한이 범위로만 나온다는 알림.
///
/// **색만으로 알리지 않는다** — 아이콘 · 한글 문장 · 색을 함께 쓴다.
/// 3층의 🟡 과 같은 뜻이라 같은 토큰(`legalMaybe`)을 쓴다.
class _ApproximateNote extends StatelessWidget {
  const _ApproximateNote();

  static const String headline = '이 기한은 범위로만 알 수 있어요';
  static const String body = '정확한 날짜를 아직 모르셔서 기한도 범위로 나와요. '
      '가장 이른 날에 맞춰 두시면 이 범위 어느 날짜여도 넘기지 않아요.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: BeobaColors.amberSoft,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.help_outline,
                size: 16,
                color: BeobaColors.legalMaybe,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: SafeText(
                  headline,
                  where: 'DeadlineCard.approximate',
                  style: theme.labelSmall?.copyWith(
                    color: BeobaColors.legalMaybe,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SafeText(
            body,
            where: 'DeadlineCard.approximateBody',
            style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
          ),
        ],
      ),
    );
  }
}

/// 기한이 하나도 안 걸렸을 때.
///
/// **동작은 정상이다** — 법원 서류를 안 받았으면 답변서 기한이 안 걸린다.
/// 문제는 빈 화면이 **실패처럼 보인다**는 것이다. 그래서 왜 없는지와 언제
/// 생기는지를 말한다. 말은 데이터가 준다 (`Deadline.appearsWhen`).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.appearsWhen});

  final List<String> appearsWhen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    if (appearsWhen.isEmpty) {
      return const NoticeBox(
        text: DeadlineSection.emptyNone,
        where: 'DeadlineSection.emptyNone',
      );
    }

    return SectionCard(
      background: BeobaColors.surfaceSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            DeadlineSection.empty,
            where: 'DeadlineSection.empty',
            style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SafeText(
            DeadlineSection.emptyWhen,
            where: 'DeadlineSection.emptyWhen',
            style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
          ),
          const SizedBox(height: 6),
          for (final line in appearsWhen)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 5, color: BeobaColors.ink3),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SafeText(
                      line,
                      where: 'Deadline.appearsWhen',
                      style: theme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
