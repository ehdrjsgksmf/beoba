import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// 화면이 만원 단위로 받아도 **저장은 원 단위 정수 그대로다.**
///
/// 인지대는 구간이 갈려서 원 단위 정확도를 하나도 잃으면 안 된다. 만원 입력은
/// 화면의 편의일 뿐이고, `Money.fromManwon` 을 지나는 순간 원이 된다.
///
/// 그리고 이 곱셈이 **웹의 2^53 을 뚫지 않는지**가 여기서 잠긴다. M0 에서
/// VM 테스트 225건이 전부 초록인 동안 웹만 틀렸던 적이 있다 (DECISIONS 20번).
void main() {
  group('만원 입력 — 원 단위로 정확히 바뀐다', () {
    const cases = <int, int>{
      1: 10000,
      5000: 50000000,
      10000: 100000000,
      1234: 12340000,
    };

    cases.forEach((manwon, won) {
      test('$manwon 만원 → $won 원', () {
        expect(Money.fromManwon(manwon), won);
      });
    });

    test('만원 입력을 거쳐도 인지대 구간 경계가 흔들리지 않는다', () {
      // 소가 1억원은 **세 번째 구간**이다. 두 번째가 아니다.
      // 만원 칸에 10000 을 넣은 사람과 원 칸에 100000000 을 넣은 사람은
      // 같은 답을 받아야 한다.
      expect(Money.fromManwon(10000), 100000000);
      expect(Money.applyRate(Money.fromManwon(10000), 0.0045), 450000);
    });

    test('원 단위 입력이 살아 있어야 하는 이유', () {
      // 1,234,567원인 사람은 만원 칸으로 표현할 수 없다. 반올림하면 틀린다.
      expect(1234567 % Money.manwon, isNot(0));
    });
  });

  group('만원 입력 — 범위를 넘으면 곱하기 전에 막는다', () {
    test('상한까지는 통과한다', () {
      expect(
        Money.fromManwon(Money.maxManwonInput),
        Money.maxBase,
      );
    });

    test('상한을 넘으면 던진다', () {
      expect(
        () => Money.fromManwon(Money.maxManwonInput + 1),
        throwsArgumentError,
      );
    });

    test('곱한 결과가 웹의 2^53 안에 있다', () {
      // 곱하고 나서 터지면 사용자는 자기가 뭘 잘못했는지 알 수 없다.
      expect(Money.fromManwon(Money.maxManwonInput), lessThan(Money.maxSafeInteger));
    });

    test('상한 금액에 요율을 곱해도 표현 범위 안이다', () {
      // 화면이 만들 수 있는 가장 큰 금액이 엔진을 통과하는지 본다.
      expect(
        () => Money.applyRate(Money.fromManwon(Money.maxManwonInput), 0.005),
        returnsNormally,
      );
    });
  });

  group('한글로 읽어 준다 — 0 개수를 세지 않게', () {
    const cases = <int, String>{
      0: '영원',
      10000: '만원',
      50000: '오만원',
      50000000: '오천만원',
      100000000: '일억원',
      500000000: '오억원',
      1234567: '백이십삼만 사천오백육십칠원',
      1000000000000: '일조원',
      12000: '만 이천원',
    };

    cases.forEach((won, korean) {
      test('$won → $korean', () {
        expect(formatWonKorean(won), korean);
      });
    });

    test('만원 칸의 오타를 드러낸다', () {
      // 만원 칸에 50000 을 넣으면 5억원이다. 숫자만 보면 0 을 세어야 안다.
      expect(formatWonKorean(Money.fromManwon(50000)), '오억원');
      expect(formatWonKorean(Money.fromManwon(5000)), '오천만원');
    });
  });
}
