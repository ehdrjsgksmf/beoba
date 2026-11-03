import 'package:engines/engines.dart';
import 'package:domain_data/domain_data.dart' show AlertDisplay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../providers/broker_providers.dart';
import '../../providers/domain_providers.dart';
import '../../providers/interview_providers.dart';
import '../../providers/result_providers.dart';
import '../../safety/disclaimers.dart';
import '../../safety/safe_text.dart';
import '../../widgets/today_pill.dart';
import '../../widgets/broker_alert_card.dart';
import '../../widgets/crisis_banner.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';
import '../bootstrap_gate.dart';
import 'not_ready_view.dart';
import 'sections/caution_section.dart';
import 'sections/crossroads_section.dart';
import 'sections/limitation_card.dart';
import '../../widgets/tally_once.dart';
import 'sections/legal_aid_card.dart';
import 'sections/pinned_caution_card.dart';
import 'sections/receive_window_card.dart';
import 'sections/starts_from_card.dart';
import 'sections/summary_cards.dart';
import 'sections/today_card.dart';
import 'sections/welfare_door.dart';
import 'take_away_link.dart';

/// 결과 요약.
///
/// ## 카드 다섯 장을 넘지 않는다
///
/// ```
/// 오늘 할 일          안 접힌다. 가장 급한 기한 하나가 여기 있다
/// 얼마나 드나요        접힘 — 갈래별 합계만 보인다
/// 뭘 준비해야 하나요    접힘 — 몇 개 중 몇 개인지만 보인다
/// 어디에 내나요        접힘 — 한 줄만 보인다
/// 어떻게 진행되나요     접힘 — 다음 한 칸만 보인다
/// ```
///
/// 폰에서 재어 보니 섹션이 펼쳐진 채로 쌓여 정작 쓸모 있는 비용이 맨 아래에
/// 있었다. **첫 화면에서 비용(또는 기한)이 보이는 것**이 이 화면의 합격선이다.
///
/// 화면에서 금액·날짜를 다시 계산하지 않는다. 층도 시각적으로 섞지 않는다.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({required this.domainId, super.key});

  final String domainId;

  /// 결과 화면의 제목.
  ///
  /// "정리한 내용입니다" 였는데 두 가지가 문제였다. 인터뷰 마지막 버튼과 낱말이
  /// 겹쳤고, 무엇보다 **아무 말도 하지 않았다.** 여기가 이 제품이 약속한 것을
  /// 내놓는 자리인데 제목이 그걸 말하지 않으면 사용자는 뭘 받은 건지 모른다.
  ///
  /// 서술어는 `계산했어요` 다. 판단도 예측도 아니고 법령의 수치를 넣어 날짜를
  /// 뽑은 것뿐이라는 사실을 제목이 스스로 말한다.
  static const String title = '언제까지 무엇을 해야 하는지 계산했어요';
  static const String disclaimer = Disclaimers.noJudgement;

  /// **「더 있다」는 신호.** 첫 화면 안에 무조건 들어간다.
  ///
  /// 예전에는 「다음 카드의 머리가 첫 화면에 보인다」가 그 일을 했다. 배율을
  /// 키우면 **첫 카드 혼자 화면보다 길어져서 원리적으로 못 지킨다** — 배율
  /// 1.5 에서 일곱 갈래 중 다섯이 깨졌다. 개수는 배율과 무관하다.
  ///
  /// 첫 카드를 다 읽고 「끝인가 보다」 하고 닫는 것보다, 이 줄 하나가 밀도를
  /// 조금 늘리는 편이 훨씬 싸다.
  ///
  /// **세는 것은 화면이다.** 카드마다 「비었으면 안 그린다」를 각자 들고
  /// 있는데, 그 판단이 위젯 안에 있으면 화면은 몇 장이 서는지 모른다.
  /// 그래서 같은 조건을 여기서 한 번 더 보고, 선 것만 [cards] 에 담는다.
  static String countLabel(int count) => '아래에 $count가지가 있어요';

  /// 검사가 이 줄을 찾는 열쇠. 문구가 바뀌어도 검사는 안 깨진다.
  static const Key countKey = Key('result-count');

  /// 도착지에 무엇이 있는지 말한다. 「자세히 보기」 는 아무것도 알려주지 않는다.
  static const String detail = '이 날짜와 금액의 근거 보기';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: beobaAppBar(context),
      body: BootstrapGate(
        child: Consumer(builder: (context, ref, _) => _body(context, ref)),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final state = ref.watch(interviewStateProvider(domainId));
    final blocks = ref.watch(layerBlocksProvider(domainId));

    void goFix(String questionId) {
      final questions = ref.read(applicableQuestionsProvider(domainId));
      final index = questions.indexWhere((q) => q.id == questionId);
      context.push(Routes.interview(domainId, index < 0 ? null : index + 1));
    }

    // 필수 정보가 모자라면 결과를 만들지 않는다.
    if (state.readiness == Readiness.red) {
      return NotReadyView(state: state, missing: blocks.red, onFix: goFix);
    }

    final deadlines = ref.watch(dueDeadlinesProvider(domainId));
    final procedures = ref.watch(proceduresProvider(domainId));

    final scenarios = ref.watch(costScenariosProvider(domainId));
    final documents = ref.watch(documentResultsProvider(domainId));
    final guide = ref.watch(jurisdictionGuideProvider(domainId));
    final places = ref.watch(jurisdictionResultsProvider(domainId));
    final cautions = ref.watch(cautionsProvider(domainId));
    final inlineCautions = [
      for (final caution in cautions)
        if (caution.display == AlertDisplay.inline) caution,
    ];

    final cards = <Widget>[
      // 오늘 할 일이 맨 위다. **가장 급한 기한이 있으면 그게 오늘 할 일이고**,
      // 없으면 밟을 수 있는 절차의 다음 한 칸이다. 기한이 없을 때 이 카드는
      // 한 줄로 줄어들고 비용 카드가 곧바로 온다 (DECISIONS 70).
      TodayCard(
        deadlines: deadlines,
        appearsWhen: ref.watch(deadlineHintsProvider(domainId)),
        nextStep: procedures.isEmpty ? null : procedures.first,
        onExplainPeriod: () => context.push(Routes.resultDetail(domainId)),
      ),
      // **신청 기한이 아니라 받는 기간이다.** 늦어지는 만큼 받을 날이
      // 줄어든다 — 「오늘 할 일」에 섞으면 그게 안 보인다(DECISIONS 189번).
      if (ref.watch(receiveWindowProvider(domainId)) case final windows
          when windows.isNotEmpty)
        ReceiveWindowCard(results: windows),
      // **기한이 아니다.** 지나면 잃는 날이 아니라 그날부터 생기는 것이라
      // D-day 를 붙이지 않는다. 대항력이 그렇다(DECISIONS 135번).
      if (ref.watch(startsFromProvider(domainId)) case final starts
          when starts.isNotEmpty)
        StartsFromCard(results: starts),
      // **되돌릴 수 없는 안내는 접지 않는다.** 물음 버튼 뒤에 두면 누르지
      // 않은 사람이 그대로 저지른다(DECISIONS 110번).
      //
      // **다만 기한보다 위는 아니다.** 하드스톱이 바로 그렇게 해서 지급명령
      // 이의신청 2주를 통째로 가렸다(DECISIONS 121번). 그리고 open 이 stop
      // 보다 먼저다 — 압류당한 사람에게 먼저 필요한 것은 안심이고, 겁을 준
      // 뒤에 안심시키는 순서가 되면 안 된다.
      for (final caution in cautions)
        if (caution.display == AlertDisplay.open)
          PinnedCautionCard(caution: caution),
      for (final caution in cautions)
        if (caution.display == AlertDisplay.stop)
          PinnedCautionCard(caution: caution),
      // 기한 아래, 비용 위. **날짜로 계산하지 않는 것**이라 기한 카드에
      // 넣지 않는다(DECISIONS 107번).
      if (ref.watch(limitationRulesProvider(domainId)) case final rules
          when rules.isNotEmpty)
        LimitationCard(rules: rules)
      else
        // **채무자에게는 시효를 말하지 않는다.** 대신 길만 연다.
        const LimitationForDebtor(),
      if (scenarios.isNotEmpty) CostCard(scenarios: scenarios),
      // **금액 바로 아래.** 돈이 없어서 온 사람에게 금액만 내밀면 벽이다.
      // 접힌 채로 온다 — 얼마인지 먼저 보고 나서 읽는 순서다.
      if (ref.watch(legalAidProvider(domainId)) case final aid?)
        LegalAidCard(aid: aid),
      if (documents.isNotEmpty)
        DocumentCard(documents: documents, procedures: procedures),
      if (guide != null || places.isNotEmpty)
        JurisdictionCard(guide: guide, results: places),
      if (procedures.isNotEmpty)
        ProcedureCard(
          procedures: procedures,
          misses: ref.watch(nearMissesProvider(domainId)),
        ),
      // 카드가 아니라 물음이다. 해당하는 것만 눌러 본다.
      // **위에 펼쳐 둔 것은 여기 다시 넣지 않는다.** 같은 말을 두 번 하면
      // 둘 다 안 읽힌다.
      if (inlineCautions.isNotEmpty) CautionSection(cautions: inlineCautions),
      // 갈림길. **소송 말고도 있다는 걸 여기서 처음 보게 된다.**
      // 고른 갈래가 다른 갈래를 감추지 않는다 — 되돌아올 수 있어야 한다.
      if (procedures.isNotEmpty) CrossroadsSection(domainId: domainId),
      // 지나오면서 걸린 브로커 경보를 모아서 다시 낸다. **브로커는 결과를
      // 본 뒤에 연락한다.** 접지도 닫지도 않고, 걸린 게 없으면 자리도 없다.
      if (ref.watch(allBrokerWarningsProvider(domainId)).isNotEmpty)
        BrokerAlertSection(domainId: domainId),
      // **맨 아래다.** 다 보고 나서 가져가는 것이지, 보기 전에 가져가는
      // 것이 아니다. 접지 않는다 — 한 줄짜리 입구라 접을 것이 없다.
      TakeAwayLink(domainId: domainId),
    ];

    return PageBody(
      // 스크롤해도 안 사라진다. 화면에 고정 버튼은 이것 하나뿐이다.
      bottom: PrimaryButton(
        label: detail,
        where: 'ResultScreen.detail',
        onPressed: () => context.push(Routes.resultDetail(domainId)),
      ),
      children: [
        // **세션 하나에 한 번.** 결과 화면에 닿은 것이 그 자리다.
        // 「세지 마세요」를 고르셨으면 아무것도 안 나간다.
        TallyOnce(domainId: domainId),
        SafeText(title, where: 'ResultScreen.title', style: theme.headlineSmall),
        // **머리 여백에서 자리를 낸다.** 개수 한 줄을 넣으면서 위아래 여백을
        // 그만큼 줄였다. 새 줄 때문에 아래 카드가 밀려나면 신호를 얻고 내용을
        // 잃는 것이라 셈이 안 맞는다.
        const SizedBox(height: 4),
        SafeText(
          countLabel(cards.length),
          key: countKey,
          where: 'ResultScreen.count',
          style: theme.labelMedium?.copyWith(color: BeobaColors.ink3),
        ),
        const SizedBox(height: 10),
        const NoticeBox(text: disclaimer, where: 'ResultScreen.disclaimer'),
        const SizedBox(height: 14),
        ...cards,
        // **법률에서 복지로 건너가는 한 줄.** 이을 근거(welfareBridge)가
        // 없는 분야에는 안 선다. 개수에 안 넣는다 — 결과가 아니라 곁문이다.
        if (ref
                .watch(domainBundleProvider)
                .requireValue
                .byId(domainId)
                .welfareBridge !=
            null)
          WelfareDoor(domainId: domainId),
        // 위기 창구는 접지 않는다. 그 자리에서 필요한 정보다.
        // **개수에 안 넣는다** — 결과가 아니라 언제나 열려 있는 문이다.
        CrisisFooter(domainId: domainId),
      ],
    );
  }
}
