import 'package:domain_data/domain_data.dart';

/// 복지 자료를 좁히는 데 쓰는 답. **저장하지 않는다** — 화면이 살아 있는
/// 동안만 메모리에 있고 주소에도 안 실린다.
///
/// ## 안 쓰는 것은 묻지 않았다
///
/// 처음 적어 둔 물음은 넷이었다 — 출생연도 · 사는 시·군 · 가구원 수 ·
/// 지금 일하는지. 그런데 자료의 축과 맞대 보니 **둘이 갈 곳이 없었다.**
///
/// ```
/// 출생연도       → 생애주기   (우리가 나이로 옮긴다. 아래 [lifeStagesFor])
/// 사는 시·군     → 없다       지자체 API 를 아직 못 열었다
/// 가구원 수      → 없다       가구상황은 저소득·한부모·장애인 … 머릿수가 아니다
/// 지금 일하는지  → 관심주제   다만 **거르지 않고 순서만 올린다** (아래 참조)
/// ```
///
/// 그래서 시·군과 가구원 수를 빼고, 가구상황은 **자료가 쓰는 여섯 이름을
/// 그대로** 물었다. 못 쓰는 답을 받아 두면 화면에 한 번도 안 나오는 항목이
/// 되고, 이 앱은 그런 자리를 기계로 센다.
class WelfareAnswers {
  const WelfareAnswers({
    this.birthYear,
    this.households = const {},
    this.topics = const {},
    this.onlineOnly = false,
    this.bridge,
    this.work,
  });

  /// 태어난 해. **생년월일이 아니라 연도만** 받는다.
  ///
  /// 달과 날은 생애주기를 가르는 데 필요 없고, 셋을 다 받으면 그 조합이
  /// 사람을 특정한다. 홈에서 「저장하지 않아요」라고 적어 둔 자리다.
  final int? birthYear;

  /// 고른 가구상황. 자료의 이름 그대로. 비어 있으면 **거르지 않는다.**
  final Set<String> households;

  /// 고른 관심주제. 결과 화면에서 사용자가 직접 켠다. 비어 있으면 안 거른다.
  final Set<String> topics;

  /// 집에서 신청할 수 있는 것만 볼 것인가.
  ///
  /// **주민센터에 못 가는 사람에게는 이것이 갈림길이다.** 몸이 아프거나
  /// 일을 못 빼거나 아이를 맡길 데가 없으면 「집에서 되는가」가 다른 어떤
  /// 축보다 실제적이다.
  final bool onlineOnly;

  /// 어느 분야에서 건너왔는가. 그 분야의 다리(근거법령)로 목록을 좁힌다.
  ///
  /// **복지로는 사용자가 왜 왔는지 모른다. 우리는 안다** — 임금이 밀렸다는
  /// 것을 이미 알고 있으니 그 사람에게 걸리는 제도를 먼저 놓을 수 있다.
  /// 다만 좁혀 둔 것을 **풀 수 있어야 한다** — 우리가 고른 것이 그 사람의
  /// 전부는 아니다.
  final WelfareBridge? bridge;

  /// 지금 일하고 있는가. **아직 안 고른 것과 「말 안 함」은 다르다.**
  ///
  /// 하나로 합치면 화면을 열자마자 「말씀드리기 어려워요」가 골라진 것처럼
  /// 보인다. 안 고른 것은 null 이다.
  final WelfareWork? work;

  WelfareAnswers copyWith({
    Object? birthYear = _keep,
    Set<String>? households,
    Set<String>? topics,
    bool? onlineOnly,
    Object? bridge = _keep,
    Object? work = _keep,
  }) =>
      WelfareAnswers(
        birthYear:
            birthYear == _keep ? this.birthYear : birthYear as int?,
        households: households ?? this.households,
        topics: topics ?? this.topics,
        onlineOnly: onlineOnly ?? this.onlineOnly,
        bridge: bridge == _keep ? this.bridge : bridge as WelfareBridge?,
        work: work == _keep ? this.work : work as WelfareWork?,
      );

  static const Object _keep = Object();
}

