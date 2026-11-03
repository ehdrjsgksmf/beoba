import 'package:engines/engines.dart';
import 'package:test/test.dart';

void main() {
  group('Money — 부동소수 함정', () {
    test('double 곱셈은 실제로 1원을 잃는다 — 그래서 이 헬퍼가 있다', () {
      // 6,000 × 0.45% 는 27원이다. double 로는 26.999999... 가 되어 26원이 된다.
      expect((6000 * 0.0045).floor(), 26);
      expect(Money.applyRate(6000, 0.0045), 27);
    });

    test('23,000 × 0.9 = 20,700 — 지급명령 + 전자소송 인지대', () {
      expect(Money.applyMultiplier(23000, 0.9), 20700);
    });

    test('455,000 × 0.9 = 409,500 — 전자소송 인지대', () {
      expect(Money.applyMultiplier(455000, 0.9), 409500);
    });

    test('230,000 × 0.1 = 23,000 — 지급명령', () {
      expect(Money.applyMultiplier(230000, 0.1), 23000);
    });

    test('연속 적용도 정확하다 — 지급명령 + 전자소송', () {
      final afterPaymentOrder = Money.applyMultiplier(230000, 0.1);
      expect(Money.applyMultiplier(afterPaymentOrder, 0.9), 20700);
    });
  });

  group('Money — 요율', () {
    test('5,000만원 × 0.45% = 225,000', () {
      expect(Money.applyRate(50000000, 0.0045), 225000);
    });

    test('1억원 × 0.4% = 400,000', () {
      expect(Money.applyRate(100000000, 0.004), 400000);
    });

    test('10억원 × 0.35% = 3,500,000', () {
      expect(Money.applyRate(1000000000, 0.0035), 3500000);
    });

    test('나누어떨어지지 않으면 내림', () {
      expect(Money.applyRate(3333333, 0.005), 16666);
    });

    test('계산 범위를 넘는 금액은 거부한다', () {
      expect(
        () => Money.applyRate(Money.maxBase + 1, 0.005),
        throwsArgumentError,
      );
    });
  });

  group('Money — 오버플로', () {
    test('1보다 큰 배수도 계산한다 (할증 modifier)', () {
      expect(Money.applyMultiplier(1000000, 1.5), 1500000);
      expect(Money.applyMultiplier(230000, 2), 460000);
    });

    test('큰 금액 × 큰 배수도 몫·나머지로 쪼개 정확히 계산한다', () {
      expect(Money.applyMultiplier(Money.maxBase, 2), Money.maxBase * 2);
      expect(Money.applyMultiplier(Money.maxBase, 1), Money.maxBase);
      expect(
        Money.applyRate(Money.maxBase, 0.005),
        45000000000, // not-a-legal-number: 경계 확인용
      );
    });

    test('그래도 표현 범위를 넘으면 거부한다 — 조용히 틀리지 않는다', () {
      expect(
        () => Money.applyMultiplier(Money.maxBase, 1000000),
        throwsArgumentError,
      );
    });

    test('웹(2^53) 기준으로 검사한다 — 플랫폼마다 답이 달라지지 않게', () {
      // int64 라면 통과하지만 웹에서는 정확하지 않은 구간.
      expect(Money.maxSafeInteger, lessThan(Money.maxBase * Money.scale));
      expect(
        () => Money.applyRate(Money.maxBase, 100000),
        throwsArgumentError,
      );
    });

    test('배수 0 은 0 이다', () {
      expect(Money.applyMultiplier(Money.maxBase, 0), 0);
    });
  });

  group('Money — 절사', () {
    test('100원 미만 절사', () {
      expect(Money.roundDown(16666, 100), 16600);
      expect(Money.roundDown(230000, 100), 230000);
      expect(Money.roundDown(99, 100), 0);
    });

    test('단위가 없으면 그대로 둔다', () {
      expect(Money.roundDown(16666, null), 16666);
      expect(Money.roundDown(16666, 1), 16666);
    });
  });

  group('Money — 단가 계산', () {
    test('송달료 5,500원 × 12회 = 66,000원', () {
      expect(Money.perUnit(5500, 12), 66000);
    });
  });
}
