import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

LimitRule ruleFixture({
  required String id,
  bool alwaysIllegal = false,
  LimitFormula? formula,
  String? message,
}) =>
    LimitRule(
      id: id,
      label: '테스트 상한',
      alwaysIllegal: alwaysIllegal,
      formula: formula,
      message: message,
      verification: verifiedFixture,
    );

/// 부동산 중개보수 (공인중개사법). 픽스처일 뿐 정답지는 도메인 JSON 이다.
const leaseTiers = [
  LimitTier(max: 50000000, rate: 0.005, cap: 200000),
  LimitTier(max: 100000000, rate: 0.004, cap: 300000),
  LimitTier(max: 600000000, rate: 0.003),
];

void main() {
  const checker = LimitChecker();

  group('LimitChecker — alwaysIllegal', () {
    test('입력과 무관하게 위법이다', () {
      final result = checker.check(
        ruleFixture(
          id: 'lr_loan_broker_fee',
          alwaysIllegal: true,
          message: '대출 중개수수료는 금액과 명칭에 관계없이 불법입니다.',
        ),
        const {},
      );
      expect(result.verdict, LimitVerdict.alwaysIllegal);
      expect(result.legalMax, 0);
      expect(result.isProblem, isTrue);
    });

    test('요구 금액이 있으면 그대로 초과분이 된다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', alwaysIllegal: true),
        const {'requestedAmount': 300000},
      );
      expect(result.excess, 300000);
    });
  });

  group('LimitChecker — tiered_with_cap', () {
    const formula = TieredWithCapLimitFormula(
      variants: {'lease': leaseTiers},
    );

    test('상한 이내면 within', () {
      final result = checker.check(
        ruleFixture(id: 'lr', formula: formula),
        const {
          'transactionAmount': 150000000,
          'dealType': 'lease',
          'requestedAmount': 450000,
        },
      );
      expect(result.verdict, LimitVerdict.within);
      expect(result.legalMax, 450000);
      expect(result.excess, 0);
    });

    test('cap 이 계산값을 눌러 준다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', formula: formula),
        const {
          'transactionAmount': 30000000,
          'dealType': 'lease',
          'requestedAmount': 250000,
        },
      );
      expect(result.legalMax, 150000); // 0.5% = 150,000 (cap 200,000 미만)
      expect(result.verdict, LimitVerdict.over);
      expect(result.excess, 100000);
    });

    test('cap 에 걸리면 cap 이 상한이다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', formula: formula),
        const {
          'transactionAmount': 49000000,
          'dealType': 'lease',
          'requestedAmount': 200000,
        },
      );
      // 49,000,000 × 0.5% = 245,000 이지만 cap 200,000
      expect(result.legalMax, 200000);
      expect(result.verdict, LimitVerdict.within);
    });

    test('거래유형을 모르면 unknown — 추측하지 않는다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', formula: formula),
        const {'transactionAmount': 30000000, 'requestedAmount': 250000},
      );
      expect(result.verdict, LimitVerdict.unknown);
    });

    test('요구 금액을 모르면 상한만 알려준다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', formula: formula),
        const {'transactionAmount': 150000000, 'dealType': 'lease'},
      );
      expect(result.verdict, LimitVerdict.unknown);
      expect(result.legalMax, 450000);
    });
  });

  group('LimitChecker — 월세 환산', () {
    const conversion = MonthlyRentConversion(
      multiplier: 100,
      fallbackMultiplier: 70,
      fallbackThreshold: 50000000,
    );

    test('보증금 + 월차임 × 100', () {
      expect(
        LimitChecker.convertMonthlyRent(
          conversion,
          deposit: 100000000,
          monthlyRent: 500000,
        ),
        150000000,
      );
    });

    test('합산액이 5천만원 미만이면 × 70', () {
      expect(
        LimitChecker.convertMonthlyRent(
          conversion,
          deposit: 10000000,
          monthlyRent: 300000,
        ),
        31000000, // 10,000,000 + 300,000 × 70
      );
    });

    test('환산액으로 구간을 고른다', () {
      final result = checker.check(
        ruleFixture(
          id: 'lr',
          formula: const TieredWithCapLimitFormula(
            variants: {'lease': leaseTiers},
            monthlyRentConversion: conversion,
          ),
        ),
        const {
          'deposit': 100000000,
          'monthlyRent': 500000,
          'dealType': 'lease',
          'requestedAmount': 450000,
        },
      );
      expect(result.legalMax, 450000); // 1.5억 × 0.3%
    });
  });

  group('LimitChecker — threshold', () {
    const formula = ThresholdLimitFormula(
      input: 'annualRate',
      thresholds: [
        ThresholdRule(over: 0.60, verdict: 'void_all', message: '원금도 무효입니다.'),
        ThresholdRule(over: 0.20, verdict: 'over', message: '초과분은 무효입니다.'),
      ],
    );

    test('연 60% 초과는 void_all', () {
      final result = checker.check(
        ruleFixture(id: 'lr_max_interest', formula: formula),
        const {'annualRate': 0.7},
      );
      expect(result.verdict, LimitVerdict.voidAll);
      expect(result.message, contains('원금'));
    });

    test('연 20% 초과는 over', () {
      final result = checker.check(
        ruleFixture(id: 'lr_max_interest', formula: formula),
        const {'annualRate': 0.24},
      );
      expect(result.verdict, LimitVerdict.over);
    });

    test('연 20% 이하는 within', () {
      final result = checker.check(
        ruleFixture(id: 'lr_max_interest', formula: formula),
        const {'annualRate': 0.19},
      );
      expect(result.verdict, LimitVerdict.within);
    });

    test('경계값 정확히 20% 는 초과가 아니다', () {
      final result = checker.check(
        ruleFixture(id: 'lr_max_interest', formula: formula),
        const {'annualRate': 0.20},
      );
      expect(result.verdict, LimitVerdict.within);
    });

    test('금리를 모르면 unknown', () {
      final result = checker.check(
        ruleFixture(id: 'lr_max_interest', formula: formula),
        const {},
      );
      expect(result.verdict, LimitVerdict.unknown);
    });
  });

  group('LimitChecker — fixed', () {
    test('정해진 금액이 상한이다', () {
      final result = checker.check(
        ruleFixture(
          id: 'lr_ccrs_fee',
          formula: const FixedLimitFormula(amount: 50000),
        ),
        const {'requestedAmount': 500000},
      );
      expect(result.legalMax, 50000);
      expect(result.verdict, LimitVerdict.over);
      expect(result.excess, 450000);
    });
  });

  group('LimitChecker — 무엇을 넣었는지 함께 돌려준다', () {
    test('구간표 판정은 거래금액·거래유형·요구액을 기록한다', () {
      final result = checker.check(
        ruleFixture(
          id: 'lr',
          formula: const TieredWithCapLimitFormula(variants: {'lease': leaseTiers}),
        ),
        const {
          'transactionAmount': 150000000,
          'dealType': 'lease',
          'requestedAmount': 450000,
          '무관한입력': 'x',
        },
      );
      expect(result.inputs, {
        'transactionAmount': 150000000,
        'dealType': 'lease',
        'requestedAmount': 450000,
      });
    });

    test('계산에 쓰이지 않은 입력은 담지 않는다', () {
      final result = checker.check(
        ruleFixture(
          id: 'lr',
          formula: const ThresholdLimitFormula(
            input: 'annualRate',
            thresholds: [
              ThresholdRule(over: 0.20, verdict: 'over', message: '초과'),
            ],
          ),
        ),
        const {'annualRate': 0.24, 'transactionAmount': 150000000},
      );
      expect(result.inputs, {'annualRate': 0.24});
    });

    test('alwaysIllegal 도 요구액은 남긴다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', alwaysIllegal: true),
        const {'requestedAmount': 300000},
      );
      expect(result.inputs, {'requestedAmount': 300000});
    });

    test('입력이 없으면 빈 맵이다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', alwaysIllegal: true),
        const {},
      );
      expect(result.inputs, isEmpty);
    });

    test('기록된 입력은 바꿀 수 없다', () {
      final result = checker.check(
        ruleFixture(id: 'lr', alwaysIllegal: true),
        const {'requestedAmount': 300000},
      );
      expect(() => result.inputs.clear(), throwsUnsupportedError);
    });

    test('월세는 환산된 금액이 기록된다 — 계산에 쓰인 값이므로', () {
      final result = checker.check(
        ruleFixture(
          id: 'lr',
          formula: const TieredWithCapLimitFormula(
            variants: {'lease': leaseTiers},
            monthlyRentConversion: MonthlyRentConversion(
              multiplier: 100,
              fallbackMultiplier: 70,
              fallbackThreshold: 50000000,
            ),
          ),
        ),
        const {
          'deposit': 100000000,
          'monthlyRent': 500000,
          'dealType': 'lease',
          'requestedAmount': 450000,
        },
      );
      expect(result.inputs['transactionAmount'], 150000000);
    });
  });

  group('LimitChecker — 도메인 전체', () {
    test('checkAll 은 규칙 수만큼 결과를 낸다', () {
      final domain = domainFixture(
        limitRules: [
          ruleFixture(id: 'lr_a', alwaysIllegal: true),
          ruleFixture(
            id: 'lr_b',
            formula: const FixedLimitFormula(amount: 50000),
          ),
        ],
      );
      final results = checker.checkAll(domain, const CaseFacts());
      expect(results.map((r) => r.ruleId), ['lr_a', 'lr_b']);
    });
  });
}
