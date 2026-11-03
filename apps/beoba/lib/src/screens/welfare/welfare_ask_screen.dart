import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/domain_providers.dart';
import '../../providers/welfare_providers.dart';
import '../../safety/safe_text.dart';
import '../../welfare/welfare_match.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/why_ask_card.dart';
import 'welfare_chips.dart';

/// 두 번째 문 — **법 문제가 아닌 사람에게 열어 두는 자리.**
///
/// ## 물음이 셋이다. 넷이 아니다
///
/// 처음 적어 둔 넷 중 **둘을 뺐다.**
///
/// ```
/// 사는 시·군   뺐다. 지자체 API 를 아직 못 열어서 쓸 데가 없다
/// 가구원 수     뺐다. 가구상황은 저소득·한부모·장애인 … 머릿수가 아니다
/// ```
///
/// 대신 가구상황을 **자료가 쓰는 이름 그대로** 묻는다. 안 쓰는 답을 받아 두면
/// 화면에 한 번도 안 나오는 항목이 되고, 그건 「없는 것과 같다」([119~143]의
/// 규칙이고 기계가 센다). 게다가 이 셋은 조합하면 사람을 특정한다 — 홈에서
/// 「저장하지 않아요」라고 적어 둔 자리라 **덜 묻는 쪽이 지키는 쪽**이다.
///
/// ## 인터뷰가 아니다
///
/// 한 화면에 셋을 다 둔다. 한 문항씩 넘기면 분야의 인터뷰와 같은 모양이 되고,
/// 그 순간 복지가 **분야가 된다.** 복지는 분야가 아니라 곁문이다.
class WelfareAskScreen extends ConsumerWidget {
  const WelfareAskScreen({this.fromDomainId, super.key});

  /// 어느 분야에서 건너왔는가. 없으면 홈에서 바로 온 것이다.
  final String? fromDomainId;

  static const String title = '세 가지만 알려주시면 찾아볼게요';
  static const String lead = '쓰지 않을 건 여쭤보지 않을게요.';

  static const String next = '찾아본 것 보기';

  static const String birthLabel = '태어난 해';
  static const String birthHint = '예) 1978';
  static const String birthWhy = '나이대로 목록을 좁혀요. '
      '생년월일이 아니라 연도만 여쭤봐요.';

  static const String workLabel = '지금 일하고 계신가요?';
  static const String workWhy = '일이 끊긴 분께는 일자리 제도를 위로 올려요. '
      '이 답 때문에 안 보이게 되는 건 없어요.';
  static const String workYes = '일하고 있어요';
  static const String workNo = '지금은 일하고 있지 않아요';
  static const String workSkip = '지금은 말하고 싶지 않아요';

  static const String householdLabel = '혹시 이런 경우가 있으신가요';
  // ★ 옛 문장 「고르지 않으면 오히려 더 많이 보여드려요」는 가구상황을 접게 된 뒤
  // 거짓이 된다 — 안 고르면 조건이 붙은 제도는 접힌다(DECISIONS 287번).
  static const String householdWhy = '안 고르셔도 괜찮아요. '
      '고르신 것에 맞는 제도를 먼저 보여드리고, 나머지도 없애지 않고 접어 둬요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(welfareCatalogProvider);

    return Scaffold(
      appBar: beobaAppBar(context),
      body: loaded.hasValue
          ? _Form(fromDomainId: fromDomainId)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _Form extends ConsumerWidget {
  const _Form({required this.fromDomainId});

  final String? fromDomainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final answers = ref.watch(welfareAnswersProvider);
    final controller = ref.read(welfareAnswersProvider.notifier);

    return PageBody(
      bottom: PrimaryButton(
        label: WelfareAskScreen.next,
        where: 'WelfareAskScreen.next',
        onPressed: () => context.push(Routes.welfareList(fromDomainId)),
      ),
      children: [
        SafeText(
          WelfareAskScreen.title,
          where: 'WelfareAskScreen.title',
          style: theme.headlineSmall,
        ),
        const SizedBox(height: 8),
        SafeText(
          WelfareAskScreen.lead,
          where: 'WelfareAskScreen.lead',
          style: theme.bodyMedium?.copyWith(color: BeobaColors.ink2),
        ),
        const SizedBox(height: 24),

        // ── 하나. 태어난 해 ────────────────────────────────────────
        const SectionHeader(WelfareAskScreen.birthLabel),
        const SizedBox(height: 10),
        _BirthYearField(
          value: answers.birthYear,
          onChanged: controller.setBirthYear,
        ),
        const SizedBox(height: 12),
        const WhyAskCard(whyAsk: WelfareAskScreen.birthWhy),
        const SizedBox(height: 26),

        // ── 둘. 일하고 있는가 ─────────────────────────────────────
        const SectionHeader(WelfareAskScreen.workLabel),
        const SizedBox(height: 10),
        for (final (label, value) in const [
          (WelfareAskScreen.workYes, WelfareWork.working),
          (WelfareAskScreen.workNo, WelfareWork.notWorking),
          (WelfareAskScreen.workSkip, WelfareWork.unsaid),
        ])
          WelfareChoiceRow(
            label: label,
            where: 'WelfareAskScreen.work',
            selected: answers.work == value,
            onTap: () => controller.setWork(value),
          ),
        const SizedBox(height: 12),
        const WhyAskCard(whyAsk: WelfareAskScreen.workWhy),
        const SizedBox(height: 26),

        // ── 셋. 가구상황 ──────────────────────────────────────────
        const SectionHeader(WelfareAskScreen.householdLabel),
        const SizedBox(height: 12),
        WelfareChipRow(
          names: ref.watch(welfareHouseholdNamesProvider),
          picked: answers.households,
          where: 'CentralWelfareService.households',
          onToggle: controller.toggleHousehold,
        ),
        // ★ 누르는 즉시 두 숫자가 바뀐다. 이미 읽어 둔 자료로 센다 — 다시
        // 안 불러온다(DECISIONS 289번).
        if (ref.watch(welfareMatchProvider(fromDomainId)) case final match?) ...[
          const SizedBox(height: 12),
          WelfareSplitLine(first: match.matched, folded: match.folded.length),
        ],
        const SizedBox(height: 12),
        const WhyAskCard(whyAsk: WelfareAskScreen.householdWhy),
      ],
    );
  }
}

/// 태어난 해. 네 자리 숫자만 받는다.
class _BirthYearField extends ConsumerStatefulWidget {
  const _BirthYearField({required this.value, required this.onChanged});

  final int? value;
  final void Function(int?) onChanged;

  @override
  ConsumerState<_BirthYearField> createState() => _BirthYearFieldState();
}

class _BirthYearFieldState extends ConsumerState<_BirthYearField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **오늘보다 뒤에 태어난 사람은 없다.** 위쪽 끝은 시계가 정한다.
    final thisYear = ref.watch(todayProvider).year;

    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        // not-a-legal-number: 연도는 네 자리다. 법률 수치가 아니다.
        LengthLimitingTextInputFormatter(4),
      ],
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: const InputDecoration(hintText: WelfareAskScreen.birthHint),
      onChanged: (raw) {
        final year = int.tryParse(raw);
        // not-a-legal-number: 사람이 살아 있을 수 있는 해의 아래쪽 끝.
        final ok = year != null && year >= 1900 && year <= thisYear;
        widget.onChanged(ok ? year : null);
      },
    );
  }
}
