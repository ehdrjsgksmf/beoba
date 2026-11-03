import 'package:engines/engines.dart' show SafetyScope;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/interview_providers.dart';
import '../../safety/disclaimers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/privacy_sheet.dart';
import '../../widgets/plain_mode_ask_sheet.dart';
import '../../widgets/tally_consent_sheet.dart';
import '../domain_select/domain_select_screen.dart';
import '../../widgets/today_pill.dart';
import '../bootstrap_gate.dart';

/// 홈 — 사건이 없는 상태.
///
/// ## 처음 보이는 곳에는 셋만 둔다
///
/// **인사말 · 입력창 · 시작하기.** 설명은 전부 접힌 선 아래로 내린다.
/// 마음먹고 온 사람은 3초 안에 쓰기 시작하고, 뭔지 모르는 사람만 내려서 읽는다.
/// **이탈은 첫 화면에 읽을 게 몇 개냐로 갈린다.**
///
/// 전에는 상단에 「알려 드립니다」 상자가 따로 떠 있었다. 같은 내용을 아래
/// 「도울 수 없어요」 로 옮겼다 — **배치만 바꿔도 "책임 회피" 가 "정직함" 으로
/// 읽힌다.**
///
/// 말하는 존재는 마중이다. 「버바」는 여기 나오지 않는다 (DECISIONS 41번).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// **화면의 첫 줄.** 세 축이 한 줄에 들어간다 —
  /// 기한(오늘) · 첫 걸음(찾다) · 동행(혼자).
  static const String headline = '오늘 뭘 해야 할지,\n혼자 찾지 않게';

  /// 부제는 기능 한 줄이다. 기억하고, 알려준다.
  static const String headlineSub =
      '놓치면 안 되는 날을 대신 기억하고,\n다음에 할 일을 하나씩 알려드려요.';

  /// 버튼 **바로 아래**. 누르기 직전에 마지막으로 읽는 말이다.
  static const String startNote = '어디서부터 해야 할지, 같이 찾아볼게요.';

  /// 확정된 인사말. 고치려면 DECISIONS 41번부터 고친다.
  static const String greetingName = '안녕하세요, 마중이에요.';
  static const List<String> greeting = [
    '어떤 일인지 제가 다 헤아릴 순 없지만,',
    '이렇게 찾아와 주셔서 정말 고마워요.',
  ];
  /// **두 갈래를 나란히 세운다.** 이 화면의 진짜 물음이다.
  ///
  /// 전에는 입력창만 크고 복지 문이 접힌 선 아래 한 줄이었다. 무게가 안
  /// 맞았다 — 법 문제가 아닌 분은 자기 자리를 못 찾고 나갔다.
  static const String pick = '어떤 일로 오셨나요?';

  /// **문제 해결이 위다.** 이 앱의 뿌리이고, 급한 사람이 먼저 봐야 한다.
  static const String pathProblem = '일어난 문제를 해결하고 싶어요';
  static const String pathProblemSub = '떼인 돈 · 해고 · 보증금 · 사기 …';

  /// 입력창은 **두 갈래 어디에도 자기 것이 안 보이는 사람**이 갈 데다.
  /// 그래서 아래로 내리되 없애지 않는다.
  static const String lead = '글로 쓰셔도 돼요';
  static const String leadSub = '어려운 말은 몰라도 괜찮아요. 나머지는 하나씩 같이 확인해봐요.';

  /// 입력창 **위**에 둔다. 키보드가 올라오면 아래는 통째로 가린다.
  ///
  /// **여기에는 사실만 짧게 둔다.** 예전에는 한 문장이 더 붙어 「남는 곳이
  /// 하나도 없다」고 단정하고 있었는데, 자판이 자주 쓰는 말을 스스로 기억하는
  /// 한 그건 사실이 아니다(DECISIONS 102번). 「저장하지 않아요」는 사실이다 —
  /// 저장 코드가 0줄이다.
  ///
  /// 나머지는 [PrivacySheet] 로 내렸다. 우리가 못 막는 것까지 거기서 말한다.
  static const String privacy = '적어주신 내용은 저장하지 않아요.';
  static const String privacyMore = '자세히';

  static const String hint = '예) 작년 3월에 오백만원을 빌려줬는데 계속 안 갚아요';
  static const String start = '마중이랑 시작하기';

  /// **두 번째 갈래.** 법 문제가 아닌 사람에게 열어 두는 자리다.
  ///
  /// ★ 문구에 판정이 들어가면 안 된다. 「받을 수 있는 걸 알고 싶어요」는
  /// **사용자가 말하는 것**이라 괜찮지만, 「받으실 수 있어요」는 우리가
  /// 말하는 것이라 안 된다. 아래 줄은 **찾는 행위까지만** 말한다.
  static const String welfareDoor = '받을 수 있는 걸 알고 싶어요';
  static const String welfareNote = '나이와 형편으로 찾아드려요';

  static const String canTitle = '이건 마중이가 잘하는 거예요';
  static const String cannotTitle = '이건 마중이가 도울 수 없어요';

  /// **여기서 약속한 것은 앱 안에서 실제로 나와야 한다.**
  static const List<(IconData, String, String)> canDo = [
    (
      Icons.event_available_outlined,
      '언제까지 해야 하는지 날짜로 알려드려요',
      '법에 정해진 기한을 오늘 기준으로 계산해요',
    ),
    (
      Icons.receipt_long_outlined,
      '필요한 서류와 드는 돈을 정리해드려요',
      '무엇을 챙기고 얼마가 드는지 미리 볼 수 있어요',
    ),
    (
      Icons.support_agent_outlined,
      '무료로 도와주는 곳을 찾아드려요',
      // 목업은 「바로 연결해요」였다. **약속을 올리지 않는다** — 첫 화면에서
      // 약속하고 끝까지 안 나오면 사용자는 못 찾은 줄 알고 다시 뒤진다.
      // 그 규칙은 이미 테스트로 잠겨 있다(「연결」 0건).
      '지금 상황에 맞는 공적 창구를 알려드려요',
    ),
  ];

  /// 하지 않는 일. 첫 줄 문구는 [Disclaimers] 한 곳에서만 관리한다.
  static const List<(String, String)> cannotDo = [
    ('이길지 질지는 알려드릴 수 없어요', '결과를 짐작해서 말씀드리지 않아요'),
    ('변호사처럼 상담해드릴 수 없어요', Disclaimers.noAdviceSoft),
    ('서류를 대신 써드릴 수 없어요', '어떻게 쓰는지는 옆에서 같이 짚어드릴게요'),
  ];

  /// 화면의 마지막 말. **감정 한 줄이면 된다.**
  ///
  /// 목업에는 이 아래에 통계와 카운터가 있었는데 둘 다 안 옮겼다
  /// (DECISIONS 99번). 허전해 보여도 빈자리를 채우지 않는다 — 여백이 맞다.
  static const String sloganBig = '혼자 가지 않게,\n마중 나갈게요';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// **걸린 개수로 갈린다.** 고르는 게 아니라 후보를 좁히는 것이다.
  ///
  /// ```
  /// 하나만 걸림   → 「이렇게 이해했어요」 확인 카드
  /// 둘 이상 걸림  → 그 둘만 놓고 고르게 한다
  /// 안 걸림       → 지금처럼 분야 목록
  /// ```
  ///
  /// **경보가 먼저다.** `startDomain` 이 세션을 열자마자 하드스톱을 보고,
  /// 위기 신호는 라우터 가드가 그 뒤 모든 경로에서 덮는다.
  void _start() {
    final narrative = _controller.text;
    ref.read(pendingNarrativeProvider.notifier).hold(narrative);

    final detected = ref.read(detectedDomainsProvider);
    if (detected.length != 1) {
      context.push(Routes.domains);
      return;
    }

    startDomain(
      context,
      ref,
      detected.single.domainId,
      narrative,
      prefill: detected.single.prefill,
      confirmFirst: true,
    );
  }

  @override
  void initState() {
    super.initState();
    // ★ **물음 둘을 한 실행에 겹쳐 띄우지 않는다**(DECISIONS 289번).
    //
    // 처음 여신 분에게는 쉬운 말 물음 **하나만** 묻는다. 집계 동의는 이 앱이
    // 무엇을 하는지 본 뒤에 묻는다 — 첫 결과 화면을 떠나 도착한 화면에서
    // (`ConsentAfterResult`), 아니면 다음에 여실 때 여기서.
    //
    // ★ 흠 — 결과를 안 보고 닫으신 분도 둘째 실행 때 동의 물음을 본다.
    // 「결과를 본 적이 있다」를 기기에 남기면 없앨 수 있지만 남기는 키가
    // 셋이 된다. 그 값이 더 크다고 봤다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final asked = await PlainModeAskSheet.openIfUnanswered(context, ref);
      if (asked || !mounted) return;
      // 묻고 켠다(DECISIONS 137번).
      await TallyConsentSheet.openIfUnanswered(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      body: BootstrapGate(
        child: PageBody(
          bottom: _StartArea(onPressed: _start),
          children: [
            const TodayBar(),
            const SizedBox(height: 18),

            // ── 여기까지가 스크롤 없이 보이는 곳 ──────────────────────
            //
            // **큰 줄이 맨 위다.** 이 앱이 무엇을 하는지 한 줄로 말한 뒤에
            // 인사한다. 뭔지 모르고 들어온 사람이 첫 화면에서 판단한다.
            SafeText(
              HomeScreen.headline,
              where: 'HomeScreen.headline',
              style: theme.headlineMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            SafeText(
              HomeScreen.headlineSub,
              where: 'HomeScreen.headlineSub',
              style: theme.bodyMedium?.copyWith(
                color: BeobaColors.ink2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 26),
            const Divider(color: BeobaColors.line2, height: 1),
            const SizedBox(height: 24),

            SafeText(
              HomeScreen.greetingName,
              where: 'HomeScreen.greetingName',
              style: theme.headlineSmall,
            ),
            const SizedBox(height: 8),
            for (final line in HomeScreen.greeting)
              SafeText(
                line,
                where: 'HomeScreen.greeting',
                style: theme.bodyLarge?.copyWith(color: BeobaColors.ink2),
              ),
            const SizedBox(height: 24),

            // ── 두 갈래 ────────────────────────────────────────────
            SafeText(
              HomeScreen.pick,
              where: 'HomeScreen.pick',
              style: theme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _PathCard(
              icon: Icons.gavel_outlined,
              title: HomeScreen.pathProblem,
              subtitle: HomeScreen.pathProblemSub,
              where: 'HomeScreen.pathProblem',
              // 적어 둔 글이 있으면 그걸로 알아채고, 없으면 분야 목록이다.
              onTap: _start,
            ),
            const SizedBox(height: 10),
            _PathCard(
              icon: Icons.volunteer_activism_outlined,
              title: HomeScreen.welfareDoor,
              subtitle: HomeScreen.welfareNote,
              where: 'HomeScreen.welfareDoor',
              onTap: () => context.push(Routes.welfare()),
            ),

            const SizedBox(height: 26),
            SafeText(
              HomeScreen.lead,
              where: 'HomeScreen.lead',
              style: theme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SafeText(
              HomeScreen.leadSub,
              where: 'HomeScreen.leadSub',
              style: theme.labelMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              style: theme.bodyMedium,
              decoration: InputDecoration(
                hintText: HomeScreen.hint,
                // **형제가 아니라 입력창의 일부다.** 스크롤 본문에서 형제로
                // 두면 입력창만 따라 올라가고 이 줄은 뒤에 남는다. helper 는
                // 입력창이 어디로 밀리든 함께 가고, 포커스가 잡혔을 때
                // 「보이게 하라」고 계산하는 넓이 안에도 같이 들어간다.
                helper: _PrivacyLine(onMore: () => PrivacySheet.open(context)),
              ),
            ),

            // ── 접힌 선 아래. 궁금한 사람만 내려서 읽는다 ──────────────
            const SizedBox(height: 30),
            const Divider(color: BeobaColors.line2, height: 1),
            const SizedBox(height: 26),
            const _CanDo(),
            const SizedBox(height: 22),
            const _CannotDo(),
            const SizedBox(height: 30),
            const _Slogan(),
          ],
        ),
      ),
    );
  }
}

/// 할 수 있는 일.
/// 🔒 적어주신 내용은 저장하지 않아요.  자세히
///
/// **입력창의 helper 다.** 사람이 망설이는 건 쓰기 직전이라 그때 눈에
/// 들어와야 하는데, 스크롤 본문에서 「바로 다음 형제」는 그 보장을 못 준다.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 15, color: BeobaColors.ink3),
        const SizedBox(width: 6),
        Flexible(
          child: SafeText(
            HomeScreen.privacy,
            where: 'HomeScreen.privacy',
            style: theme.labelMedium,
          ),
        ),
        const SizedBox(width: 8),
        // **못 막는 것까지 말하는 자리는 여기가 아니다.** 첫 화면은
        // 사실만 짧게 두고, 궁금한 사람만 연다.
        //
        // 글자 높이로는 폰에서 빗나간다. 탭 영역을 따로 넓힌다.
        InkWell(
          onTap: onMore,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: BeobaTapTarget.minimum,
            ),
            alignment: Alignment.center,
            child: SafeText(
              HomeScreen.privacyMore,
              where: 'HomeScreen.privacyMore',
              style: theme.labelMedium?.copyWith(
                color: BeobaColors.brand2,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 갈래 하나. **둘을 같은 모양으로 그린다.**
///
/// 한쪽을 크게 하거나 색을 다르게 하면 그게 곧 「이쪽이 맞습니다」가 된다.
/// 우선순위는 **순서로만** 말한다 — 문제 해결이 위다.
///
/// 복지 쪽은 분야 카드가 아니라 곁문이라 분야 목록에는 안 넣는다. 목록에
/// 끼우면 「떼인 돈 받기」 옆에 나란히 서서 같은 것으로 읽힌다.
class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.where,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String where;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BeobaSpace.radius),
        child: Container(
          // not-a-legal-number: 카드 최소 높이. 법률 수치가 아니다.
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: BeobaColors.card,
            borderRadius: BorderRadius.circular(BeobaSpace.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: BeobaColors.brand2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeText(
                      title,
                      where: where,
                      style: theme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SafeText(
                      subtitle,
                      where: '$where.sub',
                      style: theme.labelMedium,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: BeobaColors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanDo extends StatelessWidget {
  const _CanDo();

  @override
  Widget build(BuildContext context) {
    return _Block(
      title: HomeScreen.canTitle,
      titleIcon: Icons.check_circle_outline,
      titleColor: BeobaColors.green,
      children: [
        for (final (icon, headline, detail) in HomeScreen.canDo)
          _Line(
            icon: icon,
            iconColor: BeobaColors.green,
            headline: headline,
            detail: detail,
            where: 'HomeScreen.canDo',
          ),
      ],
    );
  }
}

/// 할 수 없는 일.
///
/// 전에는 이 내용이 화면 맨 위 「알려 드립니다」 상자에 있었다. 같은 정보인데
/// **먼저 내미는 변명**과 **묻는 사람에게 하는 대답**은 다르게 읽힌다.
class _CannotDo extends StatelessWidget {
  const _CannotDo();

  @override
  Widget build(BuildContext context) {
    return _Block(
      title: HomeScreen.cannotTitle,
      titleIcon: Icons.remove_circle_outline,
      titleColor: BeobaColors.ink3,
      children: [
        for (final (headline, detail) in HomeScreen.cannotDo)
          _Line(
            icon: Icons.block,
            iconColor: BeobaColors.ink3,
            headline: headline,
            detail: detail,
            where: 'HomeScreen.cannotDo',
            // 하지 않겠다는 선언이다. 예측이 아니다.
            scope: SafetyScope.disclaimer,
          ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.titleIcon,
    required this.titleColor,
    required this.children,
  });

  final String title;
  final IconData titleIcon;
  final Color titleColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(titleIcon, size: 17, color: titleColor),
            const SizedBox(width: 6),
            Flexible(
              child: SafeText(
                title,
                where: 'HomeScreen.blockTitle',
                style: theme.labelLarge?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// 한 줄. 굵은 문장 아래 작은 설명.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.iconColor,
    required this.headline,
    required this.detail,
    required this.where,
    this.scope = SafetyScope.strict,
  });

  final IconData icon;
  final Color iconColor;
  final String headline;
  final String detail;
  final String where;
  final SafetyScope scope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeText(
                  headline,
                  where: where,
                  scope: scope,
                  style: theme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SafeText(
                  detail,
                  where: where,
                  scope: scope,
                  style: theme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 슬로건. 화면의 마지막 말이다.
class _Slogan extends StatelessWidget {
  const _Slogan();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.light_mode_outlined,
          size: 28,
          color: BeobaColors.brand2,
        ),
        const SizedBox(height: 12),
        SafeText(
          HomeScreen.sloganBig,
          where: 'HomeScreen.sloganBig',
          textAlign: TextAlign.center,
          style: theme.titleMedium?.copyWith(fontSize: 19, height: 1.5),
        ),
      ],
    );
  }
}

/// 시작 버튼과 그 아래 한 줄.
///
/// **누르기 직전에 마지막으로 읽는 말**이라 버튼 위가 아니라 아래에 둔다.
/// 위에 두면 입력창과 버튼 사이가 벌어져 손이 멀어진다.
class _StartArea extends StatelessWidget {
  const _StartArea({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: HomeScreen.start,
          where: 'HomeScreen.start',
          onPressed: onPressed,
        ),
        const SizedBox(height: 9),
        SafeText(
          HomeScreen.startNote,
          where: 'HomeScreen.startNote',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BeobaColors.ink3,
              ),
        ),
      ],
    );
  }
}
