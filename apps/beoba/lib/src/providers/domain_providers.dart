import 'dart:async';

import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/asset_domain_source.dart';
import '../plain/plain_mode_store.dart';

/// 앱이 쓰는 시계. `DateTime.now()` 는 이 뒤에만 있다 (CONTRIBUTING.md 규칙 2).
///
/// 테스트는 `overrideWithValue(FixedKstClock(...))` 로 갈아끼운다.
final clockProvider = Provider<KstClock>((ref) => const SystemKstClock());

/// **오늘. 앱 전체가 이 하나를 본다.**
///
/// 예전에는 화면과 계산이 각자 `clock.today()` 를 불렀다. `SystemKstClock` 은
/// 부를 때마다 `DateTime.now()` 를 읽으므로, 앱을 열어 둔 채 자정을 넘기면
/// **홈은 어제, 계산은 오늘**이 된다. 「오늘까지입니다」라고 쓰인 화면이 어제
/// 기준으로 계산된 상태 — 기한을 다루는 앱에서 제일 하면 안 되는 어긋남이다.
///
/// 그래서 값을 한 번 고정해 내려주고 **자정에 스스로 다시 센다.**
class TodayNotifier extends Notifier<KstDate> {
  Timer? _timer;

  @override
  KstDate build() {
    final clock = ref.watch(clockProvider);
    ref.onDispose(() => _timer?.cancel());
    _scheduleMidnight(clock);
    return clock.today();
  }

  /// 다음 KST 자정에 스스로를 무효화한다.
  ///
  /// 고정 시계(테스트)는 날짜가 안 바뀌므로 타이머를 걸지 않는다. 걸면 위젯
  /// 테스트가 끝나지 않은 타이머를 물고 실패한다.
  void _scheduleMidnight(KstClock clock) {
    _timer?.cancel();
    if (clock is! SystemKstClock) return;

    // KST 는 UTC+9. 지금의 KST 벽시계에서 다음 자정까지 남은 시간.
    const kstOffset = Duration(hours: 9);
    final kstNow = clock.nowUtc().add(kstOffset);
    final nextMidnight = DateTime.utc(
      kstNow.year,
      kstNow.month,
      kstNow.day,
    ).add(const Duration(days: 1));
    final wait = nextMidnight.difference(kstNow) + const Duration(seconds: 1);

    _timer = Timer(wait, ref.invalidateSelf);
  }
}

final todayProvider =
    NotifierProvider<TodayNotifier, KstDate>(TodayNotifier.new);

/// 앱이 실제로 쓰는 시계. **`today()` 가 [todayProvider] 에 못박혀 있다.**
///
/// 화면도 엔진도 이것만 본다. `clockProvider` 를 직접 보면 자정을 사이에 두고
/// 서로 다른 날을 보게 된다.
final appClockProvider = Provider<KstClock>(
  (ref) => _PinnedClock(ref.watch(clockProvider), ref.watch(todayProvider)),
);

class _PinnedClock implements KstClock {
  const _PinnedClock(this._inner, this._today);

  final KstClock _inner;
  final KstDate _today;

  @override
  KstDate today() => _today;

  @override
  DateTime nowUtc() => _inner.nowUtc();

  @override
  KstDate localToday() => _inner.localToday();
}

/// 도메인 JSON 을 어디서 읽는가. M5 에서 원격 소스로 갈아끼운다.
final domainSourceProvider =
    Provider<DomainSource>((ref) => const AssetDomainSource());

/// ① 위기 · ② 방어 데이터를 담은 공용 도메인의 id.
const String kCrisisDomainId = '_shared_crisis';

/// M1 이 다루는 유일한 분야.
const String kDebtRecoveryDomainId = 'debt_recovery';

/// 로드가 끝난 도메인 묶음.
///
/// 화면은 개별 도메인을 따로 기다리지 않는다. 하나라도 못 읽으면 아무것도 못 하므로
/// 한 번에 받아 한 번에 실패한다.
class DomainBundle {
  const DomainBundle({
    required this.domains,
    required this.crisis,
    required this.reports,
    required this.holidays,
    required this.glossary,
    required this.courts,
    this.groupCatalog = const DomainGroupCatalog(),
  });

