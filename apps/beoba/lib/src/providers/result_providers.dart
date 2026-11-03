import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layers/layer_assembler.dart';
import '../layers/legal_layer.dart';
import '../sheet/take_away_sheet.dart';
import 'domain_providers.dart';
import 'interview_providers.dart';

/// 엔진은 전부 순수 함수라 `Provider` 로 충분하다. 비동기가 아니다.
///
/// **화면은 여기서 나온 값을 다시 계산하지 않는다.** 포맷만 한다.

final deadlineResultsProvider =
    Provider.family<List<DeadlineResult>, String>((ref, domainId) {
  // DateTime.now() 를 직접 부르지 않는다. 시계는 주입받는다 (CONTRIBUTING.md 규칙 2).
  //
  // 쉬는 날도 코드가 아니라 데이터에서 온다. 표에 없는 해는 토·일만 민다.
  final engine = DeadlineEngine(
    ref.watch(appClockProvider),
    holidays: requireBundle(ref).holidays,
  );
  return engine.compute(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  );
});

final costResultProvider = Provider.family<CostResult, String>(
  (ref, domainId) => const CostEngine().compute(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  ),
);

/// 갈래마다 한 벌씩. **화면이 쓰는 것은 이쪽이다.**
///
/// 지급명령으로 갈지 소송으로 갈지, 종이로 낼지 전자소송으로 낼지를 아직 아무도
/// 묻지 않는다. 그래서 [costResultProvider] 는 그 필드가 빈 채로 계산했고, 소장·
/// 종이 금액이 모든 사람에게 나갔다 — 지급명령·전자소송의 11배다.
///
/// 묻는 대신 갈래마다 따로 계산해 나란히 놓는다. 사용자가 아직 안 정한 것을
/// 물으면 답을 모르는 사람에게 답을 요구하게 된다.
final costScenariosProvider =
    Provider.family<List<ScenarioCostResult>, String>(
  (ref, domainId) => const CostEngine().computeScenarios(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  ),
);

final documentResultsProvider =
    Provider.family<List<DocumentResult>, String>(
  (ref, domainId) => const DocumentEngine().compute(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  ),
);

/// 관할 조회표는 아직 없다.
///
/// 표를 주지 않으므로 모든 규칙이 `tableUnavailable` 로 나온다. 화면은 그걸
/// **정직하게** 표시한다 — 없는 것을 숨기지 않는다.
final jurisdictionResultsProvider =
    Provider.family<List<JurisdictionResult>, String>(
  (ref, domainId) => JurisdictionEngine(tables: requireBundle(ref).courts.tables).compute(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  ),
);

final layerBlocksProvider = Provider.family<LayerBlocks, String>((ref, domainId) {
  return const LayerAssembler().assemble(
    domain: requireBundle(ref).byId(domainId),
    facts: ref.watch(caseFactsProvider(domainId)),
    deadlines: ref.watch(deadlineResultsProvider(domainId)),
    costs: ref.watch(costResultProvider(domainId)),
    interview: ref.watch(interviewStateProvider(domainId)),
  );
});

/// **기한만.** 「그날부터 생기는 것」은 여기 없다.
///
/// 「오늘 할 일」 카드와 D-day 는 지나면 잃는 날에만 붙는다. 대항력이
/// 생긴 날에 D-day 를 붙이면 쫓길 일이 아닌 것에 사람이 쫓긴다
/// (DECISIONS 135번).
final dueDeadlinesProvider = Provider.family<List<DeadlineResult>, String>(
  (ref, domainId) => [
    for (final result in ref.watch(deadlineResultsProvider(domainId)))
      if (result.kind == DeadlineKind.deadline) result,
  ],
);

/// **그날부터 생기는 것.** 세지 않고 나란히 낸다.
final startsFromProvider = Provider.family<List<DeadlineResult>, String>(
  (ref, domainId) => [
    for (final result in ref.watch(deadlineResultsProvider(domainId)))
      if (result.kind == DeadlineKind.startsFrom) result,
  ],
);

