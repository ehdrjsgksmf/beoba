import 'dart:convert';
import 'dart:io';

import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';

import 'build_privacy_page.dart'
    show bakePolicy, parsePolicy, policyPrivateMark, policySourcePath;
import 'build_welfare.dart' show normalizeLawName;

/// 커밋·CI 게이트.
///
/// 1. 도메인 JSON 스키마 검증 (필수 필드 · whyAsk · tests[] · critical verified)
/// 2. 문구 검증 (필드별 SafetyFilter scope)
/// 3. 소스 코드 검증 (DateTime.now() 직접 호출 · 법률 수치 하드코딩 · 한글 문구)
///
/// 실패한 항목만 보고한다. 통과한 항목은 한 줄로.
Future<void> main(List<String> args) async {
  final root = _repoRoot();

  // ★ **시계를 돌릴 수 있어야 한다.** 날짜가 걸린 검사((z) 시행 예정 개정,
  // (an) 한시법)는 그날이 와야 처음 돌아 본다. 그때 처음 돌면 그때 처음
  // 틀린다. `--today=2027-06-01` 로 미리 겪어 본다(DECISIONS 275번).
  //
  // **기본은 진짜 오늘이다.** 이 문은 재려고 있는 것이지 넘기려고 있는 것이
  // 아니다 — 사람이 안 적으면 시스템 시계를 쓴다.
  final KstClock clock;
  final todayArg =
      args.where((a) => a.startsWith('--today=')).map((a) => a.substring(8));
  if (todayArg.isEmpty) {
    clock = const SystemKstClock();
  } else {
    final parsed = KstDate.tryParse(todayArg.last);
    if (parsed == null) {
      stderr.writeln('--today 는 YYYY-MM-DD 꼴이어야 합니다: ${todayArg.last}');
      exit(2);
    }
    clock = FixedKstClock(parsed);
    stdout.writeln('★ 오늘을 ${parsed.toIso()} 로 두고 잽니다 (--today)');
  }

  // **배포 직전에만 조이는 것이 있다.** 평소에 실패로 두면 아무 일도 못 하고,
  // 경고로만 두면 배포하는 날 아무도 안 본다. 그래서 같은 검사를 두 세기로
  // 돌린다 — `melos run verify` 는 경고, `melos run verify_release` 는 실패.
  final release = args.contains('--release');
  final failures = <String>[];
  final warnings = <String>[];

  stdout.writeln('버바 검증 — ${root.path}');

  // ── 1·2. 도메인 데이터 ────────────────────────────────────────────
  final domainsDir = Directory('${root.path}/packages/domain_data/assets/domains');
  if (!domainsDir.existsSync()) {
    stderr.writeln('도메인 디렉터리를 찾을 수 없습니다: ${domainsDir.path}');
    exit(2);
  }

  final files = domainsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var domainCount = 0;
  var testCaseCount = 0;

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    try {
      final loader = DomainLoader(today: clock.today());
      loader.loadFromJsonString(file.readAsStringSync());
      warnings.addAll(
        loader.lastReport.warnings.map((w) => '$name — $w'),
      );

      // 문구 검증은 unverified 항목까지 본다.
      // 지금 화면에 안 나가더라도 나중에 verified 로 바뀌면 그대로 나가기 때문이다.
      // keepAll 은 테스트·검증 전용이다. 여기가 검증 도구라서 쓰는 유일한 예외다.
      // ignore: invalid_use_of_visible_for_testing_member
      final full = DomainLoader(policy: VerificationPolicy.keepAll)
          .loadFromJsonString(file.readAsStringSync());
      final contentIssues = const ContentValidator().validate(full);
      failures.addAll(contentIssues.map((i) => '$name — $i'));

      testCaseCount += full.deadlines.fold<int>(0, (n, d) => n + d.tests.length) +
          full.costs.fold<int>(0, (n, c) => n + c.tests.length) +
          full.limitRules.fold<int>(0, (n, r) => n + r.tests.length);
      domainCount++;
    } on DomainValidationException catch (e) {
      failures.addAll(e.errors.map((i) => '$name — $i'));
    } on FormatException catch (e) {
      failures.add('$name — JSON 을 읽지 못했습니다: ${e.message}');
    }
  }

  // ── 2a-(-1). 쉬는 날 표 ──────────────────────────────────────────
  //
  // **안전 방향이 뒤집히는 자리다.** 공휴일을 적게 알면 덜 밀어 기한이 이르고
  // 그건 안전한 쪽인데, **잘못 넣으면 더 밀어 기한이 늦어진다.**
  failures.addAll(_checkHolidays(root, warnings));

  // ── 2a-0. 물어 놓고 안 읽는 필드 ─────────────────────────────────
  //
  // 74번 (a)의 반대 방향이다. 사용자가 답까지 해 줬는데 우리가 버리면,
  // 그 답으로 걸러야 할 것이 안 걸러진다.
  warnings.addAll(_checkUnreadFields(_loadAll(files)));

  // ── 2a-1. 인용은 원문이어야 한다 ─────────────────────────────────
  //
  // `legalBasis.text` 는 화면이 **quote scope 로 그리는 자리**다. 요약이 들어가면
  // 인용이 아니라 창작을 인용처럼 보이게 한 것이고, 3층 🟢 의 전제가 거기서
  // 무너진다. 실제로 그랬다 — `ba_upfront_fee` 의 조문 끝에 우리가 쓴
  // 「위반 시 3년 이하의 징역…」이 붙어 있었다.
  final glossaryFile = File(
    '${root.path}/packages/domain_data/assets/glossary/terms.json',
  );
  failures.addAll(
    _checkQuotedText([
      ...files,
      if (glossaryFile.existsSync()) glossaryFile,
    ]),
  );

  // ── 2a-2. 멈춰 세우는 경보는 셋을 넘지 않는다 ────────────────────
  //
  // 도메인 하나만 봐서는 못 한다. 경보는 `_shared_crisis` 와 분야 파일에
  // 나뉘어 있고, 화면은 둘을 합쳐서 본다.
  failures.addAll(_checkStopBudget(files));

  // ── 2b. 일상어 풀이 ──────────────────────────────────────────────
  // 도메인 하나만 봐서는 못 한다. (a) 자동 목록이 **모든 도메인의 label** 이라
  // 전부 읽은 뒤에야 검사할 수 있다.
  final screenTexts = <ScreenText>[];
  failures.addAll(_checkPlainLanguage(files, collect: screenTexts));

  // ── 2b-1. 용어 풀이 ──────────────────────────────────────────────
  //
  // **검색하지 않고 표시한다.** 밑줄을 그을 문장은 우리가 쓴 문장이라
  // 훑을 이유가 없다. `[[낱말]]` 토큰만 본다.
  final notes = <String>[];
  final termHints = <String>[];
  failures.addAll(_checkGlossary(root, screenTexts, warnings, termHints));

  // ── 2c. 법령 매니페스트 ───────────────────────────────────────────
  // 우리가 인용한 조문이 **어느 판본에서 나온 것인지** 기계가 알아야 한다.
  // 용어집도 조문을 인용한다. 빼면 「아무도 안 쓰는 조문」이 거짓이 된다.
  failures.addAll(
    _checkLawManifest(
      root,
      [...files, if (glossaryFile.existsSync()) glossaryFile],
      clock.today(),
      warnings,
    ),
  );

  // (r) 표마다 판본이 달라 행정구역 이름이 다르게 적힌다. 선택지에 없는
  // 이름으로 적힌 행은 아무에게도 안 걸린다.
  failures.addAll(_checkRegionNames(root, _loadAll(files), notes));

  // (u) 겉이 닮은 법이 값은 다르다. 한 갈래의 카드가 다른 법을 근거로 들면
  // 화면은 멀쩡하고 값만 틀린다.
  failures.addAll(_checkLawScope(files));

  // (w) 법률과 복지를 잇는 다리가 짐작이 아닌가. 없는 법령 이름을 적으면
  // 입구는 서는데 아무것도 안 걸린다.
  failures.addAll(_checkWelfareBridge(root, files));

  // (aa) 우리 문장에 나오는 금액은 인용에도 있어야 한다.
  warnings.addAll(_checkQuotedMoney(files, notes));

  // (x) 쉬운 말이 원래 문장보다 단정해지지 않았는가. 쉬운 말 작업에서 제일
  // 흔한 사고는 어려운 낱말이 아니라 **미끄러진 어미**다.
  // 쉬운 말이 몇 자리에 붙었는지는 여기서만 센다. 인수인계가 그 값을
  // 그대로 받아 쓴다 — **세는 법이 둘이면 문서가 어느 쪽으로도 맞다고 우긴다.**
  final plainCounts = <String, (int, int, int)>{};
  failures.addAll(
    _checkPlainKorean(root, files, notes, warnings, plainCounts),
  );

  // (y) 분야가 어느 묶음에 드는가. 첫 화면에는 묶음 줄만 선다.
  failures.addAll(_checkDomainGroups(root, files, notes, warnings));

  // (p) 조문을 갖고 있어도 **그 조문이 가리키는 표**가 없으면 값을 못 낸다.
  // 원본 확보는 「그 조문」이 아니라 「그 조문이 값을 내는 데 필요한 전부」다.
  failures.addAll(_checkBorrowedLaw(root, files, notes));

  // ── 2d. showIf 가 살아 있는가 ─────────────────────────────────────
  // 틀린 문장은 화면에 보이지만 **안 나오는 경고는 안 보인다.**
  failures.addAll(_checkShowIf(files, warnings));

  // (h) 조건이 멀쩡해도 **거기까지 못 가면 없는 것과 같다.**
  failures.addAll(_checkReachable(_loadAll(files), warnings));

  // (l) 여는 질문이 뒤에 있으면 그 갈래는 조용히 건너뛰어진다.
  failures.addAll(_checkQuestionOrder(_loadAll(files)));

  // (m) 날짜와 기한에 닿는 답은 미리 채우지 않는다.
  failures.addAll(_checkPrefill(_loadAll(files)));

  // (n) 세션을 여는 문은 하나다.
  failures.addAll(_checkSessionDoor(root));

  // (o) 집계로 나가는 칸은 다섯뿐이고, 분석 SDK 는 0개다.
  failures.addAll(_checkTally(root));

  // (i)(j) 세어서 보여만 준다. 막지는 않는다.
  notes.addAll(_checkAppliesFrom(_loadAll(files)));
  notes.addAll(_checkMoneyBasis(_loadAll(files)));
  notes.addAll(_checkEmptySections(_loadAll(files)));

  // ── 2e. 조문 꼴은 저장소 어디에 있든 매니페스트에 있어야 한다 ────
  //
  // **읽을 파일을 나열하면 다음 파일에서 또 뚫린다.** 실제로 그랬다 —
  // 매니페스트 생성기가 도메인 JSON 만 읽어서 용어집이 인용한 조문이
  // 판본 추적 밖에 있었고, 「원본을 못 받은 인용 0건」이 거짓일 뻔했다.
  failures.addAll(_checkArticleRefs(root, notes, warnings));

  // ── 2f. 테스트 하네스가 실기기의 조건을 지우지 않는가 ────────────
  failures.addAll(_checkTestHarness(root));

  // ── 2h. 멈춰 세우는 안내가 몇 개인가 ────────────────────────────
  //
  // **stop 이 늘어나면 화면이 멈춤투성이가 된다.** 막지는 않는다 —
  // 되돌릴 수 없는 자리가 정말 여럿인 분야가 있을 수 있다.
  for (final domain in _loadAll(files)) {
    final stops = domain.cautions
        .where((c) => c.display == AlertDisplay.stop)
        .map((c) => c.id)
        .toList();
    if (stops.isEmpty) continue;
    notes.add('${domain.id} — 멈춰 세우는 안내 ${stops.length}개 '
        '(${stops.join(" · ")})');
    if (stops.length > _stopBudget) {
      warnings.add('${domain.id} — 멈춰 세우는 안내가 ${stops.length}개입니다. '
          '$_stopBudget개를 넘으면 큰 카드가 기본이 되고, 기본이 되면 '
          '아무것도 못 멈춥니다');
    }
  }

  // ── 2g. 시효는 계산하지 않는다 ───────────────────────────────────
  failures.addAll(_checkLimitation(_loadAll(files)));

  // ── 3. 소스 코드 ─────────────────────────────────────────────────
  final sourceIssues = _checkSources(root, notes, warnings);
  failures.addAll(sourceIssues);

  // (s) 기다리는 화면은 위젯이 아니라 HTML 이다. 그래도 화면에 나가는 글자다.
  failures.addAll(_checkWebHtml(root));

  // (t) 인수인계 머리말이 뒤처지면 다음 사람이 이미 있는 걸 또 만든다.
  failures.addAll(_checkHandover(root, notes, plainCounts));

  // (ab) 앱이 읽을 분야 목록과 실제 파일이 같은가.
  failures.addAll(_checkBundledDomains(root, notes));

  // (v) 기관이 알려 준 것에는 출처 딱지가 반드시 붙는다.
  failures.addAll(_checkWelfareNotice(root));

  // (ac) 조문에 붙은 헌재 결정 표시를 사람이 한 번은 봤는가.
  failures.addAll(_checkCourtMarks(root, notes));

  // (ad) 되받는 말과 물어볼 말 — 사람이 그대로 읽을 수 있는가.
  failures.addAll(_checkSpokenLines(files, notes, warnings));

  // (ae) 빈 절이 왜 비었는지 — 「원래 없다」와 「우리 쪽 사정」을 가른다.
  failures.addAll(_checkEmptyReasons(files, notes, warnings));

  // (af) 글에 화면 조작을 가리키는 말이 들어가지 않는가.
  failures.addAll(_checkSpokenPlace(files, notes));

  // (ag) 만들어 놓고 못 찾게 해 둔 조각이 없는가.
  failures.addAll(_checkNoDeadEnds(root, files, notes));

  // (ah) 개인정보처리방침이 아직 참인가.
  failures.addAll(_checkPrivacyPolicy(root, notes, warnings, release: release));

  // (ai) 원격에 올릴 수 없는 것이 추적 목록에 들어오지 않았는가.
  failures.addAll(_checkNeverPublish(root, notes));

  // (aj) 기다리는 화면이 지표에 안 보이는 채로 시작하지 않는가.
  failures.addAll(_checkSplashVisible(root, notes));

  // (am) 카드가 무엇에 기대어 서 있는가 — 조문 · 기관 안내 · 아무것도 아님.
  failures.addAll(_checkCautionFooting(files, notes, warnings));

  // (ak) 같은 조문을 두 분야가 인용하면 — 두 벌이 생긴다.
  failures.addAll(_checkSharedCitations(root, files, notes));

  // (al) 조문을 넘었을지 모르는 인용이 늘지 않는가 — 톱니.
  failures.addAll(_checkCitationDebt(root, files, notes));

  // (ao) 절차마다 「이 길을 만드는 법」을 사람이 한 번 판정했는가.
  failures.addAll(_checkPathLaw(root, _loadAll(files), notes));

  // (ap) 한 분야 안에서 절차의 step 이 겹치지 않는가 — 겹치면 순서가 운에 달린다.
  failures.addAll(_checkProcedureSteps(_loadAll(files), notes));

  // (z) 시행일이 정해진 개정은 그날 조용히 우리를 틀리게 만든다.
  // (an) 한시법은 그날 법 자체가 없어진다.
  final lifespanIssues = <String>[];
  final lifespan = _Lifespan.read(root, lifespanIssues);
  failures.addAll(lifespanIssues);
  failures.addAll(_checkPendingAmendments(root, clock, lifespan, notes));
  failures.addAll(_checkSunset(files, clock, lifespan, notes));

  // ── 보고 ────────────────────────────────────────────────────────
  stdout.writeln('  도메인 $domainCount개 · 정답지 $testCaseCount건');

  if (warnings.isNotEmpty) {
    stdout.writeln('\n🟡 경고 ${warnings.length}건');
    for (final warning in warnings) {
      stdout.writeln('  $warning');
    }
  }

  for (final note in notes) {
    stdout.writeln('  $note');
  }

  if (termHints.isNotEmpty) {
    stdout.writeln('\n✏️ 밑줄 후보 ${termHints.length}건 '
        '(사람이 눈으로 고릅니다. 자동으로 붙이지 않습니다)');
    for (final hint in termHints) {
      stdout.writeln('  $hint');
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('\n✅ 통과');
    return;
  }

  stderr.writeln('\n❌ 실패 ${failures.length}건');
  for (final failure in failures) {
    stderr.writeln('  $failure');
  }
  exit(1);
}

/// 한 줄 풀이 안에 어려운 말이 들어 있지 않은지 본다.
///
/// **설명 안에 설명이 필요한 말이 있으면 설명이 아니다.**
/// 금지어는 세 갈래다 — 모든 도메인의 `label`(자동) · [LegalJargon.manualJargon](수동)
/// · **자기 자신의 label**(동어반복).
List<String> _checkPlainLanguage(
  List<File> files, {
  List<ScreenText>? collect,
}) {
  final issues = <String>[];

  // 검수 전 항목의 문구도 본다. 지금 화면에 안 나가도 나중에 그대로 나간다.
  // ignore: invalid_use_of_visible_for_testing_member
  final loader = DomainLoader(policy: VerificationPolicy.keepAll);
  final domains = <Domain>[];
  for (final file in files) {
    try {
      domains.add(loader.loadFromJsonString(file.readAsStringSync()));
    } on Object {
      // 스키마 오류는 앞 단계가 이미 보고했다.
      continue;
    }
  }

  // (a) 자동 — 우리가 "어렵다" 고 판단한 말들은 이미 label 에 모여 있다.
  final labels = <String>{
    for (final domain in domains) ...[
      for (final item in domain.costs) item.label,
      for (final item in domain.documents) item.label,
      for (final item in domain.deadlines) item.label,
      for (final item in domain.jurisdiction) item.label,
      for (final item in domain.procedures) item.label,
    ],
  }..removeWhere((label) => label.isEmpty);

  void check(String where, String text, String self) {
    if (text.isEmpty) return;
    final found = LegalJargon.find(text, labels: labels, self: self);
    if (found == null) return;
    issues.add(
      "$where — 풀이에 어려운 말 \"${found.word}\" 가 있습니다. "
      "설명 안에 설명이 필요한 말이 있으면 설명이 아닙니다",
    );
  }

  // 화면에 나가는 나머지 문장들. **이제 실패다.**
  //
  // 경고로 시작한 이유는 넓히면 오탐이 나오기 때문이었다. 오탐을 거르기 전에
  // 빌드를 세우면 아무것도 못 한다 (각하→생각하면 · 최고→최고예요). 예외 패턴과
  // 음성 골든셋으로 오탐을 구조로 막았고(DECISIONS 46번), 걸린 19건을 다 고쳤다.
  // 이제 새로 들어오는 문장을 막는 자리다.
  //
  // **자동 수집(labels)을 넘기지 않는다.** 그 목적은 "풀이 안에서 다른 항목을
  // 참조하지 마라" 였고 일반 문장에는 해당이 없다. `계좌이체 내역` 은 어려운 말이
  // 아닌데 자동 수집에는 그걸 가릴 방법이 없다.
  //
  // [seen] 은 **분야 하나를 훑는 동안** 이미 풀이가 붙은 낱말이다. 두 번째부터는
  // 괄호를 요구하지 않는다 — 같은 설명을 세 문항 만에 또 하면 안내가 아니라
  // 되풀이다 (DECISIONS 47번).
  void sentence(
    Set<String> seen,
    String where,
    String? raw, {
    String? self,
  }) {
    if (raw == null || raw.isEmpty) return;
    collect?.add(ScreenText(where, raw));

    // **검사는 대괄호를 뗀 문장을 본다.** 화면이 보여주는 것도 이쪽이다.
    // 원문을 그대로 보면 `[[` 때문에 낱말이 갈라져 금지어가 빠져나간다.
    final text = stripTerms(raw);

    // 밑줄을 단 낱말은 **이미 풀이가 붙은 것**이다. 눌러야 보이는 것뿐이라
    // 뒤 문장에서 괄호를 또 요구하면 화면이 괄호 밭이 된다.
    //
    // 낱말 **안쪽**도 함께 덮는다 — `[[개인회생]]` 의 시트가 「회생」까지
    // 설명한다. 안 덮으면 토큰을 박은 그 자리에서 괄호를 또 요구한다.
    for (final marked in termsIn(raw)) {
      seen.add(marked);
      for (final term in LegalJargon.allTerms) {
        if (marked.contains(term.word)) seen.add(term.word);
      }
    }

    // 사물을 높이지 않는다. 금액·서류·기한에 `-이시-` 를 붙일 수 없다.
    final honorific = ObjectHonorific.find(text);
    if (honorific != null) {
      issues.add(
        '$where — 사물을 높이고 있습니다 "$honorific". '
        '높이는 대상은 사용자뿐입니다',
      );
    }

    for (final hit in LegalJargon.findAll(text, self: self)) {
      if (hit.kind == JargonKind.replace) {
        issues.add(
          '$where — 어려운 말 "${hit.word}" 를 쉬운 말로 갈아타세요. '
          '사용자가 이 말을 마주칠 일이 없습니다',
        );
        continue;
      }
      if (seen.contains(hit.word)) continue;
      seen.add(hit.word);
      if (_hasGloss(text, hit.word)) continue;
      issues.add(
        '$where — 공식 용어 "${hit.word}" 에 풀이를 붙이세요. '
        '이 분야에서 처음 나오는 자리입니다',
      );
    }
  }

  /// 선택지 라벨. **괄호를 요구하지 않는다.**
  ///
  /// 선택지는 나란히 놓고 고르는 것이라 괄호가 끼면 대조가 무너진다. 풀이는
  /// `whatIsThis` 로 따로 붙인다. 그 풀이가 있으면 사용자가 뜻을 읽은 것이므로
  /// 뒤 문장에서 다시 요구하지 않는다.
  void optionLabel(
    Set<String> seen,
    String where,
    String label, {
    required bool explained,
  }) {
    for (final hit in LegalJargon.findAll(label)) {
      if (hit.kind == JargonKind.replace) {
        issues.add(
          '$where — 어려운 말 "${hit.word}" 를 쉬운 말로 갈아타세요. '
          '사용자가 이 말을 마주칠 일이 없습니다',
        );
        continue;
      }
      if (explained) seen.add(hit.word);
    }
  }

  for (final domain in domains) {
    // ── 필수 풀이 (실패) ─────────────────────────────────────────────
    for (final item in domain.costs) {
      check('${domain.id}.costs.${item.id}', item.whatIsThis, item.label);
    }
    for (final item in domain.documents) {
      check('${domain.id}.documents.${item.id}', item.whatIsThis, item.label);
    }
    for (final item in domain.deadlines) {
      check('${domain.id}.deadlines.${item.id}', item.whatIsThis, item.label);
    }
    for (final item in domain.jurisdiction) {
      check('${domain.id}.jurisdiction.${item.id}', item.whatIsThis, item.label);
    }
    for (final item in domain.procedures) {
      check('${domain.id}.procedures.${item.id}', item.whatIsThis, item.label);
    }
    for (final question in domain.intake) {
      for (final option in question.options) {
        final text = option.whatIsThis;
        if (text == null) continue;
        check(
          '${domain.id}.intake.${question.id}.${option.value}',
          text,
          option.label,
        );
      }
    }

    // ── 화면에 나가는 나머지 문장 (실패) ─────────────────────────────
    //
    // **사용자가 읽는 순서대로 훑는다.** "처음 나오는 자리" 를 판정하려면 순서가
    // 곧 규칙이기 때문이다. 분야 카드 → 인터뷰 → 결과(절차·자원·조회·경보·창구).
    final id = domain.id;
    final seen = <String>{};

    // 분야 카드에 그대로 보인다.
    sentence(seen, '$id.name', domain.name);
    sentence(seen, '$id.description', domain.description);

    // 인터뷰. 사용자가 답하려면 먼저 읽어야 한다. order 가 화면 순서다.
    final intake = [...domain.intake]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final question in intake) {
      final path = '$id.intake.${question.id}';
      sentence(seen, '$path.text', question.text);
      sentence(seen, '$path.whyAsk', question.whyAsk);
      // 되받는 말도 화면에 나간다. `{value}` 는 답이 끼워질 자리라 그대로 둔다.
      sentence(seen, '$path.echo', question.echo);
      for (final option in question.options) {
        optionLabel(
          seen,
          '$path.${option.value}.label',
          option.label,
          explained: (option.whatIsThis ?? '').isNotEmpty,
        );
      }
    }

    // 절차 본문. 조문을 풀어 쓴 자리라 어려운 말이 겹쳐 있다.
    for (final procedure in domain.procedures) {
      final path = "$id.procedures.${procedure.id}";
      // 자기 항목의 안내문에서 자기 이름을 쓰는 것은 당연하다.
      final self = procedure.label;
      sentence(seen, "$path.caution", procedure.caution, self: self);
      sentence(seen, "$path.detail", procedure.detail, self: self);
      sentence(seen, "$path.whenApplicable", procedure.whenApplicable, self: self);
      sentence(seen, "$path.noticeToUser", procedure.noticeToUser, self: self);
    }

    // 소멸시효. **계산하지 않고 갈래로 내는 자리**라 문장이 특히 위험하다 —
    // 「지났습니다」 한 마디가 사람을 포기시킨다.
    for (final rule in domain.limitationRules) {
      final path = '$id.limitationRules.${rule.id}';
      sentence(seen, '$path.label', rule.label);
      sentence(seen, '$path.note', rule.note);
    }

    // 「달라질 수 있다」 안내. 화면에 그대로 나간다.
    for (final caution in domain.cautions) {
      final path = '$id.cautions.${caution.id}';
      sentence(seen, '$path.condition', caution.condition);
      sentence(seen, '$path.consequence', caution.consequence);
    }

    // 못 맡은 값에 할 말.
    for (final group in domain.exclusiveGroups) {
      sentence(
        seen,
        '$id.exclusiveGroups.${group.id}.unknownNote',
        group.unknownNote,
      );
    }

    // 자원 안내. `Resource` 에는 note 가 없고 benefit 이 그 자리다.
    for (final resource in domain.resources) {
      final path = '$id.resources.${resource.id}';
      sentence(seen, '$path.name', resource.name);
      sentence(seen, '$path.benefit', resource.benefit);
      for (final (index, rule) in resource.eligibility.indexed) {
        sentence(seen, '$path.eligibility[$index]', rule.label);
      }
    }

    // 조회 도구 안내.
    for (final tool in domain.lookupTools) {
      sentence(seen, '$id.lookupTools.${tool.id}.label', tool.label);
      sentence(seen, '$id.lookupTools.${tool.id}.hint', tool.hint);
    }

    // 브로커 경보의 사실 확인 문구. phrase 는 사기꾼 말 인용이라 제외한다.
    for (final alert in domain.brokerAlerts) {
      sentence(seen, '$id.brokerAlerts.${alert.id}.truth', alert.truth);
    }

    // 공적 창구. org(기관 공식 명칭)는 제외 — 전화·검색에 그대로 쓰인다.
    for (final entry in domain.publicChannels) {
      if (entry is! PublicChannelFull) continue;
      final channel = entry.channel;
      final path = '$id.publicChannels.${channel.id}';
      sentence(seen, '$path.label', channel.label);
      sentence(seen, '$path.note', channel.note);
    }

    // 차단 화면은 **자기만의 seen 을 쓴다.** 막다른 골목이고, 인터뷰 중간에
    // 곧장 튀어나온다. 앞 화면에서 풀이를 봤다고 가정할 수 없다.
    for (final stop in domain.hardStops) {
      final stopSeen = <String>{};
      final path = '$id.hardStops.${stop.id}';
      sentence(stopSeen, '$path.title', stop.title);
      sentence(stopSeen, '$path.message', stop.message);
      for (final (index, item) in stop.checklist.indexed) {
        sentence(stopSeen, '$path.checklist[$index]', item);
      }
    }
  }

  return issues;
}

/// 화면에 나가는 문장 한 줄. **대괄호를 떼지 않은 원문**이다.
class ScreenText {
  const ScreenText(this.where, this.raw);

  /// `debt_recovery.cautions.ct_x.condition`
  final String where;
  final String raw;

  /// 「한 카드」의 단위. 앞 세 마디가 곧 항목 하나다 —
  /// `debt_recovery.cautions.ct_x`. 화면에서 카드 한 장이 되는 자리다.
  String get card {
    final parts = where.split('.');
    return parts.length <= 3 ? where : parts.take(3).join('.');
  }
}

/// 화면에서 쓰지 않기로 한 말.
///
/// **「인용」** — 민사소송법에서 이 말이 나오는 자리는 전부 「서면 등의 인용」처럼
/// **문서를 끌어다 붙인다**는 뜻이다. 우리가 쓰려던 뜻(법원이 청구를 받아들이는
/// 것)으로는 조문에 없다. 법에 없는 실무 은어다. 「청구를 받아들이면」이라고
/// 우리 말로 쓴다.
///
/// **「채무명의」** — 지금 법의 이름은 집행권원이다(민사집행법 제56조 제목이
/// 「그 밖의 집행권원」이다).
const Map<String, String> _retiredWords = {
  '인용': '「청구를 받아들이면」처럼 우리 말로 쓰세요. 법에 그 뜻으로 없는 실무 은어입니다',
  '채무명의': '지금 법의 이름은 집행권원입니다 (민사집행법 제56조)',
};

/// 한 줄 풀이의 상한. 시트를 여는 사람은 **한 낱말이 막혀서** 연다.
/// 거기서 또 막히면 안 된다.
const int _oneLinerMax = 40;

/// 밑줄 몇 개까지. **세는 단위는 카드가 아니라 글자 수다.**
///
/// 카드가 길면 카드 하나가 화면 세 개 분량이라 카드당 셋은 화면당 하나가
/// 되고, 카드가 짧으면 셋이 밑줄 밭이 된다. 「손가락으로 한 번에 보이는
/// 만큼」에 셋 — 이어지는 문장 [_underlineWindow]자마다 [_underlinesPerWindow]개다.
const int _underlinesPerWindow = 3;
const int _underlineWindow = 300;

/// 용어 풀이 — **검색하지 않고 표시한다.**
///
/// 밑줄을 그을 문장은 우리가 쓴 문장이다. 훑을 이유가 없다. 그래서 화면
/// 문자열을 용어집 키로 뒤지지 않고 `[[낱말]]` 토큰만 본다. 「주소가」 안의
/// 「소가」, 「생각하다」 안의 「각하」 같은 문제가 **설계 단계에서 사라진다.**
List<String> _checkGlossary(
  Directory root,
  List<ScreenText> screen,
  List<String> warnings,
  List<String> hints,
) {
  final issues = <String>[];
  final file = File(
    '${root.path}/packages/domain_data/assets/glossary/terms.json',
  );
  if (!file.existsSync()) {
    return ['용어집을 찾을 수 없습니다: ${file.path}'];
  }

  final Glossary glossary;
  try {
    glossary = Glossary.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  } on Object catch (e) {
    return ['용어집을 읽지 못했습니다: $e'];
  }

  final byTerm = {for (final entry in glossary.terms) entry.term: entry};
  // 풀이 안에서 가리킨 말. 이것도 용어집에 있어야 하고, 「안 쓰는 말」로
  // 세지 않는다 — 화면 문장에는 없어도 시트에서는 쓰이고 있다.
  final linked = <String>{};
  // 어느 풀이가 어느 말을 가리키는가. 순환을 찾으려면 그래프가 있어야 한다.
  final refs = <String, List<String>>{};
  if (byTerm.length != glossary.terms.length) {
    issues.add('glossary — 같은 말이 두 번 있습니다');
  }

  // ── 항목 자체 ────────────────────────────────────────────────────
  final laws = _manifestVersions(root);
  for (final entry in glossary.terms) {
    final where = 'glossary.${entry.term}';

    // **길이는 사용자가 읽는 글자로 센다.** 대괄호는 화면에 안 나간다.
    final shownLine = stripTerms(entry.oneLiner);
    if (shownLine.runes.length > _oneLinerMax) {
      issues.add('$where — 한 줄 풀이가 $_oneLinerMax자를 넘습니다 '
          '(${shownLine.runes.length}자). 시트를 여는 사람은 한 낱말이 '
          '막혀서 엽니다');
    }

    // 풀이도 문구다. 금지 표현과 어려운 말을 똑같이 본다.
    for (final violation in SafetyFilter.scan(shownLine, where: where)) {
      issues.add('$where — 금지 표현: ${violation.excerpt}');
    }

    issues.addAll(_checkWholeWord(where, entry.oneLiner, byTerm.keys));

    // 한 줄 풀이도 토큰을 쓸 수 있다. 40자 안에서는 괄호로 풀 자리가 없고,
    // **밑줄이 곧 그 자리를 여는 문**이라 같은 장치를 그대로 쓴다.
    // 자기 자신을 가리키면 돌고 돈다.
    final marked = termsIn(entry.oneLiner);
    linked.addAll(marked);
    refs[entry.term] = marked;
    final covered = <String>{
      for (final term in marked) ...[
        term,
        for (final jargon in LegalJargon.allTerms)
          if (term.contains(jargon.word)) jargon.word,
      ],
      // **자기 이름의 조각은 자기 설명에서 써도 된다.** 「확정판결」을
      // 「…굳어지는 판결이에요」로 푸는 것은 동어반복이 아니라 정의의
      // 보통 꼴이다 — 넓은 말로 좁은 말을 설명한다.
      for (final jargon in LegalJargon.allTerms)
        if (entry.term.contains(jargon.word)) jargon.word,
    };
    final jargon = LegalJargon.find(shownLine, self: entry.term);
    if (jargon != null && !covered.contains(jargon.word)) {
      issues.add('$where — 풀이에 어려운 말 "${jargon.word}" 가 있습니다. '
          '설명 안에 설명이 필요한 말이 있으면 설명이 아닙니다');
    }

    if (entry.kind.hasStatute) {
      final basis = entry.lawRef;
      if (basis == null || (basis.text ?? '').isEmpty) {
        issues.add('$where — 🟢 인데 조문 원문이 없습니다. '
            '원문이 없으면 🟢 가 아닙니다');
        continue;
      }
      if (entry.effective.isEmpty) {
        issues.add('$where — 🟢 인데 시행일이 없습니다');
      }
      for (final ref in [basis, ...entry.alsoBasis]) {
        final law = ref.law ?? '';
        final effective = laws[law];
        if (effective == null) {
          issues.add('$where — 매니페스트에 없는 법령입니다: $law');
        } else if (ref == basis && entry.effective != effective) {
          issues.add('$where — 시행일이 매니페스트와 다릅니다: '
              '${entry.effective} ≠ $effective ($law)');
        }
      }
    } else {
      // **🟡 에 근거 배지를 붙이면 안 된다.** 우리 말에 조문 이름을 달면
      // 법이 그렇게 정했다는 뜻이 된다.
      if (entry.lawRef != null || entry.alsoBasis.isNotEmpty) {
        issues.add('$where — 🟡 인데 조문이 붙어 있습니다. '
            '풀이가 우리 말이면 근거를 달지 않습니다');
      }
      if (entry.effective.isNotEmpty) {
        issues.add('$where — 🟡 인데 시행일이 있습니다');
      }
    }
  }

  // ── 화면 문장 쪽 ─────────────────────────────────────────────────
  final used = <String>{};
  final perCard = <String, List<String>>{};
  final bareUses = <(String, String, String)>[];
  // 카드가 실제로 몇 글자인가. 밑줄 상한이 여기서 나온다.
  final cardLength = <String, int>{};

  for (final line in screen) {
    // (b) 짝이 안 맞는 대괄호가 화면으로 샌다.
    if (hasStrayBrackets(line.raw)) {
      issues.add('${line.where} — 대괄호가 화면에 남습니다. '
          '토큰은 [[낱말]] 꼴이어야 합니다');
    }

    final shownLine = stripTerms(line.raw);
    cardLength[line.card] = (cardLength[line.card] ?? 0) + shownLine.length;

    issues.addAll(_checkWholeWord(line.where, line.raw, byTerm.keys));

    for (final term in termsIn(line.raw)) {
      used.add(term);
      if (!byTerm.containsKey(term)) {
        issues.add('${line.where} — 용어집에 없는 말입니다: $term');
      }
      (perCard[line.card] ??= []).add(term);
    }

    // (g) 화면에서 쓰지 않기로 한 말.
    for (final entry in _retiredWords.entries) {
      if (!shownLine.contains(entry.key)) continue;
      issues.add('${line.where} — 화면에서 쓰지 않는 말입니다 '
          '"${entry.key}". ${entry.value}');
    }

    // 개발용 힌트는 카드를 다 모은 뒤에 낸다 — 같은 카드에 이미 밑줄이
    // 있으면 두 번째 자리는 밑줄을 **안 다는 것이 맞다.**
    final bare = stripTerms(line.raw.replaceAll(RegExp(r'\[\[[^\]]*\]\]'), ''));
    for (final term in byTerm.keys) {
      // 흔한 말 안에 숨은 낱말을 그대로 세면 힌트가 쓸모없어진다 —
      // 「받아야 할 돈**인가**요?」의 `인가` 가 그렇다. 어려운 말 목록이 이미
      // 그 예외를 들고 있으므로 **같은 예외를 그대로 쓴다** (DECISIONS 46번).
      if (KeywordMatch.occurs(bare, term, exceptPatterns: _termExcept(term))) {
        bareUses.add((line.where, line.card, term));
      }
    }
  }

  // **자동으로 붙이면 안 된다.** 밑줄을 빠뜨린 자리를 사람이 눈으로 고르기
  // 위한 목록이다. 화면에는 나가지 않는다.
  for (final (where, card, term) in bareUses) {
    if (perCard[card]?.contains(term) ?? false) continue;
    hints.add('$where — 밑줄 없이 쓰인 용어집 낱말: $term');
  }

  // (f) 이어지는 문장 300자당 셋 · 같은 말은 첫 번째만.
  for (final entry in perCard.entries) {
    final terms = entry.value;
    final distinct = terms.toSet();
    final length = cardLength[entry.key] ?? 0;
    final allowed = (length / _underlineWindow).ceil().clamp(1, 100) *
        _underlinesPerWindow;
    if (distinct.length > allowed) {
      issues.add('${entry.key} — 밑줄이 ${distinct.length}개입니다. '
          '이어지는 문장 $length자에는 $allowed개까지입니다 '
          '($_underlineWindow자당 $_underlinesPerWindow개)');
    }
    if (terms.length != distinct.length) {
      issues.add('${entry.key} — 같은 말에 밑줄을 두 번 달았습니다. '
          '그 카드에서 처음 나오는 자리에만 답니다');
    }
  }

  for (final term in linked) {
    if (!byTerm.containsKey(term)) {
      issues.add('glossary — 풀이가 용어집에 없는 말을 가리킵니다: $term');
    }
  }
  issues.addAll(_checkTermCycles(refs));

  // (i) 아직 안 쓰는 말. **막지 않는다.** 쓸 자리가 생기면 그때 박는다.
  for (final term in byTerm.keys) {
    if (!used.contains(term) && !linked.contains(term)) {
      warnings.add('glossary.$term — 아직 어느 문장에서도 안 쓰는 말입니다');
    }
  }

  return issues;
}