  /// 분야 도메인. `_shared_crisis` 는 여기 없다.
  final Map<String, Domain> domains;

  /// 공용 위기·방어 데이터. 상한 규칙과 창구 원본이 여기에 있다.
  final Domain crisis;

  /// 로더가 무엇을 버렸는지. 디버그 화면과 테스트에서 본다.
  final Map<String, LoadReport> reports;

  /// 쉬는 날 표. **민법 제161조가 이걸 본다.**
  ///
  /// 표에 없는 해는 토·일만 민다. 그건 실패가 아니라 정해 둔 동작이고,
  /// 화면이 어디까지 반영했는지 말한다 — 공휴일을 몰라서 덜 미는 쪽은
  /// 언제나 진짜 기한보다 앞이라 늦지 않는다.
  final TableHolidayRule holidays;

  /// 용어 풀이. **분야를 가로지르므로 도메인 밖에 산다.**
  ///
  /// 화면 문자열을 이 키로 훑지 않는다. 문장에 박힌 `[[낱말]]` 만 찾아본다.
  final Glossary glossary;

  /// 관할표와, 표가 말하지 않는 것.
  final CourtTables courts;

  /// 분야 묶음. **이름과 차례만 들어 있다.** 어느 분야가 어디 드는지는
  /// 분야가 적는다(`Domain.group`).
  final DomainGroupCatalog groupCatalog;

  /// 화면에 실제로 서는 묶음. **분야가 0개인 묶음은 빠진다.**
  ///
  /// ★ **눌러서 0건이 되는 입구는 세우지 않는다**(DECISIONS 228번). 여덟을
  /// 미리 적어 두었지만 지금 분야가 있는 것은 다섯뿐이고, 나머지 셋은 그
  /// 분야가 들어오는 날 저절로 선다 — 그때 코드를 고칠 일이 없다.
  ///
  /// 묶음이 없는 분야는 **사라지지 않는다.** 마지막에 묶음 없이 나온다 —
  /// 조용히 없어지는 쪽이 훨씬 나쁘다.
  List<(DomainGroup?, List<Domain>)> get grouped {
    final byGroup = <String, List<Domain>>{};
    final loose = <Domain>[];
    for (final domain in selectable) {
      final id = domain.group;
      if (id == null || groupCatalog.byId(id) == null) {
        loose.add(domain);
      } else {
        (byGroup[id] ??= []).add(domain);
      }
    }
    return [
      for (final group in groupCatalog.inOrder)
        if (byGroup[group.id] case final list?) (group, list),
      if (loose.isNotEmpty) (null, loose),
    ];
  }

  /// 한 묶음 안의 분야. `homeOrder` 순이다.
  List<Domain> domainsOf(String groupId) => [
        for (final domain in selectable)
          if (domain.group == groupId) domain,
      ];

  Domain byId(String id) {
    final domain = domains[id];
    if (domain == null) {
      throw ArgumentError.value(id, 'id', '로드되지 않은 도메인입니다');
    }
    return domain;
  }

  /// 지금 인터뷰를 열 수 있는 분야. **`homeOrder` 순이다.**
  ///
  /// 열 개가 되면 순서가 곧 안내다. 기준은 하나 — **되돌릴 수 없는 것이
  /// 위로**(DECISIONS 196번). 순서는 데이터가 정하고 코드는 정렬만 한다.
  List<Domain> get selectable => _byHomeOrder([
        for (final domain in domains.values)
          if (domain.status == DomainStatus.active ||
              domain.status == DomainStatus.beta)
            domain,
      ]);

  /// 아직 만들지 않았지만 **목록에는 보이는** 분야.
  ///
  /// 이름도 설명도 창구도 전부 도메인 JSON 에서 온다. 코드에는 id 조차 없다.
  List<Domain> get upcoming => _byHomeOrder([
        for (final domain in domains.values)
          if (domain.status == DomainStatus.comingSoon) domain,
      ]);

