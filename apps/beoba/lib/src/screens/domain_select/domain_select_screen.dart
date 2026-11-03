import 'package:domain_data/domain_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/domain_providers.dart';
import '../../providers/interview_providers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/line_icon.dart';
import '../bootstrap_gate.dart';

/// 분야 선택.
///
/// 지금은 "떼인 돈 받기" 하나뿐이다. 준비 중인 분야도 회색으로 보여 준다 —
/// 앞으로 늘어난다는 것을 알리기 위해서다.
class DomainSelectScreen extends ConsumerWidget {
  const DomainSelectScreen({
    this.showAllDomains = false,
    this.groupId,
    super.key,
  });

  /// 좁힌 목록을 무시하고 전부 본다. **사용자가 눌러서 온 것**이라
  /// 질의 문자열에 둔다 — 새로고침에도 살아남아야 맞다.
  final bool showAllDomains;

  /// 묶음 하나를 열었을 때 그 묶음의 id. 없으면 묶음 목록이다.
  final String? groupId;

  static const String title = '어떤 문제인가요?';
  static const String subtitle = '해당하는 것을 골라 주세요';
  static const String comingSoon = '준비 중';

  /// 묶음 목록의 부제.
  ///
  /// **「분류」라고 쓰지 않는다.** 고르는 사람은 자기 일을 떠올리지 우리
  /// 분류를 떠올리지 않는다.
  static const String groupSubtitle = '비슷한 일끼리 묶어 두었어요';

  /// 묶음 안에 든 분야가 몇 개인지. 눌러 보기 전에 안다.
  static String countLabel(int n) => '$n가지';

  /// 어느 묶음에도 안 든 분야. **사라지게 두지 않는다.**
  static const String looseTitle = '그 밖에';

  /// 자유 입력에서 둘 이상 걸렸을 때. **우리가 고르지 않는다.**
  static const String narrowedTitle = '둘 중 어느 쪽인가요?';
  static const String narrowedSubtitle = '적어주신 내용에 둘 다 들어 있어요.';
  static const String showAll = '둘 다 아니에요 — 전부 보기';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    // **라우터가 아니라 메모리에서 받는다.** `extra` 로 받으면 그 글이
    // 웹 브라우저 히스토리에 실려 있다는 뜻이 된다.
    final narrative = ref.read(pendingNarrativeProvider);

