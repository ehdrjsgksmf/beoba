import 'package:domain_data/domain_data.dart'
    show FeeSchedule, Procedure, ProcedureStage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../providers/result_providers.dart';
import '../../../safety/safe_text.dart';
import '../../../widgets/crisis_channels.dart';
import '../../../widgets/fee_schedule_view.dart';
import '../../../widgets/section_card.dart';

/// 갈림길 — **어느 쪽을 보고 싶은지**만 묻는다.
///
/// ## 왜 이 자리에 있는가
///
/// 결과 화면이 「지급명령이냐 소송이냐」로만 갈려 있으면 나홀로소송 안내서로
/// 읽힌다. 실제 사다리는 그보다 앞에서 시작한다 — 요구하고 증거 남기기 ·
/// 내용증명 · 공정증서가 법원 앞에 있다.
///
/// ## 세 번째가 있어야 한다
///
/// 둘만 두면 **아직 못 정한 사람이 갈 곳이 없다.** 그 사람이 이 앱에 제일
/// 많이 온다. 세 번째는 창구로 보내고 「지금 정하지 않아도 됩니다」라고 말한다.
///
/// ## 하지 않는 것
///
/// - 순서를 권하지 않는다. 「먼저 내용증명, 안 되면 조정」은 그 사건에 대한
///   판단이다 (72번 · 75번과 같은 자리).
/// - 고른 갈래에 따라 **다른 갈래를 감추지 않는다.** 되돌아올 수 있어야 한다.
/// - 재촉하지 않는다. 「빨리 정하세요」는 우리가 할 말이 아니다.
class CrossroadsSection extends ConsumerStatefulWidget {
  const CrossroadsSection({required this.domainId, super.key});

  final String domainId;

  static const String title = '어느 쪽을 보고 싶으세요?';

  /// 「법적조치」라고 쓰지 않는다. 내용증명도 공증도 조정도 전부 법적 절차라
  /// 정확하지 않고, 무겁게 들린다.
  static const String beforeCourt = '법원까지 가기 전에 할 수 있는 걸 보고 싶어요';
  static const String court = '법원을 거치는 방법을 보고 싶어요';
  static const String unsure = '아직 잘 모르겠어요 — 먼저 물어볼 곳을 알려주세요';

  static const String noRush = '지금 정하지 않아도 됩니다.';

  /// **이 앱이 처음부터 약속한 것.**
  ///
  /// 소멸시효 값이 오면 여기에 날짜가 들어간다. 지금은 값이 없어서 기간이
  /// 있다는 사실까지만 말한다 (🔴 확인 목록 — 소멸시효).
  static const String deadlineHint =
      '다만 언제까지 정해야 하는지는 알아두세요. 돈을 받을 수 있는 기간이 법으로 정해져 있어요. '
      '얼마인지는 아래 창구에서 확인해 보세요.';

  static const String empty = '지금 정보로는 절차를 추릴 수 없어요.';

  @override
  ConsumerState<CrossroadsSection> createState() => _CrossroadsSectionState();
}

class _CrossroadsSectionState extends ConsumerState<CrossroadsSection> {
  /// 펼친 갈래들. **하나를 열어도 나머지는 그대로 있다.**
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final procedures = ref.watch(proceduresProvider(widget.domainId));
    if (procedures.isEmpty) return const SizedBox.shrink();

    final before = [
      for (final p in procedures)
        if (p.stage == ProcedureStage.beforeCourt) p,
    ];
    final court = [
      for (final p in procedures)
        if (p.stage == ProcedureStage.court) p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          CrossroadsSection.title,
          icon: Icons.call_split_outlined,
        ),
        _Choice(
          label: CrossroadsSection.beforeCourt,
          open: _open.contains('before'),
          onTap: () => _toggle('before'),
          child: _Steps(procedures: before),
        ),
        _Choice(
          label: CrossroadsSection.court,
          open: _open.contains('court'),
          onTap: () => _toggle('court'),
          child: _Steps(procedures: court),
        ),
        _Choice(
          label: CrossroadsSection.unsure,
          open: _open.contains('unsure'),
          onTap: () => _toggle('unsure'),
          child: _Unsure(domainId: widget.domainId),
        ),
      ],
    );
  }

  void _toggle(String key) => setState(() {
        if (!_open.remove(key)) _open.add(key);
      });
}

