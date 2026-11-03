import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// 쉬운 말 검사가 **무엇을 잡는지** 하나씩 보여 준다.
///
/// 도구 안에 두지 않고 라이브러리로 뺀 이유가 이것이다 — 「검사가 있다」가
/// 아니라 「이런 문장을 이렇게 잡는다」를 눈으로 볼 수 있어야 한다.
void main() {
  const check = PlainKoreanCheck();

  List<PlainRule> rulesFor(String original, String plain,
          {List<String> terms = const []}) =>
      check
          .check(original: original, plain: plain, terms: terms)
          .map((i) => i.rule)
          .toList();

  group('쉬운 말 — 길이와 문장 나누기', () {
    test('한 문장이 40자를 넘으면 걸린다', () {
      const long = '법이 요양급여의 범위를 여덟 가지로 아주 자세하게 적어 두었고 '
          '그 안에 진찰과 검사도 들어 있어요.';
      expect(rulesFor('법이 적어 두었어요.', long), contains(PlainRule.tooLong));
    });

    test('40자 아래로 자르면 통과한다', () {
      expect(
        rulesFor('법이 적어 두었어요.', '법이 여덟 가지를 적어 두었어요. 진찰과 검사예요.'),
        isEmpty,
      );
    });

    group('★ 40자를 놓아 주는 자리', () {
      // **40자는 수단이지 목적이 아니다.** 목적은 한국어가 서툰 분이 읽을 수
      // 있게 하는 것이고 거기서 주범은 어려운 낱말이다. 열거를 담은 문장은
      // 쪼갤수록 길어져서, 수단을 지키다 목적을 잃는다(265번).
      const long = '법이 요양급여의 범위를 여덟 가지로 아주 자세하게 적어 두었고 '
          '그 안에 진찰과 검사도 들어 있어요.';
      const why = '열거를 담은 문장이다. 쪼개려면 서술어를 되풀이해야 한다';

      test('이유를 적으면 그 자리에서만 놓아 준다', () {
        expect(
          check
              .check(original: '법이 적어 두었어요.', plain: long, longOk: why)
              .map((i) => i.rule),
          isNot(contains(PlainRule.tooLong)),
        );
      });

      test('이유가 비면 놓아 주지 않는다', () {
        // 빈 이유를 눈감으면 이유를 요구하는 뜻이 없어진다.
        expect(
          check
              .check(original: '법이 적어 두었어요.', plain: long, longOk: '   ')
              .map((i) => i.rule),
          contains(PlainRule.tooLong),
        );
      });

      test('★ 놓아 주는 것은 길이 하나뿐이다', () {
        // 이어 붙임·시키는 말·이중피동은 「길어서 생긴 일」이 아니라
        // 뜻이 달라지는 일이다. 길이를 놓아 줘도 그대로 막는다.
        const bad = '법이 요양급여의 범위를 여덟 가지로 아주 자세하게 적어 두었고, '
            '그 안에 진찰과 검사도 들어 있으니 공단에 가세요.';
        expect(
          check
              .check(original: '법이 적어 두었어요.', plain: bad, longOk: why)
              .map((i) => i.rule),
          containsAll([PlainRule.joined, PlainRule.order]),
        );
      });
    });

    test('서술어를 「~하고,」로 이으면 걸린다', () {
      expect(
        rulesFor('적혀 있어요.', '휴업급여는 지급하고, 요양급여는 따로예요.'),
        contains(PlainRule.joined),
      );
    });

    test('「~하며」로 이어도 걸린다', () {
      expect(
        rulesFor('적혀 있어요.', '휴업급여를 지급하며 요양급여도 있어요.'),
        contains(PlainRule.joined),
      );
    });

    test('「며칠」은 이어 붙인 것이 아니다', () {
      expect(rulesFor('며칠 걸리나요?', '치료가 며칠 걸린다고 했나요?'), isEmpty);
    });
  });

  group('★ 쉬운 말이 원래 문장보다 단정하면 빨간불', () {
    test('「~일 수 있어요」가 「~예요」로 미끄러지면 걸린다', () {
      expect(
        rulesFor('3일 이내이면 지급하지 않을 수 있어요.', '3일 이내이면 못 받아요.'),
        contains(PlainRule.moreAssertive),
      );
    });

    test('「~할 수 있어요」가 「~하면 돼요」로 가면 두 가지가 걸린다', () {
      final rules = rulesFor('병원이 대신 낼 수 있어요.', '병원에 맡기면 돼요.');
      expect(rules, contains(PlainRule.order));
      expect(rules, contains(PlainRule.lostHedge));
    });

    test('「수 있」을 그대로 두면 통과한다', () {
      expect(
        rulesFor('치료받은 병원이 대신 낼 수 있어요.', '병원이 대신 낼 수도 있어요.'),
        isEmpty,
      );
    });

    test('원래가 단정이면 쉬운 말도 단정일 수 있다', () {
      expect(rulesFor('90일 이내라고 적혀 있어요.', '90일 이내예요.'), isEmpty);
    });

    test('★ 시키는 말은 원래 문장과 상관없이 안 된다', () {
      expect(
        rulesFor('공단에 신청한다고 적혀 있어요.', '공단에 가세요.'),
        contains(PlainRule.order),
      );
    });
  });

  group('쉬운 말 — 이중부정과 이중피동', () {
    test('「~하지 않으면 안 돼요」는 걸린다', () {
      expect(
        rulesFor('적혀 있어요.', '90일 안에 하지 않으면 안 돼요.'),
        contains(PlainRule.doubleNegative),
      );
    });

    test('「보여지다」는 걸린다', () {
      expect(
        rulesFor('적혀 있어요.', '그렇게 보여져요.'),
        contains(PlainRule.doublePassive),
      );
    });

    test('단순 피동은 막지 않고 센다', () {
      expect(rulesFor('적혀 있어요.', '그렇게 되는 것이에요.'), isEmpty);
      expect(PlainKoreanCheck.passiveCount('그렇게 되는 것이에요.'), 1);
    });
  });

  group('★ 어려운 법률 용어는 바꾸는 것이 아니라 병기한다', () {
    test('용어집 낱말이 사라지면 걸린다', () {
      expect(
        rulesFor(
          '3년간 요구하지 않으면 [[시효]]로 없어져요.',
          '3년이 지나면 없어져요.',
          terms: const ['시효'],
        ),
        contains(PlainRule.lostTerm),
      );
    });

    test('그대로 두고 풀이를 옆에 달면 통과한다', () {
      expect(
        rulesFor(
          '3년간 요구하지 않으면 [[시효]]로 없어져요.',
          '3년간 요구하지 않으면 [[시효]]로 없어져요. '
              '시효는 시간이 지나면 못 하게 되는 것이에요.',
          terms: const ['시효'],
        ),
        isEmpty,
      );
    });
  });

  group('어미 강도 사다리', () {
    test('0 그럴 수 있다 · 1 그렇다 · 2 그렇게 하라', () {
      expect(PlainKoreanCheck.level('대신 낼 수 있어요.'), 0);
      expect(PlainKoreanCheck.level('90일 이내예요.'), 1);
      expect(PlainKoreanCheck.level('공단에 가세요.'), 2);
    });

    test('★ 곁말 하나로 글 전체가 단정이 되지 않는다', () {
      // 「그래서 여쭤봅니다」는 단정이지만 이 글이 여는 자리는 「수 있는지」다.
      expect(
        PlainKoreanCheck.level('언제까지 요구할 수 있는지 셉니다. 그래서 여쭤봅니다.'),
        0,
      );
    });
  });
}