    return Scaffold(
      appBar: beobaAppBar(context),
      body: BootstrapGate(
        child: Consumer(
          builder: (context, ref, _) {
            final bundle = ref.watch(domainBundleProvider).requireValue;

            // **후보를 좁혀 온 경우.** 둘 이상 걸렸을 때만이다 — 하나면
            // 확인 카드로 가고 여기 오지 않는다.
            final detected = showAllDomains
                ? const <String>{}
                : {
                    for (final found in ref.watch(detectedDomainsProvider))
                      found.domainId,
                  };
            // ★ **묶음을 연 화면에서는 안 좁힌다.** 사용자가 묶음을 눌러
            // 들어왔는데 자유 입력에서 알아챈 둘만 보이면, 누른 것과 다른
            // 화면이 나온다.
            final narrowed = groupId == null && detected.length > 1;

            // ★ **묶음 목록은 아무것도 안 좁혔을 때만 선다.**
            //
            // 좁혀 온 사람에게 묶음을 보여 주면 이미 알아낸 것을 다시
            // 고르게 하는 셈이다. 그리고 묶음을 연 화면에서도 안 선다.
            final group = groupId == null
                ? null
                : bundle.groupCatalog.byId(groupId!);
            final showGroups = !narrowed && groupId == null;

            // **묶음 목록에는 분야 카드를 안 그린다.** 둘을 같이 그리면
            // 묶음이 무엇을 줄여 준 것인지 화면이 스스로 부정한다.
            final selectable = narrowed
                ? [
                    for (final domain in bundle.selectable)
                      if (detected.contains(domain.id)) domain,
                  ]
                : showGroups
                    ? const <Domain>[]
                    : bundle.domainsOf(groupId!);
            // 준비 중 분야는 묶음 목록에는 안 세운다 — 묶음 줄만 있는
            // 화면에 회색 카드가 섞이면 묶음이 몇 개인지 안 보인다.
            final upcoming = narrowed
                ? [
                    for (final domain in bundle.upcoming)
                      if (detected.contains(domain.id)) domain,
                  ]
                : showGroups
                    ? const <Domain>[]
                    : bundle.upcoming;

            return PageBody(
              children: [
                SafeText(
                  narrowed
                      ? narrowedTitle
                      : group?.name ?? title,
                  where: group == null
                      ? 'DomainSelectScreen.title'
                      : 'DomainGroup.name',
                  style: theme.headlineSmall,
                ),
                const SizedBox(height: 8),
                SafeText(
                  narrowed
                      ? narrowedSubtitle
                      : showGroups
                          ? groupSubtitle
                          : subtitle,
                  where: 'DomainSelectScreen.subtitle',
                  style: theme.bodyLarge,
                ),
                const SizedBox(height: 22),
                if (showGroups)
                  for (final (group, domains) in bundle.grouped)
                    if (group case final DomainGroup g)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: BeobaSpace.blockGap),
                        child: _GroupRow(
                          group: g,
                          count: domains.length,
                          onTap: () => context.push(Routes.domainGroup(g.id)),
                        ),
                      )
                    else
                      // 묶음이 없는 분야. **줄 뒤에 숨기지 않고 카드째 낸다** —
                      // 누르면 0건이 되는 입구를 세우지 않는 것과 같은 이유로,
                      // 눌러도 아무것도 없는 「그 밖에」 줄을 만들지 않는다.
                      for (final domain in domains)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: BeobaSpace.blockGap),
                          child: _DomainCard(
                            domain: domain,
                            onTap: () =>
                                _start(context, ref, domain.id, narrative),
                          ),
                        ),
                for (final domain in selectable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
                    child: _DomainCard(
                      domain: domain,
                      onTap: () => _start(context, ref, domain.id, narrative),
                    ),
                  ),
                for (final domain in upcoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: BeobaSpace.blockGap),
                    child: _UpcomingCard(
                      domain: domain,
                      // 회색 카드를 막다른 길로 두지 않는다. 우리가 못 하는
                      // 일이어도 어디로 가면 되는지는 말할 수 있다.
                      onTap: () => context.push(Routes.upcoming(domain.id)),
                    ),
                  ),
                // **좁힌 것이 틀릴 수 있다.** 나가는 문을 둔다.
                if (narrowed)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.push(
                        '${Routes.domains}?$kShowAllDomains',
                      ),
                      child: SafeText(
                        showAll,
                        where: 'DomainSelectScreen.showAll',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _start(
    BuildContext context,
    WidgetRef ref,
    String domainId,
    String narrative,
  ) =>
      startDomain(context, ref, domainId, narrative);
}

/// 분야 하나를 열기까지의 순서. **경보가 먼저다.**
///
/// 홈에서 알아채고 오든 목록에서 골라 오든 여기를 지난다. 순서를 한 곳에
/// 두지 않으면 한쪽 길에서만 경보가 빠진다.
///
/// ```
/// 세션 열기 → 하드스톱 → (알아챈 답이 있으면) 확인 카드 → 인터뷰
/// ```
///
/// 위기 신호는 라우터 가드가 이 뒤의 모든 경로에서 덮는다.
void startDomain(
  BuildContext context,
  WidgetRef ref,
  String domainId,
  String narrative, {
  Map<String, Object?> prefill = const {},
  bool confirmFirst = false,
}) {
  final controller = ref.read(interviewSessionProvider(domainId).notifier)
    ..start(narrative);

  // 자유 입력만으로 하드스톱이 걸릴 수 있다. **알아챈 것보다 먼저 본다.**
  final stops = ref.read(hardStopsProvider(domainId));
  if (stops.isNotEmpty) {
    final stop = stops.first;
    if (stop.needsConfirmation) {
      // 확인 화면은 되물을 뿐이다. 뒤로 나갈 수 있어야 한다.
      context.push(Routes.hardStopConfirm(domainId));
    } else {
      // 차단은 흐름의 끝이다. push 로 열면 브라우저·하드웨어 뒤로가기로 빠져나온다.
      context.go(Routes.hardStop(domainId));
    }
    return;
  }

  if (prefill.isNotEmpty) controller.prefill(prefill);
  context.push(
    confirmFirst ? Routes.detected(domainId) : Routes.interview(domainId),
  );
}

/// 분야 이름은 **두 층**이다(DECISIONS 194번).
///
/// ```
/// 큰 글씨   상황을 그리는 우리 말   「갑자기 나가라고 했을 때」
/// 작은 글씨 사람이 실제로 쓰는 말   「부당해고 · 권고사직 · 해고예고」
/// ```
///
/// 한 낱말로 둘을 다 하려 하면 따뜻하지도 않고 찾히지도 않는다. 작은 글씨는
/// 장식이 아니라 **찾는 말**이다.
class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain, required this.onTap});

  final Domain domain;
  final VoidCallback onTap;

  /// 화면에 내놓는 낱말 수. **나머지는 데이터에만 남는다.**
  ///
  /// 열 분야에 다섯 낱말씩 붙이면 홈이 안내가 아니라 목록이 된다.
  /// 안 보이는 낱말도 걸림말로는 전부 쓴다.
  // not-a-legal-number: 화면에 몇 개를 내놓느냐. 법률 수치가 아니다.
  static const int visibleTerms = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final description = domain.description;
    final terms = domain.searchTerms.take(visibleTerms).join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BeobaSpace.radius),
      child: SectionCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // **이모지를 뺐다(DECISIONS 286번).** 분야 줄은 이미 묶음 안이라 묶음
            // 그림을 되풀이하지 않는다. 이름과 걸림말이 글자로 있다.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeText(
                    domain.name,
                    where: 'Domain.name',
                    style: theme.titleMedium?.copyWith(
                      fontSize: 18,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SafeText(
                      description,
                      where: 'Domain.description',
                      style: theme.bodySmall,
                    ),
                  ],
                  if (terms.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    SafeText(
                      terms,
                      where: 'Domain.searchTerms',
                      style: theme.labelMedium?.copyWith(
                        color: BeobaColors.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: BeobaColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// 묶음 한 줄. **첫 화면에는 이것만 선다.**
///
/// ★ **분야 카드가 아니라 줄이다.** 카드는 설명과 걸림말까지 그려서 202px 인데
/// 줄은 67px 이다. 분야가 스물둘이 되면 카드 목록은 6.26화면이 되고 줄 목록은
/// 1화면 아래에 머문다 — **줄은 분야 수와 함께 늘지 않기 때문**이다.
///
/// 고르는 횟수는 한 번 는다. 대신 **첫 화면에서 전부 보인다.** 지금 목록은
/// 끝까지 보려면 네 번 넘겨야 하고, 그 사이에 자기 자리가 지나간다.
/// 그리고 아는 사람은 홈의 자유 입력으로 바로 간다 — 묶음은 모르는 사람의 길이다.
///
/// **몇 가지가 들었는지 함께 적는다.** 눌러 보기 전에 알아야 「눌렀는데 하나뿐」이
/// 안 된다.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.count,
    required this.onTap,
  });

  final DomainGroup group;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BeobaSpace.radius),
      child: SectionCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // 그림은 눈으로 찾는 표시다. 읽어 주지 않는다.
            // 이모지 대신 단색 선 아이콘 타일(DECISIONS 286번).
            ExcludeSemantics(child: IconTile(group.icon ?? '')),
            const SizedBox(width: 14),
            Expanded(
              child: SafeText(
                group.name,
                where: 'DomainGroup.name',
                style: theme.titleMedium?.copyWith(
                  fontSize: 18,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SafeText(
              DomainSelectScreen.countLabel(count),
              where: 'DomainSelectScreen.countLabel',
              style: theme.labelMedium?.copyWith(color: BeobaColors.ink3),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: BeobaColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// 준비 중 분야. **누를 수 있다.**
///
/// 아직 못 하는 일이지만 누르면 공적 창구를 안내한다. 회색 카드가 막다른 길이면
/// 사용자는 여기서 앱을 닫는다 — 차단 화면에 연결처를 넣은 것과 같은 이유다.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.domain, required this.onTap});

  final Domain domain;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BeobaSpace.radius),
      child: SectionCard(
        padding: const EdgeInsets.all(18),
        background: BeobaColors.surfaceSoft,
        child: Row(
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 26,
              color: BeobaColors.control,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SafeText(
                domain.name,
                where: 'Domain.name',
                style: theme.titleMedium?.copyWith(
                  fontSize: 18,
                  color: BeobaColors.ink2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BeobaColors.surfaceStrong,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SafeText(
                DomainSelectScreen.comingSoon,
                where: 'DomainSelectScreen.comingSoon',
                style: theme.labelSmall,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: BeobaColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
