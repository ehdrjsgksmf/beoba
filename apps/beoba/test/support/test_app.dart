import 'package:beoba/src/plain/plain_mode_store.dart';
import 'package:beoba/src/app/app.dart';
import 'package:beoba/src/app/theme.dart';
import 'package:beoba/src/data/asset_policy_source.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/policy_providers.dart';
import 'package:beoba/src/providers/tally_providers.dart';
import 'package:beoba/src/tally/tally.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/safety/safety_reporter.dart';
import 'package:beoba/src/widgets/term_sheet.dart';
import 'package:beoba/src/providers/welfare_providers.dart';
import 'package:domain_data/domain_data.dart'
    show CentralWelfareCatalog, Glossary;
import 'package:engines/engines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트에서 쓰는 고정 기준일.
///
/// 도메인 JSON 의 `checkedAt` 이 2026-08-15 이라 이 날짜를 벗어나면 검수 경과
/// 경고가 섞인다. 모든 테스트가 같은 날을 본다.
const KstClock testClock = FixedKstClock(KstDate(2026, 8, 15));

/// **화면 크기와 자판 높이를 지운 채로 앱을 띄우지 않는다.**
///
/// 예전에는 `MediaQueryData(textScaler: …)` 를 통째로 새로 만들어 덮었다.
/// 글자 배율은 제대로 들어갔지만 **`size` 가 0 이고 `viewInsets` 가 0** 이
/// 됐다. 레이아웃은 제약(constraints)으로 도니까 화면은 멀쩡해 보이는데,
/// `MediaQuery.sizeOf` 를 읽는 위젯과 **`resizeToAvoidBottomInset`(자판이
/// 올라오면 본문을 줄이는 장치)이 테스트에서 영영 안 돌았다.**
///
/// 자판이 올라온 화면을 시험할 방법이 아예 없었다는 뜻이다.
MediaQueryData testMediaQuery(WidgetTester tester, double textScale) =>
    MediaQueryData.fromView(tester.view)
        .copyWith(textScaler: TextScaler.linear(textScale));

/// 도메인 로드가 끝난 컨테이너.
///
/// 화면은 부트스트랩 성공 후에만 열리므로 `requireValue` 가 안전하다는 전제를
/// 테스트에서도 똑같이 만든다. `ProviderContainer.test` 라 정리는 자동이다.
Future<ProviderContainer> bootstrappedContainer() async {
  final container = ProviderContainer.test(
    overrides: [clockProvider.overrideWithValue(testClock)],
  );
  await container.read(domainBundleProvider.future);
  return container;
}

/// 한 번 읽은 도메인은 다시 읽지 않는다. 테스트마다 asset 을 파싱할 이유가 없다.
DomainBundle? _cachedBundle;

Future<DomainBundle> loadTestBundle() async {
  final cached = _cachedBundle;
  if (cached != null) return cached;

  final container = ProviderContainer(
    overrides: [clockProvider.overrideWithValue(testClock)],
  );
  final bundle = await container.read(domainBundleProvider.future);
  container.dispose();
  return _cachedBundle = bundle;
}