  /// 같은 자리면 id 로 가른다 — **순서가 파일 읽는 차례에 기대지 않게.**
  static List<Domain> _byHomeOrder(List<Domain> list) => list
    ..sort((a, b) {
      final byOrder = a.homeOrder.compareTo(b.homeOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });

  /// 이 분야가 연결하라는 공적 창구들. 원본은 `_shared_crisis` 가 소유한다.
  List<PublicChannel> channelsOf(String domainId) {
    final domain = domains[domainId];
    if (domain == null) return const [];

    final byId = {
      for (final channel in crisis.resolvedChannels) channel.id: channel,
    };
    return [
      for (final entry in domain.publicChannels)
        if (byId[entry.id] != null) byId[entry.id]!,
    ];
  }

  /// 쉬운 말 한 벌을 끼운 묶음. **한 벌이 없는 분야는 그대로 돌아온다.**
  ///
  /// 공용 위기 데이터(`crisis`)도 함께 바꾼다 — 위기 안내가 어려운 말로
  /// 남으면 제일 급한 자리만 안 바뀐 채로 남는다.
  DomainBundle inPlainKorean() => DomainBundle(
        domains: {
          for (final entry in domains.entries)
            entry.key: entry.value.inPlainKorean(),
        },
        crisis: crisis.inPlainKorean(),
        reports: reports,
        holidays: holidays,
        glossary: glossary,
        courts: courts,
        groupCatalog: groupCatalog,
      );

  /// 하드스톱을 분야와 공용 위기 데이터 양쪽에서 찾는다.
  ///
  /// 형사·불법도박 같은 것은 분야마다 적지 않고 `_shared_crisis` 한 곳에 있다.
  HardStop? hardStopById(String domainId, String stopId) {
    for (final domain in [domains[domainId], crisis]) {
      if (domain == null) continue;
      for (final stop in domain.hardStops) {
        if (stop.id == stopId) return stop;
      }
    }
    return null;
  }

  /// 하드스톱이 연결하라는 공적 창구들. 원본은 `_shared_crisis` 가 소유한다.
  List<PublicChannel> channelsFor(HardStop stop) {
    final byId = {
      for (final channel in crisis.resolvedChannels) channel.id: channel,
    };
    return [
      for (final id in stop.channels)
        if (byId[id] != null) byId[id]!,
    ];
  }
}

/// 앱 시작 시 한 번 도는 부트스트랩.
///
/// `VerificationPolicy.keepAll` 을 **절대 쓰지 않는다.** 기본값이 `dropUnverified`
/// 이므로 검수되지 않은 법률 정보는 여기서 이미 걸러진다 (DECISIONS.md 6번).
final domainBundleProvider = FutureProvider<DomainBundle>((ref) async {
  final source = ref.watch(domainSourceProvider);
  final today = ref.watch(todayProvider);

  final reports = <String, LoadReport>{};
  Future<Domain> load(String id) async {
    final loader = DomainLoader(today: today);
    final domain = loader.loadFromJsonString(await source.read(id));
    reports[id] = loader.lastReport;
    return domain;
  }

  final crisis = await load(kCrisisDomainId);
  final ids = (await source.list())
      .where((id) => id != kCrisisDomainId)
      .toList()
    ..sort();

  final domains = <String, Domain>{};
  for (final id in ids) {
    domains[id] = await load(id);
  }

  // 쉬는 날 표도 여기서 한 번에 받는다. 하나라도 못 읽으면 아무것도 못 한다.
  final holidays = TableHolidayRule(await const AssetHolidaySource().load());
  final glossary = await const AssetGlossarySource().load();
  final courts = await const AssetCourtSource().load(today);
  final groupCatalog = await const AssetGroupSource().load();

  return DomainBundle(
    domains: domains,
    crisis: crisis,
    reports: reports,
    holidays: holidays,
    glossary: glossary,
    courts: courts,
    groupCatalog: groupCatalog,
  );
});

/// 쉬운 말로 볼 것인가.
///
/// ★ **기기 언어로 자동으로 켜지 않는다.** 한국어 기기를 쓰는 외국인이 많고
/// 반대도 많다. 자동으로 고르면 둘 다 틀린다 — 사람이 스스로 켠다.
///
/// ## 2026-09-16 — 기억한다 (DECISIONS 289번)
///
/// 고른 것을 [PlainModeStore] 에 남기고, 앱을 열면 읽어 온다. 읽는 동안은
/// 꺼진 채로 그린다 — **읽기 전에 사람이 스위치를 누르면 그쪽이 이긴다.**
class PlainModeNotifier extends Notifier<bool> {
  bool _touched = false;

