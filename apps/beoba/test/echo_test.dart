import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/format/formatters.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/interview_providers.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 아무 반응 없이 다음 질문으로 가면 **시험지가 된다.**
///
/// 한 줄 되받는 것만으로 "얘가 내 말을 듣고 있다" 가 생긴다. 리플레이가 답을 다
/// 들고 있으니 문자열 조합이고, 비용도 위험도 없다.
void main() {
  const question = Question(
    id: 'q_amount',
    order: 3,
    text: '받지 못한 금액은 얼마인가요?',
    whyAsk: '금액에 따라 절차와 비용이 달라집니다.',
    echo: '{value}이군요.',
    type: QuestionType.money,
    field: 'claimAmount',
  );

  group('값을 그대로 되받는다', () {
    test('금액', () {
      expect(formatEcho(question, 50000000), '50,000,000원이군요.');
    });

    test('어림 날짜는 어림 그대로', () {
      // 보정해서 되받으면 사용자는 자기가 그렇게 답한 줄 안다.
      const dated = Question(
        id: 'q_due_date',
        order: 5,
        text: '언제까지 받기로 하셨나요?',
        whyAsk: '기준점이 됩니다.',
        echo: '{value}에 받기로 하셨군요.',
        type: QuestionType.date,
        field: 'dueDate',
      );
      expect(
        formatEcho(dated, const ApproxDate(2023, 3)),
        '2023년 3월에 받기로 하셨군요.',
      );
      expect(
        formatEcho(dated, const ApproxDate(2023, 3, 15)),
        '2023년 3월 15일에 받기로 하셨군요.',
      );
    });

    test('되받을 말이 없으면 아무것도 안 만든다', () {
      const plain = Question(
        id: 'q_plain',
        order: 1,
        text: '무엇인가요?',
        whyAsk: '필요합니다.',
        type: QuestionType.single,
        field: 'x',
      );
      expect(formatEcho(plain, 'yes'), isNull);
    });

    test('답이 없으면 아무것도 안 만든다', () {
      expect(formatEcho(question, null), isNull);
    });
  });

  group('해석을 붙이지 않는다', () {
    testWidgets('되받는 말은 전부 값을 그대로 끼운다', (tester) async {
      // "{value}을 빌려주셨군요" 는 앞 답이 보증금이면 거짓이 된다.
      // 값을 그대로 되받으면 틀릴 수 없다.
      final bundle = await tester.runAsync(loadTestBundle);
      var found = 0;
      for (final domain in bundle!.domains.values) {
        for (final q in domain.intake) {
          if (q.echo.isEmpty) continue;
          found++;
          expect(q.echo.contains('{value}'), isTrue, reason: q.id);
        }
      }
      expect(found, greaterThan(0), reason: '되받는 질문이 하나도 없습니다');
    });

    testWidgets('★ 화면에서는 열두 번 다 되받지 않는다', (tester) async {
      // **규칙이 옮겨 갔다.** 예전에는 데이터에 금액·날짜만 되받는 말을
      // 두어서 화면이 저절로 조용했다. 지금은 거의 모든 물음에 있다 —
      // **정리해서 가져가는 글**의 「내 상황」 절을 만들려면 다 필요하다.
      //
      // 그래서 거르는 자리를 화면으로 옮겼다. 데이터를 두 벌로 나누지
      // 않는다. 여기서는 **화면이 실제로 거르는지**를 본다.
      final bundle = await tester.runAsync(loadTestBundle);
      final domain = bundle!.domains[kDebtRecoveryDomainId]!;
      final shown = domain.intake.where(
        (q) =>
            q.echo.isNotEmpty &&
            (q.type == QuestionType.money || q.type == QuestionType.date),
      );
      expect(shown.length, lessThan(domain.intake.length ~/ 2));
    });
  });

  group('화면에서', () {
    testWidgets('금액을 답하면 다음 질문 위에 되받는 말이 나온다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(
        container,
        kDebtRecoveryDomainId,
        answers: const {
          'q_role': 'creditor',
          'q_court_document': 'none',
          'q_claim_type': 'loan',
          'q_amount': 50000000, // not-a-legal-number: 테스트 입력값
        },
      );

      // q_amount 는 4번, 그다음이 5번이다. 법원 서류 문항이 맨 앞으로 올라와
      // 한 칸씩 밀렸다(DECISIONS 121번).
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 5));
      await tester.pumpAndSettle();

      expect(find.text('50,000,000원이군요.'), findsOneWidget);
      expect(find.text('언제까지 받기로 하셨나요?'), findsOneWidget);
    });

    testWidgets('되받기가 없는 질문 뒤에는 아무것도 안 나온다', (tester) async {
      final container = await pumpApp(tester);
      seedAnswers(
        container,
        kDebtRecoveryDomainId,
        answers: const {'q_role': 'creditor'},
      );

      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 2));
      await tester.pumpAndSettle();

      expect(find.textContaining('이시군요'), findsNothing);
      expect(find.textContaining('군요'), findsNothing);
    });

    testWidgets('첫 질문에는 되받을 것이 없다', (tester) async {
      final container = await pumpApp(tester);
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('군요'), findsNothing);
    });

    testWidgets('자유 서술은 되받지 않는다', (tester) async {
      // 가장 사적인 문장이라 화면에 다시 띄우면 옆사람이 본다.
      const secret = '남편이 몰래 빌려준 돈입니다';
      final container = await pumpApp(tester);
      container
          .read(interviewSessionProvider(kDebtRecoveryDomainId).notifier)
          .start(secret);
      container.read(routerProvider).go(Routes.interview(kDebtRecoveryDomainId, 1));
      await tester.pumpAndSettle();

      expect(find.text(secret), findsNothing);
    });
  });
}