/// **토큰은 낱말 하나를 통째로 감싼다.**
///
/// 「확정[[판결]]과 같은 힘」이라고 쓰면 화면에서 「확정판결」의 뒤 두 글자에만
/// 점선이 그어진다. 읽는 사람은 「확정」과 「판결」이 다른 말인 줄 안다.
/// 아니다 — 「확정판결」이 하나의 낱말이다.
///
/// 앞쪽은 한글이 붙기만 하면 실패다. 뒤쪽은 조사·어미가 붙는 자리라
/// (「[[조정]]을」) 막을 수 없고, 대신 **이어 붙은 글자까지가 다른 용어집
/// 낱말이 되는 경우**만 잡는다.
List<String> _checkWholeWord(
  String where,
  String raw,
  Iterable<String> terms,
) {
  final issues = <String>[];
  final hangul = RegExp(r'[가-힣]');

  for (final match in RegExp(r'\[\[([^\[\]\n]+)\]\]').allMatches(raw)) {
    final word = match.group(1)!;

    if (match.start > 0 && hangul.hasMatch(raw[match.start - 1])) {
      issues.add('$where — 낱말 중간을 잘랐습니다: '
          '"${raw[match.start - 1]}[[$word]]". 토큰은 낱말을 통째로 감쌉니다');
    }

    final tail = raw.substring(match.end);
    for (final other in terms) {
      if (other == word) continue;
      if (other.startsWith(word) && tail.startsWith(other.substring(word.length))) {
        issues.add('$where — 낱말 중간을 잘랐습니다: '
            '"[[$word]]" 뒤가 이어져 "$other" 입니다. 통째로 감싸세요');
      }
    }
  }
  return issues;
}

/// 풀이가 서로를 가리키다 **돌고 도는가.**
///
/// 자기 자신을 가리키는 것은 길이 1짜리 순환일 뿐이라 같은 검사로 잡힌다.
/// 확정판결 → 판결 → 확정 → 확정판결 처럼 자기 이름은 어디에도 없는데
/// 도는 경우가 진짜 위험한 쪽이다.
List<String> _checkTermCycles(Map<String, List<String>> refs) {
  final issues = <String>[];
  final done = <String>{};

  void walk(String term, List<String> path) {
    final at = path.indexOf(term);
    if (at >= 0) {
      final loop = [...path.sublist(at), term].join(' → ');
      issues.add('glossary — 풀이가 돌고 돕니다: $loop');
      return;
    }
    if (!done.add(term)) return;
    for (final next in refs[term] ?? const <String>[]) {
      walk(next, [...path, term]);
    }
  }

  for (final term in refs.keys.toList()..sort()) {
    walk(term, const []);
  }
  return issues;
}

/// 이 낱말을 덮는 예외 패턴. 어려운 말 목록에 있으면 그 예외를 빌려 쓴다.
List<String> _termExcept(String word) {
  for (final term in LegalJargon.allTerms) {
    if (term.word == word) return term.except;
  }
  return const [];
}

/// 문서의 인용 블록. `>` 인용문과 「」·`"` 로 감싼 원문.
final RegExp _docQuote = RegExp(r'^\s*(>|\||```)|「[^」]*제\s?\d+조');

/// 사람이 판단해 달아 둔 표시.
///
/// ```
/// (불채택)  안 쓰기로 했다. 나중에 마음이 바뀌면 표시를 지운다
/// (조건부)  아직 조건이 안 왔다. 조건이 오면 표시를 지운다
/// ```
///
/// **표시를 지우면 경고가 되살아난다.** 그게 이 표시의 값어치다.
final RegExp _docMark = RegExp(r'\((불채택|조건부)\)');

/// `MediaQueryData` 를 새로 만드는 자리.
final RegExp _mediaQueryLiteral = RegExp(r'(?<![\w.$])MediaQueryData\s*\(');

/// 시효 문장이 선을 넘지 않는가.
///
/// 화면 검사(위젯)는 그 화면에 실제로 뜬 것만 본다. 데이터에 들어와 있는데
/// 조건이 안 맞아 안 뜨는 문장은 **다음 사람의 화면에서 뜬다.**
List<String> _checkLimitation(List<Domain> domains) {
  final issues = <String>[];

  for (final domain in domains) {
    for (final rule in domain.limitationRules) {
      final where = '${domain.id}.limitationRules.${rule.id}';
      final text = '${rule.label} ${rule.note}';

      for (final banned in _limitationBanned) {
        if (!text.contains(banned)) continue;
        issues.add('$where — 시효 문장에 "$banned" 가 있습니다. '
            '지났는지 남았는지는 우리가 말하지 않습니다');
      }
      final year = _calculatedYear.firstMatch(text);
      if (year != null) {
        issues.add('$where — 연도 "${year.group(0)}" 가 있습니다. '
            '우리가 계산했다는 뜻입니다. 연수(10년·3년)는 조문에 있는 말이라 괜찮습니다');
      }
    }
  }
  return issues;
}

/// **하네스가 실기기의 조건을 지우면, 테스트 수는 늘어도 본 것은 없다.**
///
/// `MediaQueryData(textScaler: …)` 로 통째로 덮어쓰고 있었다. 글자 배율은
/// 들어갔지만 `size` 가 0 이고 `viewInsets`·`padding` 이 0 이 됐다.
/// 레이아웃은 제약으로 도니까 화면은 멀쩡해 보이는데
///
/// ```
/// resizeToAvoidBottomInset   자판이 올라온 화면이 한 번도 안 돌았다
/// SafeArea                   노치·제스처 바가 없는 폰만 시험했다
/// MediaQuery.sizeOf          0 을 읽고 있었다 (바텀시트 최대 높이가 그렇다)
/// ```
///
/// **`fromView` 로 시작해서 바꿀 값만 `copyWith` 한다.** 그게 유일한 방식이다.
List<String> _checkTestHarness(Directory root) {
  final issues = <String>[];
  final dir = Directory('${root.path}/apps/beoba/test');
  if (!dir.existsSync()) return issues;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    final relative = path.replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');
    final lines = entity.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final code = _stripComment(lines[i]);
      if (!_mediaQueryLiteral.hasMatch(code)) continue;
      if (code.contains('.fromView')) continue;
      if (lines[i].contains(_notUserFacingMarker)) continue;
      issues.add('$relative:${i + 1} — MediaQueryData 를 새로 만들면 화면 크기 · '
          '자판 높이 · 노치가 전부 0 이 됩니다. '
          'MediaQueryData.fromView(tester.view).copyWith(…) 를 쓰세요');
    }
  }
  return issues;
}

/// 시효 문장에 들어오면 안 되는 말.
///
/// **어느 쪽도 안 된다** — 「지났습니다」는 포기시키고 「남았습니다」는
/// 우리가 셌다는 뜻이다. 재촉과 말리기도 같은 자리다(DECISIONS 107번).
const List<String> _limitationBanned = [
  '지났습니다', '지났어요', '남았습니다', '남았어요',
  '서두르', '늦기 전에', '소용없', '이미 늦',
];

/// 우리가 계산한 연도. 「10년」은 조문에 있는 말이라 괜찮다.
final RegExp _calculatedYear = RegExp(r'(19|20)\d\d년');

/// 별표를 가리키는 자리.
///
/// **표기가 파일마다 갈린다** — `[별표 1]` · `[별표1]` · `<별표>`.
/// 갈린 채로 두면 등록해 놓고도 못 찾고, 못 찾으면 없는 것과 같다.
/// 셋을 다 받아서 **한 가지 꼴로** 되돌린다.
final RegExp _annexKey = RegExp(r'[\[<]\s*별표\s*(\d*)\s*[\]>]');

/// 「<법령명> [별표 N]」. 번호가 없으면 「<법령명> [별표]」.
String _annexNameOf(String law, String number) =>
    number.isEmpty ? '$law [별표]' : '$law [별표 $number]';

/// 조문 꼴 문자열. **규칙은 `article_ref.dart` 하나뿐이다.**
///
/// 매니페스트 생성기와 같은 것을 쓴다. 따로 두면 한쪽만 고쳐져 조용히
/// 어긋난다 — 실제로 문서 스캔 쪽만 띄어쓰기 정규화가 빠져 있었다
/// (DECISIONS 126번).
final RegExp _articleShape = articleRefPattern;

/// 조문 꼴이 나와도 매니페스트를 안 봐도 되는 자리.
///
/// **전부 화면에 안 나가거나, 우리가 쓴 것이 아닌 글이다.**
/// 조문 원문 안의 상호 참조(「제191조의 규정에 따를 수 없거나」)는
/// **우리 인용이 아니라 인용된 글의 일부**다. 손대지 않는다([94번] 참조).
const Map<String, String> _quotedKinds = {
  // **`verification` 을 통째로 넘기지 않는다.** 890개를 갈라 보니
  // `source` 565개와 `openPart` 23개는 **하나도 빠짐없이 이미 매니페스트에
  // 있었다.** 넘겨 봐야 얻는 게 없고, 대신 누가 판본 줄에 조문 번호를 잘못
  // 적으면 아무도 모른다 — 그 줄은 다음 사람이 판본을 다시 대조할 때 보는
  // 줄이라 틀리면 아프다. 그래서 `note` 만 넘긴다.
  '_': '데이터 주석(_)',
  // `note` 는 **이 표에 안 넣는다.** 이름만 보고 넓게 넘기면 화면에
  // 나가는 `note` 까지 같이 넘어간다 — `PublicChannel.note` 가 그렇다.
  // 검수 메모 안의 `note` 만을 `walkJson` 이 자리로 가려낸다.
  // `source` 도 마찬가지로 안 넣는다 — 이젠 대조하는 자리다.
  'tests': '정답지(tests)',
  // `lifespan.json` 의 산문. `clause` 와 `text` 는 부칙을 그대로 옮긴 것이고,
  // `chosen` 과 `after` 는 우리가 그 조문들을 설명하는 글이다 — 검수 메모와
  // 같은 갈래다. **아직 아무 분야도 그 법을 안 쓰니 매니페스트에도 없다.**
  // 쓰기 시작하면 그때 조문이 매니페스트에 들어온다(DECISIONS 275번).
  'clause': '법의 시간(lifespan) — 근거 부칙',
  'chosen': '법의 시간(lifespan) — 우리가 고른 까닭',
  'after': '법의 시간(lifespan) — 만료 뒤에도 참인 것',
};

/// **읽을 파일을 나열하지 않는다.** 저장소 전체를 훑는다.
///
/// 나열식이면 새 파일이 생길 때 아무도 안 알려 준다. 실제로 용어집이
/// 그렇게 판본 추적 밖에 있었다. 뒤집어서, 조문 꼴이 **어디에 있든**
/// 매니페스트에 없으면 실패로 만든다.
List<String> _checkArticleRefs(
  Directory root,
  List<String> notes,
  List<String> warnings,
) {
  final manifest = File(
    '${root.path}/packages/domain_data/assets/laws/manifest.json',
  );
  if (!manifest.existsSync()) {
    return ['매니페스트가 없습니다: ${manifest.path}'];
  }

  final known = <String>{};
  final raw = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
  for (final law in ((raw['laws'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
    for (final article in ((law['articles'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      final ref = article['ref'];
      if (ref is String) known.add(ref);
    }
  }

  final issues = <String>[];
  // 문서에서 나온 것. 실패로 만들지 않는다.
  final docNotes = <String>[];

  // **갈래별로 센다.** 373 같은 한 덩어리 숫자로는 그 안에 화면에 나가는
  // 것이 섞였는지 알 수 없다.
  final skipped = <String, int>{};
  void skip(String kind, int n) =>
      skipped[kind] = (skipped[kind] ?? 0) + n;

  // ── 분모 ─────────────────────────────────────────────────────────
  //
  // **「넘긴 자리 N개」만으로는 0이 무슨 뜻인지 갈리지 않는다.** 예외가
  // 없다는 뜻일 수도 있고, 아무것도 안 훑었다는 뜻일 수도 있다. 둘은
  // 정반대인데 같은 숫자로 나온다(DECISIONS 244번).
  //
  // 그래서 **훑은 파일 수와 본 조문 꼴 수를 함께 낸다.** 훑은 파일이 0이면
  // 검사는 「돌긴 했는데 재는 대상이 이름과 다른」 것이라 실패로 만든다 —
  // 노트 한 줄로 두면 초록불 사이에 묻힌다. 실제로 묻히는지 눌러 봤다.
  final scannedFiles = <String, int>{};
  var matched = 0;
  // 문서 쪽은 따로 센다. **경고를 내는 줄이 따로라 분모도 따로여야 한다** —
  // 전체 분모가 3천이어도 문서를 한 개도 안 훑었으면 그 줄의 0은 거짓이다.
  var docMatched = 0;
  void sawFile(String kind) =>
      scannedFiles[kind] = (scannedFiles[kind] ?? 0) + 1;

  void check(String where, String text) {
    for (final match in _articleShape.allMatches(text)) {
      matched++;
      final ref = _normalizeArticle(match);
      if (known.contains(ref)) continue;
      issues.add('$where — 매니페스트에 없는 조문입니다: $ref. '
          '원문을 받아 law/ 에 넣고 매니페스트를 다시 만드세요');
    }
  }

  // **파일이 아니라 필드로 넘긴다.** 파일 종류로 넘기면 그 파일 안에
  // 화면에 나가는 필드가 생기는 날 같이 넘어간다.
  void walkJson(
    Object? node,
    String where, {
    required String? quotedAs,
    bool inVerification = false,
  }) {
    if (node is Map<String, dynamic>) {
      for (final entry in node.entries) {
        // 조문 원문은 `law` 옆의 `text` 다. 그 안은 **인용된 글**이라
        // 우리 인용이 아니다.
        final kind = quotedAs ??
            (entry.key == 'text' && node.containsKey('law')
                ? '조문 원문'
                // `variants[].label` 은 **각 호를 그대로 옮긴 자리**다.
                // 옆의 `detail` 은 우리 말이라 함께 넘기면 안 된다 —
                // 그래서 `variants` 통째가 아니라 `label` 하나만, 그것도
                // `key`·`detail` 이 같이 있는 꼴일 때만 본다.
                : entry.key == 'label' &&
                        node.containsKey('key') &&
                        node.containsKey('detail')
                    ? '조문 원문(각 호)'
                    // **검수 메모 안의 `note` 만 넘긴다.** 우리가 옆 조문을
                    // 설명하는 산문이라 원문을 받을 이유가 없다 — 조문 원문
                    // 안의 상호 참조와 같은 갈래다. `source` 와 `openPart` 는
                    // 대조한다.
                    : inVerification && entry.key == 'note'
                        ? '검수 메모의 산문(verification.note)'
                        : _quotedKinds[entry.key]);
        walkJson(
          entry.value,
          '$where.${entry.key}',
          quotedAs: kind,
          inVerification: entry.key == 'verification',
        );
      }
    } else if (node is List) {
      for (final item in node) {
        walkJson(item, where,
            quotedAs: quotedAs, inVerification: inVerification);
      }
    } else if (node is String) {
      final hits = _articleShape.allMatches(node).length;
      if (hits == 0) return;
      if (quotedAs != null) {
        skip(quotedAs, hits);
        return;
      }
      check(where, node);
    }
  }

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (_outOfScope.any(path.contains)) continue;
    final name = path.split('/').last;

    if (name.endsWith('.json')) {
      // **이름이 아니라 경로로 넘긴다.** 이름만 보면 `apps/beoba/web/
      // manifest.json`(웹 PWA 매니페스트)까지 같이 넘어간다 — 분모를
      // 붙이고 나서야 보였다(JSON 이 실제 32개인데 31개였다).
      const skipByPath = [
        '/packages/domain_data/assets/laws/manifest.json',
        '/packages/domain_data/assets/laws/overrides.json',
      ];
      if (skipByPath.any(path.endsWith)) continue;
      try {
        final decoded = jsonDecode(entity.readAsStringSync());
        sawFile('JSON');
        final where =
            path.replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');

        // **복지 자료의 `services[]` 는 통째로 기관 안내문이다.**
        //
        // 「장애인복지법 제2조의 규정에 의한 장애인인 경우」처럼 조문이 그대로
        // 들어 있다. 그건 **우리 인용이 아니라 기관이 쓴 문장**이고, 우리는
        // 그걸 근거로 내지 않는다 — 내는 순간 `legalBasis` 를 만들어야 하고
        // 그때 원문이 필요해진다. 지금 매니페스트를 강제하면 법령 일흔 개를
        // 받아 와야 하고, 받아 와도 우리가 안 읽는 조문이다.
        //
        // **넘기되 센다.** 머리말(`dataset`·`openPart` 같은 우리 말)은 그대로
        // 검사한다 — 파일을 통째로 넘기면 우리 문장까지 같이 넘어간다.
        if (path.contains('/assets/welfare/') &&
            decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            walkJson(
              entry.value,
              '$where.${entry.key}',
              quotedAs: entry.key == 'services' ? '기관 안내문' : null,
            );
          }
        } else {
          walkJson(decoded, where, quotedAs: null);
        }
      } on FormatException {
        continue;
      }
    } else if (name.endsWith('.md')) {
      // **문서는 제품이 아니다. 그래도 훑는다.**
      //
      // DECISIONS 와 SPEC 은 다음 사람이 읽고 그걸 근거로 코드를 짜는
      // 문서다. 다음 작업자도 그걸 먼저 읽는다. 거기 적힌 조문 번호가
      // 낡으면 **낡은 번호로 코드가 나온다** — 실제로 대부업법 제19조를
      // 잘못 적은 것이 그대로 데이터에 들어간 적이 있다.
      //
      // **경고로만 낸다.** 문서를 고치다 빌드가 서면 안 된다.
      final relative =
          path.replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');
      final lines = entity.readAsLinesSync();
      sawFile('문서(.md)');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // ① 표시가 붙은 줄. **사람이 판단해서 달아 둔 것**이라 먼저 본다.
        //    `(불채택)` 안 쓰기로 했다 · `(조건부)` 아직 조건이 안 왔다
        //    표시를 지우면 경고가 되살아난다. 그게 이 표시의 값어치다.
        final marked = _docMark.firstMatch(line);
        if (marked != null) {
          skip('문서 ${marked.group(0)}', _articleShape.allMatches(line).length);
          continue;
        }
        // ② **인용 블록 안**은 원문을 옮긴 자리다. 그 안의 상호 참조는
        //    우리가 따로 인용한 조문이 아니라 인용된 글의 일부다.
        if (_docQuote.hasMatch(line)) {
          skip('문서 인용 블록', _articleShape.allMatches(line).length);
          continue;
        }
        for (final match in _articleShape.allMatches(line)) {
          matched++;
          docMatched++;
          final ref = _normalizeArticle(match);
          if (known.contains(ref)) continue;
          docNotes.add('$relative:${i + 1} — 매니페스트에 없는 조문: $ref');
        }
      }
    } else if (name.endsWith('.dart')) {
      if (name.endsWith('.g.dart') || name.endsWith('.freezed.dart')) continue;
      final relative =
          path.replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');
      final lines = entity.readAsLinesSync();
      sawFile('Dart');
      final inTest = relative.contains('/test/');
      for (var i = 0; i < lines.length; i++) {
        final code = _stripComment(lines[i]);
        skip(
          'Dart 주석',
          _articleShape.allMatches(lines[i]).length -
              _articleShape.allMatches(code).length,
        );
        if (inTest) {
          // 테스트도 훑는다. 다만 몇 건인지 따로 세어 둔다.
          skip('테스트 파일 안(검사함)', 0);
        }
        check('$relative:${i + 1}', code);
      }
    }
  }

  final total = skipped.values.fold<int>(0, (a, b) => a + b);
  final byKind = (skipped.entries.toList()
        ..removeWhere((e) => e.value == 0)
        ..sort((a, b) => b.value.compareTo(a.value)))
      .map((e) => '${e.key} ${e.value}')
      .join(' · ');
  final fileTotal = scannedFiles.values.fold<int>(0, (a, b) => a + b);
  final fileByKind = (scannedFiles.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .map((e) => '${e.key} ${e.value}')
      .join(' · ');
  notes.add('조문 꼴 전수 검사 — 훑은 파일 $fileTotal개'
      '${fileByKind.isEmpty ? '' : ' ($fileByKind)'} · '
      '본 조문 꼴 ${matched + total}개 '
      '(대조한 것 $matched · 넘긴 자리 $total)');
  if (fileTotal == 0) {
    issues.add('조문 꼴 전수 검사 — 훑은 파일이 0개입니다. '
        '검사가 돌긴 했지만 아무것도 안 봤습니다. '
        '_outOfScope 나 훑는 경로를 보세요');
  }
  notes.add('조문 꼴 전수 검사 — 넘긴 자리 $total개 ($byKind)');

  // **별표는 별표 단위로 판본을 단다.** 매주 대조 때 각각 봐야 한다.
  //
  // 다만 **법률의 별표만 자기 개정일을 단다.** 행정규칙·재판예규의 별표는
  // `<개정 …>` 표시가 아예 없고 본체와 함께 개정된다. 그걸 「못 받았다」로
  // 두면 **영영 안 채워질 경고**가 되고, 노이즈가 되면 아무도 안 본다.
  final byName = <String, Map<String, dynamic>>{
    for (final law in ((raw['laws'] as List?) ?? const [])
        .cast<Map<String, dynamic>>())
      law['name'] as String: law,
  };
  final tables = (raw['tables'] as Map<String, dynamic>?) ?? const {};
  final counts = <String, int>{};
  for (final entry in tables.entries) {
    final table = entry.value as Map<String, dynamic>;
    final how = (table['versioning'] as String?) ?? 'missing';
    counts[how] = (counts[how] ?? 0) + 1;

    switch (how) {
      case 'dated':
        if (table['revisedAt'] == null) {
          issues.add('매니페스트 — "${entry.key}" 이 dated 인데 개정일이 없습니다');
        }
      case 'followsParent':
        // **본체 번호가 바뀌면 별표도 바뀐 것으로 본다.** 그러려면 본체가
        // 매니페스트에 있어야 하고, 이름이 맞아야 한다.
        final parent = table['parent'] as String?;
        if (parent == null || !byName.containsKey(parent)) {
          issues.add('매니페스트 — "${entry.key}" 이 본체를 따른다는데 '
              '그 본체("$parent")가 매니페스트에 없습니다');
        }
      default:
        warnings.add('매니페스트 — "${entry.key}" 의 판본을 아직 못 받았습니다');
    }
  }
  // **읽을 파일을 이름으로 고르지 않는다.** 다 읽고 못 넣은 것을 센다.
  final unfiled = (raw['unfiled'] as Map<String, dynamic>?) ?? const {};
  if (unfiled.isNotEmpty) {
    int count(String key) => ((unfiled[key] as List?) ?? const []).length;
    final unreadable = count('unreadableName');
    // **분모는 생성기가 적어 준다.** 여기서 `law/` 를 세면 CI 에서 0이
    // 나오고, 그건 「못 넣은 것이 없다」와 구별이 안 된다. PDF 는 저장소에
    // 없다. 그래서 **없는 것과 0을 갈라 적는다** — 낡은 매니페스트는
    // 「없음」이지 「0개」가 아니다.
    final scanned = unfiled['scanned'];
    final denominator = scanned is int
        ? 'PDF $scanned개 중'
        : 'PDF 를 몇 개 봤는지 매니페스트에 없음 —';
    notes.add('law/ 에서 못 넣은 PDF — $denominator '
        '법령이 아님 ${count('notLaw')} · '
        '등록 안 된 별표 ${count('annexNotRegistered')} · '
        '이름을 못 읽음 $unreadable');
    if (scanned is! int) {
      issues.add('매니페스트 — unfiled 에 scanned 가 없습니다. '
          '「못 넣은 것 0개」가 「PDF 를 한 개도 안 봤다」와 구별이 안 됩니다. '
          'build_law_manifest 를 다시 돌리세요');
    } else if (scanned == 0) {
      issues.add('매니페스트 — law/ 에서 본 PDF 가 0개입니다. '
          '생성기가 원문 없는 곳에서 돌았습니다');
    }
    if (unreadable > 0) {
      for (final name in (unfiled['unreadableName'] as List).cast<String>()) {
        warnings.add('law/ — "$name" 의 이름을 못 읽었습니다. '
            'overrides.json 의 files 에 판본을 적으세요');
      }
    }
  }

  if (tables.isNotEmpty) {
    final how = (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => '${e.key} ${e.value}')
        .join(' · ');
    notes.add('별표 ${tables.length}개 — $how '
        '(followsParent 는 금요일에 **본체 number** 를 본다)');
  }
  // **0건일 때도 줄을 낸다.** 예전에는 걸린 것이 있을 때만 냈다 — 그러면
  // 0이 「없다」가 아니라 **줄 자체가 사라지는 것**이라 아무도 못 본다.
  final docFiles = scannedFiles['문서(.md)'] ?? 0;
  warnings.addAll(docNotes);
  notes.add('문서(.md) 조문 — 문서 $docFiles개에서 조문 꼴 $docMatched개를 '
      '대조 · 매니페스트에 없는 것 ${docNotes.length}건'
      '${docNotes.isEmpty ? '' : " (경고입니다. 매주 매니페스트 대조 때 함께 봅니다)"}');
  if (docFiles == 0) {
    issues.add('문서(.md) 조문 — 훑은 문서가 0개입니다. '
        'DECISIONS 와 SPEC 의 조문 번호를 아무도 안 보고 있습니다');
  }
  return issues;
}

/// 훑지 않는 곳. 빌드 산출물과 받아 오는 원문 디렉터리다.
const List<String> _outOfScope = [
  '/build/',
  '/.dart_tool/',
  '/.git/',
  '/node_modules/',
  '/law/',
];

/// 매니페스트의 법령명 → 시행일.
Map<String, String> _manifestVersions(Directory root) {
  final file = File(
    '${root.path}/packages/domain_data/assets/laws/manifest.json',
  );
  if (!file.existsSync()) return const {};
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final laws = (raw['laws'] as List?) ?? const [];
  return {
    for (final law in laws.cast<Map<String, dynamic>>())
      law['name'] as String: (law['effective'] as String?) ?? '',
  };
}

/// 이 문장 안에서 [word] 에 풀이가 붙어 있는가.
///
/// 두 가지를 인정한다.
///
/// 1. **낱말에 바로 붙은 괄호** — `이의신청(그대로는 안 된다고 알리는 것)`.
///    사이에 낀 글자는 허용하되 **띄어쓰기는 허용하지 않는다.** `신용정보` 는
///    `신용정보회사(정부 허가를 받은 회사)` 로 쓰이므로 붙어 있는 꼬리는 넘겨야
///    한다. 반대로 띄어쓰기를 허용하면 저 멀리 다른 낱말의 괄호를 자기 것으로
///    가져간다 — `시효 계산과 지연이자(...)` 가 시효까지 통과시킨다
/// 2. **괄호 안에 낱말이 들어 있는 경우** — `(원고는 소송을 낸 쪽, 피고는
///    소송을 받은 쪽)`. 대립쌍은 따로 떼면 오히려 헷갈려서 뒤에 한 번에 붙인다
bool _hasGloss(String text, String word) {
  // (2) 괄호 안에서 설명되는가
  for (final match in RegExp(r'\(([^()]*)\)').allMatches(text)) {
    if (match.group(1)!.contains(word)) return true;
  }

  // (1) 낱말에 붙은 괄호가 뒤따르는가
  const maxTail = 6;
  var from = 0;
  while (true) {
    final at = text.indexOf(word, from);
    if (at < 0) return false;
    final end = at + word.length;
    final limit = (end + maxTail).clamp(end, text.length);
    final tail = text.substring(end, limit);
    final paren = tail.indexOf('(');
    if (paren >= 0 && !tail.substring(0, paren).contains(' ')) return true;
    from = at + 1;
  }
}

// ── 검사에서 **제외**하는 것 ────────────────────────────────────────
//
// legalBasis.text · law · article  조문 원문. 🟢 층의 근거다. 바꾸면 3층 규칙이
//                                  무너진다. 어려워도 그대로 인용한다
// label                            공식 용어. 사용자가 전자소송 화면·법원 창구·
//                                  받은 서류에서 이 이름을 다시 찾아야 한다
//                                  (DECISIONS 40번)
// PublicChannel.org                기관 공식 명칭. 전화하고 검색할 때 쓰인다
// BrokerAlert.phrase               사기꾼이 하는 말의 원문 인용. 고치면 데이터가
//                                  망가진다 (DECISIONS 5번의 quote scope 와 같다)
// verification.note                검수 메모. 화면에 안 나간다
// AutoTrigger.note                 내부 메모. 위기 화면 문구는 앱 코드에 있고
//                                  데이터에는 창구 id 목록뿐이다

/// 이 줄은 법률 수치가 아니라고 표시하는 주석.
///
/// ★ **값과 같은 줄에 단다.** 검사는 그 줄만 본다. 윗줄에 따로 세운 표식은
/// 아무것도 막지 않는다 — `tool/` 의 다섯이 그렇게 서 있었다(DECISIONS 277번).
const String _notLegalNumberMarker = 'not-a-legal-number';

/// 되돌릴 조건 — **`lib/` 에서** 무언가를 실제로 막는 표식이 이 수를 넘으면
/// 검사가 무뎌지고 있다는 뜻이다(DECISIONS 14번 · 277번).
///
/// `lib/` 만 훑던 때 세운 값이라 범위를 `lib/` 로 묶었다. `tool/` · `bin/` 을
/// 연 날 표식이 열 개 넘게 늘었는데, 그걸 같은 줄에 더하면 「이 규칙은
/// 실패했다」가 거짓으로 켜진다. 도구의 숫자(해시 상수 · 기다리는 시간)는
/// 앱이 쓰는 법률 수치와 다른 자리다.
const int _libMarkerLimit = 10;

/// **조문 번호가 코드 문자열에 있어도 되는 파일.** 14번의 조문 번호 검사만
/// 넘기고 큰 숫자 검사는 그대로 받는다.
///
/// [_safetySourceFiles] 와 같은 꼴이다 — 검사 자신이 사람에게 내는 말이나
/// 점검표 본문이 조문을 가리킨다. 문자열을 쪼개 피하지 않고 여기 이름을
/// 적는다(DECISIONS 277번).
const Map<String, String> _articleTextFiles = {
  'verify_domains.dart':
      '검사가 내는 말이 조문을 가리킨다 — 옛 용어의 근거(민사집행법) · '
      '개인정보처리방침 9절이 채워야 할 자리의 근거(개인정보 보호법)',
  'build_citation_report.dart':
      '인용 점검표를 쓰는 도구라 조문 번호가 표의 본문이다 — 269번 사례 설명',
};

/// `DateTime.now()` 를 불러도 되는 유일한 파일.
const String _clockFile = 'kst_clock.dart';

/// 문구 검사에서 제외하는 파일.
///
/// 앞의 셋은 금지어 패턴 자체를 담고 있다.
///
/// `disclaimers.dart` 는 다르다 — 금지어를 **부정문으로** 담는다
/// ("승소 가능성은 안내하지 않습니다"). 부분 문자열 검사는 부정문을 구분하지
/// 못하므로 예외가 필요한데, 마커 주석을 흩뿌리는 대신 파일 하나로 모았다.
/// 예외가 한 곳에 있어야 리뷰할 수 있다. 화면은 이 문구를
/// `SafetyScope.disclaimer` 로 그리고, 그 scope 도 단정 표현은 그대로 막는다.
///
/// `citation_audit.dart` 도 앞의 셋과 같은 까닭이다 — 「무조건」 같은 단정의
/// 표지를 **우리 문장에서 찾으려고** 담는다. 화면에 안 나간다. 문자열을 쪼개
/// 이 검사를 피하지 않고 여기 이름을 적는다(DECISIONS 271).
const Set<String> _safetySourceFiles = {
  'safety_filter.dart',
  'safety_field_scopes.dart',
  'verify_domains.dart',
  'disclaimers.dart',
  'citation_audit.dart',
};

/// 이 줄의 문자열은 사용자에게 보이지 않는다고 표시하는 주석.
const String _notUserFacingMarker = 'not-user-facing';

/// `Text(` 대신 `SafeText(` 만 쓸 수 있는 디렉터리.
///
/// SafetyFilter 를 위젯 빌드 시점에 부르는 것을 **잊을 수 없게** 만든다.
/// 규칙 5(모든 노출 문구는 SafetyFilter 통과)를 사람 기억이 아니라 빌드가 지킨다.
const List<String> _safeTextOnlyDirs = [
  '/apps/beoba/lib/src/screens/',
  '/apps/beoba/lib/src/widgets/',
];

/// `SafeText` 자신은 `Text` 를 써야 한다.
const Set<String> _safeTextSourceFiles = {'safe_text.dart'};

/// `Text(` · `Text.rich(` 직접 사용. `SafeText(` 는 걸리지 않는다.
final RegExp _rawTextWidget = RegExp(r'(?<![\w.$])Text(\.rich)?\s*\(');

/// 라우트에 값을 실어 나르는 자리. `extra:` 뒤에 무엇이 오든 걸린다.
final RegExp _routeExtra = RegExp(r'(?<![\w.$])extra\s*:');

/// 화면 코드가 문장에 이어 붙이면 안 되는 조사·어미.
///
/// 「이자를 받기로 하셨다면」 뒤에 `라면` 을 붙여 **「…하셨다면라면」** 이 나갔고,
/// 「인지대」 뒤에 `은` 을 붙여 **「인지대은」** 이 나갔다.
/// 낱말이 늘어날 때마다 다시 틀리는 종류라 낱말이 아니라 **자리**를 막는다.
///
/// 없앨 수 없는 자리는 `withJosa(word, Josa.…)` 를 쓴다 — 받침을 보고 고른다.
const String _josaAlternatives =
    '이라면|라면|으로|이라|은|는|이|가|을|를|와|과|로|라';

/// 조사·어미만 홀로 들어 있는 문자열. 이어 붙이려고 둔 것 말고는 쓸 데가 없다.
final RegExp _bareJosaLiteral = RegExp("'($_josaAlternatives)'");

/// `\${…}` 나 `\$이름` 뒤에 조사·어미가 오는 자리.
///
/// 닫는 따옴표·괄호가 사이에 껴도 같은 자리다 — `'「\${miss.label}」은'` 이
/// 실제로 있었다. 낫표 하나 낀다고 조사가 안 틀리는 것이 아니다.
final RegExp _josaAfterInterpolation = RegExp(
  r'(\$\{[^{}]*\}|\$[A-Za-z_][A-Za-z0-9_]*)'
  r'[」』’”\)\]]*'
  '($_josaAlternatives)'
  r'(?![가-힣])',
);

/// 조사 검사를 받는 곳. 말을 만드는 코드는 전부 여기 안에 있다.
const String _josaCheckedDir = '/apps/beoba/lib/';

/// 「관공서의 공휴일에 관한 규정」 제2조의 호 번호. 이름으로 찾는다.
///
/// 대체공휴일을 다시 세려면 **어느 호인지**를 알아야 한다. 제3조 제1항이
/// 호 번호로 열거하기 때문이다 — 현충일(제8호)이 열거에 **없어서** 토요일이어도
/// 대체가 없다. 이름 목록을 잘못 쓰면 거기서 틀린다.
const Map<String, int> _holidayClause = {
  '1월1일': 3,
  '설날': 4,
  '삼일절': 2,
  '부처님오신날': 5,
  '노동절': 6,
  '어린이날': 7,
  '현충일': 8,
  '제헌절': 2,
  '광복절': 2,
  '추석': 9,
  '개천절': 2,
  '한글날': 2,
  '기독탄신일': 10,
};

/// 규정이 2026년에 바뀐 자리. **그 이전 날짜는 현행 규정으로 검산하면 안 된다.**
///
/// 제헌절(제2조 제2호, 2026.5.11. 시행)과 노동절(제6호, 2026.5.1. 시행)이
/// 2026년에 새로 공휴일이 됐다. 2025년 데이터에 둘이 없는 것이 정상이고,
/// 현행 규정으로 2025년을 재계산하면 어긋난다.
///
/// **법이 바뀌면 과거 데이터를 현재 규칙으로 검산하면 안 된다.**
const String _recalcFrom = '2026-05-11';

List<String> _checkHolidays(Directory root, List<String> warnings) {
  final dir = Directory('${root.path}/packages/domain_data/assets/holidays');
  if (!dir.existsSync()) {
    return ['assets/holidays 가 없습니다. build_holidays.dart 를 돌리세요'];
  }

  final issues = <String>[];
  final all = <String, String>{}; // 날짜 → 이름
  final substitutes = <String>{};
  /// 제2조 각 호의 공휴일. **대체공휴일은 여기 없다** — 그건 제3조가 만든다.
  final statutory = <String>{};

  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.json')) continue;
    final name = file.uri.pathSegments.last;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final year = json['year'];
    final days = json['days'];
    if (year is! int || days is! List || days.isEmpty) {
      issues.add('$name — year 또는 days 가 비었습니다');
      continue;
    }

    // (a) 형식 · 중복 · 범위 밖
    for (final day in days) {
      if (day is! Map) {
        issues.add('$name — days 항목이 객체가 아닙니다');
        continue;
      }
      final date = day['date'];
      if (date is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
        issues.add('$name — 날짜 형식이 아닙니다: $date');
        continue;
      }
      if (!date.startsWith('$year-')) {
        issues.add('$name — $year 파일에 다른 해가 있습니다: $date');
        continue;
      }
      if (all.containsKey(date)) {
        issues.add('$name — 같은 날이 두 번 있습니다: $date');
        continue;
      }
      final label = day['name'];
      all[date] = label is String ? label : '';
      if (day['kind'] == 'substitute') {
        substitutes.add(date);
      } else {
        statutory.add(date);
      }
    }
  }

  if (all.isEmpty) return ['쉬는 날 표가 비어 있습니다'];

  // (b) 대체공휴일을 규정 제3조로 **다시 세어** 대조한다.
  //
  // **경고이지 실패가 아니다.** 우리 계산이 틀렸을 수도 있다 — 데이터는 한국
  // 천문연구원이 준 것이고 우리는 조문을 읽어 흉내 낼 뿐이다.
  final expected = <String>{};
  for (final entry in all.entries) {
    if (entry.key.compareTo(_recalcFrom) < 0) continue; // 규정 개정 이전은 안 본다
    final clause = _holidayClause[entry.value];
    if (clause == null) continue; // 대체공휴일 · 선거일 · 임시공휴일

    final date = DateTime.parse(entry.key);
    final weekday = date.weekday; // 6=토 7=일
    // 제3조①1호 — 제2호·제5호~제7호·제10호가 토요일이나 일요일과 겹칠 때
    final byClause1 =
        {2, 5, 6, 7, 10}.contains(clause) && (weekday == 6 || weekday == 7);
    // 제3조①2호 — 제4호(설날) 또는 제9호(추석)가 일요일과 겹칠 때
    final byClause2 = {4, 9}.contains(clause) && weekday == 7;
    if (!byClause1 && !byClause2) continue;

    // 「그 공휴일 다음의 첫 번째 **비공휴일**」 — 괄호가 「제2조 각 호의
    // 공휴일이 아닌 날」로 못박는다. **대체공휴일은 제2조가 아니라 제3조가
    // 만드는 날이라 여기서 세면 안 된다.** 넣고 세면 하루씩 밀린다.
    var next = date.add(const Duration(days: 1));
    while (true) {
      final key = next.toIso8601String().substring(0, 10);
      final closed = next.weekday >= 6 || statutory.contains(key);
      if (!closed) {
        expected.add(key);
        break;
      }
      next = next.add(const Duration(days: 1));
    }
  }

  final onlyInData = substitutes.where((d) => d.compareTo(_recalcFrom) >= 0)
      .where((d) => !expected.contains(d))
      .toList()
    ..sort();
  final onlyInRule = expected.where((d) => !substitutes.contains(d)).toList()
    ..sort();

  for (final date in onlyInData) {
    warnings.add('쉬는 날 — 데이터에는 대체공휴일 $date 가 있는데 '
        '규정으로 다시 세면 안 나옵니다. 사람이 보세요');
  }
  for (final date in onlyInRule) {
    warnings.add('쉬는 날 — 규정으로 다시 세면 $date 가 대체공휴일인데 '
        '데이터에 없습니다. 사람이 보세요');
  }

  return issues;
}

/// 조문 원문 자리에 있으면 원문이 아니라는 표시.
///
/// **법령 문장은 `~한다` 체다.** 「~입니다」 · 「~습니다」로 끝나는 문장은
/// 우리가 쓴 것이다. 「위반 시」도 조문이 아니라 요약의 말투다.
///
/// 넓게 잡는 그물이 아니다. 이미 겪은 것을 다시 못 겪게 하는 **바닥**이다.
final RegExp _ourVoiceInQuote = RegExp('입니다|습니다|해요|예요|드립니다|위반 시');

/// 조문을 여럿 걸어 놓고 원문은 하나만 실은 자리를 찾는다.
///
/// `제2조 제10호 · 제11호 · 제4조 제1항` 처럼 적어 두고 `text` 에 제10호만
/// 담으면, 화면은 **세 조문의 원문인 척** 한 조문을 보여준다.
/// 근거가 여럿이면 `alsoBasis` 로 나눈다 (76번).
final RegExp _multiArticle = RegExp(r'[·/]');

/// 검증 전용으로 도메인을 전부 읽는다. `unverified` 항목까지 본다 —
/// 지금 화면에 안 나가더라도 나중에 올라가면 그대로 나간다.
List<Domain> _loadAll(List<File> files) {
  // ignore: invalid_use_of_visible_for_testing_member
  final loader = DomainLoader(policy: VerificationPolicy.keepAll);
  return [
    for (final file in files) loader.loadFromJsonString(file.readAsStringSync()),
  ];
}

List<String> _checkQuotedText(List<File> files) {
  final issues = <String>[];

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final json = jsonDecode(file.readAsStringSync());

    void walk(Object? node, String path) {
      if (node is Map<String, dynamic>) {
        final text = node['text'];
        if (text is String && text.isNotEmpty && node.containsKey('law')) {
          final law = node['law'];
          final article = node['article'];
          final where = '$name — $path';

          // **근거 원문 안에는 아무것도 넣지 않는다.** 토큰도, 밑줄도, 병기도.
          // 손대는 순간 원문이 아니게 된다. 경고가 아니라 실패다 — 인용은
          // 3층 🟢 의 전제이고 여기가 무너지면 위가 다 무너진다.
          if (text.contains('[[') || text.contains(']]')) {
            issues.add('$where — 조문 원문 안에 용어 토큰이 있습니다. '
                '원문은 손대지 않습니다. 밑줄은 우리가 쓴 문장에만 답니다');
          }

          if (law is! String || law.isEmpty || article is! String || article.isEmpty) {
            issues.add('$where — 조문 원문이 있는데 법령명·조문 번호가 없습니다. '
                '조문이 아니면 text 를 비우고 verification.source 에 적으세요');
          } else {
            final hit = _ourVoiceInQuote.firstMatch(text);
            if (hit != null) {
              issues.add('$where — 조문 원문 자리에 우리 말투가 있습니다: '
                  '"${hit.group(0)}". 법령 문장은 ~한다 체입니다. '
                  '요약이면 내리고 원문을 받아 넣으세요');
            }
            if (_multiArticle.hasMatch(article)) {
              issues.add('$where — 조문을 여럿 걸고($article) 원문은 하나만 '
                  '실었습니다. 근거가 여럿이면 alsoBasis 로 나누세요');
            }
          }
        }
        for (final entry in node.entries) {
          // 용어집에는 `id` 가 없다. 그 자리를 `term` 이 한다 — 어느 낱말에서
          // 난 일인지 말해 주지 않으면 고칠 자리를 못 찾는다.
          final id = node['id'] ?? node['term'];
          final next = id is String && !path.endsWith(id) ? '$path.$id' : path;
          walk(entry.value, '$next.${entry.key}');
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item, path);
        }
      }
    }

    walk(json, name.replaceAll('.json', ''));
  }
  return issues;
}

/// 화면을 멈춰 세우는 브로커 경보의 상한.
///
/// 셋이 적다고 느껴지면 그게 맞는 느낌이다. **넘기면 큰 카드가 기본이 되고,
/// 기본이 되면 아무것도 못 멈춘다.** 카드 다섯 장 규칙과 같은 종류의 잠금이라
/// 경고가 아니라 실패로 둔다 — 경고로 두면 다음 사람이 하나씩 늘린다.
const int _stopBudget = 3;

List<String> _checkStopBudget(List<File> files) {
  // ignore: invalid_use_of_visible_for_testing_member
  final loader = DomainLoader(policy: VerificationPolicy.keepAll);
  final stops = <String>[];

  for (final file in files) {
    final domain = loader.loadFromJsonString(file.readAsStringSync());
    for (final alert in domain.brokerAlerts) {
      if (alert.display == AlertDisplay.stop) stops.add(alert.id);
    }
  }

  if (stops.length <= _stopBudget) return const [];
  return [
    '화면을 멈춰 세우는 브로커 경보가 ${stops.length}건입니다 (상한 $_stopBudget). '
        '${stops.join(" · ")} — 넷째로 밀린 것이 무엇인지 DECISIONS 에 적고 고르세요',
  ];
}

List<String> _checkSources(
  Directory root,
  List<String> notes,
  List<String> warnings,
) {
  final issues = <String>[];
  // 14번의 분모. 훑은 파일과 표식을 범위별로 센다(DECISIONS 277번).
  final scanned = <String, int>{'lib': 0, 'tool': 0, 'bin': 0};
  final working = <String, int>{'lib': 0, 'tool': 0, 'bin': 0};
  final idle = <String, int>{'lib': 0, 'tool': 0, 'bin': 0};
  final legalArticle = RegExp(r'제\s?\d+\s?(조|항|호)');
  final bigNumber = RegExp(r'(?<![\w.])\d{5,}(?![\w.])');
  final hangulString = RegExp(r"""(['"])((?:[^'"\\]|\\.)*[가-힣][^'"\\]*)\1""");

  for (final dir in [
    Directory('${root.path}/packages'),
    Directory('${root.path}/apps'),
  ]) {
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final fileName = path.split('/').last;

      if (path.contains('/.dart_tool/') || path.contains('/build/')) continue;

      // ★ **14번(조문 번호 · 큰 숫자)은 `tool/` 과 `bin/` 도 본다.** 전에는
      // `lib/` 이 아니면 여기서 돌아섰다. 그래서 도구에 법률 수치가 박혀도
      // 게이트가 안 빨개졌고, 표식은 사람이 손으로 지킨 예의였다(276 · 277번).
      //
      // 나머지 검사(`DateTime.now()` · 금지어 · SafeText · 조사)는 아직
      // `lib/` 만 본다. 연 것은 14번 하나다 — 277번에 센 값과 까닭이 있다.
      final isLib = path.contains('/lib/');
      final scope = isLib
          ? 'lib'
          : path.contains('/tool/')
              ? 'tool'
              : path.contains('/bin/')
                  ? 'bin'
                  : null;
      if (scope == null) continue;
      if (fileName.endsWith('.g.dart') || fileName.endsWith('.freezed.dart')) {
        continue;
      }
      scanned[scope] = scanned[scope]! + 1;

      final relative = path.replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');
      final lines = entity.readAsLinesSync();

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final where = '$relative:${i + 1}';
        final code = _stripComment(line);

        if (isLib &&
            code.contains('DateTime.now()') &&
            fileName != _clockFile) {
          issues.add('$where — DateTime.now() 직접 호출. KstClock 을 주입하세요');
        }

        if (!_safeTextSourceFiles.contains(fileName) &&
            !line.contains(_notUserFacingMarker) &&
            _safeTextOnlyDirs.any(path.contains) &&
            _rawTextWidget.hasMatch(code)) {
          issues.add('$where — Text() 대신 SafeText() 를 쓰세요. '
              '문구가 아니면 그 줄에 // $_notUserFacingMarker: 이유 를 답니다');
        }

        // **웹에서 `extra` 는 히스토리다.** `extraCodec` 을 주지 않으면
        // go_router 가 json 으로 인코딩해 라우트 상태에 싣고, 그건
        // `history.pushState` 의 state 가 된다 — 주소창에 안 보일 뿐이다.
        // 사용자가 적은 글이 실제로 그 길로 나가고 있었다(DECISIONS 101번).
        // 지금 0건이므로 0건으로 잠근다. 꼭 필요하면 그때 예외를 적는다.
        if (_safeTextOnlyDirs.any(path.contains) &&
            !line.contains(_notUserFacingMarker) &&
            _routeExtra.hasMatch(code)) {
          issues.add('$where — 라우트의 extra: 는 웹에서 브라우저 히스토리에 '
              '남습니다. 화면 사이로 값을 나를 때는 provider 를 쓰세요');
        }

        if (path.contains(_josaCheckedDir) &&
            !line.contains(_notUserFacingMarker)) {
          if (_bareJosaLiteral.hasMatch(code) ||
              _josaAfterInterpolation.hasMatch(code)) {
            issues.add('$where — 화면이 조사·어미를 이어 붙이고 있습니다. '
                '데이터 문장을 그대로 쓰거나 withJosa() 를 쓰세요');
          }
        }

        if (line.contains(_notLegalNumberMarker)) {
          // 그 줄에 막을 것이 있는가. 없으면 표식은 아무 일도 안 한다.
          if (legalArticle.hasMatch(code) || bigNumber.hasMatch(code)) {
            working[scope] = working[scope]! + 1;
          } else if (line.trim().startsWith('// $_notLegalNumberMarker')) {
            idle[scope] = idle[scope]! + 1;
          }
          continue;
        }

        if (!_articleTextFiles.containsKey(fileName) &&
            legalArticle.hasMatch(code)) {
          issues.add('$where — 조문 번호가 코드에 있습니다. 도메인 JSON 으로 옮기세요');
        }
        if (bigNumber.hasMatch(code)) {
          issues.add('$where — 큰 숫자 리터럴이 있습니다. 법률 수치라면 JSON 으로 옮기세요');
        }

        if (!isLib || _safetySourceFiles.contains(fileName)) continue;
        for (final match in hangulString.allMatches(code)) {
          final text = match.group(2)!;
          final violations = SafetyFilter.scan(text, where: where);
          issues.addAll(
            violations.map((v) => '$where — 금지 표현: ${v.excerpt}'),
          );
        }
      }
    }
  }

  // **분모를 낸다.** 「tool/ 을 열었다」는 말은 이 줄이 증명한다.
  for (final scope in ['lib', 'tool', 'bin']) {
    if (scanned[scope] == 0) {
      issues.add('코드 속 법률 수치 — $scope 에서 훑은 파일이 0개입니다. '
          '경로 판별이 틀렸으면 검사가 아무것도 안 봅니다');
    }
  }
  notes.add('코드 속 법률 수치(14번) — 훑은 파일 '
      'lib ${scanned['lib']} · tool ${scanned['tool']} · bin ${scanned['bin']} · '
      '막는 표식 lib ${working['lib']}/$_libMarkerLimit · '
      'tool ${working['tool']} · bin ${working['bin']} · '
      '아무것도 안 막는 따로 선 표식 lib ${idle['lib']} · tool ${idle['tool']} · '
      'bin ${idle['bin']} · 조문 번호를 넘기는 파일 ${_articleTextFiles.length}');
  // ★ **닿으면 빨개진다.** 「다시 본다」가 무엇인지 안 적혀 있으면 닿는 날
  // 그냥 11 로 올리게 된다. 그래서 할 일을 메시지에 적는다 — 표식을 전부 다시
  // 읽고, 규칙을 좁힐 수 있는지 본다. 숫자를 올리는 것은 마지막이다(277번).
  if (working['lib']! > _libMarkerLimit) {
    issues.add('코드 속 법률 수치 — lib/ 에서 막는 표식이 ${working['lib']}개로 '
        '$_libMarkerLimit개를 넘었습니다. 14번의 되돌릴 조건입니다. '
        '① lib/ 의 표식을 전부 다시 읽으세요 '
        '② 「이 규칙을 좁힐 수 있나」를 판단하세요 — 예를 들어 숫자 리터럴 대신 '
        '이름 있는 상수만 허용하기 '
        '③ _libMarkerLimit 을 올리는 것은 마지막 수단입니다. 올리면 DECISIONS 에 '
        '①② 를 본 결과를 적으세요');
  }
  return issues;
}