/// 지금 일하고 있는가에 대한 답.
///
/// **「말씀드리기 어려워요」를 목록에 둔다.** 이 물음은 답하기 껄끄러울 수
/// 있고, 답을 안 해도 목록이 줄지 않는다 — 순서만 못 바꿀 뿐이다.
/// 넘어갈 길이 없으면 사람은 아무거나 누르고, 그러면 답이 아니라 잡음이 된다.
enum WelfareWork { working, notWorking, unsaid }

/// 자료가 쓰는 생애주기 이름. **자료의 글자 그대로** 둔다.
///
/// 「임신 · 출산」은 생애주기에서는 가운뎃점 양옆에 공백이 있고 관심주제에서는
/// 없다. 우리가 다듬으면 이름이 안 맞아 한 건도 안 걸린다.
abstract final class WelfareLifeStage {
  static const String infant = '영유아';
  static const String child = '아동';
  static const String teen = '청소년';
  static const String youth = '청년';
  static const String middle = '중장년';
  static const String senior = '노년';

  /// 나이로는 알 수 없다. **우리가 자동으로 켜지 않는다.**
  static const String pregnancy = '임신 · 출산';
}

/// 법령 이름을 맞대기 좋게 다듬는다. **굽는 쪽과 같은 규칙이어야 한다.**
///
/// 자료의 「아동ㆍ청소년의 성보호에 관한 법률」과 우리 매니페스트의
/// 「아동·청소년의 성보호에 관한 법률」은 가운뎃점이 다르다. 공백과
/// 가운뎃점만 떼면 나머지는 그대로 맞는다.
String normalizeWelfareLawName(String name) =>
    name.replaceAll(RegExp(r'[\s·ㆍ]'), '');

/// 자료가 쓰는 관심주제 중 이 화면이 이름으로 부르는 것.
abstract final class WelfareTopic {
  static const String job = '일자리';
}

/// 태어난 해로 생애주기를 고른다. **이건 자료가 아니라 우리 판단이다.**
///
/// ## 왜 경계를 겹쳐 두는가
///
/// 자료에는 「청년이 몇 살까지인가」가 안 적혀 있다. 제도마다 다르기도 하다 —
/// 어떤 사업은 34세까지, 어떤 사업은 39세까지를 청년으로 본다. 우리가 한 줄로
/// 자르면 경계에 선 사람에게서 **볼 수 있었던 제도가 사라진다.**
///
/// 그래서 경계를 겹친다. 넓게 고르면 안 맞는 것이 섞여 보이고, 좁게 고르면
/// 맞는 것이 안 보인다. **틀리는 방향이 비대칭이면 손해가 작은 쪽으로 간다**
/// (DECISIONS 168번).
///
/// ```
///  0~6   영유아
///  5~13  아동        (5·6 은 영유아와 겹친다)
/// 12~19  청소년      (12·13 은 아동과 겹친다)
/// 18~39  청년        (18·19 는 청소년과 겹친다)
/// 35~64  중장년      (35~39 는 청년과 겹친다)
/// 60~    노년        (60~64 는 중장년과 겹친다)
/// ```
///
/// [WelfareLifeStage.pregnancy] 는 여기서 절대 안 나온다. 나이로 알 수 없는
/// 것을 나이로 짐작하면 그건 우리가 지어낸 것이다.
///
/// 나이는 **연 나이**다 (올해 − 태어난 해). 달과 날을 안 받았으므로 만 나이를
/// 셀 수 없고, 셀 수 없는 것을 센 척하지 않는다.
Set<String> lifeStagesFor(int birthYear, KstDate today) {
  final age = today.year - birthYear;
  return {
    // not-a-legal-number: 생애주기 경계. 법률 수치가 아니라 우리가 정한 눈금이다.
    if (age <= 6) WelfareLifeStage.infant,
    // not-a-legal-number: 위와 같다.
    if (age >= 5 && age <= 13) WelfareLifeStage.child,
    // not-a-legal-number: 위와 같다.
    if (age >= 12 && age <= 19) WelfareLifeStage.teen,
    // not-a-legal-number: 위와 같다.
    if (age >= 18 && age <= 39) WelfareLifeStage.youth,
    // not-a-legal-number: 위와 같다.
    if (age >= 35 && age <= 64) WelfareLifeStage.middle,
    // not-a-legal-number: 위와 같다.
    if (age >= 60) WelfareLifeStage.senior,
  };
}