/// 앱 전체를 띄운다. 화면 전환까지 도는 흐름 테스트용.
///
/// 도메인은 **미리 읽어 넣는다.** 부트스트랩 스피너가 무한 애니메이션이라
/// `pumpAndSettle` 이 끝나지 않기 때문이다. 화면은 어차피 로드가 끝난 뒤에만 열린다.
/// 돌려주는 컨테이너로 인터뷰 답을 미리 심을 수 있다. 12문항을 매번 탭할 이유는 없다.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  SafetyReporter reporter = const LoggingSafetyReporter(),
  double textScale = 1,
  List<DeadlineResult>? deadlines,
  KstClock clock = testClock,
  TallySink? tallySink,

  /// 복지 자료. **준 테스트에서만 읽는다.**
  ///
  /// `central.json` 이 1.2MB 라 안 쓰는 화면까지 읽으면 전체 테스트가
  /// 느려진다. 그리고 안 넘기면 두 번째 문 화면은 기다리는 동그라미를
  /// 그리는데, 그건 끝나지 않는 애니메이션이라 `pumpAndSettle` 이 안 끝난다.
  CentralWelfareCatalog? welfare,

  /// **기본은 「세지 마세요」다.** 안 그러면 모든 테스트에서 첫 실행 시트가
  /// 열려 화면을 덮는다 — 그리고 아무것도 안 보내는 것이 기본이어야 맞다.
  ConsentStore? consent,

  /// **기본은 「그대로 볼게요」를 이미 고른 상태다.** 안 그러면 모든 테스트에서
  /// 첫 실행 물음이 열려 화면을 덮는다(DECISIONS 289번).
  PlainModeStore? plainStore,

  /// 개인정보처리방침. **준 테스트에서만 읽는다.**
  ///
  /// 자산 읽기는 **진짜 파일 I/O 라 `runAsync` 밖에서는 끝나지 않는다.**
  /// 복지 자료와 같은 이유로 밖에서 읽어 넘긴다 — 안 넘기면 방침 화면이
  /// 빈 채로 선다.
  List<PolicyBlockData>? policy,

  /// 분야 묶음을 갈아끼운다. **분야가 스물둘일 때를 재려고 둔다.**
  ///
  /// 가짜 분야를 자산에 넣을 수는 없다 — 자산에 있으면 실기기에도 실린다.
  /// 대신 진짜 분야를 복사해 id 만 바꿔 넣는다. 카드가 진짜라서 잰 값도 진짜다.
  DomainBundle? overrideBundle,
}) async {
  consent ??= MemoryConsentStore(false);
  plainStore ??= MemoryPlainModeStore(false);
  final bundle = overrideBundle ?? await tester.runAsync(loadTestBundle);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(clock),
        domainBundleProvider.overrideWith((ref) => bundle!),
        // 기한을 갈아 끼우는 자리. 지금 데이터로는 기한이 이 화면까지 오지
        // 못한다 — 법원 서류를 받아야 걸리는 것은 하드스톱으로 끊기고
        // 소멸시효는 unverified 라 로더가 걷어낸다(🔴 확인 목록).
        // **기한이 있을 때의 화면을 시험할 방법이 이것뿐이다.**
        //
        // 타입 이름(`Override`)이 riverpod 배럴에 없어서 목록을 바깥에서
        // 만들어 넘길 수 없다. 그래서 여기서 만든다.
        if (deadlines != null)
          deadlineResultsProvider(kDebtRecoveryDomainId)
              .overrideWithValue(deadlines),
        // 집계는 **아무 데도 안 보내는 것이 기본**이다. 테스트가 보내는
        // 자리를 갈아 끼워 무엇이 나갔는지 센다.
        if (tallySink != null) tallySinkProvider.overrideWithValue(tallySink),
        consentStoreProvider.overrideWithValue(consent),
        plainModeStoreProvider.overrideWithValue(plainStore),
        if (welfare != null)
          welfareCatalogProvider.overrideWith((ref) => welfare),
        if (policy != null) policyBlocksProvider.overrideWith((ref) => policy),
      ],
      child: MediaQuery(
        data: testMediaQuery(tester, textScale),
        child: BeobaApp(reporter: reporter),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(
    tester.element(find.byType(BeobaApp)),
  );
}