/// **그 안에 다 받아야 하는 것.** 신청 기한이 아니라 받는 기간이다.
///
/// 「오늘 할 일」에 넣지 않는다. 넣으면 「그날까지 신청하면 된다」로 읽히는데
/// 실제로는 **늦어지는 만큼 받을 날이 줄어든다**(DECISIONS 189번).
final receiveWindowProvider = Provider.family<List<DeadlineResult>, String>(
  (ref, domainId) => [
    for (final result in ref.watch(deadlineResultsProvider(domainId)))
      if (result.kind == DeadlineKind.receiveWithin) result,
  ],
);

/// 아직 안 걸린 기한들이 **언제 생기는지.**
///
/// 빈 화면은 정상 동작이어도 실패처럼 보인다. 왜 없는지와 언제 생기는지를
/// 말하려고 도메인이 선언한 문장을 모은다 (`Deadline.appearsWhen`).
final deadlineHintsProvider = Provider.family<List<String>, String>(
  (ref, domainId) {
    final fired = ref
        .watch(deadlineResultsProvider(domainId))
        .map((d) => d.id)
        .toSet();
    return [
      for (final deadline in requireBundle(ref).byId(domainId).deadlines)
        // **기한만 말한다.** 「그날부터 생기는 것」을 「이런 때에 기한이
        // 생겨요」에 섞으면 기한이 아닌 것을 기한처럼 읽게 된다
        // (DECISIONS 135번).
        //
        // 「그 안에 다 받아야 하는 것」은 함께 말한다 — 날짜가 없으면 화면에
        // 아무것도 안 서는 것은 똑같고, 그 빈자리를 설명할 문장이 필요하다.
        if (deadline.kind != DeadlineKind.startsFrom &&
            !fired.contains(deadline.id) &&
            deadline.appearsWhen.isNotEmpty)
          deadline.appearsWhen,
    ];
  },
);

/// 경계를 아슬아슬하게 넘겨 못 쓰게 된 절차.
///
/// 경계값은 코드에 없다 — `showIf` 에서 읽고 `nearMissWithin` 이 얼마나 가까워야
/// 가까운 것인지를 정한다.
final nearMissesProvider = Provider.family<List<NearMiss>, String>(
  (ref, domainId) => const NearMissChecker().check(
    requireBundle(ref).byId(domainId),
    ref.watch(caseFactsProvider(domainId)),
  ),
);

/// 지금 상황에서 밟을 수 있는 절차. `showIf` 로 거른다.
///
/// 정렬은 `step` 순 — 데이터가 정한 순서다.
final proceduresProvider = Provider.family<List<Procedure>, String>(
  (ref, domainId) {
    final data = ref.watch(showIfDataProvider(domainId));
    final list = [
      for (final procedure in requireBundle(ref).byId(domainId).procedures)
        if (procedure.showIf == null || _passes(procedure.showIf!, data))
          procedure,
    ]..sort((a, b) => a.step.compareTo(b.step));
    return list;
  },
);

/// `showIf` 가 보는 사실. **답에 계산 결과를 얹는다.**
///
/// 원래 `showIf` 는 사용자가 답한 것만 봤다. 그런데 상속의 「3개월이 지났는가」는
/// 답이 아니라 **기한 엔진이 낸 결과**다 — 물으면 우리가 셀 수 있는 것을
/// 사용자에게 시키는 것이 된다(DECISIONS 109번).
///
/// 새 모델을 만들지 않고 이름 규칙으로 이었다. 기한마다 `passed:<기한 id>` 를
/// 넣어 주고 데이터는 그걸 평범한 필드처럼 본다. 검증기도 같은 규칙을 안다.
final showIfDataProvider = Provider.family<Map<String, dynamic>, String>(
  (ref, domainId) {
    final data = ref.watch(caseFactsProvider(domainId)).toJsonLogicData();
    for (final deadline in ref.watch(deadlineResultsProvider(domainId))) {
      data['$kDeadlinePassedPrefix${deadline.id}'] = deadline.daysRemaining < 0;
    }
    return data;
  },
);

/// 기한 결과를 사실로 얹을 때 쓰는 이름표.
const String kDeadlinePassedPrefix = 'passed:';

/// 값이 없어 비교할 수 없으면 **보여주지 않는다.**
///
/// JsonLogic 은 null 비교에서 던진다. 아직 안 답한 것은 오류가 아니라 모르는
/// 것이므로, 판단할 수 없으면 조용히 뺀다.
bool _passes(Map<String, dynamic> showIf, Map<String, dynamic> data) {
  try {
    return JsonLogic.test(showIf, data);
  } on Object {
    return false;
  }
}

