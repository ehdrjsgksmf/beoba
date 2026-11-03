import 'package:engines/engines.dart';
import 'package:test/test.dart';

void main() {
  group('SafetyFilter — strict (앱이 직접 말하는 문구)', () {
    test('승패 예측을 막는다', () {
      expect(SafetyFilter.isSafe('승소 가능성이 높습니다'), isFalse);
      expect(SafetyFilter.isSafe('이길 수 있습니다'), isFalse);
      expect(SafetyFilter.isSafe('이 사건은 유리합니다'), isFalse);
    });

    test('단정 표현을 막는다', () {
      expect(SafetyFilter.isSafe('무조건 받을 수 있습니다'), isFalse);
      expect(SafetyFilter.isSafe('100% 환급됩니다'), isFalse);
      expect(SafetyFilter.isSafe('확실히 됩니다'), isFalse);
      expect(SafetyFilter.isSafe('반드시 받으실 수 있습니다'), isFalse);
    });

    test('조언·위로 표현을 막는다', () {
      expect(SafetyFilter.isSafe('이렇게 주장하세요'), isFalse);
      expect(SafetyFilter.isSafe('걱정하지 마세요'), isFalse);
      expect(SafetyFilter.isSafe('제 생각에는 이렇습니다'), isFalse);
    });

    test('사실 안내는 통과한다', () {
      expect(
        SafetyFilter.isSafe('지급명령을 송달받은 날부터 2주 이내에 이의신청을 할 수 있습니다.'),
        isTrue,
      );
      expect(SafetyFilter.isSafe('소가 5,000만원이면 인지대는 230,000원입니다.'), isTrue);
      expect(SafetyFilter.isSafe('대한법률구조공단 132번으로 무료 상담을 받을 수 있습니다.'), isTrue);
    });

    test('어디가 걸렸는지 알려준다', () {
      final violations = SafetyFilter.scan('이 사건은 승소 가능성이 높습니다', where: 'test.text');
      expect(violations, isNotEmpty);
      expect(violations.first.where, 'test.text');
      expect(violations.first.excerpt, contains('승소'));
    });

    test('assertSafe 는 위반 시 던진다', () {
      expect(
        () => SafetyFilter.assertSafe('무조건 이깁니다'),
        throwsA(isA<SafetyViolationException>()),
      );
      expect(() => SafetyFilter.assertSafe('내용증명은 우체국에서 보냅니다'), returnsNormally);
    });
  });

  group('SafetyFilter — quote (사기꾼 멘트 인용)', () {
    test('실제 도메인 데이터의 인용 문구가 통과한다', () {
      const quotes = [
        '정부지원금 100% 받아 드립니다 / 합격 보장합니다',
        '회생 무조건 됩니다 / 탕감률 보장해 드립니다',
        '금융감독원: 대출 승인을 위한 선입금 요구는 100% 사기입니다.',
        '연체기록 지워 드립니다 / 신용점수 올려 드립니다',
      ];
      for (final quote in quotes) {
        expect(
          SafetyFilter.isSafe(quote, scope: SafetyScope.quote),
          isTrue,
          reason: quote,
        );
      }
    });

    test('같은 문구가 strict 에서는 막힌다', () {
      expect(SafetyFilter.isSafe('정부지원금 100% 받아 드립니다'), isFalse);
      expect(SafetyFilter.isSafe('회생 무조건 됩니다'), isFalse);
    });

    test('인용이어도 1인칭 단정·조언은 막는다', () {
      expect(
        SafetyFilter.isSafe('승소 가능성이 높습니다', scope: SafetyScope.quote),
        isFalse,
      );
      expect(
        SafetyFilter.isSafe('걱정하지 마시고 맡기세요', scope: SafetyScope.quote),
        isFalse,
      );
    });
  });

  group('필드별 scope 표는 코드에 고정된다', () {
    test('인용 필드만 quote 다', () {
      expect(scopeFor('BrokerAlert', 'phrase'), SafetyScope.quote);
      expect(scopeFor('BrokerAlert', 'truth'), SafetyScope.quote);
      expect(scopeFor('LimitRule', 'message'), SafetyScope.quote);
    });

    test('앱이 말하는 필드는 strict 다', () {
      expect(scopeFor('Question', 'whyAsk'), SafetyScope.strict);
      expect(scopeFor('Procedure', 'summary'), SafetyScope.strict);
      expect(scopeFor('Deadline', 'label'), SafetyScope.strict);
    });

    test('모르는 필드는 기본이 strict 다', () {
      expect(scopeFor('무언가', '새필드'), SafetyScope.strict);
    });
  });
}
