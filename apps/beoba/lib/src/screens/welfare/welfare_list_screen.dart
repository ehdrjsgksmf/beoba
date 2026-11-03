import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart' show SafetyScope;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/welfare_providers.dart';
import '../../safety/safe_text.dart';
import '../../welfare/welfare_match.dart';
import '../../widgets/agency_notice_line.dart';
import '../../widgets/expandable_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/today_pill.dart';
import 'welfare_chips.dart';

/// 찾아본 것. **두 층으로 그린다.**
///
/// ```
/// 자세한 내용까지 있는 것   지원대상 · 선정기준 · 지원내용 · 신청방법
/// 이름과 링크까지만 있는 것  이름 · 한 줄 요약 · 복지로 링크
/// ```
///
/// 아래쪽을 **숨기지 않는다.** 있는 제도인데 우리가 아직 상세를 못 받은
/// 것뿐이다. 숨기면 그 사람에게는 없는 제도가 되고, 우리 한도 사정이
/// 사용자의 손해로 바뀐다. 다만 **접어 둔다** — 265건이 펼쳐져 있으면
/// 목록이 아니라 벽이다.
///
/// **몇 건이 어느 쪽인지 화면에 적는다.** 「0건입니다」를 볼 때 무엇을
/// 세었는지 함께 봐야 한다 — 이 앱이 여러 번 배운 것이다.
///
/// ## 없는 축으로 나누지 않는다
///
/// 「종료 기간별」은 이 자료에 **없다.** 사업종료일은 민간 CSV 에만 있고
/// 그나마 2099-12-31 이 많다. 「기준연도별」도 대부분 2025~2026 이라
/// 갈리지 않는다. 있는 축만 쓴다 — 관심주제 · 온라인 신청 · 조회수.
///
/// 금액을 우리가 계산하지 않는다. 기관이 적어 둔 문장을 그대로 옮긴다.
class WelfareListScreen extends ConsumerWidget {
  const WelfareListScreen({this.fromDomainId, super.key});

  /// 어느 분야에서 건너왔는가. 그 분야의 다리로 목록이 좁혀져 있다.
  final String? fromDomainId;

  static const String title = '이런 제도들이 있어요';

  static const String detailedHead = '자세한 내용까지 있는 것';
  static const String listOnlyHead = '이름과 링크까지 있는 것';
  static const String listOnlyNote = '아직 자세한 내용을 다 못 받아 왔어요. '
      '없는 제도가 아니라, 복지로에서 이어서 보실 수 있어요.';

  /// 안 고르신 조건에 걸리는 것 — 접어 둔 묶음(DECISIONS 287번).
  static String foldedHead(int count) => '안 고르신 조건에 걸리는 것도 $count건 있어요';
  static const String foldedNote = '혹시 해당되실까 봐 없애지 않고 접어 두었어요.';

  static const String emptyTitle = '고르신 것으로는 아무것도 안 걸렸어요';
  static const String emptyBody = '고르신 것 중 하나를 빼면 더 보여드릴 수 있어요.';

  /// ★ **「좁힌다」도 「넓힌다」도 말하지 않는다**(DECISIONS 289번). 주제 칩은
  /// 처음 하나는 좁히고 둘째부터 넓힌다 — 움직임을 한 문장으로 정직하게 못 쓴다.
  /// 옛 「안 고르면 전부 보여드려요」는 가구상황을 접게 된 뒤(287) 거짓이었다.
  static const String narrowHead = '관심 있는 주제';
  static const String narrowNote = '관심 있는 주제만 골라 보세요. 안 고르셔도 괜찮아요.';

  /// **이 토글은 걷어내는 자리가 아니라 알려주는 자리다.**
  ///
  /// 461건 중 54건이다. 12%. 그러니 「절반이 줄어든다」가 아니라
  /// **「대부분은 직접 가야 한다」**가 이 줄이 말해야 하는 사실이다.
  /// 켜기 전에 두 숫자가 다 보이면 켜지 않아도 그 사실을 안다.
  static const String onlineLabel = '집에서 신청할 수 있는 것';

