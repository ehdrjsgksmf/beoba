import 'package:beoba/src/interview/interview_session.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:engines/engines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 인터뷰를 뒤로 돌리거나 고칠 때 **이전 답의 부산물이 남지 않는지** 본다.
///
/// `InterviewEngine.answer` 는 merge 만 한다. 선택지의 `setsField` 로 켜진 값을
/// 되돌리는 방법이 없다. 그래서 리플레이로 처음부터 다시 접는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    container = await bootstrappedContainer();
  });

  InterviewController controller() =>
      container.read(interviewSessionProvider(kDebtRecoveryDomainId).notifier);

  CaseFacts facts() => container.read(caseFactsProvider(kDebtRecoveryDomainId));

  ReplayResult replay() => container.read(replayProvider(kDebtRecoveryDomainId));

  /// 지금 답해야 할 질문. 커서가 아니라 **답한 것에서 파생된다** — 어느 질문을
  /// 보고 있는지는 라우트가 안다.
  String? currentQuestionId() {
    final step = container.read(currentStepProvider(kDebtRecoveryDomainId));
    if (step == null) return null;
    final questions =
        container.read(applicableQuestionsProvider(kDebtRecoveryDomainId));
    return questionAtStep(questions, step)?.id;
  }

  group('리플레이 — setsField 부산물', () {
    test('법원 서류를 없음으로 고치면 hasCourtDocument 가 사라진다', () {
      // 예전에는 `hasPaymentOrder` 로 이걸 확인했다. 그 필드는 아무도 안 읽는
      // 파생값이라 지웠다 — `courtDocument == "payment_order"` 로 이미 판별되고
      // 기한의 showIf 도 그쪽을 본다. 검사 (g)가 찾아냈다.
      controller().answer('q_role', 'creditor');
      controller().answer('q_court_document', 'payment_order');

      expect(facts().get<bool>('hasCourtDocument'), isTrue);
      expect(facts().get<String>('courtDocument'), 'payment_order');

      controller().answer('q_court_document', 'none');

      // merge 만 했다면 여기서 true 가 남는다. 그게 이 테스트가 막는 버그다.
      expect(facts().has('hasCourtDocument'), isFalse);
      expect(facts().get<String>('courtDocument'), 'none');
    });

    test('소장으로 고치면 앞의 갈래 값이 남지 않는다', () {
      controller().answer('q_role', 'creditor');
      controller().answer('q_court_document', 'payment_order');
      controller().answer('q_court_document', 'complaint');

      expect(facts().get<bool>('hasCourtDocument'), isTrue);
      expect(facts().get<String>('courtDocument'), 'complaint');
    });
  });

  group('리플레이 — showIf 로 닫힌 가지', () {
    test('독촉을 안 했다고 고치면 독촉 날짜 답이 사라진다', () {
      // q_demand_date 의 showIf: 받을 쪽이면서 demandMethod != none
      controller().answer('q_role', 'creditor');
      controller().answer('q_demanded', 'certified_mail');
      controller().answer('q_demand_date', const KstDate(2026, 7, 1));

      expect(facts().date('demandDate'), const KstDate(2026, 7, 1));

      controller().answer('q_demanded', 'none');

      expect(facts().has('demandDate'), isFalse);
      expect(
        replay().kept.map((s) => s.questionId),
        isNot(contains('q_demand_date')),
      );
    });

    test('버려진 답은 세션에서도 지워진다 (다시 열려도 되살아나지 않는다)', () {
      controller().answer('q_role', 'creditor');
      controller().answer('q_demanded', 'verbal');
      controller().answer('q_demand_date', const KstDate(2026, 7, 1));
      controller().answer('q_demanded', 'none');

      // 가지를 다시 열어도 옛 답이 조용히 돌아오면 안 된다. 다시 물어야 한다.
      controller().answer('q_demanded', 'verbal');

      expect(facts().has('demandDate'), isFalse);
    });
  });

  group('리플레이 — 역할 갈래', () {
    test('받을 쪽에서 갚을 쪽으로 고치면 받을 쪽 답이 사라진다', () {
      controller().answer('q_role', 'creditor');
      controller().answer('q_court_document', 'none');
      controller().answer('q_claim_type', 'loan');
      controller().answer('q_amount', 5000000); // not-a-legal-number: 테스트 입력

      expect(facts().money('claimAmount'), 5000000); // not-a-legal-number: 테스트 입력

      controller().answer('q_role', 'debtor');

      // merge 만 했다면 갚을 쪽 사람의 사건에 청구금액이 남는다.
      expect(facts().has('claimAmount'), isFalse);
      expect(facts().has('claimType'), isFalse);
      expect(currentQuestionId(), 'q_debtor_situation');
    });

    test('갚을 쪽은 물음이 넷에서 끝난다', () {
      controller().answer('q_role', 'debtor');
      controller().answer('q_debtor_situation', 'court_document');
      controller().answer('q_court_document', 'payment_order');

      final ids = container
          .read(applicableQuestionsProvider(kDebtRecoveryDomainId))
          .map((q) => q.id)
          .toList();

      expect(ids, [
        'q_role',
        'q_debtor_situation',
        'q_court_document',
        'q_payment_order_served_date',
      ]);
    });

    test('압류는 물음이 넷에서 끝난다', () {
      // 하나가 늘었다. **언제 들어온 압류인지에 따라 금액이 갈린다** —
      // 시행령 부칙 제2조의 적용례다(DECISIONS 124번).
      //
      // ★ 또 하나가 늘었다(2026-09-04). 「법원에서 서류를 받았나」를
      // 예전에는 받는 쪽과 「서류를 받았어요」를 고른 사람에게만 물었다.
      // 그래서 **압류를 당했다고 답한 사람에게 지급명령 이의신청 2주가
      // 영영 안 닿았다** — 압류는 집행권원이 있다는 뜻이니 그 사람도
      // 서류를 받았을 텐데도. 기한도 조문도 처음부터 있었고 물음이 없어서
      // 못 닿았을 뿐이다.
      controller().answer('q_role', 'debtor');
      controller().answer('q_debtor_situation', 'seizure');

      expect(
        container
            .read(applicableQuestionsProvider(kDebtRecoveryDomainId))
            .map((q) => q.id),
        ['q_role', 'q_debtor_situation', 'q_seizure_when', 'q_court_document'],
      );
    });
  });

  group('진행 위치는 답에서 파생된다', () {
    // 어느 질문을 보고 있는지는 **라우트가 안다.** 세션에 커서를 들고 있으면
    // 앱 안 버튼과 브라우저·하드웨어 뒤로가기가 서로 다르게 움직인다.

    test('답할수록 순번이 앞으로 간다', () {
      expect(container.read(currentStepProvider(kDebtRecoveryDomainId)), 1);
      expect(currentQuestionId(), 'q_role');

      // **서류부터 묻는다.** whyAsk 가 「기한이 정해진 서류라면 다른 무엇보다
      // 먼저」라고 적어 두고서 열두 번째로 묻고 있었다(DECISIONS 121번).
      controller().answer('q_role', 'creditor');
      expect(currentQuestionId(), 'q_court_document');

      controller().answer('q_court_document', 'none');
      expect(currentQuestionId(), 'q_claim_type');
    });

    test('이미 답한 질문을 고쳐도 답이 남고 순번이 되돌아가지 않는다', () {
      controller().answer('q_role', 'creditor');
      controller().answer('q_court_document', 'none');
      controller().answer('q_claim_type', 'loan');
      controller().answer('q_amount', 5000000); // not-a-legal-number: 테스트 입력

      controller().answer('q_claim_type', 'goods');

      expect(facts().get<String>('claimType'), 'goods');
      expect(facts().money('claimAmount'), 5000000); // not-a-legal-number: 테스트 입력
      expect(container.read(currentStepProvider(kDebtRecoveryDomainId)), 5);
    });

    test('가지가 닫히면 물어야 할 질문 수가 줄어든다', () {
      int applicable() => container
          .read(applicableQuestionsProvider(kDebtRecoveryDomainId))
          .length;

      // q_demand_date 의 showIf 는 `demandMethod != "none"` 이라 답하기 전에도
      // 열려 있다. 닫히는 것은 "독촉한 적 없다" 를 고른 순간이다.
      controller().answer('q_role', 'creditor');
      final open = applicable();

      controller().answer('q_demanded', 'certified_mail');
      expect(applicable(), open);

      controller().answer('q_demanded', 'none');
      expect(applicable(), open - 1);

      controller().answer('q_demanded', 'verbal');
      expect(applicable(), open);
    });

    test('다 답하면 순번이 없어진다 (정리 카드로 갈 차례)', () {
      seedAnswers(container, kDebtRecoveryDomainId);
      expect(container.read(currentStepProvider(kDebtRecoveryDomainId)), isNull);
    });
  });

  group('리플레이 — 자유 입력', () {
    test('홈에서 받은 서술이 사실에 실린다', () {
      controller().start('  빌려준 돈을 못 받고 있습니다  ');

      expect(
        facts().text(InterviewSession.narrativeField),
        '빌려준 돈을 못 받고 있습니다',
      );
    });

    test('시작하면 이전 인터뷰가 초기화된다', () {
      controller().answer('q_claim_type', 'loan');
      controller().start('처음부터 다시');

      expect(facts().has('claimType'), isFalse);
    });
  });
}
