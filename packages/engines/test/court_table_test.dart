import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/asset_paths.dart';

/// 관할표 셋. **매칭 실패는 비운다 — 넘겨짚지 않는다.**
///
/// 사람이 그림으로 본 별표와 대조한 것을 여기 박아 둔다. 표를 다시 만들 때
/// 이 다섯이 먼저 깨진다.
void main() {
  Map<String, String> tableOf(String file) {
    final path = '${domainAssetsDir().parent.path}/courts/$file';
    final raw = jsonDecode(File(path).readAsStringSync())
        as Map<String, dynamic>;
    final out = <String, String>{};
    for (final entry in (raw['entries'] as List).cast<Map<String, dynamic>>()) {
      for (final district in (entry['districts'] as List).cast<String>()) {
        out[district] = entry['court'] as String;
      }
    }
    return out;
  }

  Map<String, dynamic> rawOf(String file) =>
      jsonDecode(File('${domainAssetsDir().parent.path}/courts/$file')
          .readAsStringSync()) as Map<String, dynamic>;

  final district = tableOf('district_court.json');
  final cityCounty = tableOf('city_county_court.json');

  group('★ 사람이 그림으로 본 것과 대조', () {
    test('경기도 광주시 — 소송은 성남지원, 소액·독촉은 광주시법원', () {
      expect(district['경기도 광주시'], '수원지방법원 성남지원');
      expect(cityCounty['경기도 광주시'], '광주시법원');
    });

    test('광주광역시 — 광주지방법원. 시·군법원은 없다', () {
      expect(district['광주광역시'], '광주지방법원');
      expect(cityCounty['광주광역시'], isNull);
    });

    test('대구광역시 달서구 — 서부지원', () {
      expect(district['대구광역시 달서구'], '대구지방법원 서부지원');
    });

    test('★ 인천광역시 강화군 — 시·군법원은 나오고 지방법원은 빈다', () {
      // [별표 1]에는 인천지방법원이 있는데 [별표 3]에 관할구역이 없다.
      // 파일 문제로 보여 확인을 기다린다. **그때까지 짓지 않는다.**
      expect(cityCounty['인천광역시 강화군'], '강화군법원');
      expect(district['인천광역시 강화군'], isNull);
      expect(district['인천광역시'], isNull);
      expect(district['부천시'], isNull);
    });

    test('포천시 — 소액·독촉이면 포천시법원이지 의정부가 아니다', () {
      // 동네 법원이라 훨씬 가깝다. 모르면 먼 데를 간다.
      expect(cityCounty['포천시'], '포천시법원');
      expect(district['포천시'], '의정부지방법원');
    });
  });

  group('이름이 겹치는 곳은 시·도를 붙여야만 맞는다', () {
    test('고성군은 강원도와 경상남도에 둘 다 있다', () {
      expect(district['강원도 고성군'], '춘천지방법원 속초지원');
      expect(district['경상남도 고성군'], '창원지방법원 통영지원');
      expect(cityCounty['강원도 고성군'], '고성군법원');
      expect(cityCounty['경상남도 고성군'], '고성군법원');
      // 맨 이름으로는 안 맞는다. **아무나 맞으면 안 된다.**
      expect(district['고성군'], isNull);
      expect(cityCounty['고성군'], isNull);
    });

    test('광주시도 시·도가 있어야 갈린다', () {
      expect(district['광주시'], isNull);
    });
  });

  group('별표마다 판본이 따로다', () {
    test('[별표 3]은 2026-03-17, [별표 7]은 2023-12-26', () {
      expect(rawOf('district_court.json')['revisedAt'], '2026-03-17');
      expect(rawOf('city_county_court.json')['revisedAt'], '2023-12-26');
      expect(rawOf('family_court.json')['revisedAt'], '2026-03-17');
    });

    test('화성시법원은 이 판본 표에 없다', () {
      // 부칙 제1조 제3호가 2032.3.1. 로 두는데, 받은 [별표 7]에는 그 행이
      // 없다. **없는 것을 지어내지 않는다.** 화성시는 오산시법원이 맡는다.
      expect(cityCounty.values.any((c) => c.contains('화성')), isFalse);
      expect(cityCounty['화성시'], '오산시법원');
    });
  });

  test('표 크기 — 지역 키가 줄면 누군가 답을 못 받는다', () {
    expect(district, hasLength(greaterThanOrEqualTo(209)));
    expect(cityCounty, hasLength(greaterThanOrEqualTo(202)));
  });
}
