import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('JurisdictionEngine', () {
    final table = MapCourtLookupTable('court_by_district', {
      '서울특별시 강남구': '서울중앙지방법원',
      '서울특별시': '서울중앙지방법원',
      '수원시': '수원지방법원',
    });

    test('주소로 법원을 찾는다', () {
      final engine = JurisdictionEngine(tables: [table]);
      final domain = domainFixture(jurisdiction: [jurisdictionFixture(id: 'jr')]);
      final results = engine.compute(
        domain,
        const CaseFacts({'debtorAddress': '수원시 팔달구 1'}),
      );
      expect(results.single.status, JurisdictionStatus.resolved);
      expect(results.single.court, '수원지방법원');
    });

    test('더 구체적인 키를 먼저 본다', () {
      final engine = JurisdictionEngine(tables: [table]);
      expect(
        engine
            .computeOne(
              jurisdictionFixture(id: 'jr'),
              const CaseFacts({'debtorAddress': '서울특별시 강남구 테헤란로 1'}),
            )
            .court,
        '서울중앙지방법원',
      );
    });

    test('주소가 없으면 missingInput — 추측하지 않는다', () {
      final engine = JurisdictionEngine(tables: [table]);
      final result = engine.computeOne(
        jurisdictionFixture(id: 'jr'),
        const CaseFacts(),
      );
      expect(result.status, JurisdictionStatus.missingInput);
      expect(result.court, isNull);
    });

    test('조회표가 없으면 tableUnavailable — 그대로 알린다', () {
      const engine = JurisdictionEngine();
      final result = engine.computeOne(
        jurisdictionFixture(id: 'jr'),
        const CaseFacts({'debtorAddress': '수원시'}),
      );
      expect(result.status, JurisdictionStatus.tableUnavailable);
    });

    test('표에 없는 주소는 missingInput', () {
      final engine = JurisdictionEngine(tables: [table]);
      final result = engine.computeOne(
        jurisdictionFixture(id: 'jr'),
        const CaseFacts({'debtorAddress': '제주특별자치도'}),
      );
      expect(result.status, JurisdictionStatus.missingInput);
    });
  });

  group('DocumentEngine', () {
    const engine = DocumentEngine();

    test('중요도 순으로 정렬하되 같은 등급은 정의 순서를 지킨다', () {
      final domain = domainFixture(
        documents: [
          documentFixture(id: 'doc_medium', importance: Importance.medium),
          documentFixture(id: 'doc_high_1', importance: Importance.high),
          documentFixture(id: 'doc_low', importance: Importance.low),
          documentFixture(id: 'doc_high_2', importance: Importance.high),
        ],
      );
      final results = engine.compute(domain, const CaseFacts());
      expect(results.map((d) => d.id), [
        'doc_high_1',
        'doc_high_2',
        'doc_medium',
        'doc_low',
      ]);
    });

    test('showIf 로 거른다', () {
      final domain = domainFixture(
        documents: [
          documentFixture(id: 'doc_always'),
          documentFixture(
            id: 'doc_invoice',
            showIf: {
              'in': [
                {'var': 'claimType'},
                ['goods', 'construction'],
              ],
            },
          ),
        ],
      );
      expect(
        engine
            .compute(domain, const CaseFacts({'claimType': 'loan'}))
            .map((d) => d.id),
        ['doc_always'],
      );
      expect(
        engine
            .compute(domain, const CaseFacts({'claimType': 'goods'}))
            .map((d) => d.id),
        ['doc_always', 'doc_invoice'],
      );
    });

    test('검증 상태가 결과에 실린다 — 배지를 달아야 하기 때문', () {
      final domain = domainFixture(documents: [documentFixture(id: 'doc')]);
      expect(
        engine.compute(domain, const CaseFacts()).single.verification,
        VerificationStatus.verified,
      );
    });
  });
}
