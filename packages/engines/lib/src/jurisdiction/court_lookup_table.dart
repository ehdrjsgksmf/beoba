/// 주소 → 관할 법원 조회표.
///
/// **표는 코드에 없다.** 데이터로 주입한다. 관할 구역은 자주 바뀌므로
/// 앱 심사 없이 고칠 수 있어야 한다.
abstract interface class CourtLookupTable {
  /// 이 표의 이름. `JurisdictionRule.lookupTable` 과 맞춘다.
  String get name;

  /// 못 찾으면 null.
  String? courtFor(String address);
}

/// 표가 아직 없을 때. 모든 조회가 실패한다.
class EmptyCourtLookupTable implements CourtLookupTable {
  const EmptyCourtLookupTable([this.name = '']);

  @override
  final String name;

  @override
  String? courtFor(String address) => null;
}

/// 주소 문자열에 포함된 지역명으로 찾는다. 긴 키를 먼저 본다
/// ("서울특별시 강남구" 가 "서울특별시" 보다 우선).
class MapCourtLookupTable implements CourtLookupTable {
  MapCourtLookupTable(this.name, Map<String, String> table)
      : _keys = table.keys.toList()..sort((a, b) => b.length.compareTo(a.length)),
        _table = Map.unmodifiable(table);

  @override
  final String name;

  final Map<String, String> _table;
  final List<String> _keys;

  @override
  String? courtFor(String address) {
    for (final key in _keys) {
      if (address.contains(key)) return _table[key];
    }
    return null;
  }
}