/// 지금 상황에서 띄울 「달라질 수 있다」 안내.
///
/// **날짜를 바꾸지 않는다.** 조건을 보고 한 줄 띄우는 것이 전부다.
/// 소멸시효. **채무자에게는 빈 목록이다.**
///
/// 같은 문장이 역할에 따라 정반대로 작동한다 — 받을 사람에게는 「포기하라」로,
/// 갚으라는 요구를 받은 사람에게는 「대응하지 말라」로 읽힌다. 그 사람에게는
/// 답변서·이의신청 기한이 이미 맨 위에 있고 그게 급하다(DECISIONS 108번).
final limitationRulesProvider =
    Provider.family<List<LimitationRule>, String>((ref, domainId) {
  final facts = ref.watch(caseFactsProvider(domainId));
  if (facts.toJsonLogicData()['userRole'] == 'debtor') return const [];

  final data = facts.toJsonLogicData();
  final bundle = requireBundle(ref);
  final own = bundle.byId(domainId).limitationRules;
  // **분야가 연수 갈래를 선언한 곳에만 붙는다.** 시효 안내는 받을 사람의
  // 말이고, 갚을 쪽 분야(빚 갚기가 어려울 때)에 붙으면 「기다리면 없어진다」로
  // 읽힌다 — 역할이 갈리면 같은 문장이 정반대로 작동한다(DECISIONS 108번).
  if (own.isEmpty) return const [];
  return [
    // **분야 것이 먼저다.** 몇 년인지는 분야마다 다르고(임금 3년 · 보증금
    // 10년), 그다음에 어느 분야에나 걸리는 것이 온다 — 기산점, 멈추는 일,
    // 내용증명 6개월, 판결 10년, 미리 포기 못 함.
    for (final rule in own)
      if (rule.showIf == null || _passes(rule.showIf!, data)) rule,
    // **한 벌만 둔다.** 분야마다 복사하면 개정이 났을 때 하나가 남는다 —
    // 소송구조를 `_shared_crisis` 에 둔 것과 같은 이유다(DECISIONS 133번).
    for (final rule in bundle.crisis.limitationRules)
      if (rule.showIf == null || _passes(rule.showIf!, data)) rule,
  ];
});

final cautionsProvider = Provider.family<List<Caution>, String>(
  (ref, domainId) {
    final data = ref.watch(showIfDataProvider(domainId));
    return [
      for (final caution in requireBundle(ref).byId(domainId).cautions)
        if (caution.showIf == null || _passes(caution.showIf!, data)) caution,
    ];
  },
);

/// 기간을 세는 법. 분야가 선언한 조문 그대로.
final periodRulesProvider = Provider.family<List<LegalBasis>, String>(
  (ref, domainId) => requireBundle(ref).byId(domainId).periodRules,
);

/// 어디에 내는가. 조건에 맞는 갈래만 남긴다.
///
/// 상대가 개인인지 법인인지 묻는 질문이 지금 인터뷰에 있지만(`q_debtor_type`),
/// **갈래를 자르지 않고 다 보여준다.** 「잘 모르겠습니다」를 고른 사람이 적지 않고,
/// 셋을 나란히 보면 자기에게 맞는 것을 스스로 고를 수 있다 (DECISIONS 72번).
/// 갈래마다 `showIf` 가 따로 있다. **조문이 지역을 직접 적어 둔 자리**가
/// 그렇다 — 채무자회생법 제3조 제10항~제13항이 법원 이름을 지역과 함께
/// 박아 두었다. 해당 없는 사람에게 세 줄을 더 보이면 그건 소음이다.
///
/// 안 걸린 지역에는 **아무 줄도 안 낸다.** 「없습니다」를 쓰지 않는다 —
/// 없다는 말은 「다른 데는 못 낸다」로 읽히는데 원칙 관할은 그대로 있다.
final jurisdictionGuideProvider = Provider.family<JurisdictionGuide?, String>(
  (ref, domainId) {
    final guide = requireBundle(ref).byId(domainId).jurisdictionGuide;
    if (guide == null) return null;
    if (guide.showIf == null && guide.branches.every((b) => b.showIf == null)) {
      return guide;
    }
    final data = ref.watch(showIfDataProvider(domainId));
    if (guide.showIf != null && !_passes(guide.showIf!, data)) return null;
    return guide.copyWith(
      branches: [
        for (final branch in guide.branches)
          if (branch.showIf == null || _passes(branch.showIf!, data)) branch,
      ],
    );
  },
);

