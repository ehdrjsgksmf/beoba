import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

Domain interviewDomain() => domainFixture(
      scoring: const ScoringConfig(
        greenThreshold: 6,
        yellowThreshold: 4,
        requiredFieldRatio: 0.6,
      ),
      intake: [
        questionFixture(
          id: 'q1',
          order: 1,
          field: 'claimType',
          options: const [
            QuestionOption(value: 'loan', label: '빌려준 돈'),
            QuestionOption(value: 'wage', label: '임금', redirect: 'wage_theft'),
          ],
        ),
        questionFixture(id: 'q2', order: 2, field: 'claimAmount'),
        questionFixture(
          id: 'q3',
          order: 3,
          field: 'courtDocument',
          options: const [
            QuestionOption(value: 'none', label: '없음'),
            QuestionOption(
              value: 'payment_order',
              label: '지급명령',
              setsField: {'hasCourtDocument': true, 'hasPaymentOrder': true},
            ),
          ],
        ),
        questionFixture(
          id: 'q4',
          order: 4,
          field: 'demandDate',
          weight: 1,
          isRequired: false,
          showIf: {
            '!=': [
              {'var': 'demandMethod'},
              'none',
            ],
          },
        ),
      ],
      hardStops: [
        const HardStop(
          id: 'hs_court',
          trigger: FieldHardStopTrigger(
            field: 'hasCourtDocument',
            equalsValue: true,
          ),
          screen: 'hardstop_court',
        ),
      ],
    );

void main() {
  const engine = InterviewEngine();
  final domain = interviewDomain();

  group('InterviewEngine — 다음 질문', () {
    test('order 순으로 아직 답하지 않은 질문을 낸다', () {
      expect(engine.next(domain, const CaseFacts())!.id, 'q1');
      expect(
        engine.next(domain, const CaseFacts({'claimType': 'loan'}))!.id,
        'q2',
      );
    });

    test('showIf 를 만족하지 않는 질문은 건너뛴다', () {
      const facts = CaseFacts({
        'claimType': 'loan',
        'claimAmount': 1000000,
        'courtDocument': 'none',
        'demandMethod': 'none',
      });
      expect(engine.next(domain, facts), isNull);
    });

    test('조건이 맞으면 추가 질문이 나온다', () {
      const facts = CaseFacts({
        'claimType': 'loan',
        'claimAmount': 1000000,
        'courtDocument': 'none',
        'demandMethod': 'certified_mail',
      });
      expect(engine.next(domain, facts)!.id, 'q4');
    });
  });

  group('InterviewEngine — 점수와 판정', () {
    test('답한 질문의 weight 를 더한다', () {
      expect(engine.score(domain, const CaseFacts()), 0);
      expect(
        engine.score(domain, const CaseFacts({'claimType': 'loan'})),
        2,
      );
    });

    test('필수를 다 채우고 임계값을 넘으면 green', () {
      const facts = CaseFacts({
        'claimType': 'loan',
        'claimAmount': 1000000,
        'courtDocument': 'none',
        'demandMethod': 'none',
      });
      expect(engine.readiness(domain, facts), Readiness.green);
    });

    test('일부만 채우면 yellow', () {
      const facts = CaseFacts({
        'claimType': 'loan',
        'claimAmount': 1000000,
        'demandMethod': 'none',
      });
      expect(engine.readiness(domain, facts), Readiness.yellow);
    });

    test('거의 비어 있으면 red', () {
      expect(
        engine.readiness(domain, const CaseFacts({'claimType': 'loan'})),
        Readiness.red,
      );
    });

    test('임계값은 도메인 JSON 에서 읽는다 — 코드에 박혀 있지 않다', () {
      // 같은 사실인데 문턱만 다르다. 판정이 갈리면 판정이 JSON 에서 온다는 뜻이다.
      // 필수는 다 답했고(6점), 선택 문항 하나(1점)가 남아 최대는 7점이다.
      const same = CaseFacts({
        'claimType': 'loan',
        'claimAmount': 1000000,
        'courtDocument': 'none',
        'demandMethod': 'certified_mail',
      });
      expect(engine.maxScore(domain, same), 7);

      final loose = domain.copyWith(
        scoring: const ScoringConfig(greenThreshold: 6, yellowThreshold: 4),
      );
      expect(engine.readiness(loose, same), Readiness.green);

      final strict = domain.copyWith(
        scoring: const ScoringConfig(greenThreshold: 7, yellowThreshold: 4),
      );
      expect(engine.readiness(strict, same), Readiness.yellow);
    });

    test('딸 수 없는 문턱은 딸 수 있는 만큼으로 내려온다', () {
      // **갈래가 짧으면 문턱도 낮아져야 한다.** 문턱이 절대값이라 `showIf` 로
      // 갈라지는 분야에서 짧은 갈래는 영영 red 였다 — 채무자는 문항이 넷인데
      // 문턱이 14였고, 다 답해도 8점이라 결과 화면이 열리지 않았다
      // (DECISIONS 120번).
      //
      // 조용히 덮지는 않는다. 딸 수 있는 최대를 넘는 문턱은 검증기가 센다.
      final impossible = domain.copyWith(
        scoring: const ScoringConfig(greenThreshold: 999, yellowThreshold: 998),
      );
      const all = CaseFacts({
        'claimType': 'loan',
        'claimAmount': 1000000,
        'courtDocument': 'none',
        'demandMethod': 'none',
      });
      expect(engine.maxScore(domain, all), 6);
      expect(engine.readiness(impossible, all), Readiness.green);
    });
  });

  group('InterviewEngine — 답 기록', () {
    test('선택지의 setsField 를 함께 반영한다', () {
      final facts = engine.answer(
        domain,
        const CaseFacts(),
        'q3',
        'payment_order',
      );
      expect(facts.values['courtDocument'], 'payment_order');
      expect(facts.values['hasCourtDocument'], isTrue);
      expect(facts.values['hasPaymentOrder'], isTrue);
    });

    test('없는 질문에 답하면 거부한다', () {
      expect(
        () => engine.answer(domain, const CaseFacts(), 'q_없음', 'x'),
        throwsArgumentError,
      );
    });

    test('다른 분야로 넘겨야 하면 알려준다', () {
      final facts = engine.answer(domain, const CaseFacts(), 'q1', 'wage');
      expect(engine.redirectFor(domain, facts), 'wage_theft');
    });
  });

  group('InterviewEngine — 하드스톱', () {
    test('법원 서류를 받았다고 하면 발동한다', () {
      final facts = engine.answer(
        domain,
        const CaseFacts(),
        'q3',
        'payment_order',
      );
      expect(engine.triggeredHardStops(domain, facts), ['hs_court']);
    });

    test('아니면 발동하지 않는다', () {
      final facts = engine.answer(domain, const CaseFacts(), 'q3', 'none');
      expect(engine.triggeredHardStops(domain, facts), isEmpty);
    });
  });

  group('InterviewEngine — 상태 한 번에', () {
    test('compute 가 전체 상태를 낸다', () {
      final state = engine.compute(
        domain,
        const CaseFacts({'claimType': 'loan'}),
      );
      expect(state.nextQuestion!.id, 'q2');
      expect(state.score, 2);
      expect(state.readiness, Readiness.red);
      expect(state.missingRequiredFields, contains('claimAmount'));
      expect(state.isComplete, isFalse);
    });
  });
}