/// 좁힌 결과. **두 층으로 갈라서 돌려준다.**
///
/// 상세를 받은 것과 못 받은 것을 한 목록에 섞으면 화면이 둘을 같은 것으로
/// 그리게 된다. 못 받은 것은 **지운 것이 아니라 아직 안 받은 것**이라
/// 이름과 링크까지는 반드시 나가야 하고, 그 사실이 보여야 한다.
class WelfareMatch {
  const WelfareMatch({
    required this.detailed,
    required this.listOnly,
    required this.total,
    required this.lifeStages,
    required this.topicCounts,
    required this.onlineCount,
    required this.onAxesCount,
    this.folded = const [],
    this.bridgeCount,
  });

  /// 지원대상·선정기준·지원내용까지 있는 것.
  final List<CentralWelfareService> detailed;

  /// 이름·요약·복지로 링크까지만 있는 것.
  final List<CentralWelfareService> listOnly;

  /// 자료 전체 건수. **무엇을 세었는지 함께 낸다.**
  final int total;

  /// 우리가 고른 생애주기. 화면이 「이렇게 봤어요」라고 말할 수 있어야 한다.
  final Set<String> lifeStages;

  /// 다리로 좁혀서 남은 건수. 다리가 없으면 null.
  ///
  /// **좁혀 둔 것을 풀 수 있어야 한다.** 「전체 461건 중 18건만 보고 있어요」를
  /// 화면이 말할 수 있어야 푸는 버튼이 뜻을 가진다.
  final int? bridgeCount;

  /// 주제 이름 → 그 주제로 좁혔을 때 남는 건수.
  ///
  /// **0건짜리 칩을 만들지 않는다.** 눌러도 아무것도 안 나오는 칸은
  /// 고를 것이 아니라 헛걸음이다. 그리고 칩마다 건수를 함께 낸다 —
  /// **그 주제가 달린 제도가 몇 개인가**다. 몇 개를 골라도 참이다. 「누르면
  /// 얼마나 줄어드는지」가 아니다 — 주제는 둘째부터 넓힌다(DECISIONS 289번).
  final Map<String, int> topicCounts;

  /// 걸린 것 중 집에서 신청할 수 있는 건수. **토글을 켜기 전에도 보인다.**
  final int onlineCount;

  /// 온라인 토글을 빼고 축으로만 좁혔을 때의 건수.
  ///
  /// **두 숫자를 나란히 내야 12%라는 사실이 보인다.** 켠 뒤의 건수만
  /// 적으면 걷어낸 쪽이 얼마인지 알 수 없다.
  final int onAxesCount;

  /// **안 고르신 가구상황에 걸리는 것.** 지우지 않고 접어 둔다(DECISIONS 287번).
  ///
  /// 장애인이 아닌 분에게 장애 제도가 같이 나왔다. 그런데 조건을 잘못
  /// 고르셨을 수도 있다 — **성가신 것과 못 받는 것 중에 못 받는 쪽이 훨씬
  /// 나쁘다.** 그래서 먼저 보이는 목록에서만 빼고, 몇 건인지와 함께 접어 둔다.
  /// 상세가 있는 것이 앞, 목록뿐인 것이 뒤다.
  final List<CentralWelfareService> folded;

  int get matched => detailed.length + listOnly.length;
}

