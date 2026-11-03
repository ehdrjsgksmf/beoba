import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// 한글로 적은 금액을 읽는다. `formatWonKorean` 의 역방향이다.
///
/// **읽기가 틀리면 인지대가 틀린다.** 그리고 못 읽었을 때 조용히 0 이 되면
/// 사용자는 자기가 0 을 넣었다는 사실조차 모른다. 두 가지를 여기서 잠근다.
void main() {
  const won = 1;
  const manwon = 10000;

  group('숫자→한글 읽기의 역방향', () {
    // formatWonKorean 이 내놓는 표기를 그대로 되읽을 수 있어야 한다.
    const roundTrip = <int>[
      10000,
      50000,
      50000000,
      100000000,
      500000000,
      1234567,
      1000000000000,
      12000,
    ];

    for (final amount in roundTrip) {
      test('${formatWonKorean(amount)} → $amount', () {
        expect(parseKoreanWon(formatWonKorean(amount), unit: won)?.won, amount);
      });
    }
  });

  group('사람이 실제로 적는 방식', () {
    const cases = <String, int>{
      '오천만원': 50000000,
      '5천만원': 50000000,
      '5천만': 50000000,
      '5000만': 50000000,
      '오천만': 50000000,
      '1억': 100000000,
      '일억': 100000000,
      '1억5천만': 150000000,
      '삼백만원': 3000000,
      '50만': 500000,
      '1,234,567원': 1234567,
      '5 0 0 0 만': 50000000,
    };

    cases.forEach((text, expected) {
      test('"$text" → $expected', () {
        expect(parseKoreanWon(text, unit: won)?.won, expected);
      });
    });
  });

  group('칸의 단위 — 십·백·천은 수를 만들고 만·억·조·원은 크기를 못박는다', () {
    test('만원 칸의 "오천" 은 5천만원이다', () {
      // 만원 칸에 5000 을 넣으면 5천만원이다. "오천" 은 그걸 소리 나는 대로
      // 적은 것뿐이므로 같은 답이 나와야 한다.
      expect(parseKoreanWon('오천', unit: manwon)?.won, 50000000);
      expect(parseKoreanWon('5000', unit: manwon)?.won, 50000000);
    });

    test('원 칸의 "오천" 은 5천원이다', () {
      expect(parseKoreanWon('오천', unit: won)?.won, 5000);
    });

    test('만 이 붙으면 칸을 무시하고 절대 금액이다', () {
      expect(parseKoreanWon('오천만', unit: manwon)?.won, 50000000);
      expect(parseKoreanWon('오천만', unit: won)?.won, 50000000);
    });

    test('원 이 붙으면 만원 칸에서도 원이다', () {
      // 만원 칸에 갇히지 않는 탈출구다.
      expect(parseKoreanWon('1000원', unit: manwon)?.won, 1000);
    });

    test('글자가 단위를 말했는지 알려준다', () {
      expect(parseKoreanWon('오천', unit: manwon)?.unitWasExplicit, isFalse);
      expect(parseKoreanWon('오천만', unit: manwon)?.unitWasExplicit, isTrue);
      expect(parseKoreanWon('1000원', unit: manwon)?.unitWasExplicit, isTrue);
    });
  });

  group('못 읽으면 null 이다. **0 이 아니다**', () {
    const unreadable = <String>[
      '',
      '   ',
      '많이',
      '오천마넌',
      '대충 오천만원쯤',
      '오오',
      'abc',
      '만만',
      '영원',
      '0',
      '0원',
      '?',
      '오천만원???',
    ];

    for (final text in unreadable) {
      test('"$text" 는 값을 만들지 않는다', () {
        final parsed = parseKoreanWon(text, unit: manwon);
        expect(parsed?.won, isNot(0), reason: '0 이 되면 사용자가 모른다');
        expect(parsed, isNull);
      });
    }
  });

  group('경계', () {
    test('십 은 일십이다', () {
      expect(parseKoreanWon('십만원', unit: won)?.won, 100000);
      expect(parseKoreanWon('십', unit: won)?.won, 10);
    });

    test('자릿수가 터지면 읽지 않는다', () {
      expect(parseKoreanWon('9' * 13, unit: won), isNull);
    });

    test('읽은 값은 만원 곱셈을 거쳐도 계산 범위 안이다', () {
      final parsed = parseKoreanWon('구천억', unit: won);
      expect(parsed?.won, 900000000000);
      expect(parsed!.won, lessThan(Money.maxSafeInteger));
    });
  });
}