/// 화면에 나가는 글자인데 **검사가 안 보고 있던 자리** — `web/*.html`.
///
/// 기다리는 화면(엔진이 뜨기 전에 보이는 스플래시)은 Flutter 위젯으로 만들 수
/// 없다. 위젯은 엔진이 뜬 뒤에나 그려지는데 가리려는 것이 바로 그 시간이다.
/// 그래서 이 문장들은 `SafeText` 도 [_checkSources] 도 지나지 않는다.
/// **안 세면 없는 것이 된다**는 이유로 여기서 센다([166번](#166)와 같은 자리다).
///
/// 문장만 보지 않고 **바깥 파일을 부르는지도** 본다. 기다리는 화면이 웹글꼴
/// 하나를 기다리면 늦게 떠서 만든 뜻이 없어진다. 좁게만 잡는다 — 아이콘과
/// 매니페스트 `<link>` 는 화면을 막지 않으므로 세지 않는다.
/// 인수인계 머리말이 지금 상태와 맞는가.
///
/// **머리말이 뒤처지면 다음 사람이 이미 있는 걸 또 만든다.** 실제로 분야가
/// 여덟이 된 뒤에도 머리와 표는 「분야 여섯」에 멈춰 있었다 — 본문에는 새
/// 분야 이름이 들어갔는데 머리만 안 고쳐졌다.
///
/// 기계가 볼 수 있는 것은 둘이다.
///
/// ```
/// 분야 **8개**            ==  assets/domains 의 분야 파일 수
/// DECISIONS **184번**까지  ==  DECISIONS.md 의 마지막 항목 번호
/// ```
///
/// 커밋 해시와 테스트 건수는 기계가 못 본다 — 문서가 그 커밋과 **함께**
/// 커밋되기 때문에 비교할 대상이 없다. 그 둘은 손으로 고치고, 여기서는
/// 지금 값을 알림으로 찍어 준다.
/// 앱이 읽을 분야 목록과 `assets/domains/` 의 실제 파일이 같은가.
///
/// `AssetDomainSource.bundledDomainIds` 는 **손으로 적는 목록이다.** 플러터
/// 자산은 실행 중에 훑을 수 없어서 여기만은 어쩔 수 없다. 그래서 그냥
/// 「예외」로 두지 않고 **다른 방법으로 잠근다** — 파일 목록과 맞대 본다.
///
/// 빠지면 그 분야는 앱에 안 실린다. 남으면 로더가 없는 파일을 찾다 멈춘다.
/// 둘 다 화면에서만 드러나는 종류라 늦게 안다.
List<String> _checkBundledDomains(Directory root, List<String> notes) {
  final file = File(
    '${root.path}/apps/beoba/lib/src/data/asset_domain_source.dart',
  );
  if (!file.existsSync()) {
    return ['앱의 분야 목록 파일을 못 찾았습니다: ${file.path}'];
  }
  final text = file.readAsStringSync();
  final start = text.indexOf('bundledDomainIds');
  final open = start < 0 ? -1 : text.indexOf('[', start);
  final close = open < 0 ? -1 : text.indexOf('];', open);
  if (close < 0) {
    return ['asset_domain_source.dart — bundledDomainIds 목록을 못 읽었습니다. '
        '꼴이 바뀌었으면 이 검사도 같이 고치세요'];
  }
  final listed = RegExp("'([^']+)'")
      .allMatches(text.substring(open, close))
      .map((m) => m.group(1)!)
      .toSet();

  final dir = Directory('${root.path}/packages/domain_data/assets/domains');
  final actual = dir
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((name) => name.endsWith('.json'))
      .map((name) => name.substring(0, name.length - '.json'.length))
      .toSet();

  final issues = <String>[];
  final missing = actual.difference(listed);
  final extra = listed.difference(actual);
  if (missing.isNotEmpty) {
    issues.add('asset_domain_source.dart — 파일은 있는데 목록에 없습니다: '
        '${(missing.toList()..sort()).join(', ')}. 그 분야는 앱에 안 실립니다');
  }
  if (extra.isNotEmpty) {
    issues.add('asset_domain_source.dart — 목록에는 있는데 파일이 없습니다: '
        '${(extra.toList()..sort()).join(', ')}. 로더가 없는 파일을 찾습니다');
  }
  notes.add('앱이 읽을 분야 목록 — 적힌 것 ${listed.length}개 · '
      '실제 파일 ${actual.length}개');
  return issues;
}

/// 조문에 붙은 헌재 결정 표시를 사람이 한 번은 봤는가 — 검사 (ac).
///
/// ## 왜 필요한가
///
/// **조문 본문에는 아무 표시가 없다.** 민법 제999조 제2항은 「10년을 경과하면
/// 소멸된다」로 그대로 서 있고, 그중 일부가 위헌이라는 사실은 조문 **아래
/// 대괄호**에만 적혀 있다. 조문만 인용하면 정확히 반대로 읽힌다.
///
/// ## 왜 「취지를 적어라」가 아닌가
///
/// 처음에는 「대괄호가 붙은 조문은 그 취지가 우리 말에도 있어야 한다」로
/// 생각했다. **그런데 세어 보니 그러면 틀린 말을 쓰게 된다.** 인용 조문
/// 261개 중 표시가 붙은 것이 셋인데, 그중 둘(제166조·제766조)은 같은 결정이고
/// 그 범위가 「과거사정리 기본법 사건에 적용되는 부분」이다. 중고거래 사기를
/// 보는 사람에게 과거사 사건을 적으면 읽을 것만 늘어난다.
///
/// 그래서 요구하는 것은 **판단이 남아 있는가**다. 닿으면 우리 말에 적고,
/// 안 닿으면 왜 안 닿는지 한 줄. `expectsEveryDomain` 의 `skipped` 에 이유를
/// 요구하는 것과 같은 꼴이다 — **일부러 넘긴 것과 빠뜨린 것을 가른다.**
///
/// ## 누가 무엇을 아는가
///
/// 표시가 붙었다는 **사실**은 `law/` 의 PDF 에만 있고 CI 에는 그 폴더가 없다.
/// 그래서 생성기가 `manifest.json` 의 `articles[].courtMark` 에 적고
/// (`unfiled.scanned` 와 같은 꼴), 이 검사는 그걸 읽는다.
/// 사람이 소리 내어 읽는 두 자리 — 검사 (ad).
///
/// ## 되받는 말(`echo`)
///
/// **쉬운 말로 바꿀 수 없는 자리다.** `kPlainTargets` 에 `echo` 가 없어서
/// 쉬운 말 모드에서도 같은 문장이 그대로 나간다. 두 벌을 두지 않기로 했다 —
/// 짧은 되받기 한 문장에 두 벌을 두면 관리만 늘고 값어치가 없다.
///
/// **그래서 처음부터 쉬운 말로 쓴다.** 쉬운 말 한 벌에 거는 규칙을
/// (`PlainKoreanCheck`) 여기에 그대로 건다 — 한 문장 40자 · 서술어 하나 ·
/// 이중부정 금지.
///
/// ## 물어볼 말(`askThis`)
///
/// `openPart` 는 **우리 장부**다. 「원문 미확보」·「제42조 제1항 단서」처럼
/// 우리끼리 쓰는 말이라 창구에서 읽으면 못 알아듣는다. `askThis` 는 그것을
/// **사람이 전화로 읽는 질문 한 문장**으로 옮긴 것이다.
///
/// 세 가지를 본다.
///
/// ```
/// 우리 말이 섞였는가   「미확보」·「매니페스트」 같은 말 → 실패
/// 질문인가             물음표로 끝나야 한다
/// 뒤로 가지 않는가     한 분야에서 시작했으면 그 분야는 다 채워야 한다
/// ```
///
/// ★ **셋째가 톱니바퀴다.** 전 분야를 한 번에 요구하면 오늘 82곳을 다 써야
/// 하고, 아무 요구도 안 하면 채운 분야에 새 `openPart` 가 들어올 때 조용히
/// 벌어진다. **시작한 분야만 잠근다.** 다 차면 그때 전체로 올린다.
/// 빈 절이 왜 비었는가 — 검사 (ae).
///
/// `documents: []` 하나가 두 가지를 뜻하고 있었다. **조문에 원래 없는
/// 것**과 **우리가 아직 못 한 것**이다. 데이터가 똑같아서 화면은 못 가리고,
/// 안전한 쪽으로만 내면 「따로 챙기실 서류는 없어요」라고 말할 수 있는
/// 자리에서도 「저희가 아직 정리하지 못했어요」가 나간다. **우리를 실제보다
/// 못하게 보이게 하고 사람에게도 쓸모가 없다.**
///
/// ★ **`verification.status` 와 같은 성질이다** — 「모른다」와 「아니다」를
/// 가르는 것. 거기서도 `needsCheck` 는 값이 틀렸다는 뜻이 아니라 아직 대조를
/// 못 했다는 뜻이고, 그래서 배지로 그렇다고 말한다.
///
/// ## 톱니바퀴
///
/// (ad) 와 같다 — **시작한 분야만 잠근다.** 전 분야를 한 번에 요구하면 오늘
/// 다 써야 하고, 아무 요구도 안 하면 채운 분야에 새 빈 절이 생겨도 조용하다.
/// 글의 절 순서. **「위」·「아래」가 맞는지는 이 순서로만 정해진다.**
///
/// `apps/beoba/lib/src/sheet/take_away_sheet.dart` 의
/// `TakeAwaySheet.sectionOrder` 와 같은 값이다. 두 벌이지만 **한쪽만 바뀌면
/// 검사가 그것을 잡는다** — 아래 [_checkSpokenPlace] 가 대조한다.
const List<String> _sheetSections = [
  '제가 말씀드린 것',
  '언제까지 하셔야 하는지',
  '먼저 하실 일',
  '달라질 수 있는 것',
  '어디로 가시면 되는지',
  '물어볼 곳',
  '챙기실 것',
  '드는 돈',
  '가서 물어보실 것',
  '법에 적힌 것',
  '꼬리말',
];

/// 화면을 만져야만 뜻이 있는 말. **글에는 만질 것이 없다.**
const List<String> _screenActions = [
  '고르시면', '고르세요', '고르면', '골라', '선택하',
  '누르시면', '누르세요', '누르면', '눌러', '탭', '버튼', '스크롤', '화면',
];

/// 자리를 가리키는 말. **절 순서가 바뀌면 통째로 어긋난다.**
const List<String> _screenPlaces = ['아래', '위에', '위의', '여기'];

/// 「달라질 수 있는 것」의 문장까지 잠근 분야.
///
/// **한 분야씩 늘린다.** 그 분야의 `question`·`consequence` 를 눈으로 보고
/// 글에서도 참인지 확인한 다음 여기 한 줄을 더한다. 넣으면 (af)가 그
/// 분야를 실패로 걸기 시작한다(DECISIONS 290번).
const Set<String> _sheetCautionDomains = {'unfair_dismissal'};

/// 넘기는 자리와 **이유.**
///
/// **찾는 말을 좁히지 않는다.** 좁히면 진짜를 놓친다 — 오탐이 나오면 여기
/// 한 줄을 적는다(`expectsEveryDomain` 의 `skipped` 와 같은 꼴이다).
const Map<String, String> _screenWordSkips = {
  'deposit_return.procedures.proc_court_money.detail':
      '「둘 중 하나를 골라야 하는 것은 아니에요」 — 길을 고르는 이야기지 화면 조작이 아니다',
  'estate_division.documents.doc_family_cert.whatIsThis':
      '「여기에 적혀요」의 「여기」는 그 서류다. 화면이 아니다',
  'estate_division.documents.doc_basic_cert.whatIsThis':
      '「여기에 적혀요」의 「여기」는 그 서류다. 화면이 아니다',
  'inheritance.documents.doc_family_cert.whatIsThis':
      '「여기에 적혀요」의 「여기」는 그 서류다. 화면이 아니다',
  'inheritance.documents.doc_basic_cert.whatIsThis':
      '「여기에 적혀요」의 「여기」는 그 서류다. 화면이 아니다',
  'wage_theft.procedures.proc_civil.detail':
      '「여기서는 세지 않아요」의 「여기」는 이 안내 전체다. 자리를 가리키지 않는다',
  'wage_theft.procedures.proc_labor_report.detail':
      '3절의 「아래 창구」 — 창구는 4절이라 실제로 아래에 있다',
  'debt_relief.procedures.proc_credit_counseling.detail':
      '3절의 「아래 창구」 — 창구는 4절이라 실제로 아래에 있다',
  'debt_relief.jurisdictionGuide.lookupNote':
      '4절 안에서 바로 다음 줄에 창구가 온다',
  'debt_recovery.procedures.proc_certified_mail.detail':
      '3절의 「아래」 — 가리키는 것이 6절 비용이라 아래가 맞다',
  'child_support.procedures.proc_hanbumo_benefit.detail':
      '「아래 이름」은 같은 절에 붙는 「이 말을 그대로 보여 주세요」다',
  'child_support.procedures.proc_legal_no_title.detail':
      '「위에」가 조문 인용 안에 있다. 우리가 쓴 말이 아니다',
  'unfair_dismissal.cautions.ct_two_dates.consequence':
      '「아래 창구」 — 이 줄은 기한 옆에 실리고 창구 두 절은 그보다 아래다',
  'unfair_dismissal.cautions.ct_enforcement_fine.consequence':
      '「매년 2회의 범위에서」의 「범위에」가 걸린 것이다. 자리를 가리키는 말이 아니다',
};

/// 방침 문서에서 사람이 읽는 문장만 뽑는다.
///
/// **줄바꿈으로 자르지 않는다.** 문서는 보기 좋으라고 줄을 나눠 놨을 뿐이고,
/// 읽는 사람에게는 마침표까지가 한 문장이다. 그래서 문단 안의 줄은 이어
/// 붙이고 **마침표로만 자른다.**
///
/// 다만 `-` 로 시작하는 줄은 이어 붙이지 않는다 — 목록의 한 줄은 화면에서도
/// 한 줄이다.
List<String> _policySentences(String markdown) {
  final out = <String>[];
  final buffer = <String>[];
  void flush() {
    if (buffer.isEmpty) return;
    out.addAll(PlainKoreanCheck.sentences(buffer.join(' ')));
    buffer.clear();
  }

  var inFence = false;
  for (final raw in markdown.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    if (line.isEmpty || line.startsWith('#') || line.startsWith('---')) {
      flush();
      continue;
    }
    // 강조와 낫표는 화면에서 글자가 아니다. 길이에 넣지 않는다.
    final bare = line.replaceAll('**', '').replaceAll('「', '').replaceAll('」', '');
    if (bare.startsWith('- ')) {
      flush();
      out.add(bare.substring(2).trim());
      continue;
    }
    buffer.add(bare);
  }
  flush();
  return out.where((s) => s.isNotEmpty).toList();
}

/// 개인정보처리방침이 아직 참인가 — 검사 (ah).
///
/// ## 왜 검사가 필요한가
///
/// **방침은 문서인데, 거짓이 되는 것은 코드가 하는 일이다.** 「분석 좀
/// 붙여 보자」 한 줄이면 「밖으로 나가는 것은 없습니다」가 그날로 거짓말이
/// 된다. 고친 사람은 자기가 방침을 어겼다는 것을 모른다 — 방침을 안 봤으니까.
///
/// 「문서의 숫자는 검사가 센다」(238번)와 같은 자리다. 다만 여기서 세는 것은
/// 숫자가 아니라 **없다는 사실**이다. 없다는 말은 **하나가 생기는 순간**
/// 거짓이 된다.
///
/// ## 실패 메시지가 몇 번 절인지 말한다
///
/// 「네트워크 호출이 있습니다」로 끝나면 고치는 사람은 검사를 고친다.
/// **「방침 3절이 거짓이 됩니다」라고 해야 문서를 같이 고친다.**
///
/// ## 세지 않는 것 — 엔진 안에 문자열로 든 주소
///
/// 빌드 산출물 `flutter.js` 안에는 `www.gstatic.com` 이 들어 있다. 그런데
/// 그 자리는 `useLocalCanvasKit` 이 거짓일 때만 쓰는 갈래다 —
/// `--no-web-resources-cdn` 이 그 값을 켠다. **적힌 주소를 세면 참인 방침에
/// 빨간불이 난다.** 그래서 산출물을 뒤지지 않고 **플래그를 지킨다** —
/// 저장소에 커밋된 `flutter build web` 줄 전부에 그 플래그가 붙어 있는가.
/// CONTRIBUTING.md 가 「플래그를 빼지 않는다」고 적어 둔 바로 그 자리다.
List<String> _checkPrivacyPolicy(
  Directory root,
  List<String> notes,
  List<String> warnings, {
  required bool release,
}) {
  final issues = <String>[];

  final policy = File('${root.path}/docs/개인정보처리방침.md');
  if (!policy.existsSync()) {
    return ['개인정보처리방침 문서가 없습니다 (${policy.path}). '
        '이 검사는 그 문서가 참인지만 봅니다 — 문서가 없으면 볼 것이 없습니다'];
  }

  // 앱에 들어가는 코드만 본다. `tool/` 은 원문을 받아 오는 쪽이라 네트워크를
  // 부르는 것이 당연하고, 그건 우리 기계에서 도는 것이지 사용자 기기가 아니다.
  final libs = <Directory>[
    Directory('${root.path}/apps/beoba/lib'),
    for (final entity
        in Directory('${root.path}/packages').listSync().whereType<Directory>())
      Directory('${entity.path}/lib'),
  ];
  final dart = <File>[
    for (final dir in libs)
      if (dir.existsSync())
        ...dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.endsWith('.g.dart'))
            .where((f) => !f.path.endsWith('.freezed.dart')),
  ];
  if (dart.isEmpty) {
    return ['개인정보처리방침 — 볼 Dart 파일이 0개입니다. '
        '검사가 돌긴 했지만 아무것도 안 봤습니다'];
  }

  // ── 3절 · 밖으로 나가는 것 ────────────────────────────────────
  //
  // **부를 수 있는 자리 자체를 센다.** 「지금은 안 부른다」가 아니라
  // 「부를 것이 없다」여야 방침이 참이다.
  final network = RegExp(
    r'package:http/|package:dio/|package:web_socket|HttpClient\(|'
    r'\bWebSocket\b|XMLHttpRequest|\.fetch\(|\bSocket\.connect',
  );
  final callers = <String>[];
  for (final file in dart) {
    if (!network.hasMatch(file.readAsStringSync())) continue;
    callers.add(_relative(root, file));
  }
  if (callers.isNotEmpty) {
    issues.add('**개인정보처리방침 3절이 거짓이 됩니다** — '
        '「이 앱은 인터넷으로 어디에도 정보를 보내지 않습니다」. '
        '네트워크를 부를 수 있는 자리: ${callers.join(" · ")}');
  }

  // ── 1절 · 기기에 남기는 것 ───────────────────────────────────
  final prefsKeys = <String>{};
  var prefsFiles = 0;
  for (final file in dart) {
    final source = file.readAsStringSync();
    if (!source.contains('SharedPreferences')) continue;
    prefsFiles++;
    for (final m in RegExp(
      r'(?:get|set)(?:Bool|String|Int|Double|StringList)\(\s*'
      r"(?:'([^']*)'|(\w+))",
    ).allMatches(source)) {
      final literal = m.group(1);
      if (literal != null) {
        prefsKeys.add(literal);
        continue;
      }
      // 상수 이름으로 불렀으면 그 상수의 값을 같은 파일에서 찾는다.
      final name = m.group(2)!;
      final declared =
          RegExp("const String $name = '([^']*)';").firstMatch(source);
      prefsKeys.add(declared == null ? '이름만 있는 값($name)' : declared.group(1)!);
    }
  }
  // 2026-09-16 — 둘이 됐다. 「쉬운 말로 볼지」를 기억한다(DECISIONS 289번).
  // 방침 1절을 먼저 고치고 이 목록을 고쳤다. **하나라도 더 생기면 다시 빨갛다.**
  const allowedKeys = {'tally_consent', 'plain_mode'};
  if (prefsKeys.length != allowedKeys.length ||
      !prefsKeys.containsAll(allowedKeys)) {
    issues.add('**개인정보처리방침 1절이 거짓이 됩니다** — '
        '「두 가지입니다 — 「이용 통계를 세도 될까요」에 답하신 내용 · 쉬운 말로 '
        '볼지 고르신 것」. '
        '기기에 남기는 키: '
        '${prefsKeys.isEmpty ? "하나도 못 찾았습니다" : prefsKeys.join(" · ")}');
  }

  // ── 4절 · 이용 통계 ──────────────────────────────────────────
  final sinks = <String>[];
  for (final file in dart) {
    for (final m in RegExp(r'class (\w+) implements TallySink')
        .allMatches(file.readAsStringSync())) {
      sinks.add(m.group(1)!);
    }
  }
  if (sinks.length != 1 || sinks.single != 'NoopTallySink') {
    issues.add('**개인정보처리방침 4절이 거짓이 됩니다** — '
        '「어디에도 보내지 않고, 기기에 쌓아 두지도 않습니다」. '
        'TallySink 구현체: '
        '${sinks.isEmpty ? "하나도 못 찾았습니다" : sinks.join(" · ")}. '
        '보내기 시작하면 **방침을 먼저 고치고 앱에서 다시 여쭈어야 합니다**');
  }

  // ── 5절 · 웹으로 쓰실 때 ─────────────────────────────────────
  //
  // (가) 우리가 쓴 웹 파일이 바깥 주소를 부르지 않는가. 주석은 뗀다 —
  //      주석에 적힌 참고 주소는 브라우저가 부르지 않는다.
  final webFiles = <File>[];
  final outside = <String>[];
  final host = RegExp(r'https?://([A-Za-z0-9.\-]+)');
  final htmlComment = RegExp(r'<!--[\s\S]*?-->');
  const knownSafe = {'www.w3.org'}; // SVG·XML 이름공간. 부르는 주소가 아니다.
  final web = Directory('${root.path}/apps/beoba/web');
  if (web.existsSync()) {
    for (final entity in web.listSync(recursive: true).whereType<File>()) {
      if (!RegExp(r'\.(html|json|js|css)$').hasMatch(entity.path)) continue;
      webFiles.add(entity);
      final source = entity.readAsStringSync().replaceAll(htmlComment, ' ');
      for (final m in host.allMatches(source)) {
        if (knownSafe.contains(m.group(1))) continue;
        outside.add('${_relative(root, entity)} → ${m.group(1)}');
      }
    }
  }
  if (webFiles.isEmpty) {
    issues.add('개인정보처리방침 5절 — 볼 웹 파일이 0개입니다. '
        '검사가 돌긴 했지만 아무것도 안 봤습니다');
  }
  if (outside.isNotEmpty) {
    issues.add('**개인정보처리방침 5절이 거짓이 됩니다** — '
        '「바깥 회사 서버에서 가져오는 것은 없습니다」. '
        '${outside.toSet().join(" · ")}');
  }

  // (나) 웹을 굽는 줄에서 플래그가 빠지지 않았는가.
  final buildLines = <String>[];
  final missingFlag = <String>[];
  for (final name in const [
    '.github/workflows/ci.yml',
    'CONTRIBUTING.md',
    'docs/현황_인수인계.md',
  ]) {
    final file = File('${root.path}/$name');
    if (!file.existsSync()) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('flutter build web')) continue;
      buildLines.add('$name:${i + 1}');
      if (lines[i].contains('--no-web-resources-cdn')) continue;
      missingFlag.add('$name:${i + 1}');
    }
  }
  if (buildLines.isEmpty) {
    issues.add('개인정보처리방침 5절 — 웹을 굽는 줄이 0개입니다. '
        '명령이 옮겨 갔으면 이 검사에도 그 자리를 알려 주세요');
  }
  if (missingFlag.isNotEmpty) {
    issues.add('**개인정보처리방침 5절이 거짓이 됩니다** — '
        '「글꼴도 그림도 이 앱 안에 들어 있습니다」. '
        '`--no-web-resources-cdn` 이 빠진 줄: ${missingFlag.join(" · ")}. '
        '빼면 CanvasKit 과 엔진 글꼴을 gstatic 에서 받습니다');
  }

  // ── 전체 · 분석 SDK ──────────────────────────────────────────
  //
  // 붙이지 말라는 것은 (o) 가 이미 막는다. 여기서 또 보는 이유는 **막는 말과
  // 거짓이 되는 자리가 다르기 때문이다** — (o) 는 「넣지 마세요」라고 하고,
  // 여기서는 「넣으면 방침의 어느 문장이 거짓이 되는지」를 말한다.
  // 목록은 (o) 의 것을 그대로 쓴다. 둘로 나누면 한쪽이 낡는다.
  final analytics = <String>[];
  final pubspec = File('${root.path}/apps/beoba/pubspec.yaml');
  if (pubspec.existsSync()) {
    final source = pubspec.readAsStringSync();
    for (final package in _analyticsPackages) {
      if (source.contains(package)) analytics.add(package);
    }
  }
  if (analytics.isNotEmpty) {
    issues.add('**개인정보처리방침 전체가 거짓이 됩니다** — '
        '맨 위의 「입력하신 내용을 서버로 보내지 않습니다」부터 무너집니다. '
        '분석 SDK: ${analytics.join(" · ")}');
  }

  // ── 2절 · 처음 화면에 직접 쓰신 글 ──────────────────────────
  //
  // 「직접 쓰신 글도 저장하지 않습니다. 읽는 것도 기기 안에서 끝납니다.」
  //
  // 그 글은 앱 안에서 딱 한 번 읽힌다 — 우리가 다루지 못하는 문제가 섞여
  // 있는지 보려고. 읽고 나면 **참·거짓 하나로 사그라든다.** 방침 2절이
  // 참이려면 그 사이에 아무 데도 안 실려야 한다.
  //
  // **이름을 든 파일이 분모다.** 그 파일에 저장·전송·복사가 함께 들어오는
  // 순간을 잡는다. 이름을 하나도 못 찾으면 이름이 바뀐 것이라 그때도 멈춘다.
  final narrativeName = RegExp("narrativeField|'userNarrative'");
  final carriers = RegExp(
    r'SharedPreferences|Clipboard\.|jsonEncode|toJson\(|extra:',
  );
  final narrativeFiles = <String>[];
  final narrativeLeaks = <String>[];
  for (final file in dart) {
    final source = file.readAsStringSync();
    if (!narrativeName.hasMatch(source)) continue;
    narrativeFiles.add(_relative(root, file));
    if (carriers.hasMatch(source)) narrativeLeaks.add(_relative(root, file));
  }
  if (narrativeFiles.isEmpty) {
    issues.add('개인정보처리방침 2절 — 직접 쓰신 글을 가리키는 이름을 하나도 '
        '못 찾았습니다. 이름이 바뀌었으면 이 검사에도 알려 주세요');
  }
  if (narrativeLeaks.isNotEmpty) {
    issues.add('**개인정보처리방침 2절이 거짓이 됩니다** — '
        '「처음 화면에 직접 쓰신 글도 저장하지 않습니다」. '
        '그 글을 든 파일에 저장·전송·복사가 함께 있습니다: '
        '${narrativeLeaks.join(" · ")}');
  }

  // ── 세 곳이 같은가 ──────────────────────────────────────────
  //
  // 방침이 놓이는 자리는 셋이다 — 앱 안 · 웹앱 안(같은 라우트) · 정적 한 장.
  // **원본은 하나뿐이고 나머지는 굽는 것이다.** 손으로 한쪽만 고치면 그
  // 순간부터 두 사람이 서로 다른 방침을 읽는다. 그리고 스토어 심사자가 보는
  // 것은 하필 손이 잘 안 가는 쪽이다.
  final baked = <String, String>{};
  try {
    baked.addAll(bakePolicy(parsePolicy(policy.readAsStringSync())));
  } on FormatException catch (e) {
    issues.add('개인정보처리방침을 굽지 못했습니다 — ${e.message}');
  }
  final drifted = <String>[];
  for (final MapEntry(key: path, value: text) in baked.entries) {
    final out = File('${root.path}/$path');
    if (out.existsSync() && out.readAsStringSync() == text) continue;
    drifted.add(path);
  }
  if (drifted.isNotEmpty) {
    issues.add('**방침이 자리마다 다릅니다** — ${drifted.join(" · ")} 가 '
        '$policySourcePath 와 어긋났습니다. '
        '`dart run packages/engines/tool/build_privacy_page.dart` 로 다시 굽고 '
        '커밋하세요. **손으로 고치는 자리가 아닙니다**');
  }

  // ── 9절 · 물어보실 곳 ───────────────────────────────────────
  //
  // 제30조 제1항 6호가 말하는 자리다. **빈 채로 배포되면 안 된다.**
  //
  // 그런데 지금 실패로 두면 주소가 생길 때까지 아무 일도 못 하고, 경고로만
  // 두면 배포하는 날 아무도 안 본다. 그래서 **세기를 둘로 나눈다** —
  // 평소에는 경고, `--release` 에서는 실패. 배포하는 사람이 그 문을 지난다.
  final source = policy.readAsStringSync();
  final ninth = source.contains('## 9. ')
      ? source.split('## 9. ').last.split(policyPrivateMark).first
      : '';
  final reachable = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+|\d{2,4}-\d{3,4}-\d{4}');
  if (ninth.isEmpty) {
    issues.add('개인정보처리방침 — 9절(물어보실 곳)을 못 찾았습니다. '
        '절 번호가 바뀌었으면 이 검사도 함께 고치세요');
  } else if (!reachable.hasMatch(ninth)) {
    const message = '개인정보처리방침 9절 — 물어보실 곳이 비어 있습니다. '
        '메일 주소나 전화번호가 하나도 없습니다. '
        '제30조 제1항 6호가 말하는 자리이고, **빈 채로 배포하면 안 됩니다**';
    if (release) {
      issues.add('**$message**');
    } else {
      warnings.add('$message (배포 게이트 `melos run verify_release` 에서는 '
          '실패입니다)');
    }
  }

  // ── 9절 위쪽 · 쉬운 말 ───────────────────────────────────────
  //
  // **이 문서는 한국어가 서툰 분도 읽는다.** 화면 문구에 거는 규칙을 그대로
  // 건다 — 문장 길이 · 이어 붙인 서술어 · 시키는 말.
  //
  // 「만드는 사람에게」 아래는 우리끼리 보는 기록이라 뺀다. 원본이 없는
  // 글이라 `original` 자리에 같은 글을 넣는다 — 단정해졌는지는 견줄 것이
  // 없어 못 보고, 문장 규칙만 본다.
  final shown = source.split(policyPrivateMark).first;
  final spoken = _policySentences(shown);
  if (spoken.isEmpty) {
    issues.add('개인정보처리방침 — 쉬운 말로 잴 문장이 0개입니다. '
        '문서 모양이 바뀌었으면 이 검사도 함께 고치세요');
  }
  var plainIssues = 0;
  for (final sentence in spoken) {
    for (final issue
        in const PlainKoreanCheck().check(original: sentence, plain: sentence)) {
      plainIssues++;
      issues.add('개인정보처리방침 — 쉬운 말: ${issue.message}');
    }
  }

  notes.add('개인정보처리방침 — Dart 파일 ${dart.length}개 중 네트워크를 '
      '부를 수 있는 자리 ${callers.length}곳 · '
      '기기에 남기는 키 ${prefsKeys.length}개(SharedPreferences 를 쓰는 파일 '
      '$prefsFiles개) · 집계를 보내는 구현체 ${sinks.length}개 · '
      '웹 파일 ${webFiles.length}개 중 바깥 주소 ${outside.toSet().length}개 · '
      '웹을 굽는 줄 ${buildLines.length}개 중 플래그가 빠진 줄 '
      '${missingFlag.length}개 · 분석 SDK ${analytics.length}개 · '
      '직접 쓰신 글을 든 파일 ${narrativeFiles.length}개 중 저장·전송이 섞인 것 '
      '${narrativeLeaks.length}개 · '
      '방침을 놓는 자리 ${baked.length}곳 중 어긋난 곳 ${drifted.length}곳 · '
      '쉬운 말로 잰 문장 ${spoken.length}개 중 걸린 것 $plainIssues개');
  return issues;
}