/// 분야 목록에서 분야 하나를 고른다. **묶음을 거친다.**
///
/// 첫 화면에는 묶음 줄만 서므로 분야 이름을 바로 누를 수 없다
/// (DECISIONS 237번). 테스트마다 「어느 묶음에 들었더라」를 적으면 배치를
/// 바꿀 때마다 테스트를 줄줄이 고쳐야 하므로 **데이터에서 찾아 들어간다.**
Future<void> pickDomainFromList(
  WidgetTester tester,
  String domainId,
) async {
  // 어느 묶음에 들었는지는 **데이터가 안다.** 테스트마다 적어 두면 배치를
  // 바꿀 때 테스트를 줄줄이 고쳐야 한다.
  final bundle = await loadTestBundle();
  final groupId = bundle.byId(domainId).group;
  if (groupId != null && bundle.groupCatalog.byId(groupId) != null) {
    final name = bundle.groupCatalog.byId(groupId)!.name;
    final row = find.text(name);
    if (row.evaluate().isNotEmpty) {
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }
  }

  final card = find.text(bundle.byId(domainId).name);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

/// 위젯 하나만 띄운다. 라우팅 없이 표시만 볼 때.
Future<void> pumpWidgetOnly(
  WidgetTester tester,
  Widget child, {
  SafetyReporter reporter = const LoggingSafetyReporter(),
  double textScale = 1,
  KstClock clock = testClock,
  Glossary? glossary,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWithValue(clock)],
      child: MaterialApp(
        theme: buildBeobaTheme(),
        // **용어집은 Navigator 위에 깐다.** 바텀시트는 별도 라우트라
        // `home` 아래에 깔면 시트 안에서 안 보인다. 앱도 `builder` 에 깐다.
        builder: glossary == null
            ? null
            : (context, child) => GlossaryScope(
                  glossary: glossary,
                  child: child ?? const SizedBox.shrink(),
                ),
        home: MediaQuery(
          data: testMediaQuery(tester, textScale),
          child: SafetyReporterScope(
            reporter: reporter,
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 인터뷰를 끝까지 채운 답.
///
/// 지급명령을 받은 사람. 5,000만원을 빌려줬고 전자소송으로 진행한다.
///
/// ★ **값은 실제 선택지여야 한다.** `no_response`·`unknown` 처럼 없는 값을
/// 적어 두면 라벨을 못 찾아 **원시 값이 그대로 화면에 나간다.** 화면에서는
/// 그 답을 안 그려서 아무도 몰랐고, 정리해서 가져가는 글이 「상대방은 뭐라고
/// 하던가요? — no_response」로 드러냈다. `scenario_answers_test` 가 잠근다.
/// `_shared_crisis` 의 필드 하드스톱(`hasCourtDocument`)에 걸리지 않도록
/// 법원 서류는 받지 않은 것으로 둔다.
const Map<String, Object?> completeAnswers = {
  'q_role': 'creditor',
  'q_claim_type': 'loan',
  'q_amount': 50000000, // not-a-legal-number: 테스트 입력값
  'q_debtor_type': 'individual',
  'q_due_date': KstDate(2026, 3, 1),
  'q_evidence_written': ['contract'],
  'q_transfer_record': 'yes',
  'q_demanded': 'certified_mail',
  'q_demand_date': KstDate(2026, 7, 1),
  'q_debtor_response': 'no_contact',
  'q_debtor_address_known': 'yes',
  'q_debtor_area': '서울특별시 종로구',
  'q_debtor_assets': ['none_known'],
  'q_court_document': 'none',
};

/// 답을 미리 심는다. 화면을 12번 탭하지 않고 정리 카드·결과를 볼 수 있다.
void seedAnswers(
  ProviderContainer container,
  String domainId, {
  Map<String, Object?> answers = completeAnswers,
}) {
  final controller = container.read(interviewSessionProvider(domainId).notifier);
  answers.forEach(controller.answer);
}

/// 차단된 문구를 몇 번 보고했는지 세는 리포터.
class RecordingSafetyReporter implements SafetyReporter {
  final List<String> patterns = [];
  final List<String> wheres = [];

  /// 보고에 실린 모든 문자열. 문구 원문이 새지 않았는지 볼 때 쓴다.
  List<String> get everything => [...patterns, ...wheres];

  @override
  void report(List<SafetyViolation> violations, {required SafetyScope scope}) {
    for (final violation in violations) {
      patterns.add(violation.pattern);
      wheres.add(violation.where ?? '');
    }
  }
}

/// 화면에 **실제로 그려진 글자 전부.**
///
/// `find.textContaining` 은 평문 `Text` 만 본다. 밑줄이 섞인 문장은
/// `Text.rich` 라 그 그물을 그냥 빠져나간다 — 금지어를 0건으로 확인하던
/// 검사가 **아무것도 안 보고 통과하게 된다.** 그래서 span 까지 펴서 본다.
List<String> renderedTexts(WidgetTester tester) => [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        text.data ?? text.textSpan?.toPlainText() ?? '',
    ];

/// 이 말이 화면 어디에도 없다. 밑줄이 섞인 문장 안까지 본다.
void expectNoScreenText(WidgetTester tester, String needle, {String? reason}) {
  expect(
    renderedTexts(tester).where((t) => t.contains(needle)),
    isEmpty,
    reason: reason ?? needle,
  );
}

/// 이 말이 화면에 있다. 밑줄이 섞인 문장 안까지 본다.
void expectScreenText(WidgetTester tester, String needle, {String? reason}) {
  expect(
    renderedTexts(tester).where((t) => t.contains(needle)),
    isNotEmpty,
    reason: reason ?? needle,
  );
}
