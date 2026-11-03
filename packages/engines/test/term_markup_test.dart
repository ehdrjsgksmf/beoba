import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// **용어 풀이는 검색하지 않는다. 표시한다.**
///
/// 걸림말은 사용자가 쓴 글을 훑을 수밖에 없어 오탐이 났다. 여기는 다르다 —
/// 밑줄을 그을 문장은 우리가 쓴 문장이라 훑을 이유가 없다.
void main() {
  group('토막으로 가른다', () {
    test('토큰이 없으면 한 토막', () {
      expect(parseTerms('평범한 문장입니다'), [const TermSpan('평범한 문장입니다')]);
    });

    test('앞뒤 글자와 낱말이 갈린다', () {
      expect(parseTerms('법원이 [[지급명령]]을 합니다'), [
        const TermSpan('법원이 '),
        const TermSpan('지급명령', term: '지급명령'),
        const TermSpan('을 합니다'),
      ]);
    });

    test('문장 맨 앞·맨 뒤도 된다', () {
      expect(parseTerms('[[시효]]'), [const TermSpan('시효', term: '시효')]);
    });

    test('둘 이상도 순서대로', () {
      final terms = parseTerms('[[조정]] 과 [[지급명령]]')
          .where((s) => s.isTerm)
          .map((s) => s.term);
      expect(terms, ['조정', '지급명령']);
    });
  });

  group('검사는 대괄호를 뗀 문장을 본다', () {
    test('stripTerms 가 사용자가 읽는 문장을 낸다', () {
      expect(stripTerms('법원이 [[지급명령]]을 합니다'), '법원이 지급명령을 합니다');
    });

    test('토큰이 없으면 그대로', () {
      expect(stripTerms('그대로'), '그대로');
    });

    test('짝이 안 맞는 대괄호는 남는다', () {
      // **화면에 `[[` 가 새는 것을 막는 자리다.**
      expect(hasStrayBrackets('법원이 [[지급명령을 합니다'), isTrue);
      expect(hasStrayBrackets('법원이 [[지급명령]]을 합니다'), isFalse);
    });
  });

  group('음성 골든셋 — 훑지 않으니 걸릴 것이 없다', () {
    /// 자동 부착이었다면 전부 오탐이 났을 문장들.
    ///
    /// 「주소가」⊃「소가」 · 「생각하」⊃「각하」 · 「확정신고」⊃「확정」 ·
    /// 「인용문」⊃「인용」. **마크업 방식이라 당연히 통과한다.** 그래도 잠가
    /// 둔다 — 나중에 누가 자동 부착을 넣으면 여기서 걸린다.
    const clean = <String>[
      '법원에 서류를 내려면 상대방 주소가 필요합니다.',
      '어떻게 생각하시는지 알려 주세요.',
      '확정신고 기간을 확인해 보세요.',
      '인용문은 그대로 두었습니다.',
      '만나기로 한 장소가 어디인가요',
      '최고로 좋은 방법입니다',
    ];

    for (final text in clean) {
      test('"$text"', () {
        expect(termsIn(text), isEmpty);
        expect(parseTerms(text).where((s) => s.isTerm), isEmpty);
      });
    }
  });

  group('조문 원문의 대괄호를 건드리지 않는다', () {
    test('한 겹 대괄호는 토큰이 아니다', () {
      const text = '[별표] 국내 통상우편요금';
      expect(termsIn(text), isEmpty);
      expect(stripTerms(text), text);
    });
  });
}
