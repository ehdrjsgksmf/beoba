import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/asset_paths.dart';

/// 3,000만원과 3,000만 10원은 **밟는 절차가 다르다.** 인지대 몇 백 원보다 이게
/// 훨씬 크다. 1,500원 때문에 더 복잡한 절차로 가야 한다는 걸 모르고 진행하면
/// 나중에 되돌릴 수 없다.
///
/// **경계값은 코드에 없다.** `showIf` 에서 읽고, 얼마나 가까워야 가까운 것인지는
/// `nearMissWithin` 으로 분야가 선언한다.
void main() {
  const checker = NearMissChecker();
  final domain = DomainLoader(policy: VerificationPolicy.keepAll)
      .loadFromJsonString(domainFile('debt_recovery').readAsStringSync());

  List<NearMiss> check(int amount) =>
      checker.check(domain, CaseFacts({'claimAmount': amount}));

  group('아슬아슬하게 넘겼을 때만 알린다', () {
    test('1,500원 넘겼으면 알린다', () {
      final hits = check(30001500); // not-a-legal-number: 테스트 입력값
      expect(hits, hasLength(1));
      expect(hits.first.procedureId, 'proc_small_claim');
      expect(hits.first.excess, 1500);
    });

    test('경계는 showIf 에서 읽는다', () {
      // 코드가 30,000,000 을 들고 있지 않다는 증거다.
      expect(check(30001500).first.threshold, 30000000);
    });

    test('딱 경계면 쓸 수 있으니 알리지 않는다', () {
      expect(check(30000000), isEmpty);
    });

    test('한참 넘겼으면 알리지 않는다', () {
      // 1억원 청구에 "3,000만원을 7,000만원 넘었습니다" 는 도움이 아니라 소음이다.
      expect(check(100000000), isEmpty); // not-a-legal-number: 테스트 입력값
    });

    test('선언한 범위의 끝까지는 알린다', () {
      expect(check(31000000), hasLength(1)); // not-a-legal-number: 테스트 입력값
      expect(check(31000001), isEmpty); // not-a-legal-number: 테스트 입력값
    });

    test('한참 못 미치면 그냥 쓸 수 있다', () {
      expect(check(5000000), isEmpty); // not-a-legal-number: 테스트 입력값
    });
  });

  group('선언하지 않은 절차는 조용하다', () {
    test('nearMissWithin 이 없으면 알리지 않는다', () {
      // 켜는 것이 선택이다. 모든 경계를 다 알리면 소음이 된다.
      final declared =
          domain.procedures.where((p) => p.nearMissWithin != null).toList();
      expect(declared, hasLength(1), reason: '지금은 소액사건 하나만 선언했다');
    });

    test('값이 없으면 아무것도 안 나온다', () {
      expect(checker.check(domain, const CaseFacts({})), isEmpty);
    });
  });

  group('모르는 모양은 추측하지 않는다', () {
    test('showIf 가 위쪽 경계 비교가 아니면 건너뛴다', () {
      // `==` · `in` 같은 조건에서는 "얼마나 넘었나" 를 말할 수 없다.
      final weird = domain.procedures
          .where((p) => p.showIf != null && p.nearMissWithin == null);
      expect(
        checker.check(domain, const CaseFacts({'claimAmount': 30001500})).length,
        1,
        reason: '선언한 하나만 나와야 한다 (후보 ${weird.length}개)',
      );
    });
  });
}