/// 답으로 자료를 좁힌다.
///
/// ## 「지금 일하고 있는지」는 거르는 데 안 쓴다
///
/// 일을 안 하고 있다고 해서 관심주제를 「일자리」로 좁히면, 그 사람에게
/// **주거 · 서민금융 · 생활지원이 통째로 안 보인다.** 일이 끊긴 사람에게
/// 제일 급한 것이 그 셋인데 말이다.
///
/// 그래서 거르지 않고 **순서만 올린다.** 안 보이게 하는 것과 늦게 보이게
/// 하는 것은 다르다.
WelfareMatch matchWelfare({
  required CentralWelfareCatalog catalog,
  required WelfareAnswers answers,
  required KstDate today,
}) {
  final stages = answers.birthYear == null
      ? const <String>{}
      : lifeStagesFor(answers.birthYear!, today);

  // **다리가 먼저다.** 축은 그 안에서 다시 좁힌다.
  //
  // 잇는 기준은 하나뿐이다 — 제도 쪽 근거법령의 이름이 이 분야가 적어 둔
  // 이름과 맞는가. 주제가 비슷해 보인다는 이유로는 안 잇는다.
  final bridgeLaws = <String>{
    for (final law in answers.bridge?.laws ?? const <String>[])
      normalizeWelfareLawName(law),
  };
  bool onBridge(CentralWelfareService service) =>
      bridgeLaws.isEmpty ||
      service.laws.any((law) => bridgeLaws.contains(normalizeWelfareLawName(law)));

  final pool = [
    for (final service in catalog.services)
      if (onBridge(service)) service,
  ];

  // ★ **가구상황은 거르지 않고 가른다.** 기관이 가구상황을 적어 둔 제도는
  // 고르신 것에 걸릴 때만 먼저 보이고, 안 걸리면 접어 둔다. 아무것도 안 고르셨으면
  // 가구상황이 적힌 제도는 전부 접힌다 — 장애인이 아닌 분에게 장애 제도가 같이
  // 나오던 자리다(DECISIONS 287번). 기관이 안 적은 제도(빈 축)는 늘 먼저 보인다.
  bool householdPicked(CentralWelfareService service) =>
      service.households.isEmpty ||
      service.households.any(answers.households.contains);

  bool onAxes(CentralWelfareService service) =>
      service.matches(lifeStages: stages, topics: answers.topics) &&
      householdPicked(service);

  // **주제 칩의 건수는 주제를 빼고 센다.** 이미 고른 주제로 좁힌 뒤에 세면
  // 안 고른 주제가 전부 0건이 되어 칩이 통째로 사라진다.
  final onOtherAxes = [
    for (final service in pool)
      if (service.matches(lifeStages: stages) && householdPicked(service))
        service,
  ];
  final topicCounts = <String, int>{};
  for (final service in onOtherAxes) {
    if (answers.onlineOnly && !service.onlineApply) continue;
    for (final topic in service.topics) {
      topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
    }
  }

  final onAxesOnly = [
    for (final service in pool)
      if (onAxes(service)) service,
  ];
  final hits = [
    for (final service in onAxesOnly)
      if (!answers.onlineOnly || service.onlineApply) service,
  ];

  // 일이 끊긴 분에게는 일자리 제도를 위로. 거르는 것이 아니다.
  //
  // 그다음은 **많이 찾아본 순**이다(`views`). 기준연도는 대부분 2025~2026 이라
  // 「최신순」으로는 갈리지 않고, 이름 순은 아무 뜻이 없다.
  // ★ 무엇으로 세웠는지는 화면이 말한다.
  final liftJobs = answers.work == WelfareWork.notWorking;
  int order(CentralWelfareService a, CentralWelfareService b) {
    if (liftJobs) {
      final aJob = a.topics.contains(WelfareTopic.job) ? 0 : 1;
      final bJob = b.topics.contains(WelfareTopic.job) ? 0 : 1;
      if (aJob != bJob) return aJob - bJob;
    }
    if (a.views != b.views) return b.views - a.views;
    return a.name.compareTo(b.name);
  }

  final folded = [
    for (final service in pool)
      if (service.matches(lifeStages: stages, topics: answers.topics) &&
          !householdPicked(service) &&
          (!answers.onlineOnly || service.onlineApply))
        service,
  ];

  return WelfareMatch(
    detailed: [
      for (final s in hits)
        if (s.detailFetched) s,
    ]..sort(order),
    listOnly: [
      for (final s in hits)
        if (!s.detailFetched) s,
    ]..sort(order),
    total: catalog.services.length,
    lifeStages: stages,
    topicCounts: topicCounts,
    onlineCount: [
      for (final service in onAxesOnly)
        if (service.onlineApply) service,
    ].length,
    onAxesCount: onAxesOnly.length,
    folded: [
      ...[for (final s in folded) if (s.detailFetched) s]..sort(order),
      ...[for (final s in folded) if (!s.detailFetched) s]..sort(order),
    ],
    bridgeCount: bridgeLaws.isEmpty ? null : pool.length,
  );
}
