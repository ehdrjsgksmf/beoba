import 'dart:convert';

import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// 앱 번들에 들어 있는 도메인 JSON 을 읽는다.
///
/// 파일은 `domain_data` 패키지가 소유한다. 앱은 경로만 안다.
/// M5 에서 원격 데이터로 갈아끼울 때 이 클래스만 바꾸면 된다.
class AssetDomainSource implements DomainSource {
  const AssetDomainSource({this._bundle});

  static const String basePath = 'packages/domain_data/assets/domains';

  /// 지금 번들에 들어 있는 도메인 목록.
  ///
  /// **여기 있는 것은 id 뿐이다.** 분야 이름·설명·창구는 전부 JSON 안에 있다
  /// (CONTRIBUTING.md — 분야는 코드가 아니라 데이터다). 준비 중 분야도 도메인 파일이므로
  /// `status` 만 보고 목록에 실린다.
  ///
  /// M5 에서 매니페스트로 대체한다. 그러면 이 목록도 사라진다.
  static const List<String> bundledDomainIds = [
    '_shared_crisis',
    'debt_recovery',
    'deposit_return',
    'wage_theft',
    'debt_relief',
    'inheritance',
    'unfair_dismissal',
    'voice_phishing',
    'consumer_withdrawal',
    'installment_purchase',
    'unemployment_benefit',
    'work_injury',
    'secondhand_fraud',
    'child_support',
    'estate_division',
    'jeonse_fraud',
  ];

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  @override
  Future<String> read(String domainId) =>
      _assets.loadString('$basePath/$domainId.json');

  @override
  Future<List<String>> list() async => bundledDomainIds;
}

/// 앱 번들에 들어 있는 공휴일 표를 읽는다.
///
/// **앱은 API 를 부르지 않는다.** 네트워크가 끊긴 사람에게 기한이 안 나오면
/// 안 된다. 커밋된 JSON 이 진짜 데이터다 (`tool/build_holidays.dart` 가 만든다).
class AssetHolidaySource {
  const AssetHolidaySource({this._bundle});

  static const String basePath = 'packages/domain_data/assets/holidays';

  /// 번들에 실린 해. **늘릴 때는 원문과 검산할 규정 판본이 함께 있어야 한다.**
  /// 과거 연도는 대체공휴일 규정이 여러 번 바뀌어 검산할 수 없다.
  static const List<int> bundledYears = [2025, 2026, 2027];

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<List<HolidayCalendar>> load() async {
    final calendars = <HolidayCalendar>[];
    for (final year in bundledYears) {
      final raw = await _assets.loadString('$basePath/$year.json');
      calendars.add(
        HolidayCalendar.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
    }
    return calendars;
  }
}

/// 앱 번들에 들어 있는 용어집을 읽는다.
///
/// **용어는 분야를 가로지른다.** 지급명령은 떼인 돈에도 전세금에도 나온다.
/// 그래서 분야 JSON 이 아니라 한 파일에 둔다.
class AssetGlossarySource {
  const AssetGlossarySource({this._bundle});

  static const String path = 'packages/domain_data/assets/glossary/terms.json';

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<Glossary> load() async => Glossary.fromJson(
        jsonDecode(await _assets.loadString(path)) as Map<String, dynamic>,
      );
}

/// 앱 번들에 들어 있는 분야 묶음 목록을 읽는다.
///
/// **이름도 차례도 코드에 없다.** 묶음을 늘리거나 이름을 고치는 것은 JSON
/// 한 줄이고, 어느 분야가 어느 묶음에 드는지는 **분야가 스스로 적는다**
/// (`Domain.group`).
class AssetGroupSource {
  const AssetGroupSource({this._bundle});

  static const String path = 'packages/domain_data/assets/groups/groups.json';

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<DomainGroupCatalog> load() async => DomainGroupCatalog.fromJson(
        jsonDecode(await _assets.loadString(path)) as Map<String, dynamic>,
      );
}

/// 앱 번들에 들어 있는 관할표를 읽는다.
///
/// **모델을 새로 만들지 않았다.** 조회기가 원하는 것은 `Map<String,String>`
/// 하나뿐이고, 표의 나머지(개정일·시행일·빠진 법원)는 여기서 소화한다.
///
/// ## 시행일이 오늘 이후면 없는 법원이다
///
/// [별표 5] 에 전주가정법원과 세 지원이 적혀 있지만 **2028년 3월 1일에**
/// 생긴다(부칙 제21484호 제1조 제2호). 표에 이름이 있다고 오늘 보낼 수는
/// 없다 — 없는 법원에 서류를 내러 가게 된다.
class AssetCourtSource {
  const AssetCourtSource({this._bundle});

  /// 표 넷. **별표마다 판본이 다르다** — [별표 3]은 2026.3.17.,
  /// [별표 5]는 2026.3.17., [별표 7]은 2023.12.26., [별표 10]은 2024.12.20.
  /// 개정이다.
  static const List<String> paths = [
    'packages/domain_data/assets/courts/family_court.json',
    'packages/domain_data/assets/courts/district_court.json',
    'packages/domain_data/assets/courts/city_county_court.json',
    'packages/domain_data/assets/courts/rehabilitation_court.json',
    'packages/domain_data/assets/courts/labor_commission.json',
  ];

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  /// 표준 지역 이름 목록과 표별 별칭.
  static const String regionsPath =
      'packages/domain_data/assets/courts/regions.json';

