import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// 낱말 검사는 **사용자가 타이핑한 문자열에만** 한다.
///
/// 같은 낱말이라도 누가 썼는지에 따라 뜻이 다르다. 선택지 라벨은 우리가 쓴 말이고,
/// 그걸 사용자가 쓴 말처럼 다루면 우리가 만든 문장에 우리가 걸린다.
void main() {
  const engine = InterviewEngine();

  const stop = HardStop(
    id: 'hs_test',
    trigger: KeywordHardStopTrigger(patterns: ['고소']),
    screen: 'hardstop_test',
    title: '테스트 정지',
  );

  group('userTypedText — 무엇을 보는가', () {
    test('type: text 질문의 답을 본다', () {
      final domain = domainFixture(
        intake: [
          questionFixture(
            id: 'q_story',
            order: 1,
            field: 'story',
            type: QuestionType.text,
          ),
        ],
      );

      expect(freeTextFields(domain), {'story'});
      expect(
        userTypedText(domain, const CaseFacts({'story': '고소하려고 합니다'})),
        ['고소하려고 합니다'],
      );
    });

    test('선택지 값은 보지 않는다', () {
      final domain = domainFixture(
        intake: [
          questionFixture(id: 'q_pick', order: 1, field: 'pick'),
        ],
      );

      // 선택지 value 가 한글이어도 사용자가 타이핑한 것이 아니다.
      expect(
        userTypedText(domain, const CaseFacts({'pick': '고소하겠다고 함'})),
        isEmpty,
      );
    });

    test('금액·날짜·불리언은 보지 않는다', () {
      final domain = domainFixture();
      expect(
        userTypedText(
          domain,
          const CaseFacts({
            'amount': 50000, // not-a-legal-number: 테스트 입력값
            'due': KstDate(2026, 8, 15),
            'hasDoc': true,
          }),
        ),
        isEmpty,
      );
    });

    test('extraFields 로 도메인 밖 자유 입력을 더한다', () {
      final domain = domainFixture();
      expect(
        userTypedText(
          domain,
          const CaseFacts({'userNarrative': '고소하려고 합니다'}),
          extraFields: const {'userNarrative'},
        ),
        ['고소하려고 합니다'],
      );
    });
  });

  group('하드스톱 — 같은 낱말이라도 출처를 가린다', () {
    test('선택지를 골라서 생긴 값으로는 걸리지 않는다', () {
      // 우리가 쓴 선택지 문구가 우리 하드스톱에 걸리면 안 된다.
      final domain = domainFixture(
        intake: [
          questionFixture(
            id: 'q_response',
            order: 1,
            field: 'response',
            options: const [
              QuestionOption(value: '고소하겠다고 함', label: '고소하겠다고 합니다'),
            ],
          ),
        ],
        hardStops: [stop],
      );

      final facts = engine.answer(domain, const CaseFacts(), 'q_response', '고소하겠다고 함');

      expect(facts.values['response'], '고소하겠다고 함');
      expect(engine.triggeredHardStops(domain, facts), isEmpty);
    });

    test('setsField 로 들어온 값으로도 걸리지 않는다', () {
      final domain = domainFixture(
        intake: [
          questionFixture(
            id: 'q_pick',
            order: 1,
            field: 'pick',
            options: const [
              QuestionOption(
                value: 'yes',
                label: '네',
                setsField: {'note': '고소 예정'},
              ),
            ],
          ),
        ],
        hardStops: [stop],
      );

      final facts = engine.answer(domain, const CaseFacts(), 'q_pick', 'yes');

      expect(facts.values['note'], '고소 예정');
      expect(engine.triggeredHardStops(domain, facts), isEmpty);
    });

    test('사용자가 타이핑한 자유 서술로는 걸린다', () {
      final domain = domainFixture(
        intake: [
          questionFixture(
            id: 'q_story',
            order: 1,
            field: 'story',
            type: QuestionType.text,
          ),
        ],
        hardStops: [stop],
      );

      final facts = engine.answer(
        domain,
        const CaseFacts(),
        'q_story',
        '고소하려고 합니다',
      );

      expect(engine.triggeredHardStops(domain, facts), ['hs_test']);
    });

    test('extraTextFields 로 넘긴 자유 입력으로도 걸린다', () {
      final domain = domainFixture(hardStops: [stop]);

      expect(
        engine.triggeredHardStops(
          domain,
          const CaseFacts({'userNarrative': '고소하려고 합니다'}),
          extraTextFields: const {'userNarrative'},
        ),
        ['hs_test'],
      );
      // 넘기지 않으면 보지 않는다.
      expect(
        engine.triggeredHardStops(
          domain,
          const CaseFacts({'userNarrative': '고소하려고 합니다'}),
        ),
        isEmpty,
      );
    });

    test('필드 트리거는 문자열 검사와 무관하게 그대로 동작한다', () {
      const fieldStop = HardStop(
        id: 'hs_field',
        trigger: FieldHardStopTrigger(field: 'hasDoc', equalsValue: true),
        screen: 'hardstop_field',
      );
      final domain = domainFixture(hardStops: [fieldStop]);

      expect(
        engine.triggeredHardStops(domain, const CaseFacts({'hasDoc': true})),
        ['hs_field'],
      );
    });
  });
}