  /// 켠 뒤 목록 위에 붙는 한 줄. **기대를 먼저 맞춘다.**
  static const String onlineOnNote = '나머지는 주민센터나 해당 기관에 직접 가야 해요.';

  static const String sortNote = '복지로에서 많이 찾아본 순으로 놓았어요.';
  static const String sortNoteJobs = '일자리 제도를 앞에 두고, '
      '그다음은 복지로에서 많이 찾아본 순이에요.';

  static const String howWeRead = '이렇게 봤어요';
  static const String ourCall = '나이대는 태어난 해로 저희가 나눈 거예요. '
      '제도마다 기준이 달라서 걸치는 쪽은 넉넉히 잡았어요.';

  static const String openLink = '복지로에서 보기';
  static const String onlineBadge = '집에서 신청';

  static const String noAxisNote = '이 제도는 기관이 대상을 안 적어 뒀어요.';

  /// 분야에서 건너왔을 때 목록 머리에 붙는 줄.
  ///
  /// ★ **좁혀 둔 것을 풀 수 있어야 한다.** 우리가 고른 것이 그 사람의
  /// 전부는 아니다. 몇 건 중 몇 건인지 적고 옆에 푸는 길을 둔다.
  static const String bridgeAll = '전체 목록도 보기';

  /// 목록 맨 아래. **반대 방향의 한 줄이다.**
  ///
  /// 복지 쪽으로 들어온 분에게도 법률 쪽 입구가 있어야 한다. 다만
  /// **조건 없는 약속을 하지 않는다** — 「이런 일이 있으셨다면」까지다.
  static const String toLegalLead = '이런 일이 있으셨다면';
  static const String toLegal = '어떤 일이 있었는지 보고 같이 찾아볼까요?';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(welfareMatchProvider(fromDomainId));
    final loaded = ref.watch(welfareCatalogProvider);

    return Scaffold(
      appBar: beobaAppBar(context),
      body: match == null || !loaded.hasValue
          ? const Center(child: CircularProgressIndicator())
          : _Body(
              match: match,
              catalog: loaded.requireValue,
              fromDomainId: fromDomainId,
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.match,
    required this.catalog,
    required this.fromDomainId,
  });

  final WelfareMatch match;
  final CentralWelfareCatalog catalog;
  final String? fromDomainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final answers = ref.watch(welfareAnswersProvider);
    final controller = ref.read(welfareAnswersProvider.notifier);