/// 갈래 하나. 눌러서 열고, 다시 눌러서 닫는다.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        background: open ? BeobaColors.brandSoft : BeobaColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: BeobaTapTarget.minimum),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        open
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: open ? BeobaColors.brand : BeobaColors.control,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: SafeText(
                          label,
                          where: 'CrossroadsSection.choice',
                          style: theme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: BeobaColors.ink3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open) ...[
              const SizedBox(height: 4),
              child,
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// 그 갈래의 칸들. **순서를 권하지 않는다** — 조건만 적는다.
class _Steps extends StatelessWidget {
  const _Steps({required this.procedures});

  final List<Procedure> procedures;

  static const String hint = '순서대로 해야 하는 것은 아니에요. 조건을 보고 고르세요.';
  static const String whenLabel = '이럴 때 씁니다';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (procedures.isEmpty) {
      return const NoticeBox(
        text: CrossroadsSection.empty,
        where: 'CrossroadsSection.empty',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeText(
          hint,
          where: 'CrossroadsSection.hint',
          style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
        ),
        const SizedBox(height: 8),
        for (final procedure in procedures)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  procedure.label,
                  where: 'Procedure.label',
                  style: theme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // **이 길을 만드는 법의 이름.** 우리 말은 한 글자도 안 보탠다.
                //
                // 사람은 목록을 위에서 아래로 이어지는 순서로 읽는다. 「결정 신청 →
                // 고소장 내기」가 나란히 서면 뒤엣것이 앞엣것의 다음 단계로 보이고,
                // 278번이 막으려던 오해가 배치만으로 되살아난다. 「이건 다른
                // 길이에요」를 우리가 지어 말하지 않고, **서로 다른 법이라는 것을
                // 데이터가 말하게 한다**(DECISIONS 284번).
                //
                // `pathLaw` 가 있으면 그것, 없으면 `legalBasis` 의 법이다 — 비어 있는
                // 것은 사람이 「같다」고 판정한 자리다(검사 ao). 법이 없는 길
                // (`noPathLaw`)에는 아무것도 안 낸다.
                if (_pathLawName(procedure) case final String law)
                  SafeText(
                    law,
                    where: 'Procedure.pathLaw',
                    style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
                  ),
                if (procedure.whatIsThis.isNotEmpty)
                  SafeText(
                    procedure.whatIsThis,
                    where: 'Procedure.whatIsThis',
                    style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
                  ),
                if (procedure.whenApplicable case final String applies)
                  SafeText(
                    '$whenLabel — $applies',
                    where: 'Procedure.whenApplicable',
                    style: theme.labelSmall?.copyWith(color: BeobaColors.ink3),
                  ),
                // **주의는 여기서도 보여준다.** 사다리에서 칸을 처음 보는
                // 자리이고, 「공증만 받고 강제집행 승낙 문구가 없으면 그냥
                // 종이」 같은 것은 그 칸을 고르기 **전에** 알아야 한다.
                if (procedure.caution case final String warning)
                  SafeText(
                    warning,
                    where: 'Procedure.caution',
                    style: theme.labelSmall?.copyWith(
                      color: BeobaColors.severityWarning,
                    ),
                  ),
                // **법원까지 안 가도 되는 길이 실제로 싸다는 걸 숫자가 말한다.**
                // 사용자가 사다리에서 제일 먼저 보게 될 금액이다.
                if (procedure.fees case final FeeSchedule fees)
                  FeeScheduleView(fees: fees),
              ],
            ),
          ),
      ],
    );
  }
}

/// 갈림길에 보일 「이 길을 만드는 법」의 이름. 없으면 `null`.
String? _pathLawName(Procedure procedure) {
  if (procedure.noPathLaw != null) return null;
  final law = procedure.pathLaw?.law ?? procedure.legalBasis?.law;
  return (law == null || law.trim().isEmpty) ? null : law;
}

/// 아직 못 정한 사람. **재촉하지 않는다.**
class _Unsure extends ConsumerWidget {
  const _Unsure({required this.domainId});

  final String domainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;

    // 창구는 데이터에서 온다. 코드에 기관명·번호를 적지 않는다.
    //
    // 위기 신호와 다른 목록이다 — 저쪽은 낱말이 걸려야 뜨고 이쪽은 **아무 일이
    // 없어도** 떠야 한다. 못 정한 사람에게 뜨는 것이 이 자리의 일이다.
    final channels = ref.watch(askFirstChannelsProvider(domainId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeText(
          CrossroadsSection.noRush,
          where: 'CrossroadsSection.noRush',
          style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SafeText(
          CrossroadsSection.deadlineHint,
          where: 'CrossroadsSection.deadlineHint',
          style: theme.labelMedium?.copyWith(color: BeobaColors.ink2),
        ),
        const SizedBox(height: 12),
        CrisisChannelList(channels: channels, compact: true),
      ],
    );
  }
}