  @override
  bool build() {
    ref.read(plainModeSavedProvider.future).then((saved) {
      if (!ref.mounted || _touched || saved == null) return;
      state = saved;
    });
    return false;
  }

  void toggle() => set(!state);

  /// 고르고 기억한다. 첫 실행 물음의 답도 이 길로 온다.
  void set(bool on) {
    _touched = true;
    state = on;
    // 못 남겨도 지금 화면은 바뀐다. 다음에 여실 때 다시 물을 뿐이다.
    ref.read(plainModeStoreProvider).write(on).catchError((Object _) {});
  }
}

/// 켜짐/꺼짐을 남기는 자리.
final plainModeStoreProvider =
    Provider<PlainModeStore>((_) => const PrefsPlainModeStore());

/// **앱을 열 때 읽은 값.** 한 번만 읽는다 — 아직 한 번도 안 고르셨으면 null.
///
/// 첫 실행 물음을 띄울지가 이 값으로 정해진다. 이번 실행 중에 고르셔도 이 값은
/// 안 바뀐다 — 「이번에 처음 물었다」를 알아야 집계 동의를 같은 실행에 겹쳐
/// 띄우지 않는다.
///
/// ★ 못 읽으면(저장 공간이 막힌 브라우저 등) **안 고른 것으로 본다.** 화면이
/// 멈추는 것보다 물음이 한 번 더 뜨는 쪽이 낫다.
final plainModeSavedProvider = FutureProvider<bool?>((ref) async {
  try {
    return await ref.read(plainModeStoreProvider).read();
  } on Object {
    return null;
  }
});

/// 켜고 끄는 스위치 하나. 화면 어디에서도 이 값을 읽지 않는다 —
/// [requireBundle] 이 대신 읽고 **분야를 통째로 갈아끼운다.**
final plainModeProvider =
    NotifierProvider<PlainModeNotifier, bool>(PlainModeNotifier.new);

/// 지금 화면이 보는 분야 묶음. **쉬운 말이 켜져 있으면 갈아끼운 쪽이다.**
///
/// ★ **화면을 하나도 안 고치려고 여기서 바꾼다.** 문장마다 「쉬운 말이면
/// 이걸, 아니면 저걸」을 쓰면 새 화면이 생길 때마다 한 자리씩 빠뜨리고,
/// 빠뜨린 자리는 쉬운 말 모드에서만 보여서 아무도 못 본다.
///
/// 조문 원문은 이 길로도 안 바뀐다 — 바꿀 수 있는 자리를 `kPlainTargets` 가
/// 정하고 `SchemaValidator` 가 그 밖의 키를 막는다.
final shownBundleProvider = Provider<DomainBundle>((ref) {
  final bundle = ref.watch(domainBundleProvider).requireValue;
  if (!ref.watch(plainModeProvider)) return bundle;
  return bundle.inPlainKorean();
});

/// 부트스트랩이 끝난 뒤에만 부른다.
///
/// 라우터가 로딩·오류를 앞에서 처리하므로 화면에 도달했다면 값이 있다.
DomainBundle requireBundle(Ref ref) => ref.watch(shownBundleProvider);