    return PageBody(
      children: [
        SafeText(
          WelfareListScreen.title,
          where: 'WelfareListScreen.title',
          style: theme.headlineSmall,
        ),
        const SizedBox(height: 12),

        // **무엇을 세었는지 먼저 말한다.**
        _CountLine(match: match),
        const SizedBox(height: 12),

        // 네 번째 층의 딱지. 이 목록 전체가 기관 안내문이다.
        AgencyNoticeLine.forCatalog(catalog: catalog),

        if (match.bridgeCount != null) ...[
          const SizedBox(height: 12),
          _BridgeNote(match: match),
        ],
        const SizedBox(height: 18),

        // ── 좁히기 ────────────────────────────────────────────────
        SafeText(
          WelfareListScreen.narrowHead,
          where: 'WelfareListScreen.narrowHead',
          style: theme.labelLarge?.copyWith(
            color: BeobaColors.ink3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        SafeText(
          WelfareListScreen.narrowNote,
          where: 'WelfareListScreen.narrowNote',
          style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
        ),
        const SizedBox(height: 10),
        WelfareChipRow(
          // **0건짜리 칩을 안 만든다.** 자료에 있는 열다섯을 다 늘어놓으면
          // 눌러도 아무것도 안 나오는 칸이 생긴다.
          names: match.topicCounts.keys.toList()
            ..sort((a, b) => match.topicCounts[b]! - match.topicCounts[a]!),
          counts: match.topicCounts,
          picked: answers.topics,
          where: 'CentralWelfareService.topics',
          onToggle: controller.toggleTopic,
        ),
        const SizedBox(height: 12),
        _OnlineToggle(
          on: answers.onlineOnly,
          count: match.onlineCount,
          total: match.onAxesCount,
          onChanged: controller.setOnlineOnly,
        ),
        if (answers.onlineOnly) ...[
          const SizedBox(height: 8),
          SafeText(
            WelfareListScreen.onlineOnNote,
            where: 'WelfareListScreen.onlineOnNote',
            style: theme.labelSmall?.copyWith(
              color: BeobaColors.ink3,
              height: 1.55,
            ),
          ),
        ],
        const SizedBox(height: 16),

        _HowWeRead(match: match, answers: answers),
        const SizedBox(height: 20),

        if (match.matched == 0) const _Empty(),

        if (match.detailed.isNotEmpty) ...[
          _Head(
            label: WelfareListScreen.detailedHead,
            count: match.detailed.length,
            where: 'WelfareListScreen.detailedHead',
          ),
          const SizedBox(height: 6),
          // **무엇으로 세웠는지 적는다.** 안 적으면 왜 이 순서인지 모른다.
          SafeText(
            answers.work == WelfareWork.notWorking
                ? WelfareListScreen.sortNoteJobs
                : WelfareListScreen.sortNote,
            where: 'WelfareListScreen.sortNote',
            style: theme.labelSmall?.copyWith(
              color: BeobaColors.ink3,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          for (final service in match.detailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DetailedCard(service: service),
            ),
          const SizedBox(height: 20),
        ],

        // ── 두 번째 묶음. **접어 둔다** ────────────────────────────
        if (match.listOnly.isNotEmpty)
          ExpandableCard(
            title: WelfareListScreen.listOnlyHead,
            where: 'WelfareListScreen.listOnlyHead',
            icon: Icons.more_horiz,
            summary: SafeText(
              '${match.listOnly.length}건. ${WelfareListScreen.listOnlyNote}',
              where: 'WelfareListScreen.listOnlyNote',
              style: theme.labelMedium?.copyWith(height: 1.55),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final service in match.listOnly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StubRow(service: service),
                  ),
              ],
            ),
          ),

        // ── 안 고르신 조건에 걸리는 것. **없애지 않고 접는다** ─────────
        //
        // 조건을 잘못 고르셨을 수도 있다. 성가신 것과 못 받는 것 중에 못 받는
        // 쪽이 훨씬 나쁘다(DECISIONS 287번).
        if (match.folded.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExpandableCard(
            title: WelfareListScreen.foldedHead(match.folded.length),
            where: 'WelfareListScreen.foldedHead',
            icon: Icons.unfold_more,
            summary: SafeText(
              WelfareListScreen.foldedNote,
              where: 'WelfareListScreen.foldedNote',
              style: theme.labelMedium?.copyWith(height: 1.55),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final service in match.folded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: service.detailFetched
                        ? _DetailedCard(service: service)
                        : _StubRow(service: service),
                  ),
              ],
            ),
          ),
        ],

        // ── 반대 방향의 한 줄 ─────────────────────────────────────
        const SizedBox(height: 26),
        const Divider(color: BeobaColors.line2, height: 1),
        const SizedBox(height: 20),
        const _ToLegal(),
      ],
    );
  }
}

/// 「분야에서 건너오셨네요」 — 좁혀 둔 것을 밝히고 푸는 길을 준다.
///
/// **우리가 고른 것이 그 사람의 전부는 아니다.** 몇 건 중 몇 건인지 적고
/// 옆에 전체로 가는 길을 둔다. 안 적으면 「이것뿐이구나」로 읽힌다.
class _BridgeNote extends StatelessWidget {
  const _BridgeNote({required this.match});