/// 원격에 올릴 수 없는 것이 추적 목록에 들어오지 않았는가 — 검사 (ai).
///
/// ## 되돌릴 수 없는 자리다
///
/// 다른 검사는 틀리면 고치면 된다. 이건 **한 번 원격에 올라가면 지워도 이력에
/// 남는다.** 그래서 「올린 뒤에 확인」이 성립하지 않는다.
///
/// ## `.gitignore` 를 안 믿는다
///
/// **한 번이라도 `git add` 된 파일은 그 뒤로 `.gitignore` 를 무시하고 계속
/// 추적된다.** 무시 목록이 초록이어도 추적 목록에 들어 있을 수 있다. 그래서
/// `git ls-files` 를 직접 읽는다.
///
/// ## 목록은 코드에 없다
///
/// `docs/원격에_올리지_않는_것.md` 가 목록이고 이 함수는 그 문서를 읽는다.
/// 규칙을 늘릴 때 코드를 안 고친다 — 「문서의 숫자는 검사가 센다」(238번)와
/// 같은 자리다.
///
/// ## 이름이 아니라 값을 찾는다
///
/// `apiKey` 라는 낱말은 코드에 있어도 된다. 이름을 막으면 코드가 자기 필드를
/// 못 부르고, 그러면 사람이 검사를 끈다. **걸렸을 때도 값을 안 찍는다** —
/// 실패 메시지에 비밀을 옮겨 적으면 그 로그가 새 유출처가 된다.
List<String> _checkNeverPublish(Directory root, List<String> notes) {
  const listPath = 'docs/원격에_올리지_않는_것.md';
  final doc = File('${root.path}/$listPath');
  if (!doc.existsSync()) {
    return ['$listPath 가 없습니다. '
        '목록이 없으면 이 검사는 아무것도 막지 못합니다'];
  }

  final issues = <String>[];
  final fences = _fencedLists(doc.readAsStringSync());
  final pathRules = fences['경로'] ?? const <String>[];
  final contentRules = fences['내용'] ?? const <String>[];
  final allowed = (fences['허용'] ?? const <String>[]).toSet();
  if (pathRules.isEmpty || contentRules.isEmpty) {
    issues.add('$listPath — 「경로」와 「내용」 울타리 중 빈 것이 있습니다. '
        '규칙이 0개인 검사는 초록이어도 아무 뜻이 없습니다');
  }

  final tracked = _trackedFiles(root);
  if (tracked.isEmpty) {
    return [
      ...issues,
      '추적 중인 파일이 0개입니다. git 이 없거나 저장소가 아닙니다 — '
          '이 검사는 `git ls-files` 를 읽습니다',
    ];
  }

  // `foo/` 는 그 아래 전부, 그 밖은 파일 이름을 본다. `*` 는 이름 안에서만
  // 늘어난다.
  RegExp nameOf(String rule) => RegExp(
        '^${rule.split('*').map(RegExp.escape).join('[^/]*')}\$',
      );
  final allowedNames = allowed.map(nameOf).toList();
  final caught = <String>[];

  for (final path in tracked) {
    final name = path.split('/').last;
    if (allowedNames.any((r) => r.hasMatch(name))) continue;
    for (final rule in pathRules) {
      final hit = rule.endsWith('/')
          ? path.startsWith(rule)
          : nameOf(rule).hasMatch(name);
      if (!hit) continue;
      caught.add('$path ← 경로 규칙 `$rule`');
      break;
    }
  }

  // 값이 적힌 자리. **이 문서 자신은 뺀다** — 여기 적힌 것은 찾는 규칙이지
  // 값이 아니다. 안 빼면 목록을 적는 순간 검사가 자기 목록에 걸린다.
  final patterns = [for (final rule in contentRules) RegExp(rule)];
  var read = 0;
  for (final path in tracked) {
    if (path == listPath) continue;
    final file = File('${root.path}/$path');
    if (!file.existsSync()) continue;
    String source;
    try {
      source = file.readAsStringSync();
    } on FileSystemException {
      continue;
    } on FormatException {
      continue; // 그림 같은 이진 파일. 글자로 못 읽는다.
    }
    read++;
    for (final pattern in patterns) {
      if (!pattern.hasMatch(source)) continue;
      // **찾은 값을 안 옮겨 적는다.** 규칙 이름만 말한다.
      caught.add('$path ← 내용 규칙 `${pattern.pattern}`');
    }
  }

  if (caught.isNotEmpty) {
    issues.add('**원격에 올리면 안 되는 것이 추적 중입니다** — '
        '${caught.join(" · ")}. '
        '`.gitignore` 에 넣는 것으로는 안 지워집니다. '
        '`git rm --cached` 로 추적에서 빼고, **이미 올린 적이 있으면 이력까지 '
        '봐야 합니다** — $listPath 를 읽으세요');
  }

  notes.add('원격에 올리지 않는 것 — 추적 중인 파일 ${tracked.length}개 중 '
      '걸린 것 ${caught.length}개 (글자로 읽은 것 $read개 · '
      '경로 규칙 ${pathRules.length}개 · 내용 규칙 ${contentRules.length}개 · '
      '허용 ${allowed.length}개)');
  return issues;
}

/// ` ```이름 ` 울타리 안의 줄들. 빈 줄과 앞뒤 공백은 뺀다.
Map<String, List<String>> _fencedLists(String markdown) {
  final out = <String, List<String>>{};
  String? open;
  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('```')) {
      if (open != null) {
        open = null;
        continue;
      }
      final label = line.substring(3).trim();
      if (label.isEmpty) continue;
      open = label;
      out.putIfAbsent(label, () => <String>[]);
      continue;
    }
    if (open == null) continue;
    final value = line.trim();
    if (value.isEmpty) continue;
    out[open]!.add(value);
  }
  return out;
}

/// **실제로 추적 중인 것.** `.gitignore` 가 아니라 `git ls-files` 를 읽는다.
///
/// `-z` 로 받는다 — 그러지 않으면 git 이 한글 경로를 `\355\230\204` 꼴로
/// 따옴표에 싸서 내주고, 그러면 이름 대조가 통째로 빗나간다.
List<String> _trackedFiles(Directory root) {
  final ProcessResult result;
  try {
    result = Process.runSync(
      'git',
      const ['ls-files', '-z'],
      workingDirectory: root.path,
      stdoutEncoding: utf8,
    );
  } on ProcessException {
    return const [];
  }
  if (result.exitCode != 0) return const [];
  return (result.stdout as String)
      .split('\u0000')
      .where((s) => s.isNotEmpty)
      .toList();
}

/// 저장소 뿌리에서 본 경로. 실패 메시지에 절대경로를 뿌리지 않는다.
String _relative(Directory root, File file) => file.path
    .replaceAll(r'\', '/')
    .replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');

/// 만들어 놓고 못 찾게 해 둔 조각이 없는가 — 검사 (ag).
///
/// ## 왜 필요한가
///
/// 떼인 돈의 지급명령 이의신청 2주는 **기한도 조문도 처음부터 있었다.**
/// 그런데 「법원에서 서류를 받았나」를 일부에게만 물어서 **압류를 당했다고
/// 답한 사람에게는 영영 안 닿았다.**
///
/// **만들어 놓고 못 찾게 해 둔 것은 안 만든 것보다 나쁘다.** 안 만든 것은
/// 세면 보이지만 이것은 안 보인다 — 검사가 없으면 영영 모른다
/// (DECISIONS 253번).
///
/// ## 무엇을 보는가
///
/// ```
/// 묻지 않는 필드    showIf 가 보는 이름을 그 분야의 물음이 만들지 않는다
/// 없는 값          == · in 이 요구하는 값이 그 물음의 선택지에 없다
/// ```
///
/// ## 계산으로 생기는 필드는 손으로 안 적는다
///
/// `passed:<기한 id>` 는 물음이 아니라 **기한 결과가 만든다.** 그 이름을 여기
/// 손으로 적으면 목록이 낡는다. **데이터에서 뽑는다** — 그 분야의 기한 id 로
/// 만들면 끝이다(생성기가 `unfiled.scanned` 를 적어 주는 것과 같은 꼴이다).
///
/// ★ 그리고 **접두어가 늘면 이 검사가 먼저 걸린다.** `result_providers.dart`
/// 에서 접두어 상수를 세어 하나가 아니면 실패한다 — 새 계산 필드가 조용히
/// 들어오면 여기서 멈춘다.
List<String> _checkNoDeadEnds(
  Directory root,
  List<File> files,
  List<String> notes,
) {
  final issues = <String>[];

  // 계산으로 생기는 이름의 접두어. **손으로 안 적는다 — 코드에서 읽는다.**
  final providers = File(
    '${root.path}/apps/beoba/lib/src/providers/result_providers.dart',
  );
  final prefixes = <String>[];
  if (providers.existsSync()) {
    for (final m in RegExp(r"const String k\w*Prefix = '([^']+)';")
        .allMatches(providers.readAsStringSync())) {
      prefixes.add(m.group(1)!);
    }
  }
  if (prefixes.length != 1) {
    issues.add('닿을 수 있는가 — 계산 필드의 접두어가 ${prefixes.length}개입니다. '
        '하나일 때만 이 검사가 무엇을 세는지 압니다. 늘었으면 이 검사에도 '
        '그 이름을 어떻게 만드는지 가르치세요');
    return issues;
  }
  final passedPrefix = prefixes.single;

  const sections = [
    'deadlines',
    'procedures',
    'documents',
    'cautions',
    'costs',
    'jurisdiction',
    'limitationRules',
  ];

  var gated = 0;

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;

    // 이 분야가 만들 수 있는 이름과 값.
    final made = <String, Set<String>>{};
    void note(String field, [Object? value]) {
      final bucket = made.putIfAbsent(field, () => <String>{});
      if (value != null && value is! Map && value is! List) {
        bucket.add('$value');
      }
    }

    for (final raw in (json['intake'] as List<dynamic>? ?? const [])) {
      final q = raw as Map<String, dynamic>;
      final field = q['field'];
      if (field is String) note(field);
      for (final rawOption in (q['options'] as List<dynamic>? ?? const [])) {
        final o = rawOption as Map<String, dynamic>;
        if (field is String) note(field, o['value']);
        for (final e
            in ((o['setsField'] as Map<String, dynamic>?) ?? const {}).entries) {
          note(e.key, e.value);
        }
      }
    }
    for (final raw in (json['costScenarios'] as List<dynamic>? ?? const [])) {
      for (final e in (((raw as Map<String, dynamic>)['facts']
                  as Map<String, dynamic>?) ??
              const {})
          .entries) {
        note(e.key, e.value);
      }
    }
    // **기한 결과가 만드는 이름.** 손으로 안 적는다.
    for (final raw in (json['deadlines'] as List<dynamic>? ?? const [])) {
      note('$passedPrefix${(raw as Map<String, dynamic>)['id']}');
    }

    void look(String where, Object? showIf) {
      if (showIf is! Map<String, dynamic>) return;
      gated++;
      final seen = <String>{};
      final wants = <String, List<String>>{};
      void scan(Object? node) {
        if (node is Map) {
          for (final e in node.entries) {
            if (e.key == 'var' && e.value is String) seen.add(e.value as String);
            if ((e.key == '==' || e.key == 'in') &&
                e.value is List &&
                (e.value as List).length == 2) {
              final pair = e.value as List;
              final left = pair.first;
              final right = pair.last;
              if (left is Map && left['var'] is String) {
                final field = left['var'] as String;
                if (e.key == '==' && right is! Map && right is! List) {
                  (wants[field] ??= []).add('$right');
                }
                if (e.key == 'in' && right is List) {
                  (wants[field] ??= []).addAll(right.map((v) => '$v'));
                }
              }
            }
            scan(e.value);
          }
        } else if (node is List) {
          for (final v in node) {
            scan(v);
          }
        }
      }

      scan(showIf);
      for (final field in seen) {
        if (!made.containsKey(field)) {
          issues.add('$where — 이 분야가 만들지 않는 이름을 봅니다: $field. '
              '묻는 물음이 없으면 이 조각은 어떤 답으로도 안 뜹니다');
        }
      }
      for (final entry in wants.entries) {
        final have = made[entry.key];
        if (have == null || have.isEmpty) continue;
        final missing =
            entry.value.where((v) => !have.contains(v)).toSet();
        if (missing.length == entry.value.toSet().length) {
          issues.add('$where — 선택지에 없는 값을 요구합니다: '
              '${entry.key} = ${missing.join(", ")}. '
              '있는 것: ${(have.toList()..sort()).join(", ")}');
        }
      }
    }

    for (final section in sections) {
      for (final raw in (json[section] as List<dynamic>? ?? const [])) {
        final item = raw as Map<String, dynamic>;
        look('$domainId.$section.${item['id']}', item['showIf']);
      }
    }
    final guide = json['jurisdictionGuide'];
    if (guide is Map<String, dynamic>) {
      for (final raw in (guide['branches'] as List<dynamic>? ?? const [])) {
        final br = raw as Map<String, dynamic>;
        look('$domainId.jurisdictionGuide.${br['id']}', br['showIf']);
      }
    }
  }

  if (gated == 0) {
    issues.add('닿을 수 있는가 — 조건이 붙은 조각이 0개입니다. '
        '검사가 돌긴 했지만 아무것도 안 봤습니다');
  }
  notes.add('닿을 수 있는가 — 조건이 붙은 조각 $gated개를 봤습니다 '
      '(계산으로 생기는 이름은 `$passedPrefix<기한 id>` 하나입니다)');
  return issues;
}

/// 글에 화면 조작을 가리키는 말이 들어가지 않는가 — 검사 (af).
///
/// ## 화면에는 조작이 있고 글에는 없다
///
/// 「일하던 곳을 고르시면 어느 지방노동위원회인지 나와요」는 화면에서는
/// 맞는 말이다. 그런데 **카카오톡으로 받은 사람에게는 고를 것이 없다.**
/// 글에는 **이미 고른 결과**가 들어가 있어야 한다.
///
/// ## 「위」와 「아래」는 절 순서에 매여 있다
///
/// 3절에서 「아래 창구」는 맞다 — 창구가 4절이다. 그런데 6절에서 같은 말을
/// 쓰면 틀린다. **절 순서를 바꾸면 데이터에 적힌 말이 통째로 어긋난다.**
/// 그래서 순서를 [_sheetSections] 상수로 두고 글 쪽과 대조한다
/// (DECISIONS 251번).
///
/// ## 「달라질 수 있는 것」이 2026-10-13 부터 글에 실린다
///
/// 예전에는 이 자리를 안 봤다 — 화면에만 나갔으니 조작 이야기를 해도 됐다.
/// 이제는 **그 사람의 답 때문에 뜬 것**이 물음과 답째로 글에 실린다
/// (DECISIONS 290번). 그래서 보는 자리가 둘 늘었다.
///
/// ```
/// cautions.question      늘 본다 — 늘 뜨는 것도 물음은 글에 간다
/// cautions.consequence   showIf 가 있는 것만 — 그것만 글에 실린다
/// ```
///
/// ★★ **시작한 분야만 잠근다**(ad·ae와 같은 톱니). 지금 10개 분야에 화면을
/// 가리키는 문장이 45곳 있고, 그건 그 자리가 화면용으로 쓰였기 때문이다.
/// 한 번에 다 고치려면 열 분야의 문장을 눈으로 못 보고 손보게 된다.
/// 잠근 분야는 실패로 걸고 **나머지는 몇 곳인지 센다** — 늘면 그것대로
/// 신호다.
List<String> _checkSpokenPlace(List<File> files, List<String> notes) {
  final issues = <String>[];

  // 글에 실리는 자리만.
  const fields = {
    'intake': ['text', 'echo'],
    'deadlines': ['label', 'whatIsThis'],
    'procedures': ['label', 'whatIsThis', 'detail'],
    'documents': ['label', 'whatIsThis'],
    'costs': ['label', 'whatIsThis'],
    'costScenarios': ['label', 'option'],
    'jurisdiction': ['label', 'rule'],
  };

  var scanned = 0;
  var hits = 0;
  final used = <String>{};
  var paperDebt = 0;
  final paperDebtDomains = <String>{};

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;

    void look(String where, Object? text) {
      if (text is! String || text.trim().isEmpty) return;
      scanned++;
      final found = [
        ..._screenActions.where(text.contains),
        ..._screenPlaces.where(text.contains),
      ];
      if (found.isEmpty) return;
      final key = '$domainId.$where';
      if (_screenWordSkips.containsKey(key)) {
        used.add(key);
        return;
      }
      hits++;
      issues.add('$key — 글에 화면을 가리키는 말이 있습니다: '
          '${found.join(", ")}. 글에는 만질 것도 스크롤할 것도 없습니다. '
          '넘겨야 할 자리면 _screenWordSkips 에 이유를 적으세요');
    }

    // 「달라질 수 있는 것」. **잠근 분야만 본다.**
    for (final raw in (json['cautions'] as List<dynamic>? ?? const [])) {
      final item = raw as Map<String, dynamic>;
      final onPaper = [
        'question',
        // 늘 뜨는 것은 물음만 글에 간다 — 답은 안 실린다.
        if (item['showIf'] != null) 'consequence',
      ];
      for (final field in onPaper) {
        final text = item[field];
        if (text is! String || text.trim().isEmpty) continue;
        if (_sheetCautionDomains.contains(domainId)) {
          look('cautions.${item['id']}.$field', text);
          continue;
        }
        if (_screenActions.any(text.contains) ||
            _screenPlaces.any(text.contains)) {
          paperDebt++;
          paperDebtDomains.add(domainId);
        }
      }
    }

    for (final entry in fields.entries) {
      for (final raw in (json[entry.key] as List<dynamic>? ?? const [])) {
        final item = raw as Map<String, dynamic>;
        for (final field in entry.value) {
          look('${entry.key}.${item['id'] ?? item['label']}.$field',
              item[field]);
        }
        for (final rawOption in (item['options'] as List<dynamic>? ?? const [])) {
          final option = rawOption as Map<String, dynamic>;
          look('${entry.key}.${item['id']}.options.${option['value']}.echo',
              option['echo']);
        }
      }
    }
    final guide = json['jurisdictionGuide'];
    if (guide is Map<String, dynamic>) {
      look('jurisdictionGuide.lookupNote', guide['lookupNote']);
    }
    for (final entry
        in ((json['emptySections'] as Map<String, dynamic>?) ?? const {})
            .entries) {
      look('emptySections.${entry.key}.why',
          (entry.value as Map<String, dynamic>)['why']);
    }
    void walkAsk(Object? node, Object? ident) {
      if (node is List) {
        for (final v in node) {
          walkAsk(v, ident);
        }
        return;
      }
      if (node is! Map<String, dynamic>) return;
      final id = node['id'] ?? ident;
      final v = node['verification'];
      if (v is Map<String, dynamic> && v['askThis'] != null) {
        look('$id.askThis', v['askThis']);
      }
      for (final e in node.entries) {
        walkAsk(e.value, id);
      }
    }

    walkAsk(json, domainId);
  }

  if (scanned == 0) {
    issues.add('글의 화면 조작 말 — 훑은 문장이 0개입니다. '
        '검사가 돌긴 했지만 아무것도 안 봤습니다');
  }

  // 낡은 줄. 문장이 고쳐졌는데 넘김이 남아 있으면 지운다.
  final stale = _screenWordSkips.keys.where((k) => !used.contains(k));
  if (stale.isNotEmpty) {
    issues.add('글의 화면 조작 말 — 이제 안 걸리는데 넘김이 남아 있습니다: '
        '${(stale.toList()..sort()).join(", ")}');
  }

  // **절 순서가 글 쪽과 같은가.** 한쪽만 바뀌면 「아래 창구」가 통째로 어긋난다.
  final sheet = File(
    '${files.first.parent.parent.parent.parent.parent.path}'
    '/apps/beoba/lib/src/sheet/take_away_sheet.dart',
  );
  if (sheet.existsSync()) {
    final text = sheet.readAsStringSync();
    for (final section in _sheetSections) {
      if (!text.contains("'$section'")) {
        issues.add('글의 절 순서 — 「$section」이 take_away_sheet.dart 의 '
            'sectionOrder 에 없습니다. 순서가 바뀌면 데이터의 '
            '「아래 창구」 같은 말이 통째로 어긋납니다');
      }
    }
  }

  notes.add('글의 화면 조작 말 — 문장 $scanned개를 훑어 걸린 것 $hits곳 · '
      '이유를 적고 넘긴 것 ${used.length}곳');
  notes.add('글에 실리는 「달라질 수 있는 것」 — 잠근 분야 '
      '${_sheetCautionDomains.length}개 · 아직 화면을 가리키는 문장 '
      '$paperDebt곳(분야 ${paperDebtDomains.length}개). 그 분야를 '
      '_sheetCautionDomains 에 넣기 전에 문장을 눈으로 보고 고치세요');
  return issues;
}

List<String> _checkEmptyReasons(
  List<File> files,
  List<String> notes,
  List<String> warnings,
) {
  final issues = <String>[];

  /// 글과 화면에서 절이 되는 자리. 비어 있을 수 있고, 비면 이유가 필요하다.
  const sections = ['deadlines', 'documents', 'costs', 'jurisdiction'];

  var blank = 0;
  var explained = 0;
  final started = <String>[];

  for (final file in files) {
    // **공용 조각은 글이 없다.** `_shared_crisis` 는 분야가 아니라 모든
    // 분야가 빌려 쓰는 조각이라 「정리해서 가져가기」가 안 그려진다.
    // 빈 절을 셀 자리가 아니다.
    if (file.uri.pathSegments.last.startsWith('_')) continue;

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;
    final reasons =
        (json['emptySections'] as Map<String, dynamic>?) ?? const {};

    final missing = <String>[];
    for (final section in sections) {
      final items = json[section];
      // 비용은 갈래(costScenarios)로도 나간다. 둘 다 없어야 빈 절이다.
      final alsoEmpty = section != 'costs' ||
          (json['costScenarios'] as List<dynamic>? ?? const []).isEmpty;
      if (items is List && items.isNotEmpty || !alsoEmpty) {
        if (reasons.containsKey(section)) {
          issues.add('$domainId.emptySections.$section — 비어 있지 않은데 '
              '왜 비었는지가 적혀 있습니다. 줄을 지우세요');
        }
        continue;
      }
      blank++;
      final row = reasons[section];
      if (row is! Map<String, dynamic>) {
        missing.add(section);
        continue;
      }
      explained++;
      final why = row['why'];
      if (why is! String || why.trim().isEmpty) {
        issues.add('$domainId.emptySections.$section — why 가 비어 있습니다. '
            '사람에게 그대로 나가는 줄입니다');
      }
      const kinds = {'none', 'notYet'};
      if (!kinds.contains(row['kind'])) {
        issues.add('$domainId.emptySections.$section — kind 가 '
            'none(조문에 없다) 또는 notYet(우리 쪽 사정) 이어야 합니다');
      }
    }

    for (final key in reasons.keys) {
      if (!sections.contains(key)) {
        issues.add('$domainId.emptySections.$key — 절이 아닙니다. '
            '${sections.join(" · ")} 중에서 고르세요');
      }
    }

    if (reasons.isNotEmpty) started.add(domainId);
    // **2026-09-04 에 전 분야로 올렸다.** 29곳이 다 찼으니 이제 빈 절이
    // 새로 생기면 그 자리에서 걸린다.
    if (missing.isNotEmpty) {
      issues.add('$domainId — ${missing.join(", ")} 가 비어 있는데 왜 비었는지가 '
          '없습니다. 없으면 글이 안전한 쪽(「아직 정리하지 못했어요」)으로 '
          '나가는데, 그것이 거짓일 수 있습니다');
    }
  }

  if (blank == 0) {
    issues.add('빈 절의 이유 — 빈 절이 0곳입니다. 검사가 돌긴 했지만 '
        '아무것도 안 봤습니다');
  }
  notes.add('빈 절의 이유 — 빈 절 $blank곳 중 $explained곳에 이유가 있습니다 '
      '(다 쓴 분야 ${started.length}개: ${started.isEmpty ? "없음" : started.join(" · ")})');

  return issues;
}

List<String> _checkSpokenLines(
  List<File> files,
  List<String> notes,
  List<String> warnings,
) {
  final issues = <String>[];
  const checker = PlainKoreanCheck();

  /// `askThis` 에 있으면 안 되는 말. **우리 장부의 어휘다.**
  const ourWords = [
    '미확보', '미확인', 'openPart', '매니페스트', '근거 못 찾음',
    '확인 전', '영영', '조문 해석', '원본',
  ];

  var echoCount = 0;
  var askCount = 0;
  var openCount = 0;
  final started = <String>[];

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;

    // ── 되받는 말 ────────────────────────────────────────────────
    void plainLine(String where, String text) {
      echoCount++;
      for (final issue in checker.check(
        original: text,
        plain: text,
        terms: const [],
      )) {
        issues.add('$where — ${issue.message} '
            '(되받는 말은 쉬운 말 모드에서도 그대로 나갑니다. '
            '처음부터 쉬운 말로 쓰세요)');
      }
    }

    for (final raw in (json['intake'] as List<dynamic>? ?? const [])) {
      final q = raw as Map<String, dynamic>;
      final line = q['echo'];
      if (line is String && line.trim().isNotEmpty) {
        // `{value}` 자리는 값이 들어가는 곳이라 길이를 재기 전에 채워 본다.
        plainLine('$domainId.intake.${q['id']}.echo',
            line.replaceAll('{value}', '2026년 8월 1일'));
      }
      for (final rawOption in (q['options'] as List<dynamic>? ?? const [])) {
        final o = rawOption as Map<String, dynamic>;
        final optionLine = o['echo'];
        if (optionLine is String && optionLine.trim().isNotEmpty) {
          plainLine(
            '$domainId.intake.${q['id']}.options.${o['value']}.echo',
            optionLine,
          );
        }
      }
    }

    // ── 물어볼 말 ────────────────────────────────────────────────
    final missing = <String>[];
    var hasAsk = false;
    void walk(Object? node, String where) {
      if (node is List) {
        for (final v in node) {
          walk(v, where);
        }
        return;
      }
      if (node is! Map<String, dynamic>) return;
      final ident = node['id'] ?? node['term'];
      for (final entry in node.entries) {
        if (entry.key == 'verification' && entry.value is Map<String, dynamic>) {
          final v = entry.value as Map<String, dynamic>;
          if (v['openPart'] is String) {
            openCount++;
            final ask = v['askThis'];
            final at = '$domainId.${ident ?? where}';
            if (ask is! String || ask.trim().isEmpty) {
              missing.add(at);
              continue;
            }
            hasAsk = true;
            askCount++;
            final hit = ourWords.where(ask.contains).toList();
            if (hit.isNotEmpty) {
              issues.add('$at.askThis — 우리끼리 쓰는 말이 들어 있습니다: '
                  '${hit.join(', ')}. 창구에서 그대로 읽을 문장이라 '
                  '우리 사정은 openPart 에 두세요');
            }
            if (!ask.trim().endsWith('?')) {
              issues.add('$at.askThis — 물음표로 끝나지 않습니다. '
                  '전화로 읽는 질문 한 문장입니다');
            }
          }
        }
        walk(entry.value, where);
      }
    }

    walk(json, domainId);

    if (hasAsk) started.add(domainId);
    // **2026-09-04 에 전 분야로 올렸다.** 82곳이 다 차기 전에는 「시작한
    // 분야만」이었다 — 전부를 한 번에 요구하면 첫날에 82곳을 다 써야 했다.
    // 다 찼으니 이제 **openPart 가 새로 생기면 그 자리에서 걸린다.**
    if (missing.isNotEmpty) {
      issues.add('$domainId — openPart 가 있는데 물어볼 말이 없습니다: '
          '${missing.join(', ')}. openPart 는 우리 장부이고 '
          'askThis 는 사람이 전화로 읽는 질문입니다');
    }
  }

  if (openCount == 0) {
    issues.add('되받는 말·물어볼 말 — openPart 가 0곳입니다. '
        '검사가 돌긴 했지만 아무것도 안 봤습니다');
  }
  notes.add('되받는 말 — $echoCount곳을 쉬운 말 규칙으로 봤습니다');
  notes.add('물어볼 말 — openPart $openCount곳 중 $askCount곳에 질문이 있습니다 '
      '(다 쓴 분야 ${started.length}개: ${started.isEmpty ? "없음" : started.join(" · ")})');

  return issues;
}

List<String> _checkCourtMarks(Directory root, List<String> notes) {
  final issues = <String>[];
  final base = '${root.path}/packages/domain_data/assets/laws';
  final manifestFile = File('$base/manifest.json');
  final overridesFile = File('$base/overrides.json');
  if (!manifestFile.existsSync() || !overridesFile.existsSync()) {
    return ['매니페스트나 overrides.json 을 못 찾았습니다: $base'];
  }

  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final overrides =
      jsonDecode(overridesFile.readAsStringSync()) as Map<String, dynamic>;

  // 매니페스트가 본 것.
  final marked = <String, ({String kind, List<String> usedBy})>{};
  var articleTotal = 0;
  for (final law in (manifest['laws'] as List<dynamic>? ?? const [])) {
    final lawMap = law as Map<String, dynamic>;
    for (final a in (lawMap['articles'] as List<dynamic>? ?? const [])) {
      final art = a as Map<String, dynamic>;
      articleTotal++;
      final kind = art['courtMark'];
      if (kind is! String) continue;
      marked['${lawMap['name']} ${art['ref']}'] = (
        kind: kind,
        usedBy: (art['usedBy'] as List<dynamic>? ?? const []).cast<String>(),
      );
    }
  }

  // 분모. 매니페스트가 조문을 하나도 안 실었으면 이 검사는 돌아도 아무것도
  // 안 본 것이다 (DECISIONS 244번).
  if (articleTotal == 0) {
    issues.add('헌재 결정 표시 — 매니페스트에 인용 조문이 0개입니다. '
        '검사가 돌긴 했지만 아무것도 안 봤습니다. '
        'build_law_manifest.dart 를 다시 돌리세요');
    return issues;
  }

  final decided = (overrides['courtMarks'] as Map<String, dynamic>?) ?? const {};
  final domainDir = '${root.path}/packages/domain_data/assets/domains';

  for (final entry in (marked.keys.toList()..sort())) {
    final mark = marked[entry]!;
    final row = decided[entry];
    if (row is! Map<String, dynamic>) {
      issues.add('헌재 결정 표시 — $entry 원문에 [${mark.kind}] 이 붙어 있는데 '
          'overrides.json 의 courtMarks 에 없습니다. '
          '우리 사용자에게 닿는지(reaches)와 왜 그렇게 봤는지(why)를 적으세요');
      continue;
    }
    final why = row['why'];
    if (why is! String || why.trim().isEmpty) {
      issues.add('헌재 결정 표시 — $entry 의 why 가 비어 있습니다. '
          '이유가 없으면 일부러 넘긴 것과 빠뜨린 것이 구별되지 않습니다');
    }
    final reaches = row['reaches'];
    if (reaches is! bool) {
      issues.add('헌재 결정 표시 — $entry 에 reaches 가 없습니다 (true/false)');
      continue;
    }
    if (!reaches) continue;

    final mustSay = row['mustSay'];
    if (mustSay is! String || mustSay.trim().isEmpty) {
      issues.add('헌재 결정 표시 — $entry 는 닿는다고 적혀 있는데 mustSay 가 '
          '비어 있습니다. 우리 말에 무엇이 들어 있어야 하는지 적으세요');
      continue;
    }
    // 인용하는 분야 파일마다 우리 말이 들어 있어야 한다. **조문 원문은
    // 접히므로** legalBasis.text 에만 있으면 화면에서 안 보인다.
    final files = <String>{
      for (final used in mark.usedBy) used.split('.').first,
    };
    for (final id in (files.toList()..sort())) {
      final file = File('$domainDir/$id.json');
      if (!file.existsSync()) continue;
      // **조문 원문(`text`)은 빼고 본다.** 원문에는 대괄호가 그대로 들어
      // 있으니 그것만으로 통과하면 화면에서는 안 보이는 채로 초록이 된다 —
      // LegalBasisCard 가 원문을 기본으로 접기 때문이다.
      final ours = StringBuffer();
      void collect(Object? node, {bool isQuote = false}) {
        if (node is String) {
          if (!isQuote) ours.write('$node\n');
        } else if (node is List) {
          for (final v in node) {
            collect(v);
          }
        } else if (node is Map<String, dynamic>) {
          for (final e in node.entries) {
            collect(e.value, isQuote: e.key == 'text');
          }
        }
      }

      collect(jsonDecode(file.readAsStringSync()));
      final quoted = mustSay;
      if (!ours.toString().contains(quoted)) {
        issues.add('헌재 결정 표시 — $entry 을 $id.json 이 인용하는데 '
            '「$quoted」 이 우리 말에 없습니다. 조문 원문은 접히므로 '
            'note 나 label 에 있어야 화면에서 보입니다');
      }
    }
  }

  // 낡은 줄. 매니페스트에서 사라진 조문이 courtMarks 에 남아 있으면 지운다.
  final stale = decided.keys.where((k) => k != '_' && !marked.containsKey(k));
  if (stale.isNotEmpty) {
    issues.add('헌재 결정 표시 — courtMarks 에 있는데 매니페스트에 없습니다: '
        '${(stale.toList()..sort()).join(', ')}. '
        '인용을 그만뒀으면 이 줄도 지우세요');
  }

  final reachCount =
      decided.values.whereType<Map<String, dynamic>>().where((r) => r['reaches'] == true).length;
  notes.add('헌재 결정 표시 — 인용 조문 $articleTotal개 중 원문에 표시가 붙은 것 '
      '${marked.length}개 (우리 사용자에게 닿는다고 본 것 $reachCount개 · '
      '안 닿는다고 본 것 ${marked.length - reachCount}개)');
  return issues;
}

