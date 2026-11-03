import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// 인지대 4단계 구간 (민사소송 등 인지법 제2조 제1항).
/// 테스트 픽스처일 뿐, 실제 값은 도메인 JSON 이 정답지다.
const stampTiers = [
  CostTier(max: 10000000, rate: 0.005),
  CostTier(max: 100000000, rate: 0.0045, add: 5000),
  CostTier(max: 1000000000, rate: 0.004, add: 55000),
  CostTier(rate: 0.0035, add: 555000),
];

CostItem stampFee() => costFixture(
      id: 'cost_stamp',
      label: '인지대',
      formula: const TieredCostFormula(
        input: 'claimAmount',
        tiers: stampTiers,
        rounding: CostRounding(roundDown: 100),
      ),
      modifiers: const [
        CostModifier(
          id: 'mod_payment_order',
          label: '지급명령',
          multiply: 0.1,
          condition: {
            '==': [
              {'var': 'procedure'},
              'payment_order',
            ],
          },
        ),
        CostModifier(
          id: 'mod_efiling',
          label: '전자소송',
          multiply: 0.9,
          condition: {
            '==': [
              {'var': 'useEfiling'},
              true,
            ],
          },
        ),
      ],
    );

int amountFor(int claimAmount, {String procedure = 'lawsuit', bool efiling = false}) {
  const engine = CostEngine();
  return engine
      .computeOne(
        stampFee(),
        CaseFacts({
          'claimAmount': claimAmount,
          'procedure': procedure,
          'useEfiling': efiling,
        }),
      )!
      .amount;
}

void main() {
  const engine = CostEngine();

  group('CostEngine — tier 경계값', () {
    test('소가 1억원은 세 번째 구간이다 (두 번째가 아니다)', () {
      // 두 번째 구간이면 455,000 이 아니라 455,000 보다 작은 값이 나온다.
      expect(amountFor(100000000), 455000);
      expect(CostEngine.selectTier(stampTiers, 100000000), stampTiers[2]);
    });

    test('구간 경계 6종', () {
      expect(CostEngine.selectTier(stampTiers, 9999999), stampTiers[0]);
      expect(CostEngine.selectTier(stampTiers, 10000000), stampTiers[1]);
      expect(CostEngine.selectTier(stampTiers, 99999999), stampTiers[1]);
      expect(CostEngine.selectTier(stampTiers, 100000000), stampTiers[2]);
      expect(CostEngine.selectTier(stampTiers, 999999999), stampTiers[2]);
      expect(CostEngine.selectTier(stampTiers, 1000000000), stampTiers[3]);
    });

    test('max 가 null 인 구간이 무한대를 받는다', () {
      expect(CostEngine.selectTier(stampTiers, 99999999999), stampTiers[3]);
    });

    test('1천만원 경계에서 금액이 뛴다', () {
      expect(amountFor(9999999), 49900); // 9,999,999 × 0.5% = 49,999 → 49,900
      expect(amountFor(10000000), 50000); // 10,000,000 × 0.45% + 5,000
    });
  });

  group('CostEngine — modifier 체인', () {
    test('배열 순서대로 곱한다 — 지급명령 후 전자소송', () {
      expect(amountFor(50000000, procedure: 'payment_order'), 23000);
      expect(
        amountFor(50000000, procedure: 'payment_order', efiling: true),
        20700,
      );
    });

    test('조건이 맞지 않으면 적용하지 않는다', () {
      expect(amountFor(50000000), 230000);
    });

    test('적용된 modifier id 가 순서대로 기록된다', () {
      final line = engine.computeOne(
        stampFee(),
        const CaseFacts({
          'claimAmount': 50000000,
          'procedure': 'payment_order',
          'useEfiling': true,
        }),
      );
      expect(line!.appliedModifiers, ['mod_payment_order', 'mod_efiling']);
    });
  });

  group('CostEngine — 계산식 3종', () {
    test('fixed', () {
      final line = engine.computeOne(
        costFixture(
          id: 'cost_fixed',
          formula: const FixedCostFormula(amount: 50000),
        ),
        const CaseFacts(),
      );
      expect(line!.amount, 50000);
    });

    test('perUnit — 송달료', () {
      final line = engine.computeOne(
        costFixture(
          id: 'cost_service',
          formula: const PerUnitCostFormula(
            unitPrice: 5500,
            unitsFormula: UnitsFormula(
              parties: 2,
              roundsByProcedure: {'payment_order': 6, 'lawsuit': 15},
            ),
          ),
        ),
        const CaseFacts({'procedure': 'payment_order'}),
      );
      expect(line!.amount, 66000);
    });

    test('perUnit — 모르는 절차면 계산하지 않는다', () {
      final line = engine.computeOne(
        costFixture(
          id: 'cost_service',
          formula: const PerUnitCostFormula(
            unitPrice: 5500,
            unitsFormula: UnitsFormula(
              parties: 2,
              roundsByProcedure: {'lawsuit': 15},
            ),
          ),
        ),
        const CaseFacts({'procedure': 'appeal'}),
      );
      expect(line, isNull);
    });

    test('끝수 처리는 tier 계산 직후 1회만', () {
      // 3,333,333 × 0.5% = 16,666 → 절사 16,600 → ×0.9 = 14,940
      final line = engine.computeOne(
        costFixture(
          id: 'cost_round',
          formula: const TieredCostFormula(
            input: 'claimAmount',
            tiers: stampTiers,
            rounding: CostRounding(roundDown: 100),
          ),
          modifiers: const [
            CostModifier(id: 'mod', label: '할인', multiply: 0.9),
          ],
        ),
        const CaseFacts({'claimAmount': 3333333}),
      );
      expect(line!.amount, 14940);
    });
  });

  group('CostEngine — 목록 계산', () {
    test('금액은 int 다. double 을 넣으면 거부한다', () {
      expect(
        () => engine.computeOne(
          stampFee(),
          const CaseFacts({'claimAmount': 5000000.5, 'procedure': 'lawsuit'}),
        ),
        throwsArgumentError,
      );
    });

    test('입력이 없으면 항목을 빼고 합계를 낸다', () {
      final domain = domainFixture(
        costs: [
          stampFee(),
          costFixture(
            id: 'cost_fixed',
            formula: const FixedCostFormula(amount: 5000),
          ),
        ],
      );
      final result = engine.compute(domain, const CaseFacts());
      expect(result.lines.map((l) => l.id), ['cost_fixed']);
      expect(result.total, 5000);
    });

    test('합계는 각 줄의 합이다', () {
      final domain = domainFixture(
        costs: [
          stampFee(),
          costFixture(
            id: 'cost_fixed',
            formula: const FixedCostFormula(amount: 5000),
          ),
        ],
      );
      final result = engine.compute(
        domain,
        const CaseFacts({'claimAmount': 50000000, 'procedure': 'lawsuit'}),
      );
      expect(result.total, 235000);
      expect(result.lineById('cost_stamp')!.amount, 230000);
    });
  });
}
