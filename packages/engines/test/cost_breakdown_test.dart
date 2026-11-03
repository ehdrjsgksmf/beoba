import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/asset_paths.dart';

/// **왜 그 숫자인지**가 안 보이면 🟢 이 아니다. 조문은 있는데 그 조문이 어떻게
/// 이 금액이 됐는지가 없으면 사용자는 검산할 수 없다.
///
/// 그리고 화면이 다시 계산하면 두 곳이 갈라진다. 여기 담긴 것이 **엔진이 실제로
/// 밟은 단계**여야 한다.
void main() {
  const engine = CostEngine();
  final domain = DomainLoader(policy: VerificationPolicy.keepAll)
      .loadFromJsonString(domainFile('debt_recovery').readAsStringSync());
  final stampFee = domain.costs.firstWhere((c) => c.id == 'cost_stamp_fee');

  CostLine lineFor(Map<String, Object?> facts) =>
      engine.computeOne(stampFee, CaseFacts(facts))!;

  group('구간식 — 밟은 단계가 그대로 남는다', () {
    // 3,000만 1,500원 → 두 번째 구간 (1,000만 초과 ~ 1억 이하)
    final line = lineFor({
      'claimAmount': 30001500, // not-a-legal-number: 테스트 입력값
      'procedure': 'lawsuit',
      'useEfiling': false,
    });
    final steps = line.breakdown!;

    test('입력 금액을 들고 있다', () {
      expect(steps.input, 30001500);
    });

    test('고른 구간과 그 아래쪽 경계를 들고 있다', () {
      expect(steps.tierFloor, 10000000);
      expect(steps.tier!.max, 100000000);
      expect(steps.tier!.rate, 0.0045);
      expect(steps.tier!.add, 5000);
    });

    test('요율만 곱한 값이 남아 있다', () {
      expect(steps.rated, 135006);
      expect(steps.beforeRounding, 140006);
    });

    test('끝수 규칙과 그 결과가 남아 있다', () {
      expect(steps.rounding!.roundDown, 100);
      expect(steps.base, 140000);
    });

    test('단계를 이어 붙이면 최종 금액이 나온다', () {
      // 화면은 이 숫자들을 늘어놓기만 하면 된다.
      expect(steps.rated! + steps.tier!.add, steps.beforeRounding);
      expect(steps.amount, line.amount);
    });
  });

  group('배수 — 밟은 순서대로', () {
    final line = lineFor({
      'claimAmount': 50000000, // not-a-legal-number: 테스트 입력값
      'procedure': 'payment_order',
      'useEfiling': true,
    });
    final steps = line.breakdown!;

    test('둘 다 적용되고 순서가 유지된다', () {
      expect(steps.modifiers.map((m) => m.id),
          ['mod_payment_order', 'mod_efiling']);
    });

    test('말은 데이터에서 온다', () {
      // 코드가 배수를 설명하지 않는다.
      expect(steps.modifiers.first.label, isNotEmpty);
      expect(steps.modifiers.first.multiply, 0.1);
    });

    test('각 단계 뒤 금액이 남아 있다', () {
      expect(steps.base, 230000);
      expect(steps.modifiers[0].amount, 23000);
      expect(steps.modifiers[1].amount, 20700);
      expect(line.amount, 20700);
    });

    test('안 걸린 배수는 없다', () {
      final plain = lineFor({
        'claimAmount': 50000000, // not-a-legal-number: 테스트 입력값
        'procedure': 'lawsuit',
        'useEfiling': false,
      });
      expect(plain.breakdown!.modifiers, isEmpty);
    });
  });

  group('경계값을 그대로 드러낸다', () {
    test('소가 1억원은 세 번째 구간이다', () {
      // 화면이 구간을 다시 고르면 여기서 갈라진다.
      final line = lineFor({
        'claimAmount': 100000000, // not-a-legal-number: 테스트 입력값
        'procedure': 'lawsuit',
        'useEfiling': false,
      });
      expect(line.breakdown!.tierFloor, 100000000);
      expect(line.breakdown!.tier!.rate, 0.004);
      expect(line.amount, 455000);
    });
  });

  group('단가식', () {
    test('단가와 수량이 남는다', () {
      final serviceFee = domain.costs.firstWhere((c) => c.id == 'cost_service_fee');
      final line = engine.computeOne(
        serviceFee,
        const CaseFacts({'procedure': 'lawsuit'}),
      )!;
      expect(line.breakdown!.unitPrice, isNotNull);
      expect(line.breakdown!.units, isNotNull);
      expect(
        line.breakdown!.unitPrice! * line.breakdown!.units!,
        line.breakdown!.base,
      );
    });
  });
}
