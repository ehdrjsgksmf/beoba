import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// **사물을 높이지 않는다.** 높이는 대상은 사용자뿐이다.
///
/// 「50,000,000원이시군요」는 「주문하신 커피 나오셨습니다」와 같은 오류다.
/// 이 앱은 정확함을 파는데, 문법이 틀리면 그 인상이 계산까지 번진다.
void main() {
  group('값 바로 뒤의 존대를 잡는다', () {
    // 되받는 말에 끼워지는 값은 금액·날짜·선택지뿐이고 **사람인 적이 없다.**
    const bad = <String>[
      '{value}이시군요.',
      '{value}이세요',
      '{value}이십니다',
      '{value}세요',
      '{value}시군요',
    ];

    for (final text in bad) {
      test('"$text" 는 사물 존대다', () {
        expect(ObjectHonorific.find(text), isNotNull);
      });
    }
  });

  group('사용자를 높이는 것은 잡지 않는다', () {
    const fine = <String>[
      '{value}이군요.',
      '{value}입니다',
      '{value}에 받기로 하셨군요.',
      '{value}에 요구하셨군요.',
      '{value}을 적어 주셨네요',
      '{value}원을 받으셔야 합니다',
    ];

    for (final text in fine) {
      test('"$text" 는 괜찮다', () {
        expect(ObjectHonorific.find(text), isNull, reason: text);
      });
    }
  });

  group('단위 낱말 + 존대', () {
    test('금액에 -이시- 는 붙을 수 없다', () {
      expect(ObjectHonorific.find('오천만원이시군요'), '원이시');
      expect(ObjectHonorific.find('총 3건이시네요'), '건이시');
    });

    test('멀쩡한 한국어는 잡지 않는다', () {
      // 좁게만 잡는다. 오탐이 나면 검사가 무뎌지고 사람이 무시하게 된다.
      const mustBeClean = <String>[
        '무슨 일이세요?',
        '세 명이시군요',
        '두 분이세요',
        '언제까지 받기로 하셨나요?',
        '5,000만원이군요.',
        '어떤 분이세요',
        '고객이시군요',
        '변호사이십니다',
      ];
      for (final text in mustBeClean) {
        expect(ObjectHonorific.find(text), isNull, reason: text);
      }
    });
  });

  group('실제 문구', () {
    test('고친 되받기는 통과한다', () {
      expect(ObjectHonorific.find('{value}이군요.'), isNull);
    });

    test('고치기 전 문구는 걸린다', () {
      // 이 검사를 만든 계기다. 사람이 읽고 잡았고, 이제 기계가 잡는다.
      expect(ObjectHonorific.find('{value}이시군요.'), isNotNull);
    });
  });
}