  Future<CourtTables> load(KstDate today) async {
    final tables = <CourtLookupTable>[];
    final notYet = <String>[];
    final unmapped = <String>[];

    // **표마다 판본이 달라 같은 땅을 다른 이름으로 부른다.** 노동위원회법
    // 시행령 [별표 1]은 「전남광주통합특별시」라고 적고 법원 표들은 아직
    // 「광주광역시」·「전라남도」라고 적는다. 사용자가 고르는 것은 표준
    // 이름이므로, 표를 읽을 때 별칭 행에 표준 이름을 함께 건다 —
    // 안 그러면 그 행이 아무에게도 안 걸린다(DECISIONS 164번).
    final regions =
        jsonDecode(await _assets.loadString(regionsPath)) as Map<String, dynamic>;
    final aliases = {
      for (final entry in
          ((regions['aliases'] as Map<String, dynamic>?) ?? const {}).entries)
        entry.key: (entry.value as List<dynamic>).cast<String>(),
    };

    for (final path in paths) {
      final raw = jsonDecode(await _assets.loadString(path))
          as Map<String, dynamic>;
      final name = raw['name'] as String;
      final table = <String, String>{};

      for (final entry
          in (raw['entries'] as List).cast<Map<String, dynamic>>()) {
        final court = entry['court'] as String;
        final from = entry['effectiveFrom'] as String?;
        if (from != null && today.toIso().compareTo(from) < 0) {
          notYet.add(court);
          continue;
        }
        for (final district in (entry['districts'] as List).cast<String>()) {
          table[district] = court;
          for (final standard in aliases[district] ?? const <String>[]) {
            table[standard] = court;
          }
        }
      }

      tables.add(MapCourtLookupTable(name, table));
      for (final row in (raw['unmapped'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        unmapped.add(row['court'] as String);
      }
    }

    return CourtTables(
      tables: List.unmodifiable(tables),
      notYetEffective: List.unmodifiable(notYet),
      unmapped: List.unmodifiable(unmapped),
    );
  }
}

/// 표와, 표가 **말하지 않는 것**.
class CourtTables {
  const CourtTables({
    required this.tables,
    required this.notYetEffective,
    required this.unmapped,
  });

  /// 표 셋 — 가정법원 · 지방법원 · 시·군법원.
  ///
  /// **한 표로 합치지 않는다.** 같은 지역이 절차에 따라 다른 법원으로 간다 —
  /// 포천시는 소액·독촉·조정이면 포천시법원이고 그 밖의 소송이면
  /// 의정부지방법원이다(DECISIONS 140번).
  final List<CourtLookupTable> tables;

  /// 표에 있지만 아직 안 생긴 법원. 오늘은 없는 법원이다.
  final List<String> notYetEffective;

  /// [별표 1] 에는 있는데 [별표 5] 에 관할구역이 없는 법원.
  /// **이름을 내지 않는다.**
  final List<String> unmapped;
}

/// 앱 번들에 실린 복지 자료를 읽는다.
///
/// **두 자료를 한 목록으로 합치지 않는다.** 공공은 이름과 복지로 링크까지고
/// 민간은 지원대상·신청방법과 세 축이 있다. 합치면 화면이 둘을 같은 것으로
/// 그리게 되고, 그 순간 「목록뿐인 것」과 「조건이 적힌 것」의 차이가 사라진다.
///
/// **앱은 복지 API 를 부르지 않는다.** 키가 브라우저 번들에 그대로 들어가고
/// 웹에서는 CORS 로 막힌다. `tool/build_welfare.dart` 가 구운 JSON 이 진짜
/// 데이터다 — 법령·공휴일과 같은 규칙이다.
class AssetWelfareSource {
  const AssetWelfareSource({this._bundle});

  static const String publicPath =
      'packages/domain_data/assets/welfare/public_services.json';
  static const String privatePath =
      'packages/domain_data/assets/welfare/private_services.json';

  /// 중앙부처 자료. **CSV 판(`publicPath`)과 같은 제도인데 깊이가 다르다.**
  ///
  /// CSV 에는 이름·요약·링크뿐이고 여기에는 지원대상·선정기준·지원내용과
  /// 근거법령이 있다.
  ///
  /// ★ **CSV 판은 물러났다**(2026-08-24, DECISIONS 235번). 겹치는 362건은
  /// API 가 이긴다 — 상세를 갖고 있기 때문이다. 그런데 **지우지는 않았다.**
  /// CSV 에만 있는 5건이 없어진 제도인지 API 목록이 빠뜨린 것인지 확인할
  /// 방법이 없다. 화면에는 한 줄도 안 그린다.
  static const String centralPath =
      'packages/domain_data/assets/welfare/central.json';

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  Future<PublicWelfareCatalog> loadPublic() async =>
      PublicWelfareCatalog.fromJson(
        jsonDecode(await _assets.loadString(publicPath))
            as Map<String, dynamic>,
      );

  Future<PrivateWelfareCatalog> loadPrivate() async =>
      PrivateWelfareCatalog.fromJson(
        jsonDecode(await _assets.loadString(privatePath))
            as Map<String, dynamic>,
      );

  Future<CentralWelfareCatalog> loadCentral() async =>
      CentralWelfareCatalog.fromJson(
        jsonDecode(await _assets.loadString(centralPath))
            as Map<String, dynamic>,
      );
}