  final WelfareMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BeobaColors.surfaceStrong,
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            '지금 보고 계신 건 근거 법이 같은 ${match.bridgeCount}건이에요. '
            '자료 전체는 ${match.total}건이에요.',
            where: 'WelfareListScreen.bridgeNote',
            style: theme.labelMedium?.copyWith(height: 1.55),
          ),
          InkWell(
            onTap: () => context.go(Routes.welfareList()),
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: BeobaTapTarget.minimum),
              alignment: Alignment.centerLeft,
              child: SafeText(
                WelfareListScreen.bridgeAll,
                where: 'WelfareListScreen.bridgeAll',
                style: theme.labelLarge?.copyWith(
                  color: BeobaColors.brand2,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 목록 맨 아래 한 줄. **반대 방향이다.**
///
/// 복지 쪽으로 들어온 분에게도 법률 쪽 입구가 있어야 한다.
/// **조건 없는 약속을 하지 않는다** — 「이런 일이 있으셨다면」까지다.
class _ToLegal extends StatelessWidget {
  const _ToLegal();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => context.go(Routes.domains),
      borderRadius: BorderRadius.circular(BeobaSpace.radius),
      child: Container(
        constraints: const BoxConstraints(minHeight: BeobaTapTarget.choice),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: BeobaColors.card,
          borderRadius: BorderRadius.circular(BeobaSpace.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.gavel_outlined,
                size: 19,
                color: BeobaColors.brand2,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeText(
                    WelfareListScreen.toLegalLead,
                    where: 'WelfareListScreen.toLegalLead',
                    style: theme.labelMedium?.copyWith(
                      color: BeobaColors.brand2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SafeText(
                    WelfareListScreen.toLegal,
                    where: 'WelfareListScreen.toLegal',
                    style: theme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: BeobaColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 몇 건을 무엇에서 세었는가. **한 값에서 나온다** — 목록과 따로 세지 않는다.
class _CountLine extends StatelessWidget {
  const _CountLine({required this.match});

  final WelfareMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SectionCard(
      background: BeobaColors.brandSoft,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ★ 물음 화면과 **같은 줄**이다. 옛 「전체 461건 가운데 182건이
          // 걸렸어요」는 접힌 279건도 걸린 것이라 뜻이 흐렸다(DECISIONS 289번).
          WelfareSplitLine(
            first: match.matched,
            folded: match.folded.length,
            style: theme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: BeobaColors.brandInk,
            ),
          ),
          const SizedBox(height: 5),
          SafeText(
            '자세한 내용까지 있는 것 ${match.detailed.length}건 · '
            '이름과 링크까지 ${match.listOnly.length}건.',
            where: 'WelfareListScreen.countSplit',
            style: theme.labelMedium?.copyWith(color: BeobaColors.brandInk),
          ),
        ],
      ),
    );
  }
}

/// 집에서 신청할 수 있는 것만 보기.
class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle({
    required this.on,
    required this.count,
    required this.total,
    required this.onChanged,
  });

  final bool on;
  final int count;

  /// 켜기 전의 건수. **두 숫자를 나란히 낸다** — 12%라는 사실이
  /// 누르지 않아도 보여야 한다.
  final int total;

  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Semantics(
      toggled: on,
      button: true,
      child: InkWell(
        onTap: () => onChanged(!on),
        borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
        child: Container(
          constraints: const BoxConstraints(minHeight: BeobaTapTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: on ? BeobaColors.brandSoft : BeobaColors.surfaceStrong,
            borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
          ),
          foregroundDecoration: on
              ? BoxDecoration(
                  border: Border.all(color: BeobaColors.brand, width: 2),
                  borderRadius: BorderRadius.circular(BeobaSpace.radiusInner),
                )
              : null,
          child: Row(
            children: [
              Icon(
                on ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                size: 19,
                color: on ? BeobaColors.brand : BeobaColors.control,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SafeText(
                  WelfareListScreen.onlineLabel,
                  where: 'WelfareListScreen.onlineLabel',
                  style: theme.bodyMedium?.copyWith(
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    color: on ? BeobaColors.brand : BeobaColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SafeText(
                '$count / $total',
                where: 'WelfareListScreen.onlineCount',
                style: theme.labelMedium?.copyWith(color: BeobaColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 우리가 어떤 축으로 좁혔는지. **우리 판단인 것을 우리 판단이라고 적는다.**
class _HowWeRead extends StatelessWidget {
  const _HowWeRead({required this.match, required this.answers});

  final WelfareMatch match;
  final WelfareAnswers answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final picked = [...match.lifeStages, ...answers.households];
    if (picked.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeText(
          WelfareListScreen.howWeRead,
          where: 'WelfareListScreen.howWeRead',
          style: theme.labelLarge?.copyWith(
            color: BeobaColors.ink3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in picked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: BeobaColors.surfaceStrong,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SafeText(
                  name,
                  where: 'WelfareMatch.axis',
                  scope: SafetyScope.quote,
                  style: theme.labelSmall?.copyWith(color: BeobaColors.ink2),
                ),
              ),
          ],
        ),
        if (match.lifeStages.isNotEmpty) ...[
          const SizedBox(height: 8),
          SafeText(
            WelfareListScreen.ourCall,
            where: 'WelfareListScreen.ourCall',
            style: theme.labelSmall?.copyWith(
              color: BeobaColors.ink3,
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({
    required this.label,
    required this.count,
    required this.where,
  });

  final String label;
  final int count;
  final String where;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: SafeText(label, where: where, style: theme.titleMedium),
        ),
        const SizedBox(width: 8),
        SafeText(
          '$count건',
          where: '$where.count',
          style: theme.titleMedium?.copyWith(color: BeobaColors.ink3),
        ),
      ],
    );
  }
}

/// 상세까지 있는 한 건.
///
/// **접힌 채로도 제목 · 한 줄 요약 · 부처 이름이 보인다.** 제목만 보이면
/// 열어 보기 전에는 뭔지 알 수 없어서 스물몇 장을 다 열어 봐야 한다.
class _DetailedCard extends StatelessWidget {
  const _DetailedCard({required this.service});

  final CentralWelfareService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ExpandableCard(
      title: service.name,
      where: 'CentralWelfareService.name',
      icon: Icons.volunteer_activism_outlined,
      summary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (service.summary.isNotEmpty)
            SafeText(
              service.summary,
              where: 'CentralWelfareService.summary',
              scope: SafetyScope.quote,
              style: theme.labelMedium?.copyWith(height: 1.55),
            ),
          const SizedBox(height: 7),
          _CardFoot(service: service),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(label: _Field.target, body: service.target, field: 'target'),
          _Field(
            label: _Field.criteria,
            body: service.criteria,
            field: 'criteria',
          ),
          _Field(
            label: _Field.benefit,
            body: service.benefit,
            field: 'benefit',
          ),
          _Links(label: _Field.howToApply, links: service.howToApply),
          _Links(label: _Field.inquiries, links: service.inquiries),
          if (service.url.isNotEmpty) _OpenLink(url: service.url),
          const SizedBox(height: 12),
          // 건마다 알려 준 기관이 다르다. **그 이름은 이 자리에서만 나온다.**
          AgencyNoticeLine(notice: service.notice),
          if (service.unstatedAxes.isNotEmpty) ...[
            const SizedBox(height: 8),
            SafeText(
              WelfareListScreen.noAxisNote,
              where: 'WelfareListScreen.noAxisNote',
              style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 밑줄 — 부처 이름과 「집에서 신청」 딱지.
class _CardFoot extends StatelessWidget {
  const _CardFoot({required this.service});

  final CentralWelfareService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (service.ministry.isNotEmpty)
          SafeText(
            service.ministry,
            where: 'CentralWelfareService.ministry',
            scope: SafetyScope.quote,
            style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
          ),
        if (service.onlineApply)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: BeobaColors.greenSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SafeText(
              WelfareListScreen.onlineBadge,
              where: 'WelfareListScreen.onlineBadge',
              style: theme.labelSmall?.copyWith(
                color: BeobaColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// 이름과 링크까지만 있는 한 줄. **지운 것이 아니라 아직 안 받은 것이다.**
class _StubRow extends StatelessWidget {
  const _StubRow({required this.service});

  final CentralWelfareService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            service.name,
            where: 'CentralWelfareService.name',
            scope: SafetyScope.quote,
            style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (service.summary.isNotEmpty) ...[
            const SizedBox(height: 5),
            SafeText(
              service.summary,
              where: 'CentralWelfareService.summary',
              scope: SafetyScope.quote,
              style: theme.labelMedium?.copyWith(height: 1.55),
            ),
          ],
          const SizedBox(height: 7),
          _CardFoot(service: service),
          if (service.url.isNotEmpty) _OpenLink(url: service.url),
          const SizedBox(height: 8),
          AgencyNoticeLine(notice: service.notice),
        ],
      ),
    );
  }
}

/// 한 칸. 비어 있으면 그리지 않는다 — 빈 제목만 남기지 않는다.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.body,
    required this.field,
  });

  static const String target = '누가 받을 수 있나요';
  static const String criteria = '어떤 기준으로 정하나요';
  static const String benefit = '무엇을 받나요';
  static const String howToApply = '어떻게 신청하나요';
  static const String inquiries = '어디에 물어보나요';

  final String label;
  final String body;
  final String field;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            label,
            where: 'WelfareListScreen.fieldLabel',
            style: theme.labelLarge?.copyWith(
              color: BeobaColors.ink3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          SafeText(
            body,
            where: 'CentralWelfareService.$field',
            scope: SafetyScope.quote,
            style: theme.bodyMedium?.copyWith(height: 1.62),
          ),
        ],
      ),
    );
  }
}

/// 신청방법·문의처 줄. **`servSeDetailLink` 에는 주소가 아닌 것도 온다** —
/// 전화번호가 오기도 하고 문장 하나가 오기도 한다. 그래서 눌러서 여는 것은
/// 주소일 때뿐이다.
class _Links extends StatelessWidget {
  const _Links({required this.label, required this.links});

  final String label;
  final List<WelfareLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            label,
            where: 'WelfareListScreen.fieldLabel',
            style: theme.labelLarge?.copyWith(
              color: BeobaColors.ink3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SafeText(
                link.name.isEmpty ? link.value : '${link.name} — ${link.value}',
                where: 'WelfareLink.value',
                scope: SafetyScope.quote,
                style: theme.bodyMedium?.copyWith(height: 1.55),
              ),
            ),
        ],
      ),
    );
  }
}

/// 복지로 상세로 나가는 줄.
class _OpenLink extends StatelessWidget {
  const _OpenLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () async {
        await launchUrl(Uri.parse(url)).catchError((_) => false);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: BeobaTapTarget.linkRow),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: BeobaColors.brand2,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: SafeText(
                WelfareListScreen.openLink,
                where: 'WelfareListScreen.openLink',
                style: theme.labelLarge?.copyWith(
                  color: BeobaColors.brand2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하나도 안 걸렸을 때. **막다른 골목으로 두지 않는다.**
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeText(
            WelfareListScreen.emptyTitle,
            where: 'WelfareListScreen.emptyTitle',
            style: theme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SafeText(
            WelfareListScreen.emptyBody,
            where: 'WelfareListScreen.emptyBody',
            style: theme.bodyMedium?.copyWith(
              color: BeobaColors.ink2,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