/// 아직 어느 길로 갈지 못 정한 사람에게 보여줄 창구.
///
/// **위기 신호와 다른 목록이다.** 저쪽은 낱말이 걸려야 뜨고 이쪽은 아무 일이
/// 없어도 뜬다. 어느 창구인지는 분야가 정한다 (`askFirstChannels`) — 코드에
/// 기관명·번호를 적지 않는다.
final askFirstChannelsProvider =
    Provider.family<List<PublicChannel>, String>((ref, domainId) {
  final bundle = requireBundle(ref);
  final byId = {
    for (final channel in bundle.crisis.resolvedChannels) channel.id: channel,
    for (final channel in bundle.byId(domainId).resolvedChannels)
      channel.id: channel,
  };
  return [
    for (final id in bundle.byId(domainId).askFirstChannels)
      if (byId[id] != null) byId[id]!,
  ];
});

/// 소송구조 안내. **모든 분야에 같은 조문으로 붙는다.**
///
/// 분야마다 복사하지 않는다 — 조문이 같은데 다섯 벌이 있으면 개정이 났을 때
/// 하나가 남는다. `_shared_crisis` 가 한 벌 들고 있고 화면이 가져다 쓴다.
///
/// 붙는 자리는 **법원에 돈을 낼 일이 있는 화면**이다.
///
/// - 비용 갈래가 있으면 (떼인 돈 · 상속) — 비용 카드 바로 아래
/// - 비용 항목이 없어도 법원으로 가는 절차가 있으면 (임금의 민사) 함께 낸다
///
/// 갚는 쪽에는 안 붙는다. 비용 갈래도 법원 절차도 걷혀 있어서 자연히 빠진다
/// (DECISIONS 125번).
final legalAidProvider = Provider.family<Caution?, String>((ref, domainId) {
  final needsCourtMoney =
      ref.watch(costScenariosProvider(domainId)).isNotEmpty ||
          ref
              .watch(proceduresProvider(domainId))
              .any((procedure) => procedure.stage == ProcedureStage.court);
  if (!needsCourtMoney) return null;

  for (final caution in requireBundle(ref).crisis.cautions) {
    if (caution.id == 'ct_legal_aid') return caution;
  }
  return null;
});

/// 정리해서 가져가는 글. **화면이 아니라 데이터에서 만든다.**
///
/// 여기 들어가는 것은 **그 사람의 답으로 실제로 뜬 것 전부**다 — 화면이 이미
/// 고른 것을 그대로 쓴다. 접혔든 펼쳐졌든 상관없다(DECISIONS 134·246번).
final takeAwaySheetProvider = Provider.family<TakeAwaySheet, String>(
  (ref, domainId) => buildTakeAwaySheet(
    domain: requireBundle(ref).byId(domainId),
    session: ref.watch(interviewSessionProvider(domainId)),
    deadlines: ref.watch(deadlineResultsProvider(domainId)),
    procedures: ref.watch(proceduresProvider(domainId)),
    documents: ref.watch(documentResultsProvider(domainId)),
    costs: ref.watch(costScenariosProvider(domainId)),
    guide: ref.watch(jurisdictionGuideProvider(domainId)),
    places: ref.watch(jurisdictionResultsProvider(domainId)),
    cautions: ref.watch(cautionsProvider(domainId)),
    channels: ref.watch(askFirstChannelsProvider(domainId)),
    // **`clockProvider.today()` 를 직접 부르지 않는다.** `SystemKstClock` 은
    // 부를 때마다 `DateTime.now()` 를 읽어서, 앱을 열어 둔 채 자정을 넘기면
    // 글에 박히는 날짜와 나머지 화면이 어긋난다. `todayProvider` 가 그 값을
    // 한 번 고정하고 자정에 스스로 다시 센다.
    today: ref.watch(todayProvider),
  ),
);
