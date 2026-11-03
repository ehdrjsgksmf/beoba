import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// **설명 안에 설명이 필요한 말이 있으면 설명이 아니다.**
///
/// 그런데 낱말 목록은 늘릴 때마다 흔한 말 안에 숨은 것을 잡는다. 네 번 겪었다:
/// `각하`⊂생각하다 · `최고`=최고예요 · `인가`⊂인가요 · `소가`⊂주소가.
///
/// 아래 **음성 골든셋**이 그걸 막는다. 목록을 늘릴 때마다 사람이 눈으로 확인하는
/// 것은 오래 못 간다 (DECISIONS 46번).
void main() {
  /// 어떤 낱말도 걸려서는 안 되는 문장들.
  const mustBeClean = <String>[
    // 인터뷰 질문 — "…인가요?" 안에 `인가` 가 숨는다
    '상대방은 어떤 사람인가요?',
    '받지 못한 금액은 얼마인가요?',
    '받아야 할 돈인가요, 갚아야 할 돈인가요?',
    // `주소가` 안에 `소가` 가 숨는다
    '법원에 서류를 내려면 상대방 주소가 필요합니다.',
    '만나기로 한 장소가 어디인가요',
    // `생각하다` 안에 `각하` 가 숨는다
    '생각하시는 대로 하시면 됩니다',
    '어떻게 생각하세요',
    // `최고` 는 "가장 좋다" 로 훨씬 자주 쓰인다
    '최고예요',
    '최고로 좋은 방법입니다',
    // 그 밖에 흔한 말 안에 숨는 것
    '원고지에 적었어요',
    '원고료를 받았습니다',
    '피고용인 신분입니다',
    '상계좌를 확인했어요',
    // 평범한 안내 문장
    '돈을 빌려줬다고 적어 둔 종이예요',
    '법원에 소송을 낼 때 내는 수수료예요',
    '있었던 일을 그대로 적어 주세요',
  ];

  group('음성 골든셋 — 걸리면 안 되는 문장', () {
    for (final text in mustBeClean) {
      test('"$text"', () {
        final hits = LegalJargon.findAll(text);
        expect(
          hits.map((h) => h.word),
          isEmpty,
          reason: '흔한 말 안에 숨은 낱말을 잡았습니다. except 로 좁히세요',
        );
      });
    }
  });

  group('갈래를 가른다', () {
    test('사용자가 마주칠 일 없는 말은 교체 대상', () {
      expect(LegalJargon.find('송달받은 날부터')?.kind, JargonKind.replace);
      expect(LegalJargon.find('소송절차로 넘어갑니다')?.kind, JargonKind.replace);
      expect(LegalJargon.find('변제금액은 법원이 정합니다')?.kind, JargonKind.replace);
    });

    test('서류·법원에서 마주치는 말은 병기 대상', () {
      // 갈아치우면 사용자가 현장에서 그 이름을 못 찾는다.
      expect(LegalJargon.find('이의신청을 하면')?.kind, JargonKind.annotate);
      expect(LegalJargon.find('지급명령을 받았습니다')?.kind, JargonKind.annotate);
      expect(LegalJargon.find('내가 원고인지 확인')?.kind, JargonKind.annotate);
      expect(LegalJargon.find('채무자대리인 무료지원')?.kind, JargonKind.annotate);
    });

    test('무엇을 할지 메시지가 다르다', () {
      expect(LegalJargon.find('송달받은')?.action, '쉬운 말로 갈아타세요');
      expect(LegalJargon.find('이의신청')?.action, '풀이를 붙이세요');
    });
  });

  group('예외가 히트를 덮는다', () {
    test('채무자대리인은 제도 이름이라 채무자로 잡지 않는다', () {
      final hits = LegalJargon.findAll('채무자대리인 무료지원 신청 가능');
      expect(hits.map((h) => h.word), isNot(contains('채무자')));
      expect(hits.map((h) => h.word), contains('채무자대리인'));
    });

    test('채권추심은 채권으로 잡지 않는다', () {
      final hits = LegalJargon.findAll('채권추심은 등록된 회사만 할 수 있습니다');
      expect(hits.map((h) => h.word), isNot(contains('채권')));
      expect(hits.map((h) => h.word), contains('채권추심'));
    });

    test('공시송달은 송달로 잡지 않는다', () {
      // 제도 이름이다. 안쪽의 `송달` 까지 갈아타라고 하면 이름을 쓸 수 없다.
      final hits = LegalJargon.findAll('법원이 인정하면 공시송달로 진행할 수 있습니다');
      expect(hits.map((h) => h.word), isNot(contains('송달')));
      expect(hits.map((h) => h.word), contains('공시송달'));
    });

    test('소멸시효는 시효로 두 번 잡지 않는다', () {
      final hits = LegalJargon.findAll('소멸시효가 지났습니다');
      expect(hits.map((h) => h.word), isNot(contains('시효')));
    });
  });

  group('whatIsThis 전용 규칙', () {
    test('자기 자신의 label 은 동어반복이라 잡는다', () {
      expect(LegalJargon.find('송달료는 서류 보내는 값이에요', self: '송달료')?.word, '송달료');
    });

    test('자동 수집은 whatIsThis 에만 넘긴다', () {
      const text = '계좌이체 내역이 있습니다';
      // 일반 문장 — 어려운 말이 아니다
      expect(LegalJargon.findAll(text), isEmpty);
      // 풀이 안 — 다른 항목을 참조하지 마라
      expect(
        LegalJargon.find(text, labels: const ['계좌이체 내역'])?.word,
        '계좌이체 내역',
      );
    });
  });

  test('목록이 두 갈래 다 비어 있지 않다', () {
    expect(LegalJargon.replaceTerms, isNotEmpty);
    expect(LegalJargon.annotateTerms, isNotEmpty);
  });
}