List<String> _checkHandover(
  Directory root,
  List<String> notes,
  Map<String, (int, int, int)> plainCounts,
) {
  final issues = <String>[];
  final doc = File('${root.path}/docs/현황_인수인계.md');
  if (!doc.existsSync()) {
    return ['인수인계 문서를 찾을 수 없습니다: ${doc.path}'];
  }
  final text = doc.readAsStringSync();

  // ── 분야 수 ──────────────────────────────────────────────────────
  final domainDir = Directory('${root.path}/packages/domain_data/assets/domains');
  final actualDomains = domainDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => f.path.replaceAll(r'\', '/').split('/').last)
      // `_shared_crisis` 는 분야가 아니라 공통 조각이다.
      .where((name) => !name.startsWith('_'))
      .length;

  final saidDomains = RegExp(r'분야 \*\*(\d+)개\*\*').allMatches(text);
  if (saidDomains.isEmpty) {
    issues.add('docs/현황_인수인계.md — 「분야 **N개**」 가 없습니다. '
        '머리말에 분야 수를 적어 두세요');
  }
  for (final match in saidDomains) {
    final said = int.parse(match.group(1)!);
    if (said != actualDomains) {
      issues.add('docs/현황_인수인계.md — 분야가 $actualDomains개인데 '
          '$said개라고 적혀 있습니다. 머리말과 1번 표를 함께 고치세요');
    }
  }

  // ── DECISIONS 마지막 번호 ────────────────────────────────────────
  final decisions = File('${root.path}/DECISIONS.md');
  var lastDecision = 0;
  if (decisions.existsSync()) {
    final numbers = RegExp(r'^## (\d+)\.', multiLine: true)
        .allMatches(decisions.readAsStringSync())
        .map((m) => int.parse(m.group(1)!))
        .toList();
    final last = numbers.isEmpty
        ? 0
        : numbers.reduce((a, b) => a > b ? a : b);
    lastDecision = last;
    final said = RegExp(r'DECISIONS \*\*(\d+)번\*\*').firstMatch(text);
    if (said == null) {
      issues.add('docs/현황_인수인계.md — 「DECISIONS **N번**까지」 가 없습니다');
    } else if (int.parse(said.group(1)!) != last) {
      issues.add('docs/현황_인수인계.md — DECISIONS 가 $last번까지인데 '
          '${said.group(1)}번이라고 적혀 있습니다');
    }
  }

  final hash = RegExp(r'마지막 커밋 `([0-9a-f]{7,40})`').firstMatch(text);

  // ── 이어받기 한 줄 ───────────────────────────────────────────────
  //
  // **다음 작업자가 실제로 읽는 것은 이 세 줄이다.** 머리말이 맞아도 여기가
  // 뒤처지면 다음 사람은 엉뚱한 커밋에서 시작하고, 이미 정해진 규칙을 안 읽는다.
  //
  // 커밋 해시 자체는 여전히 기계가 못 본다(문서가 그 커밋과 함께 커밋된다).
  // **그런데 머리말과 같은지는 볼 수 있다** — 둘 다 문서 안에 있다. 실제로
  // 어긋난 적이 있다: 머리말은 `06836fa` 인데 이어받기 줄은 `290179c` 였다.
  final resume =
      RegExp(r'직전 커밋은 ([0-9a-f]{7,40}) 입니다').firstMatch(text);
  if (resume == null) {
    issues.add('docs/현황_인수인계.md — 이어받기 한 줄에 「직전 커밋은 … 입니다」 '
        '가 없습니다. 다음 작업자가 그 줄을 그대로 씁니다');
  } else if (hash != null && resume.group(1) != hash.group(1)) {
    issues.add('docs/현황_인수인계.md — 이어받기 줄의 커밋(${resume.group(1)})이 '
        '머리말의 커밋(${hash.group(1)})과 다릅니다. 둘을 같이 고치세요');
  }

  final range =
      RegExp(r'확인 목록, (\d+)~(\d+)번을 읽어 주세요').firstMatch(text);
  if (range == null) {
    issues.add('docs/현황_인수인계.md — 이어받기 한 줄에 DECISIONS 범위가 '
        '없습니다');
  } else if (lastDecision > 0 && int.parse(range.group(2)!) != lastDecision) {
    issues.add('docs/현황_인수인계.md — 이어받기 줄이 ${range.group(2)}번까지 '
        '읽으라는데 DECISIONS 는 $lastDecision번까지입니다. 새로 정한 규칙을 '
        '다음 작업자가 안 읽게 됩니다');
  }

  // ── openPart 로 열려 있는 값 ─────────────────────────────────────
  //
  // **사람이 손으로 적는 숫자는 반드시 어긋난다.** 4번 절 제목의
  // 「39가지 · 56곳」이 실제 71곳과 어긋나 있었다. 검사는 돌았고 초록이었는데
  // 재는 대상이 그 숫자가 아니었을 뿐이다 — 위 두 숫자(분야 · DECISIONS)와
  // 똑같은 자리인데 세는 쪽이 없었다.
  //
  // **세는 법을 여기 하나로 못박는다.** 세는 법이 여럿이면 문서가 어느
  // 쪽으로도 맞다고 우길 수 있다. 실제로 넷이 나왔다 — 분야만 보느냐
  // assets 전체를 보느냐, 통짜로 보느냐 「 / 」로 쪼개느냐.
  //
  // ```
  // 곳     = assets/ 아래 JSON 에서 키가 openPart 이고 값이 문자열인 자리 수
  // 가짓수 = 그 문자열을 통짜로 본 서로 다른 값의 수
  // ```
  //
  // `null` 은 세지 않는다 — 그건 「열린 자리가 없다」를 적어 둔 자리다.
  // 본문에 낱말로 적힌 「openPart」도 세지 않는다. 그건 설명이다.
  final openParts = _openPartValues(
    Directory('${root.path}/packages/domain_data/assets'),
  );
  final saidOpen = RegExp(
    r'openPart` 로 열려 있는 값 — 문자열 \*\*(\d+)가지\*\* · \*\*(\d+)곳\*\*',
  ).firstMatch(text);
  if (saidOpen == null) {
    issues.add('docs/현황_인수인계.md — 4번 절 제목에 '
        '「문자열 **N가지** · **M곳**」 이 없습니다. '
        '열린 자리가 몇인지는 손으로 세지 말고 여기에 적으세요');
  } else {
    final kinds = openParts.toSet().length;
    final places = openParts.length;
    if (int.parse(saidOpen.group(1)!) != kinds ||
        int.parse(saidOpen.group(2)!) != places) {
      issues.add('docs/현황_인수인계.md — openPart 는 $kinds가지 · $places곳인데 '
          '${saidOpen.group(1)}가지 · ${saidOpen.group(2)}곳이라고 적혀 '
          '있습니다. 4번 절 제목을 고치세요');
    }
  }

  // ── 매니페스트에서 오는 숫자 ─────────────────────────────────────
  //
  // **238번이 「문서의 숫자는 검사가 센다」인데 이 셋만 빠져 있었다.**
  // 한부모가족지원법이 들어온 뒤 「법령 139개 · 인용 조문 256개」가 그대로
  // 남아 실제 140·261 과 어긋났는데 게이트는 초록이었다. 매니페스트에 있는
  // 값이면 손으로 적을 이유가 없다.
  final manifestFile = File(
    '${root.path}/packages/domain_data/assets/laws/manifest.json',
  );
  if (manifestFile.existsSync()) {
    final raw =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final laws =
        ((raw['laws'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final articles = laws.fold<int>(
      0,
      (n, law) => n + (((law['articles'] as List?) ?? const []).length),
    );
    final scanned =
        ((raw['unfiled'] as Map<String, dynamic>?) ?? const {})['scanned'];

    void machineNumber(String what, RegExp pattern, int actual) {
      final said = pattern.firstMatch(text);
      if (said == null) {
        issues.add('docs/현황_인수인계.md — 머리말에 「$what」 이 없습니다. '
            '손으로 세지 말고 매니페스트가 세게 두세요');
      } else if (int.parse(said.group(1)!) != actual) {
        issues.add('docs/현황_인수인계.md — $what 가 실제로는 $actual인데 '
            '${said.group(1)}이라고 적혀 있습니다');
      }
    }

    machineNumber('법령 **N개**', RegExp(r'법령 \*\*(\d+)개\*\*'), laws.length);
    machineNumber(
      '별표 **N개**',
      RegExp(r'별표 \*\*(\d+)개\*\*'),
      ((raw['tables'] as Map<String, dynamic>?) ?? const {}).length,
    );
    machineNumber(
      '원본 못 받은 인용 **N건**',
      RegExp(r'\*\*원본 못 받은 인용 (\d+)건\*\*'),
      ((raw['unsourced'] as List?) ?? const []).length,
    );
    machineNumber(
      '인용 조문 **N개**',
      RegExp(r'인용 조문 \*\*(\d+)개\*\*'),
      articles,
    );
    // `scanned` 가 없는 낡은 매니페스트는 여기서 안 잡는다 —
    // `_checkArticleRefs` 가 이미 실패로 세운다. 두 곳에서 같은 말을 하면
    // 어느 쪽을 고쳐야 하는지 흐려진다.
    if (scanned is int) {
      machineNumber(
        'law/ PDF **N개**',
        RegExp(r'law/ PDF \*\*(\d+)개\*\*'),
        scanned,
      );
    }
  }

  // ── 복지 자료에서 오는 숫자 ──────────────────────────────────────
  //
  // **머리말의 숫자는 전부 커밋된 JSON 하나를 읽으면 나온다.** 손으로 적을
  // 이유가 없다. 세는 것은 **기록된 총계가 아니라 실제 항목 수**다 —
  // 총계 칸이 틀리면 그것도 같이 잡혀야 한다.
  int serviceCount(String name) {
    final file = File(
      '${root.path}/packages/domain_data/assets/welfare/$name.json',
    );
    if (!file.existsSync()) return -1;
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return ((raw['services'] as List?) ?? const []).length;
  }

  int detailedCount() {
    final file = File(
      '${root.path}/packages/domain_data/assets/welfare/central.json',
    );
    if (!file.existsSync()) return -1;
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    // **상세를 받은 것**은 `target` 이 채워진 것이다. `detailFetchedCount`
    // 칸을 그대로 믿지 않는다 — 그 칸이 틀리면 문서도 같이 틀린다.
    return ((raw['services'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((s) => ((s['target'] as String?) ?? '').isNotEmpty)
        .length;
  }

  final publicCount = serviceCount('public_services');
  final privateCount = serviceCount('private_services');
  final centralCount = serviceCount('central');
  if (publicCount >= 0 && privateCount >= 0) {
    void welfareNumber(String what, RegExp pattern, int actual) {
      final said = pattern.firstMatch(text);
      if (said == null) {
        issues.add('docs/현황_인수인계.md — 머리말에 「$what」 이 없습니다. '
            '손으로 세지 말고 커밋된 JSON 이 세게 두세요');
      } else if (int.parse(said.group(1)!) != actual) {
        issues.add('docs/현황_인수인계.md — $what 가 실제로는 $actual인데 '
            '${said.group(1)}이라고 적혀 있습니다');
      }
    }

    welfareNumber(
      '복지 자료 CSV **N건**',
      RegExp(r'복지 자료 CSV \*\*(\d+)건\*\*'),
      publicCount + privateCount,
    );
    welfareNumber('공공 **N**', RegExp(r'공공 \*\*(\d+)\*\*'), publicCount);
    welfareNumber('민간 **N**', RegExp(r'민간 \*\*(\d+)\*\*'), privateCount);
    if (centralCount >= 0) {
      welfareNumber(
        '중앙부처 API **N건**',
        RegExp(r'중앙부처 API \*\*(\d+)건\*\*'),
        centralCount,
      );
      welfareNumber(
        '상세 **N건**',
        RegExp(r'상세 \*\*(\d+)건\*\*'),
        detailedCount(),
      );
    }
  }

  // ── 복지 상세를 어디까지 받았나 ──────────────────────────────────
  //
  // **머리말이 아니라 본문의 숫자다.** 본문도 같은 방법으로 잠근다.
  // 여기서도 기록된 총계가 아니라 **실제 항목 수**를 센다.
  //
  // 「총」과 「남은 것」을 낱말로 갈라 둔다 — 예전에는 한 곳에서 「2순위
  // 55건」(남은 것)이고 다른 곳에서 「2순위 104건」(총계)이라 같은 말이
  // 두 숫자를 가리켰다.
  final centralFile = File(
    '${root.path}/packages/domain_data/assets/welfare/central.json',
  );
  if (centralFile.existsSync()) {
    final raw2 =
        jsonDecode(centralFile.readAsStringSync()) as Map<String, dynamic>;
    final services =
        ((raw2['services'] as List?) ?? const []).cast<Map<String, dynamic>>();
    int count(int priority, {bool? fetched}) => services
        .where((s) => (s['priority'] as num?)?.toInt() == priority)
        .where((s) => fetched == null || (s['detailFetched'] == true) == fetched)
        .length;

    void everyMention(String what, RegExp pattern, int actual) {
      final said = pattern.allMatches(text).toList();
      if (said.isEmpty) {
        issues.add('docs/현황_인수인계.md — 「$what」 이 한 번도 안 적혀 '
            '있습니다. 세는 자리를 지웠으면 검사도 같이 지우세요');
        return;
      }
      for (final match in said) {
        if (int.parse(match.group(1)!) != actual) {
          issues.add('docs/현황_인수인계.md — $what 가 실제로는 $actual인데 '
              '${match.group(1)}이라고 적힌 곳이 있습니다');
        }
      }
    }

    everyMention('1순위 총 N건', RegExp(r'1순위 총 (\d+)건'), count(1));
    everyMention('2순위 총 N건', RegExp(r'2순위 총 (\d+)건'), count(2));
    everyMention(
      '2순위 남은 것 N건',
      RegExp(r'2순위 남은 것 (\d+)건'),
      count(2, fetched: false),
    );
    everyMention('순위 밖 총 N건', RegExp(r'순위 밖 총 (\d+)건'), count(0));
    everyMention(
      '순위 밖 남은 것 N건',
      RegExp(r'순위 밖 남은 것 (\d+)건'),
      count(0, fetched: false),
    );

    // 자료 쪽 `baslawList` 와 우리 매니페스트가 겹친 법령. 「경계 법령」이다.
    everyMention(
      '맞은 법령 **N개**',
      RegExp(r'맞은 법령 \*\*(\d+)개\*\*'),
      ((raw2['matchedLaws'] as List?) ?? const []).length,
    );

    // **목록 머리에 기관 이름을 못 적는 이유가 이 수다**(212번). 커지면
    // 이유가 더 세지고, 작아지면 그 결정을 다시 봐야 한다.
    everyMention(
      '소관부처 N곳',
      RegExp(r'소관부처 (\d+)곳'),
      services.map((s) => s['ministry']).toSet().length,
    );

    // **빈 축을 거르지 않는 이유가 이 수다.** 「해당 없음」이 아니라
    // 「기관이 안 적었다」라서 거르면 대상을 좁게 안 적은 기관부터 사라진다.
    int blank(String axis) =>
        services.where((s) => ((s[axis] as List?) ?? const []).isEmpty).length;
    everyMention('생애주기 **N**', RegExp(r'생애주기 \*\*(\d+)\*\*'),
        blank('lifeStages'));
    everyMention('가구상황 **N**', RegExp(r'가구상황 \*\*(\d+)\*\*'),
        blank('households'));
    everyMention('관심주제 **N**', RegExp(r'관심주제 \*\*(\d+)\*\*'),
        blank('topics'));
    everyMention(
      '한 칸이라도 빈 행 **N건**',
      RegExp(r'한 칸이라도 빈 행 \*\*(\d+)건\*\*'),
      services
          .where((s) => const ['lifeStages', 'households', 'topics']
              .any((a) => ((s[a] as List?) ?? const []).isEmpty))
          .length,
    );
  }

  // ── 쉬운 말이 붙은 자리 ──────────────────────────────────────────
  //
  // **검사 (x)가 이미 세는 값이다.** 문서가 그 값을 받아 쓴다. 예전에는
  // 「work_injury 하나에 39자리」라고만 적혀 있었는데 그 사이 양육비가
  // 붙어서 **분야가 둘인데 문서는 하나만 알고 있었다.**
  if (plainCounts.isNotEmpty) {
    final saidCount =
        RegExp(r'쉬운 말이 붙은 곳 \*\*(\d+)개\*\*').firstMatch(text);
    if (saidCount == null) {
      issues.add('docs/현황_인수인계.md — 「쉬운 말이 붙은 곳 **N개**」 가 '
          '없습니다. 열셋 중 몇인지가 있어야 규모를 압니다');
    } else if (int.parse(saidCount.group(1)!) != plainCounts.length) {
      issues.add('docs/현황_인수인계.md — 쉬운 말이 붙은 곳이 '
          '${plainCounts.length}개인데 ${saidCount.group(1)}개라고 적혀 '
          '있습니다');
    }
    for (final entry in plainCounts.entries) {
      final row = RegExp(
        r'\| `' + entry.key + r'` \| (\d+) \| (\d+) \| (\d+) \|',
      ).firstMatch(text);
      final wrote = entry.value.$1;
      final slots = entry.value.$2;
      final waived = entry.value.$3;
      if (row == null) {
        issues.add('docs/현황_인수인계.md — 쉬운 말 표에 "${entry.key}" 줄이 '
            '없습니다. 「| `${entry.key}` | $wrote | $slots | $waived |」 로 '
            '넣으세요');
        continue;
      }
      if (int.parse(row.group(1)!) != wrote ||
          int.parse(row.group(2)!) != slots ||
          int.parse(row.group(3)!) != waived) {
        issues.add('docs/현황_인수인계.md — "${entry.key}" 의 쉬운 말이 '
            '실제로는 $wrote자리 / $slots개 / 놓아 준 자리 $waived곳인데 '
            '${row.group(1)}자리 / ${row.group(2)}개 / ${row.group(3)}곳이라고 '
            '적혀 있습니다');
      }
    }
  }

  // ── 손으로 고칠 것 ───────────────────────────────────────────────
  //
  // **테스트 건수는 문서에서 뺐다.** 매번 바뀌고, 검사가 자기 자신을 세는
  // 꼴이라 유지비가 값어치보다 컸다. 지금 값은 `melos run test` 가 낸다.
  //
  // 본문의 숫자(복지 1순위·다리 건수·용어집 자리 수)는 아직 손으로 적는다.
  // **머리말부터 잠갔고, 본문은 다음에 같은 방법으로 붙인다.**
  notes.add('인수인계 머리말 — 분야 $actualDomains개 · '
      '적힌 마지막 커밋 ${hash == null ? "없음" : hash.group(1)}. '
      '커밋 해시는 기계가 못 봅니다 (문서가 그 커밋과 함께 커밋됩니다)');

  return issues;
}

/// `assets/` 아래 JSON 에서 `openPart` 문자열을 전부 모은다.
///
/// [_checkHandover] 가 문서에 적힌 숫자와 맞대는 데 쓴다. **세는 법은 여기
/// 하나뿐이다** — 키가 `openPart` 이고 값이 문자열인 자리만 센다.
List<String> _openPartValues(Directory assets) {
  final values = <String>[];
  void walk(Object? node) {
    if (node is Map) {
      node.forEach((key, value) {
        if (key == 'openPart' && value is String) {
          values.add(value);
        } else {
          walk(value);
        }
      });
    } else if (node is List) {
      for (final item in node) {
        walk(item);
      }
    }
  }

  if (!assets.existsSync()) return values;
  final files = assets
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    walk(jsonDecode(file.readAsStringSync()));
  }
  return values;
}

/// **법의 시간** — 한시법과 시행 예정 개정.
///
/// `packages/domain_data/assets/laws/lifespan.json` 에서 읽는다.
///
/// ★ **날짜가 코드에 박혀 있었다.** `not-a-legal-number` 표식을 달아 조문 꼴
/// 검사를 비켜 가고 있었는데, **그 표식이 필요했다는 것 자체가 잘못된 자리라는
/// 신호였다.** 규칙 9번 옆자리라 데이터로 옮겼다(DECISIONS 275번).
class _Lifespan {
  const _Lifespan({required this.sunsets, required this.amendments});

  /// 법 이름 → 한시법 정보.
  final Map<String, _Sunset> sunsets;
  final List<_Amendment> amendments;

  static _Lifespan read(Directory root, List<String> issues) {
    final file = File(
      '${root.path}/packages/domain_data/assets/laws/lifespan.json',
    );
    if (!file.existsSync()) {
      issues.add('법의 시간 — assets/laws/lifespan.json 이 없습니다');
      return const _Lifespan(sunsets: {}, amendments: []);
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final sunsets = <String, _Sunset>{};
    for (final e in (json['sunset'] as Map<String, dynamic>? ?? const {}).entries) {
      if (e.key == '_') continue;
      final v = e.value as Map<String, dynamic>;
      final expires = KstDate.tryParse('${v['expires']}');
      if (expires == null) {
        issues.add('법의 시간 — 「${e.key}」 의 expires 가 YYYY-MM-DD 가 아닙니다: '
            '${v['expires']}');
        continue;
      }
      sunsets[e.key] = _Sunset(
        law: e.key,
        expires: expires,
        clause: '${v['clause'] ?? ''}',
        text: '${v['text'] ?? ''}',
        chosen: v['chosen'] as String?,
        after: v['after'] as String?,
      );
    }

    final amendments = <_Amendment>[];
    for (final raw in (json['amendments'] as List<dynamic>? ?? const [])) {
      final v = raw as Map<String, dynamic>;
      final effective = KstDate.tryParse('${v['effective']}');
      if (effective == null) {
        issues.add('법의 시간 — 개정의 effective 가 YYYY-MM-DD 가 아닙니다: '
            '${v['effective']}');
        continue;
      }
      amendments.add(_Amendment(
        effective: effective,
        law: '${v['law']}',
        part: '${v['part']}',
        what: '${v['what']}',
        marker: '${v['marker']}',
      ));
    }
    return _Lifespan(sunsets: sunsets, amendments: amendments);
  }
}

/// **한시법 하나.** 그날이 지나면 우리 화면이 거짓말을 시작한다.
class _Sunset {
  const _Sunset({
    required this.law,
    required this.expires,
    required this.clause,
    required this.text,
    this.chosen,
    this.after,
  });

  final String law;

  /// 만료일. **조문에 날짜가 없으면 우리가 고른 값**이고 [chosen] 이 그걸 적는다.
  final KstDate expires;

  /// 그 날짜의 근거 부칙. **비면 실패한다** — 근거 없는 날짜는 우리가 지은 것이다.
  final String clause;

  /// 그 부칙의 원문. 비면 실패한다.
  final String text;

  /// 조문에 날짜가 없어 우리가 골랐을 때만. 왜 그 값인지.
  final String? chosen;

  /// 만료일이 지나도 참인 것. 있으면 화면 전체를 가리지 않는다.
  final String? after;
}

/// **시행일이 정해진 개정** 하나.
///
/// [_checkPendingAmendments] 가 쓴다. 날짜가 지나면 [marker] 가 데이터에
/// 남아 있는지 본다.
class _Amendment {
  const _Amendment({
    required this.effective,
    required this.law,
    required this.part,
    required this.what,
    required this.marker,
  });

  /// 바뀌는 날 (KST). 이날부터 옛 조문은 틀린 것이 된다.
  final KstDate effective;

  /// 어느 법인가. [marker] 만으로는 남의 법에 걸릴 수 있어 함께 본다.
  final String law;

  /// 어느 자리인가. 사람이 읽을 이름이다.
  final String part;

  /// 무엇이 바뀌는가.
  final String what;

  /// **데이터에서 그 자리를 찾는 표식.** 없어지는 조문에만 있고 남는 조문에는
  /// 없는 말이라야 한다.
  final String marker;
}

/// 시행일이 정해진 개정을 그날 잊지 않는가 — 검사 (z).
///
/// ## 왜 note 만으로는 모자란가
///
/// 「2026-10-29 에 바뀝니다」를 문서에 적어 두면 **그날 아무도 안 읽는다.**
/// 우리 데이터는 조용히 틀려지고, 화면은 멀쩡해 보인다. 없어진 요건을
/// 「해당해야 합니다」로 계속 내면 안 되는 사람을 돌려보내게 된다.
///
/// **그래서 날짜를 게이트에 건다.** 그날이 지나면 빨간불이고, 옛 조문을
/// 데이터에서 걷어내야 초록이 된다. 그날 기억하는 것은 사람이 아니라 검사다.
///
/// ## 세는 법
///
/// 그날 전에는 **알림만** 낸다 — 미리 지우면 지금 맞는 조문을 지우는 것이다.
/// 그날부터는 [_Amendment.marker] 와 [_Amendment.law] 가 **같은 파일에**
/// 있으면 실패로 올린다.
List<String> _checkPendingAmendments(
  Directory root,
  KstClock clock,
  _Lifespan lifespan,
  List<String> notes,
) {
  final issues = <String>[];
  final today = clock.today();
  final dir = Directory('${root.path}/packages/domain_data/assets/domains');
  if (!dir.existsSync()) return issues;

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final amendment in lifespan.amendments) {
    final due = today >= amendment.effective;
    final hits = <String>[];
    for (final file in files) {
      final text = file.readAsStringSync();
      if (text.contains(amendment.law) && text.contains(amendment.marker)) {
        // 파일 이름만 낸다. `path` 를 손으로 쪼개면 구분자가 OS 마다 달라
        // 조용히 빈 문자열이 된다 — 실제로 그랬다.
        hits.add(file.uri.pathSegments.last);
      }
    }

    if (!due) {
      notes.add('시행 예정 — ${amendment.effective} ${amendment.law} '
          '${amendment.part}: ${amendment.what}. '
          '${hits.isEmpty ? "지금 데이터에 없습니다" : "지금 쓰는 곳: ${hits.join(" · ")}"}');
      continue;
    }
    if (hits.isEmpty) continue;
    issues.add('${amendment.effective} 부터 ${amendment.law} '
        '${amendment.part} — ${amendment.what}. '
        '그런데 아직 남아 있습니다: ${hits.join(" · ")}. '
        '옛 조문을 걷어내세요');
  }
  return issues;
}

List<String> _checkWebHtml(Directory root) {
  final issues = <String>[];
  final legalArticle = RegExp(r'제\s?\d+\s?(조|항|호)');
  final hangul = RegExp('[가-힣]');
  final comment = RegExp(r'<!--[\s\S]*?-->');
  final block = RegExp(r'<(script|style)\b[\s\S]*?</\1>', caseSensitive: false);
  final tag = RegExp(r'<[^>]*>');
  // 태그 안에 숨은 문장. `<meta content="…">` · `alt` · `aria-label` 이 그렇다.
  final attrDouble = RegExp(
    r'\b(?:content|alt|title|placeholder|aria-label)\s*=\s*"([^"]*)"',
    caseSensitive: false,
  );
  final attrSingle = RegExp(
    r"\b(?:content|alt|title|placeholder|aria-label)\s*=\s*'([^']*)'",
    caseSensitive: false,
  );
  // 화면을 막는 바깥 파일. 이 셋만 본다.
  const blockers = {
    'rel="stylesheet"': '바깥 스타일시트는 첫 그림을 막습니다',
    'fonts.googleapis.com': '웹글꼴을 기다리면 기다리는 화면이 늦게 뜹니다',
    '@font-face': '웹글꼴을 기다리면 기다리는 화면이 늦게 뜹니다',
    '<img': '그림 파일을 기다리면 기다리는 화면이 늦게 뜹니다. CSS 나 인라인 SVG 로 그리세요',
  };

  final apps = Directory('${root.path}/apps');
  if (!apps.existsSync()) return issues;

  for (final app in apps.listSync().whereType<Directory>()) {
    final web = Directory('${app.path}/web');
    if (!web.existsSync()) continue;

    for (final entity in web.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.html')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final relative =
          path.replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');
      final source = entity.readAsStringSync();

      for (final entry in blockers.entries) {
        if (source.toLowerCase().contains(entry.key)) {
          issues.add('$relative — ${entry.key} : ${entry.value}');
        }
      }

      // 주석과 스크립트·스타일은 화면에 안 나간다. 떼고 본다.
      final shown = source.replaceAll(comment, ' ').replaceAll(block, ' ');
      final texts = <String>[
        for (final match in attrDouble.allMatches(shown)) match.group(1)!,
        for (final match in attrSingle.allMatches(shown)) match.group(1)!,
        ...shown.split(tag),
      ];

      for (final raw in texts) {
        final text = raw.trim();
        if (text.isEmpty || !hangul.hasMatch(text)) continue;
        for (final violation in SafetyFilter.scan(text, where: relative)) {
          issues.add('$relative — 금지 표현: ${violation.excerpt}');
        }
        if (legalArticle.hasMatch(text)) {
          issues.add('$relative — 조문 번호가 HTML 에 있습니다. '
              '판본이 바뀌면 아무도 여기를 안 봅니다');
        }
      }
    }
  }
  return issues;
}

String _stripComment(String line) {
  final index = line.indexOf('//');
  return index < 0 ? line : line.substring(0, index);
}

Directory _repoRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    if (File('${dir.path}/melos.yaml').existsSync() ||
        Directory('${dir.path}/packages/domain_data').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current;
}

/// 인용한 조문이 **어느 판본에서 나온 것인지** 매니페스트와 맞춰 본다.
///
/// 매니페스트는 `packages/domain_data/assets/laws/manifest.json` 에 커밋되어 있고
/// PDF 원본(`law/`)은 저장소에 없다. 그래서 CI 에서도 이 검사가 돈다 —
/// **검사는 커밋된 파일을 보지 PDF 를 보지 않는다.**
List<String> _checkLawManifest(
  Directory root,
  List<File> files,
  KstDate today,
  List<String> warnings,
) {
  final issues = <String>[];
  final manifestFile =
      File('${root.path}/packages/domain_data/assets/laws/manifest.json');
  if (!manifestFile.existsSync()) {
    return ['법령 매니페스트가 없습니다. build_law_manifest.dart 를 돌리세요'];
  }

  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final laws = (manifest['laws'] as List<dynamic>).cast<Map<String, dynamic>>();
  final unsourced =
      (manifest['unsourced'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  // 이름과 약칭 모두로 찾을 수 있게 편다.
  final byName = <String, Map<String, dynamic>>{};
  for (final law in laws) {
    byName[law['name'] as String] = law;
    for (final alias in (law['aliases'] as List<dynamic>? ?? const [])) {
      byName[alias as String] = law;
    }
  }
  final unsourcedNames = {for (final u in unsourced) u['law'] as String};

  // 매니페스트가 판본을 달아 둔 별표. 「<법령명> [별표 N]」 꼴이다.
  final annexNames = <String>{
    ...((manifest['tables'] as Map<String, dynamic>?) ?? const {}).keys,
  };

  /// 이 조문을 쓰는 곳이 하나라도 있는가.
  final used = <String>{};

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;

    for (final citation in _citationsIn(json, domainId)) {
      final where = citation.where;

      // **조문 번호가 없는 것은 legalBasis 가 아니다.**
      //
      // 죄명만 적힌 「형법 사문서위조·사기」 나 예규 번호 「제2025-24호」 는
      // 근거가 있는 것처럼 보이지만 어느 판본의 무엇인지 대조할 수 없다.
      // 조문 번호를 붙이든가, 근거 칸에서 빼고 `verification.source` 로 내리든가
      // 둘 중 하나다.
      // **별표는 조가 아니다.** 조문 번호를 붙일 수 없다.
      //
      // 그렇다고 근거에서 빼면 우편요금·송달료처럼 **표가 곧 근거인 값**이
      // 화면에서 출처를 잃는다. 대신 `tables` 에 등록돼 있어야 한다 —
      // 별표마다 판본을 다는 자리가 이미 있다(DECISIONS 113번).
      final annex = _annexKey.firstMatch(citation.article);
      if (annex != null) {
        final key = _annexNameOf(citation.law, annex.group(1) ?? '');
        if (!annexNames.contains(key)) {
          issues.add('$where — 별표를 인용하는데 "$key" 이 매니페스트의 '
              'tables 에 없습니다. overrides.json 에 판본을 적으세요');
        }
        continue;
      }

      if (citation.articles.isEmpty) {
        issues.add(
          '$where — legalBasis.article 이 "제N조" 꼴이 아닙니다 '
          '("${citation.article}"). 조문 번호를 붙이거나 '
          'verification.source 로 내리세요',
        );
        continue;
      }

      final law = byName[citation.law];
      if (law == null) {
        // (a) 매니페스트에 없다.
        //
        // ★ **원본이 없는 인용은 실패다.** 예전에는 「모른다고 적어 둔 것과
        // 빠뜨린 것은 다르다」로 갈라 경고만 냈다. 그런데 갈라 봐야 화면에
        // 나가는 것은 같다 — **대조한 적 없는 조문이 근거 칩을 달고 뜬다.**
        //
        // 게다가 그 경고는 **빠져나가는 통로**였다. 빠뜨린 쪽이 실패로 잡히면
        // 메시지가 「build_law_manifest.dart 를 다시 돌리세요」라고 길을
        // 가르쳐 주는데, 시킨 대로 다시 구우면 그 법이 `unsourced` 로
        // 옮겨가 **빨간불이 노란불이 됐다.** 다시 굽는 것이 검사를 통과시키는
        // 수단이 되면 안 된다.
        //
        // 일부러 둘 자리가 생기면 **그때 그 자리에만** 예외를 적는다.
        // 미리 예외 자리를 만들어 두지 않는다.
        if (unsourcedNames.contains(citation.law)) {
          issues.add(
            '$where — "${citation.law}" 은 원본을 아직 안 받았습니다. '
            '대조한 적 없는 조문이 근거 칩을 달고 화면에 뜹니다. '
            'law/ 에 원문을 넣고 매니페스트를 다시 만들거나, 근거 칸에서 '
            '빼고 verification.source 로 내리세요',
          );
          continue;
        }
        issues.add(
          '$where — "${citation.law}" 이 법령 매니페스트에 없습니다. '
          'build_law_manifest.dart 를 다시 돌리세요',
        );
        continue;
      }

      // (d) 아직 시행되지 않은 판본을 인용하면 **틀린 조문을 옮긴 것**이다.
      final effective = law['effective'] as String;
      if (effective.compareTo(today.toIso()) > 0) {
        issues.add(
          '$where — "${citation.law}" 은 아직 시행 전 판본입니다 '
          '(시행 $effective). 현행판을 받아 매니페스트를 고치세요',
        );
        continue;
      }

      final refs = {
        for (final a in (law['articles'] as List<dynamic>))
          (a as Map<String, dynamic>)['ref'] as String,
      };
      for (final ref in citation.articles) {
        used.add('${law['name']}$ref');
        // (b) 매니페스트가 낡았다.
        if (!refs.contains(ref)) {
          issues.add(
            '$where — "${citation.law} $ref" 이 매니페스트에 없습니다. '
            'build_law_manifest.dart 를 다시 돌리세요',
          );
        }
      }
    }
  }

  // (c) 아무도 안 쓰는 조문·법령. 에러가 아니라 경고다 — 받아 두고 아직 안 쓰는 것은
  // 잘못이 아니다. 다만 매니페스트가 낡아서 남은 것일 수도 있으니 보이게 둔다.
  for (final law in laws) {
    final articles = law['articles'] as List<dynamic>;
    for (final entry in articles) {
      final map = entry as Map<String, dynamic>;
      final ref = map['ref'] as String;
      // 「화면 문구의 근거」는 인용이 없어도 쓰이는 것이다 — 화면에 안 나갈
      // 뿐 화면 문구가 그 위에 서 있다(DECISIONS 106번).
      final grounds = ((map['usedBy'] as List?) ?? const [])
          .any((u) => u is String && u.contains('근거'));
      if (!grounds && !used.contains('${law['name']}$ref')) {
        warnings.add(
          '매니페스트 — "${law['name']} $ref" 을 아무도 안 씁니다',
        );
      }
    }
  }

  return issues;
}

/// JSON 을 훑어 `legalBasis` 를 모은다. 생성기와 같은 규칙으로 읽는다.
List<({String law, String article, Set<String> articles, String where})>
    _citationsIn(Map<String, dynamic> json, String domainId) {
  final found = <({String law, String article, Set<String> articles, String where})>[];

  void walk(Object? node, String path) {
    if (node is Map<String, dynamic>) {
      final law = node['law'];
      final article = node['article'];
      if (law is String && article is String) {
        found.add((
          law: law,
          article: article,
          articles: _articleRefsOf(article),
          where: path,
        ));
      }
      for (final entry in node.entries) {
        if (entry.key == 'law' || entry.key == 'article') continue;
        final id = node['id'];
        // 루트의 id 는 이미 경로 첫머리에 있다. 두 번 붙이지 않는다.
        final next = id is String && !path.endsWith(id) ? '$path.$id' : path;
        walk(entry.value, entry.key == 'legalBasis' ? next : '$next.${entry.key}');
      }
    } else if (node is List) {
      for (final item in node) {
        walk(item, path);
      }
    }
  }

  walk(json, domainId);  // 루트 id 는 이미 경로에 있다
  return found;
}

/// `제2조 제10호 · 제11호 · 제4조 제1항` → `{제2조, 제4조}`
Set<String> _articleRefsOf(String article) => articleRefsIn(article);

String _normalizeArticle(RegExpMatch match) =>
    normalizeArticleRef(match.group(0)!);

/// 앱이 코드에서 채우는 필드. 질문이 없어도 존재한다.
///
/// **여기 적힌 것만 예외다.** 목록이 짧아야 리뷰할 수 있다.
/// 기한 엔진이 채워 주는 사실의 이름표. `passed:dl_x` 꼴이다.
const String _deadlineFlagPrefix = 'passed:';

/// 헷갈리기 쉬운 이름표. **비슷하면 더 위험하다** — 눈으로는 안 보인다.
const List<String> _deadlineFlagTypos = ['passed_', 'past:', 'past_', 'pass:'];

const Set<String> _appProvidedFields = {
  // 홈 화면 자유 서술. `InterviewSession.narrativeField`.
  'userNarrative',
};

/// (g) 물어 놓고 **아무 데서도 안 읽는 필드**를 찾는다.
///
/// [_checkShowIf] 의 (a)가 「조건이 보는 필드를 아무도 안 채운다」를 잡는다면
/// 이쪽은 **반대 방향**이다 — 사용자가 답까지 해 줬는데 우리가 버리는 자리다.
///
/// `q_debtor_address_known` 이 그 구멍이었다. 답을 받아 놓고 안 읽어서, 주소를
/// 모르는 사람에게 **밟을 수 없는 지급명령의 비용**을 계산해 보여줬다
/// ([84번](DECISIONS.md)). `procedure`·`useEfiling` 과 방향만 반대인 같은 결함이다.
///
/// **경고이지 실패가 아니다.** 묻는 이유가 계산만은 아니다 — 다음 질문을
/// 고르려고, 또는 사용자가 자기 상황을 정리하도록 묻는 것도 정당하다.
/// 다만 **그렇다고 적혀 있어야 한다.** `flowOnly: true` 가 그 자리다.
List<String> _checkUnreadFields(List<Domain> domains) {
  final warnings = <String>[];

  // 분야 하나만 보면 안 된다. `_shared_crisis` 의 하드스톱·상한 규칙이 다른
  // 분야의 필드를 읽는다.
  final read = <String>{};
  for (final domain in domains) {
    read.addAll(_fieldsReadBy(domain));
  }

  for (final domain in domains) {
    for (final question in domain.intake) {
      if (question.flowOnly) continue;

      // 질문 하나가 여러 필드를 채운다 — field 와 선택지의 setsField 다.
      final written = <String>{
        question.field,
        for (final option in question.options)
          ...?option.setsField?.keys,
      };
      final unread = written.where((f) => !read.contains(f)).toList()..sort();
      if (unread.isEmpty) continue;

      warnings.add(
        '${domain.id}.intake.${question.id} — 물어 놓고 안 읽는 필드가 '
        '있습니다: ${unread.join(" · ")}. 읽어야 하는데 안 읽는 것이거나 '
        '물을 이유가 없는 질문입니다. 흐름·정리용이면 flowOnly: true 를 다세요',
      );
    }
  }
  return warnings;
}

/// 이 분야가 **읽는** 필드 전부.
///
/// 읽는 자리를 하나 빠뜨리면 멀쩡한 질문이 경고로 뜬다. 새로 필드를 보는
/// 자리를 만들면 여기에도 더한다.
Set<String> _fieldsReadBy(Domain domain) {
  final read = <String>{};

  // showIf 계열 — intake · deadlines · documents · costs(+modifiers·roundsWhen)
  // · procedures · jurisdiction · cautions · jurisdictionGuide · costScenarios
  for (final entry in _showIfsOf(domain)) {
    read.addAll(_varsIn(entry.showIf));
  }

  for (final deadline in domain.deadlines) {
    read.add(deadline.basisField);
    final known = deadline.knownDateField;
    if (known != null) read.add(known);
  }

  for (final group in domain.exclusiveGroups) {
    read.add(group.field);
  }

  for (final rule in domain.jurisdiction) {
    read.add(rule.inputField);
  }

  for (final item in domain.costs) {
    read.addAll(_fieldsInCostFormula(item.formula));
  }

  for (final rule in domain.limitRules) {
    for (final input in rule.inputs) {
      read.add(input.field);
    }
    final formula = rule.formula;
    if (formula != null) read.addAll(_fieldsInLimitFormula(formula));
  }

  for (final stop in domain.hardStops) {
    final trigger = stop.trigger;
    if (trigger is FieldHardStopTrigger) read.add(trigger.field);
  }

  return read;
}

Set<String> _fieldsInCostFormula(CostFormula formula) => switch (formula) {
      TieredCostFormula(:final input) => {input},
      PerUnitCostFormula(:final unitsFormula) => {
          unitsFormula.procedureField,
          if (unitsFormula.partiesField case final String field) field,
        },
      _ => const {},
    };

Set<String> _fieldsInLimitFormula(LimitFormula formula) => switch (formula) {
      TieredWithCapLimitFormula(:final variantField, :final amountField) => {
          variantField,
          amountField,
        },
      _ => const {},
    };

/// `showIf` 가 **실제로 존재하는 필드와 값을 가리키는지** 본다.
///
/// 틀린 문장은 화면에 보이지만 **안 나오는 경고는 안 보인다.** 필드명이 하나
/// 어긋나면 그 안내는 영원히 안 뜨고 아무도 모른다. 자살 신호가 창구에 연결되지
/// 않은 채 죽어 있던 일과 같은 종류다.
///
/// 도메인 하나만 봐서는 못 한다 — `_shared_crisis` 의 하드스톱은 다른 분야의
/// 필드를 본다. 그래서 **모든 도메인의 필드를 합쳐** 놓고 검사한다.
List<String> _checkShowIf(List<File> files, List<String> warnings) {
  final issues = <String>[];

  // ignore: invalid_use_of_visible_for_testing_member
  final loader = DomainLoader(policy: VerificationPolicy.keepAll);
  final domains = <Domain>[];
  for (final file in files) {
    try {
      domains.add(loader.loadFromJsonString(file.readAsStringSync()));
    } on Object {
      continue;
    }
  }

  // 어디에선가 채워질 수 있는 필드 전부.
  final known = <String>{
    ..._appProvidedFields,
    // **계산 결과도 조건이 될 수 있다.**
    //
    // `showIf` 는 원래 사용자가 답한 것만 봤다. 그런데 상속에서 「3개월이
    // 지났는가」는 답이 아니라 **기한 엔진이 낸 결과**다 — 물으면 우리가 셀
    // 수 있는 것을 사용자에게 시키는 것이 된다.
    //
    // 새 모델을 만들지 않고 이름 규칙으로 이었다. 화면이 기한마다
    // `passed:<기한 id>` 를 사실에 넣어 주고, 데이터는 평범한 필드처럼 본다.
    for (final domain in domains)
      for (final deadline in domain.deadlines)
        '$_deadlineFlagPrefix${deadline.id}',
  };
  // 값이 정해져 있는 필드 → **실제로 나올 수 있는 값들**.
  //
  // 두 갈래에서 온다. 질문의 선택지, 그리고 비용 시나리오가 가정하는 값이다.
  // 시나리오는 사용자가 아직 안 정한 갈래를 앱이 대신 세우는 것이라, 질문이
  // 없어도 그 값은 실제로 계산에 들어간다.
  final reachable = <String, Set<String>>{};
  // 자유 입력 필드 — `==` 로 비교하면 거의 틀린다.
  // 홈의 자유 서술도 여기 든다. 사용자가 무엇을 적을지 우리가 알 수 없다.
  final freeText = <String>{'userNarrative'};

  for (final domain in domains) {
    for (final question in domain.intake) {
      known.add(question.field);
      if (question.type == QuestionType.text) freeText.add(question.field);
      if (question.options.isNotEmpty) {
        reachable
            .putIfAbsent(question.field, () => <String>{})
            .addAll(question.options.map((o) => o.value));
      }
      for (final option in question.options) {
        known.addAll((option.setsField ?? const {}).keys);
      }
    }
    for (final scenario in domain.costScenarios) {
      for (final entry in scenario.facts.entries) {
        known.add(entry.key);
        reachable
            .putIfAbsent(entry.key, () => <String>{})
            .add('${entry.value}');
      }
    }
  }

  // (f) 계산식이 읽는 입력이 채워지는가.
  //
  // 조건이 안 맞으면 그 항목만 빠지지만, **입력이 없으면 줄이 통째로 사라진다.**
  // 그게 더 위험하다 — 빠진 줄은 화면에 자리조차 남기지 않으므로 사용자는
  // 송달료라는 것이 있다는 사실 자체를 모른다. 실제로 그러고 있었다.
  for (final domain in domains) {
    for (final item in domain.costs) {
      for (final input in _costInputsOf(item)) {
        if (known.contains(input.field)) continue;
        issues.add(
          '${domain.id}.costs.${item.id} — ${input.what} "${input.field}" 을 '
          '**아무도 안 채웁니다.** 이 비용은 계산되지 않아 화면에서 줄째로 사라집니다',
        );
      }
      // 절차별 표에 적혀 있는데 그 절차가 실제로 나오지 않는 칸.
      final formula = item.formula;
      if (formula is! PerUnitCostFormula) continue;
      final field = formula.unitsFormula.procedureField;
      final allowed = reachable[field];
      if (allowed == null) continue;
      for (final key in formula.unitsFormula.roundsByProcedure.keys) {
        if (allowed.contains(key)) continue;
        warnings.add(
          '${domain.id}.costs.${item.id} — 표에 "$key" 칸이 있는데 "$field" 이 '
          '그 값이 되는 길이 없습니다. 이 칸은 화면에 한 번도 안 나옵니다',
        );
      }
    }
  }

  for (final domain in domains) {
    for (final entry in _showIfsOf(domain)) {
      final where = '${domain.id}.${entry.where}';
      final rule = entry.showIf;

      // (a) 어느 질문의 field 인가. 아니면 이 조건은 영원히 안 맞는다.
      final vars = _varsIn(rule);
      if (vars.isEmpty) {
        warnings.add('$where — showIf 에 var 가 없어 무엇을 보는지 알 수 없습니다');
        continue;
      }
      var unknownVar = false;
      for (final name in vars) {
        // **이름 규칙은 검증기가 강제한다.** 오타가 나면 JsonLogic 이 조용히
        // false 를 내고 화면에서 갈래가 사라진다 — 아무도 모른다.
        final wrongPrefix = _deadlineFlagTypos
            .firstWhere(name.startsWith, orElse: () => '');
        if (wrongPrefix.isNotEmpty) {
          unknownVar = true;
          issues.add('$where — "$name" 은 기한 표시가 아닙니다. '
              '이름표는 "$_deadlineFlagPrefix" 하나뿐입니다');
          continue;
        }
        if (name.startsWith(_deadlineFlagPrefix)) {
          final id = name.substring(_deadlineFlagPrefix.length);
          if (domain.deadlines.any((d) => d.id == id)) continue;
          unknownVar = true;
          issues.add('$where — "$name" 이 가리키는 기한이 이 분야에 없습니다. '
              'deadlines 의 id 를 그대로 적으세요');
          continue;
        }
        if (known.contains(name)) continue;
        unknownVar = true;
        issues.add(
          '$where — showIf 가 "$name" 을 보는데 **아무도 그 필드를 안 채웁니다.** '
          '질문의 field · setsField · 비용 시나리오 중 어디에도 없습니다. '
          '이 조건은 영원히 참이 되지 않습니다',
        );
      }
      if (unknownVar) continue;

      // (b) 비교하는 값이 그 질문의 선택지에 있는가.
      //
      // `and`·`or` 를 뚫고 **안쪽 비교를 하나하나** 본다. 묶여 있다고 통째로
      // 넘기면, 조건이 늘어날수록 검사가 헐거워진다 — 검사를 피하는 가장 쉬운
      // 방법이 `and` 로 감싸는 것이 되면 안 된다.
      final comparisons = _comparisonsIn(rule);

      for (final compared in comparisons.checked) {
        // (d) 자유 입력은 사용자가 무엇이든 적는다. `==` 로 맞추려는 것은 거의 틀린다.
        if (freeText.contains(compared.field)) {
          warnings.add(
            '$where — 자유 입력 "${compared.field}" 을 == 로 비교합니다. '
            '사용자가 그대로 적을 일이 없습니다',
          );
          continue;
        }

        // (e) 그 값이 **실제로 나올 수 있는가.** 값이 안 나오면 조건은 죽어 있다.
        //
        // 인지대가 여기서 걸렸다. `procedure == "payment_order"` 는 문법이 멀쩡했지만
        // 그 값을 만드는 곳이 아무 데도 없어서 지급명령 1/10 할인이 한 번도 적용되지
        // 않았다. 소장 인지액이 그대로 나가 지급명령·전자 대비 11배였다.
        final allowed = reachable[compared.field];
        if (allowed == null) continue;
        for (final value in compared.values) {
          if (allowed.contains(value)) continue;
          issues.add(
            '$where — "${compared.field}" 이 "$value" 가 되는 길이 없습니다. '
            '나올 수 있는 값: ${(allowed.toList()..sort()).join(' · ')}',
          );
        }
      }

      // (c) 우리가 값까지 볼 수 있는 모양이 아니다. 값이 정해진 필드일 때만
      // 알린다 — 금액·날짜 필드에 `<=` 를 쓰는 것은 정상이다.
      for (final field in comparisons.unchecked) {
        if (!reachable.containsKey(field)) continue;
        warnings.add(
          '$where — "$field" 을 == · in 이 아닌 모양으로 비교합니다. '
          '값이 맞는지 검사하지 못했습니다',
        );
      }
    }
  }

  return issues;
}

/// **(h) 어떤 답으로도 화면에 안 나오는 항목은 없는 것과 같다.**
///
/// 지급명령 이의신청 2주가 여기서 새어 나갔다. `showIf` 는 멀쩡했다 —
/// `courtDocument == "payment_order"`. 문제는 **그 답을 고르는 순간 하드스톱이
/// 걸려 결과 화면이 열리지 않는다**는 것이었다. 조건이 참이 되는 길과 그
/// 조건을 볼 수 있는 길이 서로를 지우고 있었다(DECISIONS 121번).
///
/// 사람 눈으로 찾을 것이 아니다. **답 조합을 실제로 돌려 본다.**
///
/// 한 조합이 통과하려면 넷을 모두 만족해야 한다.
///
/// 1. 고른 선택지에 `redirect` 가 없다 — 있으면 다른 분야로 넘어간다
/// 2. 그 답을 낸 질문이 실제로 물어지는 질문이다 (질문의 `showIf` 도 참)
/// 3. 어떤 하드스톱도 걸리지 않는다 — 걸리면 결과 화면을 못 본다
/// 4. 항목의 `showIf` 가 참이다
///
/// 완전탐색이 아니다. 조건에 **이름이 나온 필드와 그 필드를 여는 질문**까지만
/// 훑는다. 그걸로 이번 건은 잡힌다.
List<String> _checkReachable(List<Domain> domains, List<String> warnings) {
  final issues = <String>[];

  // 하드스톱은 분야를 넘어 걸린다. `_shared_crisis` 것이 debt_recovery 에도 온다.
  final fieldStops = <({String id, String field, Object? value})>[];
  for (final domain in domains) {
    for (final stop in domain.hardStops) {
      final trigger = stop.trigger;
      if (trigger is FieldHardStopTrigger) {
        fieldStops.add(
          (id: stop.id, field: trigger.field, value: trigger.equalsValue),
        );
      }
    }
  }

  for (final domain in domains) {
    if (domain.intake.isEmpty) continue;

    // 이 필드를 채울 수 있는 질문. `setsField` 로 곁들여 채우는 것도 센다.
    final owners = <String, List<Question>>{};
    for (final question in domain.intake) {
      owners.putIfAbsent(question.field, () => []).add(question);
      for (final option in question.options) {
        for (final key in (option.setsField ?? const {}).keys) {
          owners.putIfAbsent(key, () => []).add(question);
        }
      }
    }

    // 넣어 볼 값. **조건에 적힌 값을 그대로 쓴다.** 숫자는 양옆도 넣는다 —
    // 경계에서만 갈리는 조건(`<= 3000만원`)은 그 값 하나로는 반쪽만 본다.
    final probes = <String, Set<Object?>>{};
    for (final entry in _showIfsOf(domain)) {
      _probesIn(entry.showIf).forEach((field, values) {
        probes.putIfAbsent(field, () => <Object?>{}).addAll(values);
      });
    }
    for (final scenario in domain.costScenarios) {
      scenario.facts.forEach((key, value) {
        probes.putIfAbsent(key, () => <Object?>{}).add(value);
      });
    }
    for (final deadline in domain.deadlines) {
      probes['$_deadlineFlagPrefix${deadline.id}'] = {true, false};
    }

    for (final entry in _showIfsOf(domain)) {
      final where = '${domain.id}.${entry.where}';

      // 조건이 이름을 댄 필드에서 시작해, 그 필드를 여는 질문이 다시 보는
      // 필드까지 따라간다. **역할을 안 고르면 뒷 질문이 안 열린다** —
      // 그 사슬을 놓치면 멀쩡한 항목을 못 나온다고 잘못 세게 된다.
      final fields = <String>{..._varsIn(entry.showIf)};
      for (var depth = 0; depth < 6; depth++) {
        final grown = <String>{};
        for (final field in fields) {
          for (final question in owners[field] ?? const <Question>[]) {
            grown.addAll(_varsIn(question.showIf));
          }
        }
        if (grown.every(fields.contains)) break;
        fields.addAll(grown);
      }

      final moves = <List<({Map<String, Object?> facts, Question? from})>>[];
      final seen = <String>{};
      for (final field in fields) {
        final question = (owners[field] ?? const <Question>[])
            .where((q) => !seen.contains(q.id))
            .firstOrNull;
        if (question != null) {
          seen.add(question.id);
          moves.add([
            // 안 물어본 상태도 하나의 경우다. `!=` 는 그래도 참이 된다.
            (facts: const <String, Object?>{}, from: null),
            for (final option in question.options)
              if (option.redirect == null)
                (
                  facts: <String, Object?>{
                    question.field: option.value,
                    ...?option.setsField,
                  },
                  from: question,
                ),
            // 선택지가 없는 질문(금액·날짜·글). 조건에 적힌 값을 넣어 본다.
            if (question.options.isEmpty)
              for (final value in probes[field] ?? const <Object?>{})
                (facts: <String, Object?>{field: value}, from: question),
          ]);
          continue;
        }
        // 아무도 안 채우는 필드는 (a) 가 이미 잡는다. 여기서는 값만 넣어 본다.
        moves.add([
          (facts: const <String, Object?>{}, from: null),
          for (final value in probes[field] ?? const <Object?>{})
            (facts: <String, Object?>{field: value}, from: null),
        ]);
      }

      final blocked = <String>{};
      var reached = false;
      var tried = 0;
      void search(int index, Map<String, Object?> facts, List<Question> asked) {
        if (reached || tried > 20000) return; // not-a-legal-number: 갈래 탐색 상한. 법률 수치가 아니다.
        if (index == moves.length) {
          tried++;
          // (2) 그 답을 낸 질문이 실제로 물어지는가.
          for (final question in asked) {
            try {
              if (!JsonLogic.test(question.showIf, facts)) return;
            } on Object {
              return;
            }
          }
          // (3) 하드스톱이 걸리면 결과 화면을 못 본다.
          for (final stop in fieldStops) {
            if (facts[stop.field] == stop.value) {
              blocked.add(stop.id);
              return;
            }
          }
          // (4) 그리고 조건이 참이어야 한다.
          //
          // 넣어 본 값이 조문의 값과 비교 불가일 수 있다(글자 vs 숫자).
          // 그건 이 조합이 아니라는 뜻이지 데이터가 틀렸다는 뜻이 아니다.
          try {
            if (JsonLogic.test(entry.showIf, facts)) reached = true;
          } on Object {
            return;
          }
          return;
        }
        for (final move in moves[index]) {
          search(
            index + 1,
            {...facts, ...move.facts},
            move.from == null ? asked : [...asked, move.from!],
          );
          if (reached) return;
        }
      }

      search(0, const {}, const []);
      if (reached) continue;
      if (tried > 20000) { // not-a-legal-number: 갈래 탐색 상한. 윗줄과 같은 값이다.
        warnings.add('$where — 답 조합이 너무 많아 도달 가능성을 못 셌습니다');
        continue;
      }
      if (blocked.isNotEmpty) {
        issues.add(
          '$where — 이 조건이 참이 되는 답을 고르면 '
          '**하드스톱(${blocked.join(' · ')})이 먼저 걸립니다.** '
          '사용자는 이 항목을 화면에서 볼 수 없습니다. '
          '하드스톱을 내리거나 조건을 고치세요',
        );
        continue;
      }
      issues.add(
        '$where — **어떤 답으로도 화면에 나오지 않습니다.** '
        '조건이 참이 되는 답 조합이 하나도 없습니다',
      );
    }
  }

  return issues;
}

/// 조건에 적힌 값. **`var` 와 나란히 놓인 쪽**을 그 필드의 후보로 본다.
///
/// `_comparisonsIn` 은 `==`·`in` 만 본다 — 값이 그 질문의 선택지에 있는지
/// 보는 검사라 그걸로 충분했다. 도달 가능성은 `<=` 도 넘어가야 하고, 경계에서
/// 갈리는 조건은 그 값 하나로는 반쪽만 본다. 그래서 숫자는 양옆도 넣는다.
Map<String, Set<Object?>> _probesIn(Object? rule) {
  final found = <String, Set<Object?>>{};

  void add(String field, Object? value) {
    final slot = found.putIfAbsent(field, () => <Object?>{})..add(value);
    if (value is int) slot.addAll([value - 1, value + 1]);
  }

  void walk(Object? node) {
    if (node is List) {
      node.forEach(walk);
      return;
    }
    if (node is! Map || node.isEmpty) return;
    final args = node.values.first;
    if (args is List) {
      final vars = [
        for (final arg in args)
          if (arg is Map && arg['var'] is String) arg['var']! as String,
      ];
      if (vars.length == 1) {
        for (final arg in args) {
          if (arg is Map) continue;
          if (arg is List) {
            for (final value in arg) {
              add(vars.first, value);
            }
            continue;
          }
          add(vars.first, arg);
        }
      }
    }
    node.values.forEach(walk);
  }

  walk(rule);
  return found;
}

/// 화면에 금액이 든 문장. 「250만원」 · 「1,500원」.
///
/// 백분율(연 20%)은 뺀다 — 금액이 아니고 적용례가 걸리는 방식도 다르다.
final RegExp _moneyInText = RegExp(r'\d[\d,]*\s*(만원|억원|원)(?![가-힣])');

/// **(i) 적용례가 없는 금액.**
///
/// 부칙에는 시행일 말고 **적용례**가 따로 있다. 민사집행법 시행령 부칙
/// 제2조가 그렇다 — 「이 영 시행 이후 접수되는 압류명령 신청사건부터
/// 적용한다」. 오늘 시행 중인 조문이라도 **내 사건에 적용되는지는 따로**다
/// (DECISIONS 124번).
///
/// 관할표에서 이미 같은 것을 겪었다. 표에 이름이 있어도 시행일이 오늘
/// 이후면 없는 법원이다. 이번엔 시행일이 아니라 적용례다.
///
/// 실패가 아니라 경고다. **전부 달아야 하는 값이 아니라, 안 달린 자리를
/// 사람이 한 번은 봐야 하는 값**이다.
List<String> _checkAppliesFrom(List<Domain> domains) {
  final notes = <String>[];

  void look(String where, Verification verification, Iterable<String> texts) {
    if (verification.appliesFrom != null) return;
    for (final text in texts) {
      final hit = _moneyInText.firstMatch(text);
      if (hit == null) continue;
      notes.add('$where — 화면에 금액("${hit.group(0)}")이 나가는데 '
          'verification.appliesFrom 이 없습니다. 부칙의 적용례를 보고 '
          '어느 사건부터 적용되는지 적으세요');
      return;
    }
  }

  for (final domain in domains) {
    for (final item in domain.cautions) {
      look('${domain.id}.cautions.${item.id}', item.verification,
          [item.condition, item.consequence]);
    }
    for (final item in domain.deadlines) {
      look('${domain.id}.deadlines.${item.id}', item.verification,
          [item.label, item.whatIsThis, item.appearsWhen]);
    }
    for (final item in domain.procedures) {
      look('${domain.id}.procedures.${item.id}', item.verification,
          [item.label, item.detail ?? '', item.caution ?? '']);
    }
    for (final item in domain.limitationRules) {
      look('${domain.id}.limitationRules.${item.id}', item.verification,
          [item.label, item.note]);
    }
  }

  return notes;
}

/// **(j) 항목이 하나도 없는 섹션.**
///
/// 갚을 쪽 화면에서 비용·서류·관할·절차 카드가 빈 껍데기로 남아 있었다.
/// 「금액을 계산할 만한 정보가 아직 없어요」는 답을 더 하면 채워지는 자리에서
/// 정직한 신호지만, 항목 자체가 없는 갈래에서는 **영영 안 끝나는 약속**이다
/// (DECISIONS 125번).
///
/// 화면은 항목이 0개면 안 그린다. 여기서는 **어느 갈래에서 그렇게 되는지**를
/// 목록으로 낸다 — 분야가 늘면 이 자리가 계속 생긴다.
List<String> _checkEmptySections(List<Domain> domains) {
  final notes = <String>[];

  for (final domain in domains) {
    final roles = <String>{};
    for (final question in domain.intake) {
      if (question.field != 'userRole') continue;
      roles.addAll(question.options.map((o) => o.value));
    }
    if (roles.isEmpty) continue;

    for (final role in roles.toList()..sort()) {
      final facts = <String, Object?>{'userRole': role};
      final empty = <String>[];

      int count(Iterable<JsonMap?> showIfs) => showIfs
          .where((showIf) => JsonLogic.test(showIf, facts))
          .length;

      if (count(domain.costs.map((c) => c.showIf)) == 0) empty.add('비용');
      if (count(domain.documents.map((c) => c.showIf)) == 0) empty.add('서류');
      if (count(domain.procedures.map((c) => c.showIf)) == 0) empty.add('절차');
      if (count(domain.jurisdiction.map((c) => c.showIf)) == 0) {
        empty.add('관할');
      }
      if (empty.isEmpty) continue;
      notes.add('${domain.id} · $role — 항목이 0개인 섹션: ${empty.join(' · ')} '
          '(화면은 안 그립니다)');
    }
  }

  return notes;
}

/// **(k) 조립식 없는 금액.**
///
/// 「비용은 5,000원 내외입니다」가 그랬다. 범위 안에 있는 값이긴 했는데
/// **우리가 고른 값**이었고, 어디서 왔는지 화면에서 볼 수 없었다.
/// 송달료 5,500원도 같은 자리에서 한 번 걸렸다([117번](#117)).
///
/// [_checkAppliesFrom] 과 **축이 다르다.** 저쪽은 「언제부터 적용되는가」,
/// 여기는 「어디서 온 숫자인가」다. 5,000원이 저쪽 검사에 걸린 것은 우연이다.
///
/// 근거로 인정하는 것은 셋 중 하나다.
///
/// - `legalBasis` 또는 `alsoBasis` — 조문·별표가 붙어 있다
/// - `fees.parts` — 조립식이 화면에 그대로 있다 (내용증명)
/// - `costs[].formula` — 엔진이 계산한다 (인지대·송달료)
///
/// 실패가 아니라 경고다. **모르는 것을 막으면 지어내게 된다**
/// (DECISIONS 127번).
List<String> _checkMoneyBasis(List<Domain> domains) {
  final notes = <String>[];

  void look(
    String where,
    Iterable<String> texts, {
    required bool hasBasis,
    required bool hasAssembly,
  }) {
    if (hasBasis || hasAssembly) return;
    for (final text in texts) {
      final hit = _moneyInText.firstMatch(text);
      if (hit == null) continue;
      notes.add('$where — 화면에 금액("${hit.group(0)}")이 나가는데 근거도 '
          '조립식도 없습니다. 조문을 달거나 어떻게 더했는지 적으세요');
      return;
    }
  }

  for (final domain in domains) {
    for (final item in domain.cautions) {
      look('${domain.id}.cautions.${item.id}',
          [item.condition, item.consequence],
          hasBasis: item.legalBasis != null || item.alsoBasis.isNotEmpty,
          hasAssembly: false);
    }
    for (final item in domain.procedures) {
      look('${domain.id}.procedures.${item.id}',
          [item.label, item.detail ?? '', item.caution ?? '',
           item.whatIsThis],
          hasBasis: item.alsoBasis.isNotEmpty,
          hasAssembly: (item.fees?.parts ?? const []).isNotEmpty);
    }
    for (final item in domain.deadlines) {
      look('${domain.id}.deadlines.${item.id}',
          [item.label, item.whatIsThis, item.appearsWhen],
          hasBasis: true, hasAssembly: false);
    }
    for (final item in domain.limitationRules) {
      look('${domain.id}.limitationRules.${item.id}', [item.label, item.note],
          hasBasis: true, hasAssembly: false);
    }
    for (final item in domain.brokerAlerts) {
      // `phrase` 는 **브로커가 하는 말**이다. 우리 주장이 아니라 인용이라
      // 근거를 요구하지 않는다 — 「일당 30~50만원 드립니다」가 그렇다.
      look('${domain.id}.brokerAlerts.${item.id}', [item.truth],
          hasBasis: item.legalBasis != null || item.alsoBasis.isNotEmpty,
          hasAssembly: false);
    }
    for (final item in domain.costs) {
      look('${domain.id}.costs.${item.id}', [item.label, item.whatIsThis],
          hasBasis: item.legalBasis != null || item.alsoBasis.isNotEmpty,
          hasAssembly: true);
    }
  }

  return notes;
}

/// **(l) 여는 질문은 열리는 질문보다 앞이다.**
///
/// 질문은 `order` 순으로 나온다. A 의 답이 B 의 `showIf` 를 여는데 A 가 B 보다
/// 뒤에 있으면, B 를 지나갈 때 그 필드는 아직 비어 있다 — **B 는 조용히
/// 건너뛰어진다.** 화면에는 아무 표시도 안 남는다.
///
/// `q_court_document` 를 열두 번째에서 세 번째로 올린 것이 같은 종류였다.
/// 거기서는 갈래가 아니라 **기한**이 가려졌다(DECISIONS 121번).
///
/// 순서를 정하는 기준은 하나다 — **그 답에 따라 뒤 질문이 열리거나 닫히는가.**
/// 그런 질문일수록 앞이다.
List<String> _checkQuestionOrder(List<Domain> domains) {
  final issues = <String>[];

  for (final domain in domains) {
    for (final opener in domain.intake) {
      final writes = <String>{
        opener.field,
        for (final option in opener.options) ...?option.setsField?.keys,
      };

      for (final opened in domain.intake) {
        if (identical(opener, opened)) continue;
        if (opened.order > opener.order) continue;
        if (!_varsIn(opened.showIf).any(writes.contains)) continue;

        issues.add(
          '${domain.id}.intake.${opened.id} — 이 질문을 여는 '
          '"${opener.id}"(${opener.order}번)가 뒤에 있습니다'
          '(${opened.order}번). 지나갈 때 그 필드가 비어 있어 **조용히 '
          '건너뛰어집니다.** 여는 질문을 앞으로 옮기세요',
        );
      }
    }
  }

  return issues;
}

/// **(m) 틀렸을 때 되돌릴 수 없는 것은 미리 채우지 않는다.**
///
/// 금액을 잘못 채우면 화면에서 보고 고친다. **날짜를 잘못 채우면 사람이 그걸
/// 믿고 안 움직인다.** 그러고 기한이 지난다(DECISIONS 130번).
///
/// 세 가지를 막는다. 셋 다 기계가 알아볼 수 있는 꼴로 옮겨 놓았다.
///
/// - `type: date` 인 질문           — 날짜 그 자체
/// - 어떤 기한의 `basisField`       — 기한을 세는 기준일
/// - 어떤 기한의 `showIf` 에 나오는 필드 — 「서류를 받았는지」가 여기 든다
///
/// 마지막 줄이 중요하다. `courtDocument` 는 날짜가 아니지만 그 답 하나로
/// 기한 셋이 갈린다. 잘못 채우면 없는 기한이 뜨거나 있는 기한이 사라진다.
List<String> _checkPrefill(List<Domain> domains) {
  final issues = <String>[];

  for (final domain in domains) {
    final detect = domain.detect;
    if (detect == null) continue;

    if (detect.patterns.isNotEmpty && detect.tests.isEmpty) {
      issues.add('${domain.id}.detect — 걸림말이 있는데 정답지(tests)가 '
          '없습니다. **오탐은 사용자를 쫓아냅니다.** 참·거짓 예문을 적으세요');
    }

    // 기한이 보는 필드 전부. 하나라도 채우면 기한이 흔들린다.
    final deadlineFields = <String>{};
    for (final deadline in domain.deadlines) {
      deadlineFields.add(deadline.basisField);
      final known = deadline.knownDateField;
      if (known != null) deadlineFields.add(known);
      deadlineFields.addAll(_varsIn(deadline.showIf));
    }

    for (final rule in detect.prefill) {
      final where = '${domain.id}.detect.prefill.${rule.questionId}';
      final question = domain.questionById(rule.questionId);
      if (question == null) {
        issues.add('$where — 그런 질문이 없습니다. intake 의 id 를 그대로 적으세요');
        continue;
      }

      if (question.type == QuestionType.date) {
        issues.add('$where — **날짜는 미리 채우지 않습니다.** 틀리면 사람이 '
            '그걸 믿고 안 움직입니다');
        continue;
      }

      if (deadlineFields.contains(question.field)) {
        issues.add('$where — "${question.field}" 은 기한이 보는 필드입니다. '
            '**미리 채우면 없는 기한이 뜨거나 있는 기한이 사라집니다**');
        continue;
      }

      if (rule.fromAmount) {
        if (question.type != QuestionType.money) {
          issues.add('$where — fromAmount 인데 질문이 금액 칸이 아닙니다');
        }
        continue;
      }

      final value = rule.value;
      if (value == null) {
        issues.add('$where — 채울 값이 없습니다. value 나 fromAmount 중 하나를 '
            '정하세요');
        continue;
      }
      if (question.options.every((option) => option.value != value)) {
        issues.add('$where — "$value" 는 그 질문의 선택지에 없습니다');
      }
    }
  }

  return issues;
}

/// 사건 세션을 여는 유일한 자리.
const String _sessionDoorFile = 'domain_select_screen.dart';

/// 세션을 여는 호출. `InterviewController.start(narrative)`.
final RegExp _sessionOpen = RegExp(r'\.\.?start\(\s*narrative');

/// **(n) 세션을 여는 문은 하나다.**
///
/// 문을 하나로 모아도 새 문은 계속 생긴다 — 딥링크, 공유 링크, 알림,
/// 나중에 붙일 저장 이어하기. 문마다 안전장치를 붙이는 방식은 언젠가
/// 하나를 빠뜨린다.
///
/// 실제로 빠뜨렸다. 홈에 분야 감지를 붙이자마자 「사기죄로 고소하려고
/// 합니다」가 형사 하드스톱을 **건너뛰고** 확인 카드로 갔다
/// (DECISIONS 132번).
///
/// 그래서 둘로 막는다. 여는 자리는 여기서 하나로 잠그고, 하드스톱은
/// 라우터 가드가 세션 경로 전부에서 다시 본다.
List<String> _checkSessionDoor(Directory root) {
  final issues = <String>[];
  final lib = Directory('${root.path}/apps/beoba/lib');
  if (!lib.existsSync()) return issues;

  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final name = entity.uri.pathSegments.last;
    if (name == _sessionDoorFile) continue;

    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!_sessionOpen.hasMatch(_stripComment(lines[i]))) continue;
      final relative =
          entity.path.replaceAll(r'\', '/').split('/apps/').last;
      issues.add('apps/$relative:${i + 1} — **세션을 여는 문을 새로 냈습니다.** '
          'startDomain 을 지나게 하세요 — 거기서 하드스톱을 먼저 봅니다');
    }
  }

  return issues;
}

/// 집계로 보내도 되는 칸. **[SessionTally.allowedKeys] 와 같아야 한다.**
const List<String> _tallyKeys = ['domain', 'role', 'exitAt', 'reached', 'version'];

/// 붙이면 우리가 통제 못 하는 값이 같이 나가는 것들.
const List<String> _analyticsPackages = [
  'firebase_analytics',
  'google_analytics',
  'amplitude',
  'mixpanel',
  'sentry',
  'appsflyer',
  'facebook_app_events',
];

/// **(o) 집계로 나가는 칸은 다섯뿐이다.**
///
/// 「이것도 있으면 좋겠는데」가 한 번 통과하면 그다음이 쉬워진다. 그래서
/// 허용 목록을 소스에 박고 검증기가 대조한다(DECISIONS 136번).
///
/// 값도 본다 — 숫자나 날짜 꼴이 들어가면 실패다. 금액·날짜가 없어야
/// 조합해도 사람이 특정되지 않는다.
///
/// 그리고 **분석 SDK 를 0개로 잠근다.** 계획서에 「분석 SDK 없음」이 적혀
/// 있고 그게 사실이어야 한다.
List<String> _checkTally(Directory root) {
  final issues = <String>[];

  final tally = File(
    '${root.path}/packages/engines/lib/src/tally/session_tally.dart',
  );
  if (tally.existsSync()) {
    final source = tally.readAsStringSync();

    // toJson 이 내놓는 키를 그대로 읽는다.
    final body = RegExp(r'toJson\(\)\s*=>\s*\{(.*?)\};', dotAll: true)
        .firstMatch(source);
    if (body == null) {
      issues.add('SessionTally.toJson 을 못 읽었습니다. 모양이 바뀌었으면 '
          '검증기도 함께 고치세요');
    } else {
      final keys = RegExp(r"'([^']+)'\s*:")
          .allMatches(body.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
      for (final key in keys) {
        if (_tallyKeys.contains(key)) continue;
        issues.add('SessionTally.toJson — **허용 목록에 없는 칸 "$key" 이 '
            '붙었습니다.** 집계로 나가는 것은 ${_tallyKeys.join(" · ")} 뿐입니다');
      }
      for (final key in _tallyKeys) {
        if (keys.contains(key)) continue;
        issues.add('SessionTally.toJson — "$key" 이 빠졌습니다');
      }

      // 값에 숫자나 날짜가 섞이면 안 된다. 리터럴로 박힌 것만 본다.
      final values = RegExp(r"'[^']+'\s*:\s*([^,\n]+)")
          .allMatches(body.group(1)!)
          .map((m) => m.group(1)!.trim());
      for (final value in values) {
        if (RegExp(r'^\d').hasMatch(value) ||
            RegExp(r'^.\d{4}-\d{2}-\d{2}').hasMatch(value)) {
          issues.add('SessionTally.toJson — 값에 숫자·날짜가 박혀 있습니다 '
              '("$value"). 금액·날짜는 보내지 않습니다');
        }
      }
    }
  }

  final pubspec = File('${root.path}/apps/beoba/pubspec.yaml');
  if (pubspec.existsSync()) {
    final source = pubspec.readAsStringSync();
    for (final package in _analyticsPackages) {
      if (!source.contains(package)) continue;
      issues.add('apps/beoba/pubspec.yaml — 분석 SDK "$package" 가 붙었습니다. '
          '넣는 순간 우리가 통제 못 하는 값이 같이 나갑니다');
    }
  }

  return issues;
}

/// 비용 계산식이 `CaseFacts` 에서 읽어 가는 필드.
List<({String field, String what})> _costInputsOf(CostItem item) {
  switch (item.formula) {
    case TieredCostFormula(:final input):
      return [(field: input, what: '계산 입력')];
    case PerUnitCostFormula(:final unitsFormula):
      return [
        (field: unitsFormula.procedureField, what: '절차 필드'),
        if (unitsFormula.partiesField != null)
          (field: unitsFormula.partiesField!, what: '당사자 수 필드'),
      ];
    // 모르는 금액은 읽어 갈 필드가 없다.
    case FixedCostFormula() || UnknownCostFormula():
      return const [];
  }
}

/// 도메인 안의 모든 `showIf` 를 어디 것인지와 함께 모은다.
List<({JsonMap showIf, String where})> _showIfsOf(Domain domain) {
  final found = <({JsonMap showIf, String where})>[];
  void add(JsonMap? showIf, String where) {
    if (showIf != null) found.add((showIf: showIf, where: where));
  }

  for (final item in domain.intake) {
    add(item.showIf, 'intake.${item.id}');
  }
  for (final item in domain.deadlines) {
    add(item.showIf, 'deadlines.${item.id}');
  }
  for (final item in domain.documents) {
    add(item.showIf, 'documents.${item.id}');
    // 「이미 갖고 있는가」도 같은 모양이다. 여기가 틀리면 **있다고 답한 서류를
    // 다시 준비하라고** 한다.
    add(item.haveIf, 'documents.${item.id}.이미 있는가');
  }
  for (final item in domain.costs) {
    add(item.showIf, 'costs.${item.id}');
    for (final modifier in item.modifiers) {
      add(modifier.condition, 'costs.${item.id}.${modifier.id}');
    }
    // 회수를 가르는 조건도 같은 모양이다. 여기가 틀리면 금액이 조용히 틀린다.
    final formula = item.formula;
    if (formula is PerUnitCostFormula) {
      for (final rule in formula.unitsFormula.roundsWhen) {
        add(rule.showIf, 'costs.${item.id}.회수(${rule.label})');
      }
    }
  }
  for (final item in domain.procedures) {
    add(item.showIf, 'procedures.${item.id}');
  }
  for (final item in domain.jurisdiction) {
    add(item.showIf, 'jurisdiction.${item.id}');
  }
  for (final item in domain.cautions) {
    add(item.showIf, 'cautions.${item.id}');
  }
  for (final item in domain.jurisdictionGuide?.branches ?? const <Caution>[]) {
    add(item.showIf, 'jurisdictionGuide.${item.id}');
  }
  // 갈래를 아예 못 쓰는 경우를 거르는 조건. 여기가 틀리면 **밟을 수 없는 절차의
  // 금액**이 화면에 남는다.
  for (final item in domain.costScenarios) {
    add(item.showIf, 'costScenarios.${item.id}');
  }
  return found;
}

/// JSONLogic 안의 모든 `{"var": name}`.
Set<String> _varsIn(Object? node) {
  final found = <String>{};
  void walk(Object? value) {
    if (value is Map) {
      final variable = value['var'];
      if (variable is String) found.add(variable);
      value.values.forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  walk(node);
  return found;
}

/// 조건 안의 값 비교를 **전부** 모은다. `and`·`or`·`!` 를 뚫고 들어간다.
///
/// [unchecked] 는 값까지 못 본 자리의 필드명이다. **모른다는 것을 남긴다** —
/// 조용히 통과시키면 검사가 있는 척만 하게 된다.
({
  List<({String field, Set<String> values})> checked,
  Set<String> unchecked,
}) _comparisonsIn(Object? rule) {
  final checked = <({String field, Set<String> values})>[];
  final unchecked = <String>{};

  void walk(Object? node) {
    if (node is List) {
      node.forEach(walk);
      return;
    }
    if (node is! Map) return;
    if (node.length != 1) {
      unchecked.addAll(_varsIn(node));
      return;
    }
    final op = node.keys.first;
    if (op == 'var') return;
    if (op == 'and' || op == 'or' || op == '!' || op == 'not') {
      walk(node.values.first);
      return;
    }
    final one = _comparedValues(Map<String, dynamic>.from(node));
    if (one != null) {
      checked.add(one);
      return;
    }
    unchecked.addAll(_varsIn(node));
  }

  walk(rule);
  return (checked: checked, unchecked: unchecked);
}

/// `{"==": [{"var": f}, "a"]}` · `{"in": [{"var": f}, ["a","b"]]}` 에서 값을 뽑는다.
({String field, Set<String> values})? _comparedValues(JsonMap showIf) {
  if (showIf.length != 1) return null;
  final op = showIf.keys.first;
  if (op != '==' && op != 'in' && op != '!=') return null;

  final args = showIf[op];
  if (args is! List || args.length != 2) return null;

  // 값은 문자열만이 아니다. `useEfiling == true` 처럼 참·거짓으로도 가른다.
  // 그것도 검사한다 — 그 필드에 true 가 오는 길이 없으면 조건은 죽어 있다.
  bool isScalar(Object? v) => v is String || v is bool || v is num;

  final left = args[0];
  final right = args[1];

  // **`in` 은 양쪽 모양이 다 쓰인다.**
  //
  // ```
  // {"in": [{"var": f}, ["a","b"]]}   f 가 둘 중 하나인가
  // {"in": ["a", {"var": f}]}          f(여러 개 고른 답)에 a 가 들어 있는가
  // ```
  //
  // 뒤엣것을 못 읽으면 다중 선택 답을 보는 조건이 전부 「검사하지 못했습니다」로
  // 빠진다. **그러면 오타가 난 값이 그대로 통과한다.**
  if (op == 'in' && isScalar(left) && right is Map) {
    final field = right['var'];
    if (field is String) return (field: field, values: {'$left'});
  }

  if (left is! Map) return null;
  final field = left['var'];
  if (field is! String) return null;

  if (isScalar(right)) return (field: field, values: {'$right'});
  if (op == 'in' && right is List && right.every(isScalar)) {
    return (field: field, values: right.map((e) => '$e').toSet());
  }
  return null;
}

/// 조문 원문 안에서 **다른 법령을 빌려 오는 자리.** 「」로 감싸 인용한다.
///
/// **법·법률·령으로 끝나는 것만 본다.** 「」는 조문에서 정의어를 감쌀 때도
/// 쓰인다 — 「개인채무자」·「하여야 한다」가 그렇다. 이름 꼴로 거른다.
final RegExp _quotedName = RegExp('「([^」]{2,40})」');

bool _looksLikeLawName(String name) =>
    name.endsWith('법') || name.endsWith('법률') || name.endsWith('령');

/// **(p) 빌려 온 표 — 인용 법령 미확보 금액.**
///
/// 조문 원문을 갖고 있어도 **그 조문 혼자서는 값을 못 내는 경우**가 있다.
/// 주택임대차보호법 시행령 제10조가 그렇다 — 소액임차인 금액을 지역별로
/// 나누는데, 그 지역 구분이 「수도권정비계획법」의 과밀억제권역 표에 있다.
/// 그 표가 없으면 인천을 2호로 놓을지 3호로 놓을지 정할 수 없다.
///
/// 지금까지의 검사는 이걸 못 잡았다. [_checkLawManifest] 는 **인용한 조문**이
/// 매니페스트에 있는지를 보는데, 이 경우 인용한 조문은 갖고 있다. 없는 것은
/// 그 조문이 **가리키는 다른 법령**이다. 통과가 곧 「아무것도 안 셌다」인
/// 또 한 판이다.
///
/// ## 무엇이 실패인가 — 「인용하는가」가 아니라 「기대는가」
///
/// 처음에는 「조문 원문이 다른 법령을 인용하는가」로 물었다. 그러면 셋이
/// 걸렸는데 둘이 오탐이었다 — 전자소송 10분의 9 는 인지법에 숫자가 있고,
/// 개인회생 15억은 제579조에 숫자가 있다. 빌려 온 것은 **정의어**였지
/// 값을 고르는 표가 아니었다.
///
/// **정의어냐 표냐는 사람이 눈으로 가르는 기준이라 다음 사람이 못 쓴다.**
/// 그래서 묻는 것을 바꿨다(DECISIONS 152번).
///
/// ```
/// 실패  금액에 구분(variants)이 있고, 그 구분의 label 이 인용 법령의 이름을 쓴다
///       → 우리가 그 법령에 기대어 칸을 고르고 있다
/// 알림  구분이 없거나, 구분이 우리 답에서만 나온다
/// ```
///
/// 소액임차인이 실패 쪽이다 — 2호·3호가 「수도권정비계획법」의 과밀억제권역
/// 으로 갈린다. 15억/10억은 알림 쪽이다. 그런데 **나중에 「내 빚이 담보 있는
/// 빚인가」를 묻기 시작해 가목·나목을 `variants` 로 가르면 그 순간 실패로
/// 올라온다.** 그게 이 기준의 쓸모다.
///
/// 실패라도 항목을 지우라는 뜻은 아니다 — 원본을 받아 매니페스트에
/// 등록하거나, `verification.openPart` 에 그 법령 이름을 적으면 통과한다.
/// 「모르는 것은 경고로, 틀린 것은 실패로 잡는다」([127번])와 같은 자리다.
List<String> _checkBorrowedLaw(
  Directory root,
  List<File> files,
  List<String> notes,
) {
  final issues = <String>[];
  final manifestFile =
      File('${root.path}/packages/domain_data/assets/laws/manifest.json');
  if (!manifestFile.existsSync()) return issues;

  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final known = <String>{};
  for (final entry in (manifest['laws'] as List<dynamic>)) {
    final law = entry as Map<String, dynamic>;
    known.add(law['name'] as String);
    for (final alias in (law['aliases'] as List<dynamic>? ?? const [])) {
      known.add(alias as String);
    }
  }
  // 별표는 「<법령명> [별표 N]」 꼴로 등록돼 있다. 법령명 쪽만 본다.
  //
  // `covers` 는 **표가 채워 주는 다른 법령의 이름**이다. 조문은 「수도권정비
  // 계획법」에 따른 과밀억제권역이라고 적는데, 그 권역의 범위는 실제로 같은
  // 법 **시행령의 [별표 1]** 에 있다. 이름이 어긋나서 기계는 못 잇는다 —
  // **사람이 overrides 에 한 줄로 잇는다.** 자동으로 넓히지 않는다.
  final tables = (manifest['tables'] as Map<String, dynamic>?) ?? const {};
  for (final entry in tables.entries) {
    known.add(entry.key.split(' [별표').first);
    final covers = (entry.value as Map<String, dynamic>)['covers'];
    if (covers is List) {
      for (final name in covers) {
        if (name is String) known.add(name);
      }
    }
  }

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;

    for (final item in _verifiableItemsIn(json)) {
      final borrowed = <String>{};
      final ours = <String>[];
      var quotesMoney = item.containsKey('formula');

      void walk(Object? node) {
        if (node is Map<String, dynamic>) {
          // 조문 원문이다. **여기서 빌려 온 법령을 줍고 우리 말로는 안 센다.**
          if (node['law'] is String &&
              node['article'] is String &&
              node['text'] is String) {
            for (final match in _quotedName.allMatches(node['text'] as String)) {
              final name = match.group(1)!;
              if (_looksLikeLawName(name)) borrowed.add(name);
            }
            return;
          }
          for (final entry in node.entries) {
            // 검증 기록은 우리가 화면에 내는 말이 아니다.
            if (entry.key == 'verification') continue;
            if (entry.value is Map || entry.value is List) {
              walk(entry.value);
            } else if (entry.value is String &&
                !_notScreenText.contains(entry.key)) {
              ours.add(entry.value as String);
            }
          }
        } else if (node is List) {
          for (final child in node) {
            walk(child);
          }
        }
      }

      walk(item);
      quotesMoney = quotesMoney || ours.any(_moneyInText.hasMatch);

      // **우리가 그 인용에 기대어 칸을 고르는가.** 조문이 인용만 한 것과
      // 우리 구분이 그 이름을 쓰는 것은 다르다.
      final leaned = <String>{};
      for (final variant in (item['variants'] as List<dynamic>? ?? const [])) {
        if (variant is! Map) continue;
        final label = variant['label'];
        if (label is! String) continue;
        for (final match in _quotedName.allMatches(label)) {
          final name = match.group(1)!;
          if (_looksLikeLawName(name)) leaned.add(name);
        }
      }

      final verification = item['verification'] as Map<String, dynamic>;
      final openPart = verification['openPart'] as String? ?? '';
      final missing = borrowed.where((name) => !known.contains(name)).toList()
        ..sort();
      if (missing.isEmpty) continue;

      final where = '$domainId.${item['id']}';
      final undeclared = missing
          .where((name) => leaned.contains(name) && !openPart.contains(name))
          .toList();
      if (quotesMoney && undeclared.isNotEmpty) {
        issues.add('$where — 금액의 구분(variants)이 '
            '"${undeclared.join(" · ")}" 의 이름으로 갈리는데 그 법령이 '
            '매니페스트에 없습니다. 우리가 그 법령에 기대어 칸을 고르고 '
            '있습니다. 원본을 받거나 verification.openPart 에 적으세요');
        continue;
      }
      notes.add('$where — 조문이 ${missing.join(" · ")} 을 빌려 옵니다. '
          '${leaned.isEmpty ? "우리 구분이 그 이름을 쓰지 않아 알림입니다 — "
              "구분을 가르기 시작하면 실패로 올라옵니다" : "openPart 에 적혀 있습니다"}');
    }
  }

  return issues;
}

/// 시·도급 이름인가. **시·군·구는 안 본다** — [별표 3]·[별표 7]은 시·군을
/// 하나하나 적고 그건 표준 목록에 넣을 것이 아니다.
final RegExp _provinceName =
    RegExp(r'^[가-힣]{2,6}(특별시|광역시|특별자치시|특별자치도|도)$');

/// **(r) 행정구역 이름 — 표마다 판본이 달라 다르게 적힌다.**
///
/// 노동위원회법 시행령 [별표 1](2026.6.23. 개정)은 「전남광주통합특별시」라고
/// 적고, 각급법원법 [별표 3](2026.3.17. 개정)은 「광주광역시」·「전라남도」라고
/// 적는다. **판본이 다른 것이지 틀린 게 아니다.**
///
/// 그런데 우리 지역 선택지는 하나다. 선택지에 없는 이름으로 적힌 행은
/// **아무에게도 안 걸린다** — 표를 등록해 놓고도 그 지역 사람에게 이름이
/// 안 나간다. 화면에는 아무 표시도 안 남는다.
///
/// 그래서 표준 목록(`regions.json`)을 한 곳에 두고 표마다 별칭을 매핑한다.
/// **사용자가 안 부르는 이름을 선택지로 만들지 않는다**(DECISIONS 164번).
///
/// 함께 본다 — 지역을 고르게 하는 질문의 선택지가 표준 목록과 **글자까지
/// 같은지.** 두 벌로 적으면 한쪽만 고치는 사고가 나도 아무도 못 잡는다.
List<String> _checkRegionNames(
  Directory root,
  List<Domain> domains,
  List<String> notes,
) {
  final issues = <String>[];
  final base = '${root.path}/packages/domain_data/assets/courts';
  final file = File('$base/regions.json');
  if (!file.existsSync()) {
    return ['지역 표준 목록이 없습니다: ${file.path}'];
  }

  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final standard = (raw['standard'] as List<dynamic>).cast<String>().toSet();
  final aliases =
      ((raw['aliases'] as Map<String, dynamic>?) ?? const {}).keys.toSet();
  final known = {...standard, ...aliases};

  var checked = 0;
  for (final table in Directory(base)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('regions.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path))) {
    final json = jsonDecode(table.readAsStringSync()) as Map<String, dynamic>;
    final name = json['name'] as String? ?? table.uri.pathSegments.last;
    for (final entry in (json['entries'] as List).cast<Map<String, dynamic>>()) {
      for (final district in (entry['districts'] as List).cast<String>()) {
        if (!_provinceName.hasMatch(district)) continue;
        checked++;
        if (known.contains(district)) continue;
        issues.add('$name — 관할구역 "$district" 이 지역 표준 목록에도 별칭에도 '
            '없습니다. 선택지에 없는 이름으로 적힌 행은 아무에게도 안 걸립니다. '
            'regions.json 의 aliases 에 이으세요');
      }
    }
  }

  // 지역을 고르게 하는 질문. **선택지 다섯 이상이 표준 목록에 있으면** 그
  // 질문이다 — 이름으로 고르지 않는다(DECISIONS 118번과 같은 태도다).
  for (final domain in domains) {
    for (final question in domain.intake) {
      final values = question.options.map((o) => o.value).toSet();
      if (values.where(standard.contains).length < 5) continue;
      final missing = standard.difference(values).toList()..sort();
      final extra = values.difference(standard).toList()..sort();
      if (missing.isEmpty && extra.isEmpty) continue;
      issues.add('${domain.id}.intake.${question.id} — 지역 선택지가 표준 '
          '목록과 다릅니다 (빠짐: ${missing.join(" · ")} / 더함: '
          '${extra.join(" · ")}). regions.json 의 standard 와 글자까지 '
          '맞추세요');
    }
  }

  notes.add('행정구역 이름 — 시·도급 관할구역 $checked개를 표준 목록과 대조했습니다');
  return issues;
}

/// 문자열이지만 화면에 내는 우리 말이 아닌 칸.
const Set<String> _notScreenText = {
  'id',
  'url',
  'var',
  'type',
  'field',
  'status',
  'icon',
  'law',
  'article',
  'stage',
  'lookupTable',
  'inputField',
};

/// `id` 와 `verification` 을 함께 가진 것이 **화면에 나가는 한 항목**이다.
///
/// 모델마다 필드 이름이 달라서 종류를 나열하면 다음에 생기는 것을 빠뜨린다.
/// 도메인 루트에는 `verification` 이 없어서 저절로 빠진다.
List<Map<String, dynamic>> _verifiableItemsIn(Map<String, dynamic> json) {
  final found = <Map<String, dynamic>>[];

  void walk(Object? node) {
    if (node is Map<String, dynamic>) {
      if (node['id'] is String && node['verification'] is Map) {
        found.add(node);
      }
      for (final value in node.values) {
        if (value is Map || value is List) walk(value);
      }
    } else if (node is List) {
      for (final child in node) {
        walk(child);
      }
    }
  }

  walk(json);
  return found;
}

/// **(u) 갈래마다 쓸 수 있는 법령을 못 박는다.**
///
/// 전자상거래법·방문판매법·할부거래법은 겉이 아주 닮았다. 조 번호도 문언도
/// 비슷하다. 그런데 **값이 다르다.**
///
/// ```
/// 기간        7일 / 14일 / 7일
/// 반품 비용   소비자 / 판매자 / 판매자
/// 금액 문턱   없음 / 없음 / 10만원·20만원
/// ```
///
/// 한 갈래의 카드가 다른 법을 근거로 들면 **화면은 멀쩡하고 값만 틀린다.**
/// 조문 원문까지 그럴듯하게 붙어 있어서 눈으로는 못 잡는다.
///
/// 그래서 분야마다 `lawScope` 에 쓸 수 있는 법령을 적는다. 갈래를 타는 법령은
/// `branches` 에 (필드, 값)과 함께 적고, **갈래에 안 묶인 카드는 공통 법령만**
/// 쓸 수 있다 — 그 카드는 모든 갈래에 뜨기 때문이다.
///
/// ## ★ 이 선언은 복지 다리의 0을 읽는 데도 쓰인다 (DECISIONS 232번)
///
/// `welfareBridge` 가 0건일 때 **고장인지 아닌지**를 여기 적힌 법령으로 가른다.
///
/// ```
/// 일반법만 들고 있다      구조적으로 0. 고장이 아니다
///   민법 · 형법 · 민사소송법 · 형사소송법 — 복지 자료의 근거법령 137가지에
///   이 이름들이 **하나도 없다.** 복지제도는 자기 근거법을 적지 민법을 적지 않는다
///
/// 특별법을 들고 있는데 0   눌러 봐야 한다
///   산재보험법 · 고용보험법 · 기초생활보장법 같은 것이 0이면 **아직 안 받은
///   0** 일 수 있다. 산재가 그랬다 — 제도 아홉 건이 detailFetched:false 라
///   baslawList 가 비어 있었다
/// ```
///
/// **같은 0인데 하나는 기다리면 되고 하나는 영영 아니다.**
///
/// 넣자마자 둘을 잡았다. `ct_card_stop` 과 `ct_return_cost_own` 이 결제 수단과
/// 무르는 이유만 보고 떴다. 인터넷 갈래 하나뿐일 때는 아무 일도 없었는데,
/// 방문판매 갈래가 열리는 순간 **전자상거래법 문장이 그대로 그 사람에게 간다** —
/// 반품 비용을 내는 쪽이 정반대인 문장이다(DECISIONS 186번).
/// 법률과 복지를 잇는 다리가 **짐작이 아닌가** — 검사 (w).
///
/// 복지로는 사용자가 왜 왔는지 모르고 우리는 안다. 그게 이 앱만 할 수 있는
/// 자리인데, **바로 그래서 위험하다** — 우리가 「비슷하니까」로 이으면
/// 그건 근거 없는 안내이고, 틀렸을 때 어디서 틀렸는지 되짚을 수가 없다.
///
/// 그래서 잇는 기준을 하나로 못 박았다 — **제도 쪽 근거법령(`baslawList`)의
/// 이름이 `welfareBridge.laws` 와 맞는가.** 이 검사는 그 이름들이
/// **실제로 있는 법령**인지 본다. 없는 이름을 적으면 아무것도 안 걸리는데
/// 화면에는 입구가 서서 「눌러 봤더니 0건」이 된다.
///
/// 그리고 [why] 가 비어 있으면 실패다. 목록만 남기면 다음 사람이
/// 「비슷하니까 하나 더」를 한다.
// ───────────────────────── 쉬운 한국어 ─────────────────────────

/// 쉬운 말이 대신할 수 있는 자리. `kPlainTargets` 와 같은 것을 본다.
const Map<String, List<String>> _plainSlots = <String, List<String>>{
  '': <String>['description'],
  'intake': <String>['text', 'whyAsk'],
  'cautions': <String>['question', 'condition', 'consequence'],
  'procedures': <String>['whatIsThis', 'detail'],
  'limitationRules': <String>['note'],
};

/// (x) **쉬운 말은 짧아야 하고, 원래 문장보다 단정하면 안 된다.**
///
/// 재는 규칙은 [PlainKoreanCheck] 에 있다 — 도구가 아니라 **라이브러리**에
/// 둔 이유는 규칙 하나하나가 실제로 무엇을 잡는지 테스트로 보여야 하기
/// 때문이다. 도구 안에 두면 「검사가 있다」까지만 말할 수 있고 「몇 건을
/// 잡는다」는 못 말한다.
///
/// 피동은 **막지 않고 센다.** 「최소화」는 0으로 만들라는 말이 아니고,
/// 넓게 막으면 오탐이 나고 오탐이 나면 검사가 무뎌진다([39번](#39)).
List<String> _checkPlainKorean(
  Directory root,
  List<File> files,
  List<String> notes,
  List<String> warnings,
  Map<String, (int, int, int)> counts,
) {
  final issues = <String>[];
  const checker = PlainKoreanCheck();
  var passive = 0;
  var waivedAll = 0;
  var slotsAll = 0;

  final glossaryFile = File(
    '${root.path}/packages/domain_data/assets/glossary/terms.json',
  );
  final terms = <String>[];
  if (glossaryFile.existsSync()) {
    final raw =
        jsonDecode(glossaryFile.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in (raw['terms'] as List<dynamic>? ?? const [])) {
      terms.add((entry as Map<String, dynamic>)['term'] as String);
    }
  }

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;
    final plain = json['plain'];
    if (plain is! Map) continue;

    // 이 분야에 쉬운 말을 붙일 수 있는 자리가 몇 개인가.
    var slots = 0;
    for (final section in _plainSlots.entries) {
      if (section.key.isEmpty) {
        for (final field in section.value) {
          if ((json[field] as String? ?? '').trim().isNotEmpty) slots++;
        }
        continue;
      }
      for (final item in (json[section.key] as List<dynamic>? ?? const [])) {
        final map = item as Map<String, dynamic>;
        for (final field in section.value) {
          if ((map[field] as String? ?? '').trim().isNotEmpty) slots++;
        }
      }
    }

    // 40자 규칙을 놓아 준 자리. 이유가 비어 있으면 놓아 주지 않는다 —
    // 빈 이유는 `SchemaValidator` 가 따로 실패로 잡는다.
    final longOkRaw = json['plainLongOk'];
    final longOk = <String, String>{};
    if (longOkRaw is Map) {
      for (final entry in longOkRaw.entries) {
        final reason = entry.value;
        if (reason is String) longOk['${entry.key}'] = reason;
      }
    }

    var waived = 0;
    for (final entry in plain.entries) {
      final key = '${entry.key}';
      final value = entry.value;
      if (value is! String) continue;
      final where = '$domainId.plain.$key';
      final original = _plainOriginal(json, key) ?? '';
      final reason = longOk[key];
      if (reason != null && reason.trim().isNotEmpty) waived++;

      for (final issue in checker.check(
        original: original,
        plain: value,
        terms: terms,
        longOk: reason,
      )) {
        issues.add('$where — ${issue.message}');
      }
      passive += PlainKoreanCheck.passiveCount(value);
    }

    waivedAll += waived;
    slotsAll += plain.length;
    counts[domainId] = (plain.length, slots, waived);
    notes.add('쉬운 말 — $domainId: ${plain.length}자리 / '
        '바꿀 수 있는 자리 $slots개 / 40자를 놓아 준 자리 $waived곳');

    // ★ **절반을 넘으면 그 분야에서 40자는 아무것도 안 막는다.**
    // 막지는 않는다 — 열거가 정말 많은 분야가 있을 수 있다. 세어서 말한다.
    if (plain.isNotEmpty && waived * 2 > plain.length) {
      warnings.add('쉬운 말 — $domainId 는 ${plain.length}자리 중 $waived곳에서 '
          '40자를 놓아 줬습니다. 절반을 넘으면 그 분야에서 40자 규칙이 '
          '사실상 없는 것입니다');
    }
  }

  // **분모와 함께 센다.** 놓아 준 곳만 세면 늘어나는 것이 안 보인다.
  notes.add('쉬운 말 — 40자를 놓아 준 자리 $waivedAll곳 / 쉬운 말 자리 '
      '$slotsAll개');

  if (passive > 0) {
    warnings.add('쉬운 말 — 피동 표현 $passive곳. 막지 않고 셉니다');
  }
  return issues;
}

/// 쉬운 말 키가 가리키는 **원래 문장**.
String? _plainOriginal(Map<String, dynamic> json, String key) {
  final parts = key.split('.');
  if (parts.length == 1) return json[parts.first] as String?;
  if (parts.length != 3) return null;
  for (final item in (json[parts[0]] as List<dynamic>? ?? const [])) {
    final map = item as Map<String, dynamic>;
    if (map['id'] == parts[1]) return map[parts[2]] as String?;
  }
  return null;
}

/// (y) **분야가 어느 묶음에 드는가.**
///
/// 첫 화면에는 묶음 줄만 선다. 묶음을 안 적은 분야는 목록 끝에 따로 나오는데
/// **그건 임시 자리이지 제자리가 아니다** — 화면에서 조용히 사라지지 않게
/// 두었을 뿐이다. 없는 묶음 이름을 적으면 같은 자리로 떨어지므로 여기서 막는다.
///
/// 0개인 묶음은 **막지 않고 센다.** 여덟을 미리 적어 두었고 지금 분야가 있는
/// 것은 다섯뿐이다 — 나머지는 그 분야가 들어오는 날 저절로 선다. 화면은
/// 애초에 빈 묶음을 안 그리므로([228번](#228)) 세는 것으로 충분하다.
List<String> _checkDomainGroups(
  Directory root,
  List<File> files,
  List<String> notes,
  List<String> warnings,
) {
  final issues = <String>[];

  final catalog =
      File('${root.path}/packages/domain_data/assets/groups/groups.json');
  if (!catalog.existsSync()) {
    return ['묶음 목록을 찾을 수 없습니다: ${catalog.path}'];
  }
  final raw = jsonDecode(catalog.readAsStringSync()) as Map<String, dynamic>;
  final known = <String, String>{};
  for (final entry in (raw['groups'] as List<dynamic>)) {
    final group = entry as Map<String, dynamic>;
    final id = group['id'] as String;
    if (known.containsKey(id)) {
      issues.add('groups.json — 같은 묶음 id 가 두 번 있습니다: $id');
    }
    known[id] = group['name'] as String;
  }

  final counted = {for (final id in known.keys) id: 0};
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;
    if (domainId.startsWith('_')) continue;
    final status = json['status'] as String?;
    if (status != 'active' && status != 'beta') continue;

    final group = json['group'];
    if (group is! String || group.isEmpty) {
      issues.add('$domainId — 묶음(group)이 없습니다. 첫 화면은 묶음 줄만 '
          '서므로 묶음이 없으면 목록 끝의 임시 자리로 떨어집니다. '
          '들어갈 자리: ${known.entries.map((e) => '${e.key}(${e.value})').join(' · ')}');
      continue;
    }
    if (!known.containsKey(group)) {
      issues.add('$domainId — 없는 묶음입니다: $group. '
          'groups.json 에 먼저 적으세요');
      continue;
    }
    counted[group] = counted[group]! + 1;
  }

  final empty = [
    for (final entry in counted.entries)
      if (entry.value == 0) '${entry.key}(${known[entry.key]})',
  ];
  notes.add('분야 묶음 — 서는 것 ${counted.length - empty.length}개 / '
      '적어 둔 것 ${counted.length}개 · '
      '${counted.entries.where((e) => e.value > 0).map((e) => '${known[e.key]} ${e.value}').join(' · ')}');
  if (empty.isNotEmpty) {
    warnings.add('분야 묶음 — 아직 분야가 0개라 화면에 안 서는 것: '
        '${empty.join(' · ')}. 그 분야가 들어오는 날 저절로 섭니다');
  }

  return issues;
}

/// 우리 문장에 나오는 **금액은 인용에도 있어야 한다** — 검사 (aa).
///
/// 양육비에서 나온 규칙이다. 처음에는 「우리 문장에 금액이 없다」로 잡았는데
/// 과태료 1천만원(가사소송법 제67조 제1항)에 걸렸다. **그건 조문에 있는
/// 숫자다.** 규칙 쪽이 틀렸다.
///
/// ```
/// ⭕ 1천만원   가사소송법 제67조 제1항에 있다 — 그대로 옮긴 것이다
/// ⭕ 3천만원   시행령 제17조의2 제1항 제2호에 있다
/// ✘ 월 20만원  선지급 금액은 고시다. 조문에 없다 — 우리가 지어낸 것이 된다
/// ```
///
/// **금액은 제도가 바뀔 때 제일 먼저 바뀐다.** 조문에 있는 숫자는 개정을
/// 매니페스트가 따라가지만, 우리가 지어 쓴 숫자는 아무도 안 따라간다.
/// 그러면 앱 심사 없이 못 고치는 자리가 화면에 남는다(CONTRIBUTING.md 9번).
///
/// **인용 웅덩이는 그 파일과 `_shared_crisis`, 용어집을 합친다.** 화면이
/// 그 셋을 함께 그리기 때문이다.
///
/// ★ 지금은 **세기만 한다.** 넓게 막으면 오탐이 나고, 오탐이 나면 검사가
/// 무뎌진다([39번](#39)) — `_checkPlainLanguage` 가 걸어온 길과 같다.
/// 걸린 것을 다 훑고 나면 실패로 올린다.
List<String> _checkQuotedMoney(List<File> files, List<String> notes) {
  final warnings = <String>[];

  // 인용 웅덩이. 파일이 다 읽힌 뒤에 재야 하므로 두 번 돈다.
  final quotesOf = <String, String>{};
  final shared = StringBuffer();
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final buffer = StringBuffer();
    _quoteTextsIn(json, buffer);
    final id = json['id'] as String? ?? file.uri.pathSegments.last;
    quotesOf[id] = buffer.toString();
    if (id.startsWith('_')) shared.write(buffer);
  }

  var hits = 0;
  var badged = 0;
  var scanned = 0;
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = json['id'] as String? ?? file.uri.pathSegments.last;
    final pool = '${quotesOf[id] ?? ''}$shared';
    // **네 번째 층의 딱지가 붙은 자리.** 조문이 아닌 금액이 여기 있을 수 있다.
    final noticed = _noticedPathsIn(json, id);

    // **띄어쓰기는 안 본다.** 조문은 「500만 원」이고 우리는 「500만원」이다.
    // 다른 것은 띄어쓰기뿐인데 그걸로 걸면 검사가 무뎌진다.
    final bare = pool.replaceAll(RegExp(r'\s'), '');

    for (final (where, sentence) in _screenSentencesIn(json, id)) {
      scanned++;
      for (final match in _moneyWord.allMatches(sentence)) {
        final money = match.group(0)!;
        if (bare.contains(money.replaceAll(RegExp(r'\s'), ''))) continue;
        // 「잔액이 0원이어도」는 금액 주장이 아니다. 법정 금액에 0은 없다.
        if (money.replaceAll(RegExp(r'\s'), '') == '0원') continue;
        // **딱지가 붙어 있으면 인용 대신 기관 이름과 확인한 날로 견준다.**
        // 조문이 아닌 금액을 숨기는 것이 아니라 어디서 왔는지 적는 것이다.
        if (noticed.keys.any(where.startsWith)) {
          badged++;
          continue;
        }
        hits++;
        warnings.add('$where — "$money" 이 인용에 없습니다. 조문에 있는 '
            '숫자면 그 조문을 근거로 다세요. 조문이 아니라 기관이 알려 준 '
            '것이면 그 항목에 notice(기관 이름 + 확인한 날)를 다세요');
      }
    }
  }

  notes.add('금액 인용 — 화면 문장 $scanned줄 · 인용에 없는 금액 $hits건 · '
      '기관이 알려 준 것으로 딱지 붙은 금액 $badged건');
  return warnings;
}

/// **네 번째 층의 딱지가 붙은 항목의 경로.** 경로 → 「기관 이름 + 확인한 날」.
///
/// 딱지는 `notice` 다 — `agency` 와 `checkedAt` 이 둘 다 있어야 딱지로 본다.
/// 기관 이름만 있고 날짜가 없으면 **언제 것인지 모르는 안내**라 딱지가 아니다.
Map<String, String> _noticedPathsIn(Map<String, dynamic> json, String domainId) {
  final out = <String, String>{};
  for (final entry in json.entries) {
    final section = entry.value;
    if (section is! List) continue;
    for (final raw in section) {
      if (raw is! Map<String, dynamic>) continue;
      final notice = raw['notice'];
      if (notice is! Map<String, dynamic>) continue;
      final agency = notice['agency'];
      final checkedAt = notice['checkedAt'];
      if (agency is! String || agency.isEmpty) continue;
      if (checkedAt is! String || checkedAt.isEmpty) continue;
      out['$domainId.${entry.key}.${raw['id']}'] = '$agency · $checkedAt';
    }
  }
  return out;
}

/// `1천만원` · `3천만원` · `50만 원` · `3만원` — 화면에 나가는 금액 꼴.
final RegExp _moneyWord = RegExp(r'[0-9]+\s?[천만억조]?\s?원');

/// 조문 원문만 모은다. `law`·`article`·`text` 가 함께 있는 자리다.
void _quoteTextsIn(Object? node, StringBuffer out) {
  if (node is Map<String, dynamic>) {
    if (node['law'] is String &&
        node['article'] is String &&
        node['text'] is String) {
      out
        ..write(node['text'] as String)
        ..write('\n');
      return;
    }
    for (final value in node.values) {
      if (value is Map || value is List) _quoteTextsIn(value, out);
    }
  } else if (node is List) {
    for (final child in node) {
      _quoteTextsIn(child, out);
    }
  }
}

/// **화면에 나가는 우리 문장.** `verification` 아래와 개발 메모는 안 본다 —
/// 거기 적은 숫자는 사람이 읽는 기록이지 사용자에게 가는 글이 아니다.
const Map<String, List<String>> _screenSlots = <String, List<String>>{
  '': <String>['name', 'description'],
  'intake': <String>['text', 'whyAsk', 'echo'],
  'deadlines': <String>['label', 'whatIsThis', 'appearsWhen'],
  'cautions': <String>['question', 'condition', 'consequence'],
  'limitationRules': <String>['label', 'note'],
  'documents': <String>['label', 'whatIsThis'],
  'costs': <String>['label', 'whatIsThis'],
  'jurisdiction': <String>['label', 'whatIsThis'],
  'procedures': <String>[
    'label',
    'whatIsThis',
    'detail',
    'whenApplicable',
    'caution',
    'noticeToUser',
  ],
  'resources': <String>['name', 'benefit'],
  'lookupTools': <String>['label', 'hint'],
  'brokerAlerts': <String>['truth'],
  'brokerChecklists': <String>['title', 'thresholdMessage'],
  // 상한 규칙은 **금액을 말하는 자리**다. 여기를 빼면 검사가 반쪽이 된다 —
  // 실제로 신복위 신청비가 세 자리에 있었는데 한 자리만 걸렸다.
  'limitRules': <String>['label', 'message'],
  'hardStops': <String>['title', 'message'],
  'exclusiveGroups': <String>['unknownNote'],
};

Iterable<(String, String)> _screenSentencesIn(
  Map<String, dynamic> json,
  String domainId,
) sync* {
  for (final section in _screenSlots.entries) {
    if (section.key.isEmpty) {
      for (final field in section.value) {
        final value = json[field];
        if (value is String && value.isNotEmpty) yield ('$domainId.$field', value);
      }
      continue;
    }
    for (final raw in (json[section.key] as List<dynamic>? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id'] as String? ?? '?';
      final where = '$domainId.${section.key}.$id';
      for (final field in section.value) {
        final value = raw[field];
        if (value is String && value.isNotEmpty) yield ('$where.$field', value);
      }
      // 선택지와 목록도 화면에 나간다.
      for (final option in (raw['options'] as List<dynamic>? ?? const [])) {
        if (option is! Map<String, dynamic>) continue;
        for (final field in const ['label', 'whatIsThis']) {
          final value = option[field];
          if (value is String && value.isNotEmpty) {
            yield ('$where.${option['value']}.$field', value);
          }
        }
      }
      for (final field in const ['checklist']) {
        for (final item in (raw[field] as List<dynamic>? ?? const [])) {
          if (item is String && item.isNotEmpty) yield ('$where.$field', item);
        }
      }
      // 법원이 지키는 눈금도 우리 문장이다.
      for (final term in (raw['courtTerms'] as List<dynamic>? ?? const [])) {
        if (term is! Map<String, dynamic>) continue;
        for (final field in const ['label', 'within']) {
          final value = term[field];
          if (value is String && value.isNotEmpty) {
            yield ('$where.${term['id']}.$field', value);
          }
        }
          for (final item in (term['exceptWhen'] as List<dynamic>? ?? const [])) {
          if (item is String && item.isNotEmpty) {
            yield ('$where.${term['id']}.exceptWhen', item);
          }
        }
      }
    }
  }

  // **창구는 꼴이 둘이다** — 통짜 객체와 id 참조. 통짜인 것만 우리 글이다.
  for (final raw in (json['publicChannels'] as List<dynamic>? ?? const [])) {
    if (raw is! Map<String, dynamic>) continue;
    final where = '$domainId.publicChannels.${raw['id']}';
    for (final field in const ['label', 'note']) {
      final value = raw[field];
      if (value is String && value.isNotEmpty) yield ('$where.$field', value);
    }
  }
}

List<String> _checkWelfareBridge(Directory root, List<File> files) {
  final issues = <String>[];

  final manifestFile =
      File('${root.path}/packages/domain_data/assets/laws/manifest.json');
  if (!manifestFile.existsSync()) return issues;
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final known = <String>{};
  for (final entry in (manifest['laws'] as List<dynamic>)) {
    final law = entry as Map<String, dynamic>;
    known.add(normalizeLawName(law['name'] as String));
    for (final alias in (law['aliases'] as List<dynamic>? ?? const [])) {
      known.add(normalizeLawName(alias as String));
    }
  }

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;
    final bridge = json['welfareBridge'];
    if (bridge == null) continue;
    if (bridge is! Map<String, dynamic>) {
      issues.add('$domainId.welfareBridge — 객체여야 합니다');
      continue;
    }

    final why = (bridge['why'] as String? ?? '').trim();
    if (why.isEmpty) {
      issues.add('$domainId.welfareBridge — 왜 잇는지(why)가 비어 있습니다. '
          '목록만 남기면 다음 사람이 「비슷하니까 하나 더」를 합니다');
    }

    final laws = <String>[
      for (final law in (bridge['laws'] as List<dynamic>? ?? const []))
        if (law is String) law,
    ];
    if (laws.isEmpty) {
      issues.add('$domainId.welfareBridge — 이어 볼 법령이 하나도 없습니다. '
          '그러면 입구는 서는데 아무것도 안 걸립니다');
    }
    for (final law in laws) {
      if (!known.contains(normalizeLawName(law))) {
        issues.add('$domainId.welfareBridge — 매니페스트에 없는 법령입니다: '
            '$law. 없는 이름은 아무것도 못 잇습니다');
      }
    }
  }
  return issues;
}

List<String> _checkLawScope(List<File> files) {
  final issues = <String>[];

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? name;
    final scope = json['lawScope'];
    if (scope is! Map<String, dynamic>) {
      issues.add('$domainId — 쓸 수 있는 법령 선언(lawScope)이 없습니다. '
          '겉이 닮은 법이 섞이면 화면은 멀쩡하고 값만 틀립니다');
      continue;
    }

    final common = <String>{
      for (final law in (scope['laws'] as List<dynamic>? ?? const []))
        if (law is String) law,
    };

    // 갈래마다 **더** 쓸 수 있는 법령. 키는 `필드=값` 이다.
    final branchLaws = <String, Set<String>>{};
    for (final raw in (scope['branches'] as List<dynamic>? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      branchLaws['${raw['field']}=${raw['value']}'] = <String>{
        for (final law in (raw['laws'] as List<dynamic>? ?? const []))
          if (law is String) law,
      };
    }

    // 선언한 갈래가 **실제로 있는 선택지인지.** 이름이 한 글자 어긋나면 그
    // 갈래의 검사가 조용히 꺼지고, 그러면 통과는 「아무것도 안 셌다」가 된다
    // (DECISIONS 175번).
    final options = <String>{};
    for (final raw in (json['intake'] as List<dynamic>? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      for (final opt in (raw['options'] as List<dynamic>? ?? const [])) {
        if (opt is Map && opt['value'] != null) {
          options.add('${raw['field']}=${opt['value']}');
        }
      }
    }
    for (final key in branchLaws.keys) {
      if (options.contains(key)) continue;
      issues.add('$domainId.lawScope — 갈래 "$key" 는 어느 질문의 선택지에도 '
          '없습니다. 이름이 어긋나면 그 갈래의 검사가 조용히 꺼집니다');
    }

    // 기간 규칙도 화면에 나가는 조문이다. 갈래를 안 타므로 공통이어야 한다.
    for (final raw in (json['periodRules'] as List<dynamic>? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final law = raw['law'];
      if (law is String && !common.contains(law)) {
        issues.add('$domainId.periodRules — "$law" 이 lawScope.laws 에 '
            '없습니다');
      }
    }

    for (final section in json.values) {
      if (section is! List) continue;
      for (final item in section) {
        if (item is! Map<String, dynamic>) continue;
        if (item['id'] is! String) continue;

        final pins = <String>{};
        _pinsIn(item['showIf'], pins);

        final allowed = <String>{...common};
        for (final pin in pins) {
          allowed.addAll(branchLaws[pin] ?? const <String>{});
        }

        final used = <String, String>{};
        _lawsIn(item, used);

        for (final law in used.keys) {
          if (allowed.contains(law)) continue;
          final owner = branchLaws.entries
              .where((e) => e.value.contains(law))
              .map((e) => e.key)
              .toList()
            ..sort();
          issues.add(
            '$domainId.${item['id']} — "$law ${used[law]}" 을 근거로 드는데 '
            '${owner.isEmpty ? "lawScope 에 없는 법령입니다"
                : "${owner.join(" · ")} 갈래의 법령입니다"}. '
            '${pins.isEmpty ? "이 항목은 갈래에 안 묶여 있어 모든 갈래에 뜹니다 — "
                "showIf 로 갈래에 묶거나 " : "showIf 를 고치거나 "}'
            'lawScope 에 적으세요',
          );
        }
      }
    }
  }

  return issues;
}

/// `showIf` 가 **어느 갈래에 못 박혀 있는지.** `필드=값` 꼴로 모은다.
///
/// `!=` 는 갈래가 아니다 — 「그것만 빼고 전부」라서 어느 값에도 안 묶인다.
/// `or` 안의 `==` 둘은 갈래 둘에 묶인 것으로 본다(허용 법령은 합집합).
void _pinsIn(Object? node, Set<String> out) {
  if (node is Map<String, dynamic>) {
    for (final key in const ['==', '===']) {
      final args = node[key];
      if (args is List && args.length == 2) {
        final left = args[0];
        final right = args[1];
        if (left is Map && left['var'] is String && right is String) {
          out.add('${left['var']}=$right');
        }
      }
    }
    final inArgs = node['in'];
    if (inArgs is List && inArgs.length == 2) {
      final left = inArgs[0];
      final right = inArgs[1];
      if (left is Map && left['var'] is String && right is List) {
        for (final value in right) {
          if (value is String) out.add('${left['var']}=$value');
        }
      }
    }
    for (final value in node.values) {
      if (value is Map || value is List) _pinsIn(value, out);
    }
  } else if (node is List) {
    for (final child in node) {
      _pinsIn(child, out);
    }
  }
}

/// 이 항목이 **근거로 드는** 법령. 법령명 → 처음 나온 조문.
///
/// 조문 원문 **안**은 안 본다 — 인용이 다른 법을 부르는 것은 우리가 그 법에
/// 기댄 것과 다르고, 그쪽은 (p)가 본다.
void _lawsIn(Object? node, Map<String, String> out) {
  if (node is Map<String, dynamic>) {
    if (node['law'] is String &&
        node['article'] is String &&
        node['text'] is String) {
      out.putIfAbsent(node['law'] as String, () => node['article'] as String);
      return;
    }
    for (final value in node.values) {
      if (value is Map || value is List) _lawsIn(value, out);
    }
  } else if (node is List) {
    for (final child in node) {
      _lawsIn(child, out);
    }
  }
}

/// **(v) 기관이 알려 준 것에는 출처 딱지가 반드시 붙는다.**
///
/// 복지 자료는 조문이 아니다. 원문 대조를 한 적이 없고 할 수도 없다.
/// 그래서 「법에 적힌 게 아니라 ○○에서 알려 준 내용이에요. 마지막 확인 …」
/// 한 줄이 항상 함께 나가야 하고, 그 줄은 `notice` 에서 나온다.
///
/// **모델이 이미 `notice` 를 required 로 막고 있는데 왜 또 세는가** —
/// 구운 JSON 은 손으로 고칠 수 있고, 다음에 다른 출처를 붙일 때 여기를
/// 안 채우고 넣기 쉽다. 딱지가 없으면 그 줄은 **우리 말로 읽힌다.**
///
/// 인용에서도 막는 말이 걸려 뺀 항목은 `excluded[]` 에 이유와 함께 남아
/// 있어야 한다. 조용히 사라지면 다음 사람은 다 들어온 줄 안다(199번).
List<String> _checkWelfareNotice(Directory root) {
  final issues = <String>[];
  final dir = Directory('${root.path}/packages/domain_data/assets/welfare');
  if (!dir.existsSync()) return issues;

  final date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  const scopes = {'record', 'dataset'};

  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.json')) continue;
    final name = file.uri.pathSegments.last;
    final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    for (final raw in (catalog['services'] as List? ?? const [])) {
      final service = raw as Map<String, dynamic>;
      final id = service['id'] ?? '(id 없음)';
      final notice = service['notice'] as Map<String, dynamic>?;
      if (notice == null) {
        issues.add('$name — $id 에 출처 딱지(notice)가 없습니다. '
            '「기관이 알려 준 것」은 출처 없이 화면에 못 나갑니다');
        continue;
      }
      if ((notice['agency'] as String? ?? '').trim().isEmpty) {
        issues.add('$name — $id 의 notice.agency 가 비어 있습니다');
      }
      if (!date.hasMatch(notice['checkedAt'] as String? ?? '')) {
        issues.add('$name — $id 의 notice.checkedAt 이 날짜가 아닙니다');
      }
      if (!scopes.contains(notice['dateScope'])) {
        issues.add('$name — $id 의 notice.dateScope 가 record/dataset 이 '
            '아닙니다');
      }
    }

    for (final raw in (catalog['excluded'] as List? ?? const [])) {
      final row = raw as Map<String, dynamic>;
      if ((row['reason'] as String? ?? '').trim().isEmpty) {
        issues.add('$name — ${row['id']} 를 뺐는데 이유가 안 적혀 있습니다');
      }
    }
  }
  return issues;
}


/// (aj) **기다리는 화면이 처음부터 보이는가.**
///
/// 크롬의 Paint Timing 은 `opacity: 0` 으로 그려진 글자를 **안 그려진 것**으로
/// 센다. 그리고 그 뒤의 opacity 변화는 합성 스레드가 처리해서 새 페인트
/// 기록을 안 남긴다. 그래서 페이드인을 넣으면 **글자는 0.24초에 눈앞에 있는데
/// 지표는 8.5초로 적힌다.**
///
/// ★ **우리 도구만의 문제가 아니다.** Lighthouse 도 실사용자 지표(CrUX)도 같은
/// API 를 쓴다. 기관 담당자가 링크를 재 보면 그 8초가 나온다(266번).
///
/// 그래서 **글자를 감싸는 자리에는 `opacity` 도 `animation` 도 못 둔다.**
/// 나가는 쪽(`.is-leaving`)과 장식(`.beoba-stack`)은 첫 페인트 뒤의 일이라
/// 여기서 안 본다 — 막을 것만 막는다.
List<String> _checkSplashVisible(Directory root, List<String> notes) {
  final file = File('${root.path}/apps/beoba/web/index.html');
  if (!file.existsSync()) {
    return ['apps/beoba/web/index.html 을 찾을 수 없습니다'];
  }
  final text = file.readAsStringSync();

  // 글자를 감싸는 자리. 여기가 안 보이면 첫 페인트에 아무것도 안 잡힌다.
  const wrappers = <String>[
    '#beoba-splash',
    '.beoba-splash-inner',
    '.beoba-splash-title',
  ];

  final issues = <String>[];
  var scanned = 0;

  for (final selector in wrappers) {
    // `#beoba-splash {` 는 잡고 `#beoba-splash.is-leaving {` 은 안 잡는다.
    final start = text.indexOf('$selector {');
    if (start < 0) {
      issues.add('index.html — 「$selector {」 규칙이 없습니다. 기다리는 화면의 '
          '모양이 바뀌었으면 이 검사도 함께 고치세요');
      continue;
    }
    final end = text.indexOf('}', start);
    if (end < 0) {
      issues.add('index.html — 「$selector」 규칙이 안 닫혔습니다');
      continue;
    }
    final body = text.substring(start, end);
    scanned++;

    if (RegExp(r'\bopacity\s*:').hasMatch(body)) {
      issues.add('index.html — 「$selector」 에 opacity 가 있습니다. 기다리는 '
          '화면은 첫 페인트부터 보여야 합니다. opacity 0 뒤의 글자는 '
          'Paint Timing 이 못 봐서 Lighthouse 가 8초로 적습니다 (266번)');
    }
    if (RegExp(r'\banimation\s*:').hasMatch(body)) {
      issues.add('index.html — 「$selector」 에 animation 이 있습니다. 들어오는 '
          '애니메이션은 두지 않습니다 — opacity 로 나타나면 첫 페인트가 '
          '지표에서 사라집니다 (266번)');
    }
  }

  // **분모를 낸다.** 셋 중 하나도 못 읽었으면 이 검사는 돌아도 아무것도 안 본다.
  if (scanned == 0) {
    issues.add('기다리는 화면 — 볼 규칙을 하나도 못 읽었습니다. 분모가 0이면 '
        '이 검사는 통과해도 뜻이 없습니다');
  }
  // **걸린 수를 그대로 적는다.** 「0건」이라고 박아 두면 걸렸을 때도 0건이라
  // 말해서, 알림 줄만 보는 사람이 통과한 줄 안다.
  notes.add('기다리는 화면 — 글자를 감싸는 규칙 $scanned개 / '
      '${wrappers.length}개를 봤습니다 (걸린 것 ${issues.length}건)');

  return issues;
}


/// (al) **표시된 자리 가운데 사람이 안 본 것이 늘지 않는가 — 톱니.**
///
/// ## 왜 「표시 수」가 아닌가
///
/// 처음에는 분야별 **표시 수**에 톱니를 걸었다. 그런데 **고칠수록 빨개지는 일이
/// 생겼다.** 단서를 되살리려고 「보정하지 않으면」을 넣었더니 그 낱말이 옆 조문에
/// 걸려 표시가 하나 늘었다. 고친 것이 맞는데 게이트가 빨개졌다.
///
/// **표시 수는 낱말을 세는 숫자라 진도를 못 잰다.** 그래서 톱니를 옮겼다 —
/// **표시된 자리 가운데 장부의 `reviewed` 에 없는 것**을 센다.
///
/// ```
/// 사람이 보고 결론을 적으면   고쳤든 헛표시든 두고 보든   내려간다
/// 새 분야·새 문장이 표시를 만들면                        올라간다
/// 고치다 낱말이 늘어 표시가 늘어도, 그 자리를 봤으면       안 올라간다
/// ```
///
/// 이 숫자는 **한 방향으로만 간다.** 그래서 진도를 잰다(DECISIONS 273번).
///
/// ★ **결론은 셋뿐이다** — 고쳤다 · 헛표시다 · 두고 본다. 「두고 본다」가 있는
/// 까닭은 판단이 안 서는 자리를 「안 본 것」에 남겨 두면 영영 안 끝나기 때문이다.
/// 다만 따로 센다 — 늘어나면 그것대로 신호다.
///
/// ★★ **표시는 잡아내는 것이 아니라 사람이 볼 순서다.** 이 검사가 초록이라고
/// 우리 문장이 조문을 안 넘는 것이 아니다. 「조문에 있는데 우리가 안 말한 것」과
/// 「우리 문장의 근거가 이 카드에 없는 것」은 이 셈이 영원히 못 본다(270번 ④⑤).
List<String> _checkCitationDebt(
  Directory root,
  List<File> files,
  List<String> notes,
) {
  final issues = <String>[];
  const ledgerPath = 'packages/domain_data/review/citations.json';
  final ledgerFile = File('${root.path}/$ledgerPath');
  if (!ledgerFile.existsSync()) {
    return ['인용 점검 — 장부가 없습니다: $ledgerPath'];
  }
  final ledger = jsonDecode(ledgerFile.readAsStringSync()) as Map<String, dynamic>;
  final wrote = Map<String, dynamic>.of(
      (ledger['unreviewed'] as Map<String, dynamic>?) ?? const {})
    ..remove('_');
  final reviewed = Map<String, dynamic>.of(
      (ledger['reviewed'] as Map<String, dynamic>?) ?? const {})
    ..remove('_');

  const results = {'고쳤다', '헛표시다', '두고 본다'};

  final rows = <CitationRow>[];
  final actual = <String, int>{};
  for (final file in files) {
    final id = file.uri.pathSegments.last.replaceAll('.json', '');
    actual[id] = 0;
    rows.addAll(collectCitations(
      id,
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    ));
  }

  // **분모를 낸다.** 인용을 하나도 못 모았으면 이 검사는 돌아도 아무것도 안 본다.
  if (rows.isEmpty) {
    return ['인용 점검 — 인용을 하나도 못 모았습니다. 분모가 0이면 톱니가 헛돕니다'];
  }

  final keys = {for (final r in rows) r.key};
  var marked = 0;
  var guided = 0;
  final markedKeys = <String>{};
  for (final r in rows) {
    final f = flagCitation(r);
    guided += f.guided;
    if (f.isEmpty) continue;
    marked++;
    markedKeys.add(r.key);
    if (!reviewed.containsKey(r.key)) actual[r.domain] = actual[r.domain]! + 1;
  }

  for (final d in {...actual.keys, ...wrote.keys}.toList()..sort()) {
    final now = actual[d];
    final was = wrote[d];
    if (now == null) {
      issues.add('인용 점검 — 장부에 「$d」가 있는데 그런 분야가 없습니다. 지우세요');
      continue;
    }
    if (was is! int) {
      issues.add('인용 점검 — 장부의 unreviewed 에 「$d」 줄이 없습니다. '
          '「"$d": $now」 로 넣으세요. 새 분야라면 이 수가 곧 새로 진 빚입니다');
      continue;
    }
    if (now > was) {
      issues.add('인용 점검 — 「$d」 에 아직 안 본 자리가 늘었습니다 ($was → $now). '
          '사람이 보고 장부의 reviewed 에 결론(고쳤다 · 헛표시다 · 두고 본다)과 이유를 '
          '적으세요. 어디인지는 docs/인용_점검.md 에 있습니다');
    } else if (now < was) {
      issues.add('인용 점검 — 「$d」 에 안 본 자리가 줄었습니다 ($was → $now). '
          '장부를 $now 로 내려 박으세요 — 안 박으면 다음에 누가 늘려도 그만큼은 '
          '조용히 지나갑니다');
    }
  }

  // 장부의 결론이 실제 자리를 가리키는가. 낡은 줄은 거짓말이 된다.
  final counts = <String, int>{for (final r in results) r: 0};
  for (final k in reviewed.keys) {
    final v = reviewed[k];
    if (v is! Map) {
      issues.add('인용 점검 — 본 자리 「$k」 가 무엇인지 못 읽겠습니다');
      continue;
    }
    if (!keys.contains(k)) {
      issues.add('인용 점검 — 본 자리 「$k」 가 이제 없습니다. 장부에서 지우세요');
      continue;
    }
    final result = v['result'];
    if (!results.contains(result)) {
      issues.add('인용 점검 — 본 자리 「$k」 의 결론이 「$result」 입니다. '
          '고쳤다 · 헛표시다 · 두고 본다 셋 중 하나여야 합니다');
    } else {
      counts[result as String] = counts[result]! + 1;
    }
    if ((v['why'] as String? ?? '').trim().isEmpty) {
      issues.add('인용 점검 — 본 자리 「$k」 에 왜 그렇게 봤는지가 없습니다. '
          '이유가 없으면 본 것과 안 본 것이 구별되지 않습니다');
    }
    if ((v['at'] as String? ?? '').trim().isEmpty) {
      issues.add('인용 점검 — 본 자리 「$k」 에 언제 봤는지가 없습니다');
    }
    if (result == '고쳤다' &&
        ((v['commit'] as String? ?? '').trim().isEmpty || v['decision'] == null)) {
      issues.add('인용 점검 — 본 자리 「$k」 는 고쳤다고 했는데 commit 이나 decision 이 '
          '없습니다. 무엇을 왜 고쳤는지 없으면 다음 사람이 못 맞대 봅니다');
    }
  }

  // **표의 숫자는 검사가 센다**(238번). 표가 낡으면 10월에 틀린 답을 낸다.
  final unreviewed = actual.values.fold<int>(0, (a, b) => a + b);
  final unreviewedKeys =
      markedKeys.where((k) => !reviewed.containsKey(k)).length;
  final doc = File('${root.path}/docs/인용_점검.md');
  if (!doc.existsSync()) {
    issues.add('인용 점검 — docs/인용_점검.md 가 없습니다. '
        'build_citation_report.dart 로 뽑으세요');
  } else {
    final text = doc.readAsStringSync();
    int? read(String label) {
      final m = RegExp('$label\\s+(\\d+)').firstMatch(text);
      return m == null ? null : int.parse(m.group(1)!);
    }

    if (read('인용 전체') != rows.length ||
        read('표시된 것') != marked ||
        read('안 본 자리') != unreviewedKeys) {
      issues.add('인용 점검 — docs/인용_점검.md 가 낡았습니다 (표: '
          '${read('인용 전체')} · ${read('표시된 것')} · ${read('안 본 자리')} / 실제: '
          '${rows.length} · $marked · $unreviewedKeys). '
          'build_citation_report.dart 로 다시 뽑으세요');
    }
  }

  notes.add('인용 점검 — 인용 ${rows.length}개 · 표시 $marked개 '
      '(자리 ${markedKeys.length}곳) · 본 자리 ${reviewed.length}곳 '
      '(고쳤다 ${counts['고쳤다']} · 헛표시다 ${counts['헛표시다']} · '
      '두고 본다 ${counts['두고 본다']}) · 안 본 자리 $unreviewedKeys곳(인용 $unreviewed개) · '
      '길 안내라서 뺀 문장 $guided');
  return issues;
}

/// (ak) **같은 조문을 두 분야가 인용하면 두 벌이 생긴다.**
///
/// 두 분야가 같은 조문에 기대면 그 조문을 **두 번 옮겨 적은 것**이다. 전세사기가
/// 들어오면 주택임대차보호법 여섯 조문이 보증금 분야와 겹친다 — 짓기 전에
/// 이것이 있어야 짓는 순간 두 벌이 생기는 것을 본다.
///
/// ```
/// ① 원문 조각   겹치는 부분의 글자가 다르면 빨간불 — 한쪽만 고친 흔적이다
///               (발췌 길이만 다르거나 표의 다른 줄이면 괜찮다)
/// ② 우리 문장   분야마다 전부 다르면 이유를 적는다 — 없으면 빨간불
/// ```
///
/// ②를 막지 않고 이유를 적게 하는 까닭 — 같은 항이 **다른 물음에 답하는** 일이
/// 흔하다. 근로기준법 시행령 [별표 1]은 해고 분야에서는 「4명 이하 사업장에
/// 구제신청이 안 걸린다」이고 임금 분야에서는 「그래도 임금 규정은 걸린다」다.
/// 문장이 같으면 오히려 틀린다.
///
/// ★ **이유를 지어내지 않는다.** 같은 것을 두 말로 부르고 있을 뿐이면 그건
/// 이유가 아니라 맞출 일이다 — 그 자리는 빨간불로 둔다.
List<String> _checkSharedCitations(
  Directory root,
  List<File> files,
  List<String> notes,
) {
  final issues = <String>[];
  final ledgerFile =
      File('${root.path}/packages/domain_data/review/citations.json');
  if (!ledgerFile.existsSync()) {
    return ['같은 조문 — 장부가 없습니다: packages/domain_data/review/citations.json'];
  }
  final ledger = jsonDecode(ledgerFile.readAsStringSync()) as Map<String, dynamic>;
  final reasons = Map<String, dynamic>.of(
    (ledger['overlap'] as Map<String, dynamic>?) ?? const {},
  )..remove('_');

  final rows = <CitationRow>[];
  for (final file in files) {
    rows.addAll(collectCitations(
      file.uri.pathSegments.last.replaceAll('.json', ''),
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    ));
  }
  final shared = sharedCitations(rows);

  var conflicts = 0;
  var diverging = 0;
  final seen = <String>{};
  for (final s in shared) {
    seen.add(s.cite);
    final doms = s.byDomain.keys.join(' · ');

    final bad = excerptConflicts(s);
    if (bad.isNotEmpty) {
      conflicts += bad.length;
      issues.add('같은 조문 ① — 「${s.cite}」 원문 조각이 겹치는데 글자가 다릅니다 '
          '($doms). 한쪽만 고친 흔적입니다. 두 곳을 같은 원문으로 맞추세요');
    }

    if (wordingDiverges(s)) {
      diverging++;
      final why = reasons[s.cite];
      if (why is! String || why.trim().isEmpty) {
        issues.add('같은 조문 ② — 「${s.cite}」 를 $doms 가 인용하는데 우리 문장이 '
            '분야마다 다르고 이유가 없습니다. 다른 물음에 답하는 것이면 장부의 '
            'overlap 에 이유를 적고, 같은 것을 두 말로 부르는 것이면 맞추세요');
      }
    } else if (reasons.containsKey(s.cite)) {
      issues.add('같은 조문 ② — 「${s.cite}」 는 이제 분야 사이에 같은 문장이 '
          '있습니다. 장부의 이유를 지우세요 — 낡은 이유는 거짓말이 됩니다');
    }
  }
  for (final k in reasons.keys) {
    if (!seen.contains(k)) {
      issues.add('같은 조문 ② — 장부의 「$k」 는 이제 두 분야가 인용하지 않습니다. '
          '지우세요');
    }
  }

  notes.add('같은 조문 — 두 분야 이상이 인용하는 조문 ${shared.length}개 · '
      '① 겹치는데 글자가 다른 조각 $conflicts쌍 · '
      '② 분야마다 문장이 다른 곳 $diverging (이유 ${reasons.length})');
  return issues;
}


/// (am) **카드가 무엇에 기대어 서 있는가.**
///
/// 막는 것은 `SchemaValidator` 가 한다 — 조문도 기관 안내도 없이는 카드가 못
/// 서고, `noBasis` 로 비켜 가려면 이유를 적어야 하며, 적어 놓고 법 이야기를 하면
/// 실패한다(274번). **여기서는 세기만 한다.**
///
/// ★ **왜 세는가** — 「기관이 자기 이름을 얹는다」를 말하려면 **실물이 몇 곳인지**를
/// 알아야 한다. 2026-09-16 에 세 보니 `AgencyNotice` 가 붙은 곳이 셋뿐이었고
/// 전부 같은 기관(신용회복위원회)이었다. 그 숫자를 모르는 채로 그 말을 할 뻔했다.
///
/// **분모를 낸다**(244·245·247번). 카드가 0장이면 이 검사는 돌아도 아무것도 안 본다.
List<String> _checkCautionFooting(
  List<File> files,
  List<String> notes,
  List<String> warnings,
) {
  final issues = <String>[];
  var cards = 0;
  var byLaw = 0;
  var byNotice = 0;
  var byBoth = 0;
  var bare = 0;
  final agencies = <String>{};
  final where = <String>[];

  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;
    for (final raw in (json['cautions'] as List<dynamic>? ?? const [])) {
      final caution = raw as Map<String, dynamic>;
      cards++;
      final hasLaw = caution['legalBasis'] != null ||
          ((caution['alsoBasis'] as List<dynamic>?) ?? const []).isNotEmpty;
      final notice = caution['notice'];
      if (notice is Map<String, dynamic>) {
        final agency = notice['agency'];
        if (agency is String) agencies.add(agency);
        where.add('$domainId.${caution['id']}');
        if (hasLaw) {
          byBoth++;
        } else {
          byNotice++;
        }
      } else if (hasLaw) {
        byLaw++;
      } else {
        bare++;
      }
    }
  }

  if (cards == 0) {
    return ['카드가 선 자리 — 카드를 하나도 못 읽었습니다. 분모가 0이면 이 검사는 '
        '통과해도 뜻이 없습니다'];
  }

  notes.add('카드가 선 자리 — 카드 $cards장 (조문만 $byLaw · 기관 안내만 $byNotice · '
      '둘 다 $byBoth · 둘 다 없이 noBasis 로 선 것 $bare)');

  // ★ **이 숫자를 모르는 채로 「기관이 이름을 얹는다」를 말하지 않는다.**
  final onCards = byNotice + byBoth;
  notes.add('기관 안내 — 카드에 붙은 것 $onCards곳'
      '${where.isEmpty ? "" : " (${where.join(" · ")})"} · '
      '서로 다른 기관 ${agencies.length}곳'
      '${agencies.isEmpty ? "" : " (${(agencies.toList()..sort()).join(" · ")})"}');
  if (agencies.length < 2) {
    warnings.add('기관 안내 — 서로 다른 기관이 ${agencies.length}곳입니다. '
        '「기관이 자기 이름을 얹는다」를 말하려면 이 수가 하나보다 커야 합니다');
  }
  return issues;
}


/// (an) **한시법은 그날 법 자체가 없어진다.**
///
/// 우리 글은 「법에 이렇게 적혀 있어요」라고 말한다. 그 말은 **법이 있는
/// 동안만** 참이다. 만료일이 지나면 그 법에 기댄 문장이 전부 거짓이 되는데
/// 🟢 은 「법에 있는 내용」이지 「지금도 법에 있는 내용」이 아니라서
/// **아무것도 안 걸린다.**
///
/// ```
/// 그날 전   알림만 낸다 — 미리 지우면 지금 맞는 조문을 지우는 것이다
/// 그날부터  실패. 그 법을 인용하는 분야가 있으면 사람이 손을 대야 한다
/// ```
///
/// ★ **연장됐는지 없어졌는지는 사람만 안다.** 그래서 검사가 고쳐 주지 않고
/// 멈춰 세운다. 그날 기억하는 것은 사람이 아니라 검사다(DECISIONS 275번).
///
/// ★ **근거 부칙이 비면 실패한다.** 근거 없는 만료일은 우리가 지은 날짜다.
/// 그리고 조문에 날짜가 없어 우리가 골랐으면 `chosen` 에 그걸 적어야 한다 —
/// 「법에 없는 숫자」를 조용히 쓰지 않는다(272번과 같은 자리다).
///
/// **분모를 낸다** — 한시법이 0개면 이 검사는 돌아도 아무것도 안 본다.
List<String> _checkSunset(
  List<File> files,
  KstClock clock,
  _Lifespan lifespan,
  List<String> notes,
) {
  final issues = <String>[];
  final today = clock.today();

  if (lifespan.sunsets.isEmpty) {
    notes.add('한시법 — 적어 둔 것이 0개입니다. 생기면 '
        'assets/laws/lifespan.json 의 sunset 에 적습니다');
    return issues;
  }

  // 그 법을 실제로 인용하는 분야. 안 쓰는 법은 만료돼도 우리 화면과 무관하다.
  final usedBy = <String, List<String>>{};
  for (final file in files) {
    final text = file.readAsStringSync();
    final domainId = file.uri.pathSegments.last.replaceAll('.json', '');
    for (final law in lifespan.sunsets.keys) {
      if (text.contains(law)) {
        usedBy.putIfAbsent(law, () => []).add(domainId);
      }
    }
  }

  var soonest = '';
  for (final s in lifespan.sunsets.values) {
    // 근거가 없는 날짜는 우리가 지은 것이다.
    if (s.clause.trim().isEmpty || s.text.trim().isEmpty) {
      issues.add('한시법 — 「${s.law}」 의 만료일에 근거 부칙이 없습니다. '
          'clause 와 text 를 적으세요. 근거 없는 날짜는 우리가 지은 것입니다');
    }

    final here = usedBy[s.law] ?? const <String>[];
    final due = today >= s.expires;

    if (!due) {
      notes.add('한시법 — ${s.expires.toIso()} 까지 ${s.law}'
          '${s.chosen == null ? "" : " (★ 조문에 없는 날. 우리가 고른 값)"}. '
          '${here.isEmpty ? "지금 쓰는 분야가 없습니다" : "쓰는 분야: ${here.join(" · ")}"}');
      if (soonest.isEmpty) soonest = s.expires.toIso();
      continue;
    }
    if (here.isEmpty) continue;

    issues.add('${s.expires.toIso()} 로 ${s.law} 의 유효기간이 지났습니다 '
        '(${s.clause}). 그런데 아직 쓰고 있습니다: ${here.join(" · ")}. '
        '연장됐는지 없어졌는지는 사람만 알 수 있습니다 — 원문을 받아 '
        'lifespan.json 의 expires 를 고치거나, 그 분야를 내리세요'
        '${s.after == null ? "" : ". ★ 다만 만료일이 지나도 참인 것이 있습니다: ${s.after}"}');
  }

  notes.add('한시법 — 적어 둔 것 ${lifespan.sunsets.length}개 · '
      '그중 지금 쓰는 것 ${usedBy.length}개'
      '${soonest.isEmpty ? "" : " · 가장 가까운 만료 $soonest"} '
      '(오늘 ${today.toIso()})');
  return issues;
}

/// (ao) **절차마다 「이 길을 만드는 법」을 사람이 한 번 판정했는가.**
///
/// `legalBasis` 는 「카드의 문장이 기대는 조문」이고, 그게 늘 「이 길을 만드는
/// 법」은 아니다. 제소전화해 카드는 인지법에 기대지만 그 길은 민사소송법이
/// 만든다. 다를 때만 `pathLaw` 를 적고, **같다는 판정은 장부에 적는다** —
/// 비어 있는 칸만으로는 「같다고 봤다」와 「안 봤다」가 구별되지 않기
/// 때문이다. 그 구멍이 「법원을 거쳐 받기」의 잘못 달린 근거를 살려
/// 두었다(DECISIONS 280 · 281번).
///
/// ```
/// pathLaw / noPathLaw 가 있다   판정이 데이터에 있다
/// 둘 다 없다                   장부에 「같다」 판정과 이유가 있어야 한다
///                              판정할 때의 법 이름이 지금 legalBasis 와 달라도 실패
/// 장부에만 있다                 낡은 판정이다 — 실패
/// ```
///
/// **분모를 낸다** — 절차가 0개면 이 검사는 아무것도 안 본다.
List<String> _checkPathLaw(
  Directory root,
  List<Domain> domains,
  List<String> notes,
) {
  final issues = <String>[];
  const ledgerPath = 'packages/domain_data/review/path_law.json';
  final ledgerFile = File('${root.path}/$ledgerPath');
  if (!ledgerFile.existsSync()) {
    return ['이 길을 만드는 법 — 장부가 없습니다: $ledgerPath'];
  }
  final ledger = jsonDecode(ledgerFile.readAsStringSync()) as Map<String, dynamic>;
  final same = Map<String, dynamic>.of(
      (ledger['sameAsLegalBasis'] as Map<String, dynamic>?) ?? const {})
    ..remove('_');

  var total = 0;
  var judgedSame = 0;
  var withPathLaw = 0;
  var withNoPathLaw = 0;
  final seen = <String>{};

  for (final domain in domains) {
    for (final procedure in domain.procedures) {
      total++;
      final key = '${domain.id}.${procedure.id}';
      seen.add(key);
      final entry = same[key];

      if (procedure.pathLaw != null || procedure.noPathLaw != null) {
        if (procedure.pathLaw != null) withPathLaw++;
        if (procedure.noPathLaw != null) withNoPathLaw++;
        if (entry != null) {
          issues.add('이 길을 만드는 법 — $key 에 pathLaw/noPathLaw 가 있는데 장부에 '
              '「같다」 판정도 남아 있습니다. 낡은 판정을 $ledgerPath 에서 지우세요');
        }
        continue;
      }

      final law = procedure.legalBasis?.law;
      if (law == null || law.trim().isEmpty) {
        issues.add('이 길을 만드는 법 — $key 에 근거도 길을 만드는 법도 없습니다. '
            'pathLaw 를 달거나, 정말 법이 없으면 noPathLaw 에 왜 없는지 적으세요');
        continue;
      }
      if (entry is! Map<String, dynamic>) {
        issues.add('이 길을 만드는 법 — $key 를 아직 아무도 판정하지 않았습니다. '
            '「$law」이 이 길을 만드는 법인지 사람이 한 번 보세요. 같으면 '
            '$ledgerPath 의 sameAsLegalBasis 에 법 이름과 이유를, 다르면 pathLaw 를 적습니다');
        continue;
      }
      if (entry['law'] != law) {
        issues.add('이 길을 만드는 법 — $key 를 판정할 때의 법은 「${entry['law']}」인데 '
            '지금 legalBasis 는 「$law」입니다. 근거가 바뀌었으니 다시 판정하세요');
        continue;
      }
      final why = entry['why'];
      if (why is! String || why.trim().isEmpty) {
        issues.add('이 길을 만드는 법 — $key 의 「같다」 판정에 이유가 없습니다. '
            '「같다」만 적으면 다음 사람이 다시 판정해야 합니다');
        continue;
      }
      judgedSame++;
    }
  }

  for (final key in same.keys) {
    if (!seen.contains(key)) {
      issues.add('이 길을 만드는 법 — 장부의 $key 가 데이터에 없습니다. 낡은 판정을 지우세요');
    }
  }

  if (total == 0) {
    issues.add('이 길을 만드는 법 — 훑은 절차가 0개입니다. 검사가 아무것도 안 봅니다');
  }
  notes.add('이 길을 만드는 법 — 절차 $total개 · 「같다」 판정 $judgedSame · '
      'pathLaw $withPathLaw · noPathLaw $withNoPathLaw');
  return issues;
}

/// (ap) **한 분야 안에서 절차의 step 이 겹치지 않는가.**
///
/// 맨 앞 절차가 「오늘 할 일」이 되고, 가져가기 글의 〔먼저 하실 일〕에 실린다.
/// step 이 같으면 먼저를 **정렬이 정한다** — Dart 의 `List.sort` 는 안정성을
/// 약속하지 않는다. 전세사기의 고소장 내기가 배당요구와 같은 step 이었는데 순서가
/// 맞게 나온 것은 파일 순서와 운 덕분이었다(DECISIONS 280번).
///
/// ★ **「순서가 없다」를 같은 step 으로 나타낼 수 없다.** 화면은 목록이라 하나가
/// 반드시 먼저 선다. 조문이 순서를 말하지 않으면 그 사실과 우리가 그렇게 둔
/// 까닭을 note 에 적고 번호를 가른다(283번). showIf 가 서로를 배제해 같이 안
/// 서는 짝도 가른다 — 배제를 기계가 증명하기 어렵고, 번호를 가르는 값이 싸다.
List<String> _checkProcedureSteps(List<Domain> domains, List<String> notes) {
  final issues = <String>[];
  var procedures = 0;
  for (final domain in domains) {
    final byStep = <int, List<String>>{};
    for (final procedure in domain.procedures) {
      procedures++;
      (byStep[procedure.step] ??= []).add(procedure.id);
    }
    for (final entry in byStep.entries) {
      if (entry.value.length < 2) continue;
      issues.add('절차 순서 — ${domain.id} 에서 step ${entry.key} 이 겹칩니다: '
          '${entry.value.join(' · ')}. 순서가 정렬 운에 달립니다. 조문이 순서를 '
          '말하지 않으면 그 사실과 까닭을 note 에 적고 step 을 가르세요');
    }
  }
  if (procedures == 0) {
    issues.add('절차 순서 — 훑은 절차가 0개입니다. 검사가 아무것도 안 봅니다');
  }
  notes.add('절차 순서 — 분야 ${domains.length}개 · 절차 $procedures개 · 겹침 ${issues.length}');
  return issues;
}
