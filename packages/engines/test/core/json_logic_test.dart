import 'package:engines/engines.dart';
import 'package:test/test.dart';

void main() {
  const data = <String, dynamic>{
    'claimType': 'loan',
    'claimAmount': 30000000,
    'hasPaymentOrder': true,
    'demandMethod': 'none',
    'assets': ['salary', 'vehicle'],
  };

  group('JsonLogic — 도메인 JSON 에 실제로 쓰이는 연산자', () {
    test('== 비교', () {
      expect(
        JsonLogic.test({
          '==': [
            {'var': 'claimType'},
            'loan',
          ],
        }, data),
        isTrue,
      );
    });

    test('!= 비교', () {
      expect(
        JsonLogic.test({
          '!=': [
            {'var': 'demandMethod'},
            'none',
          ],
        }, data),
        isFalse,
      );
    });

    test('<= 비교 — 소액사건 3,000만원', () {
      expect(
        JsonLogic.test({
          '<=': [
            {'var': 'claimAmount'},
            30000000,
          ],
        }, data),
        isTrue,
      );
      expect(
        JsonLogic.test({
          '<=': [
            {'var': 'claimAmount'},
            29999999,
          ],
        }, data),
        isFalse,
      );
    });

    test('in — 값이 목록에 있는지', () {
      expect(
        JsonLogic.test({
          'in': [
            {'var': 'claimType'},
            ['goods', 'construction'],
          ],
        }, data),
        isFalse,
      );
      expect(
        JsonLogic.test({
          'in': [
            {'var': 'claimType'},
            ['loan', 'deposit'],
          ],
        }, data),
        isTrue,
      );
    });

    test('bool 값 비교', () {
      expect(
        JsonLogic.test({
          '==': [
            {'var': 'hasPaymentOrder'},
            true,
          ],
        }, data),
        isTrue,
      );
    });

    test('and / or / !', () {
      expect(
        JsonLogic.test({
          'and': [
            {
              '==': [
                {'var': 'claimType'},
                'loan',
              ],
            },
            {
              '<=': [
                {'var': 'claimAmount'},
                30000000,
              ],
            },
          ],
        }, data),
        isTrue,
      );
      expect(
        JsonLogic.test({
          '!': [
            {'var': 'hasPaymentOrder'},
          ],
        }, data),
        isFalse,
      );
    });

    test('없는 필드는 거짓으로 다룬다', () {
      expect(
        JsonLogic.test({
          '==': [
            {'var': 'nonexistent'},
            'x',
          ],
        }, data),
        isFalse,
      );
    });

    test('아직 안 채워진 값과는 크기를 견주지 않는다', () {
      // 예전에는 예외를 던졌다. 사용자가 아직 답하지 않은 필드를 보는 조건은
      // 흔한데, 그때마다 화면 하나가 통째로 죽는다. **참이 아니다**로 끝낸다.
      const rule = {
        '<=': [
          {'var': 'nonexistent'},
          30000000, // not-a-legal-number: 테스트 입력값
        ],
      };
      expect(JsonLogic.test(rule, data), isFalse);
      expect(
        JsonLogic.test(const {
          '>': [
            {'var': 'nonexistent'},
            0,
          ],
        }, data),
        isFalse,
      );
    });

    test('값이 있는데 숫자가 아니면 그대로 던진다', () {
      // 조용히 false 로 넘기면 조건이 왜 안 맞는지 아무도 모른다.
      expect(
        () => JsonLogic.test(const {
          '<=': [
            {'var': 'claimType'},
            10,
          ],
        }, data),
        throwsA(isA<JsonLogicException>()),
      );
    });

    test('조건이 없으면 항상 참', () {
      expect(JsonLogic.test(null, data), isTrue);
      expect(JsonLogic.test(const {}, data), isTrue);
    });
  });

  group('JsonLogic — 모르는 것은 조용히 넘기지 않는다', () {
    test('지원하지 않는 연산자는 예외', () {
      expect(
        () => JsonLogic.test({
          'reduce': [1, 2],
        }, data),
        throwsA(isA<JsonLogicException>()),
      );
    });

    test('비교할 수 없는 값은 예외', () {
      expect(
        () => JsonLogic.test({
          '<': [
            {'var': 'claimType'},
            10,
          ],
        }, data),
        throwsA(isA<JsonLogicException>()),
      );
    });
  });
}
