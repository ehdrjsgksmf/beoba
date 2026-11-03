import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/providers/result_providers.dart';
import 'package:beoba/src/screens/result/sections/caution_section.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **시효 중단은 판단하지 않는다.** 내용증명이 최고에 해당하는지, 6개월 안에 다음
/// 조치를 했는지는 사실관계 평가라 이 앱의 선을 넘는다.
///
/// 틀리는 방향도 비대칭이다 — 「중단됐습니다」가 틀리면 사용자는 안심하고 기다리다
/// 권리를 영구히 잃는다.
///
/// 그래서 안내만 한다. **날짜는 손대지 않는다.**
///
/// 화면에서는 **물음 버튼**이다. 넷을 펼쳐 놓으면 해당 없는 사람도 넷을 다
/// 지나쳐 내려가야 한다. 눌러야 답이 나온다.
void main() {
  final certifiedMail = {
    ...completeAnswers,
    'q_demanded': 'certified_mail',
  };
  final verbal = {
    ...completeAnswers,
    'q_demanded': 'verbal',
  };

  const mailQuestion = '내용증명을 보내셨나요?';
  const interestQuestion = '이자를 받기로 하셨나요?';

  Future<ProviderContainer> openResult(
    WidgetTester tester,
    Map<String, Object?> answers,
  ) async {
    final container = await pumpApp(tester);
    seedAnswers(container, kDebtRecoveryDomainId, answers: answers);
    container.read(routerProvider).go(Routes.result(kDebtRecoveryDomainId));
    await tester.pumpAndSettle();
    return container;
  }

  /// 물음 하나를 눌러 편다.
  Future<void> ask(WidgetTester tester, String question) async {
    final finder = find.text(question);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// 보이는 물음을 전부 편다.
  Future<void> askAll(WidgetTester tester) async {
    for (var i = 0; i < tester.widgetList(find.byType(CautionQuestion)).length; i++) {
      final finder = find.byType(CautionQuestion).at(i);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
  }

  group('내용증명을 보냈을 때만 나온다', () {
    testWidgets('보냈으면 물음이 뜬다', (tester) async {
      await openResult(tester, certifiedMail);

      expect(find.text(CautionSection.title), findsOneWidget);
      expect(find.text(mailQuestion), findsOneWidget);
    });

    testWidgets('말로만 했으면 그 물음은 안 뜬다', (tester) async {
      // 요구한 적 없는 사람에게 요구 얘기를 안 하는 것뿐이다. 판단이 아니다.
      // 이자 상한 물음은 역할(받을 사람)로 걸리므로 그대로 남는다.
      await openResult(tester, verbal);

      expect(find.text(mailQuestion), findsNothing);
      expect(find.text(interestQuestion), findsOneWidget);
    });
  });

  group('물음은 접혀 있다', () {
    testWidgets('누르기 전에는 답이 안 보인다', (tester) async {
      await openResult(tester, certifiedMail);

      expect(find.textContaining('내용증명을 보내셨다면'), findsNothing);
      expect(find.textContaining('6개월'), findsNothing);
    });

    testWidgets('누르면 조건절과 답이 함께 나온다', (tester) async {
      await openResult(tester, certifiedMail);
      await ask(tester, mailQuestion);

      expect(find.text('내용증명을 보내셨다면'), findsOneWidget);
      expect(find.textContaining('6개월'), findsOneWidget);
    });

    testWidgets('물음은 상태를 단정하지 않는다', (tester) async {
      // 「대부업자이신가요?」가 아니라 「빌려주는 일을 업으로 하시나요?」다.
      // 대부업자인지는 판단이고, 그 판단은 하지 않는다.
      await openResult(tester, certifiedMail);

      expect(find.text('빌려주는 일을 업으로 하시나요?'), findsOneWidget);
      expect(find.textContaining('대부업자이신가요'), findsNothing);
    });
  });

  group('안내일 뿐이다', () {
    testWidgets('창구로 보낸다', (tester) async {
      await openResult(tester, certifiedMail);
      await askAll(tester);

      expect(find.textContaining('창구에서 확인해 보세요'), findsWidgets);
    });

    testWidgets('단정하지 않는다', (tester) async {
      await openResult(tester, certifiedMail);
      await ask(tester, mailQuestion);

      // 「없어졌습니다」가 아니라 「없어질 수 있어요」다.
      expect(find.textContaining('없어질 수 있어요'), findsOneWidget);
      expect(find.textContaining('중단됐습니다'), findsNothing);
      expect(find.textContaining('중단되었습니다'), findsNothing);
    });

    testWidgets('근거 조문 이름이 붙어 있다', (tester) async {
      // 접힌 상태에서는 이름만이다. 원문은 한 번 더 눌러야 나온다.
      await openResult(tester, certifiedMail);
      await ask(tester, mailQuestion);

      expect(find.textContaining('제174조'), findsOneWidget);
    });

    testWidgets('근거가 둘이면 둘 다 보인다', (tester) async {
      // 연 60% 는 시행령에 있고 「계약이 무효가 된다」는 말은 법률 본문에 있다.
      // 하나만 보여주면 사용자가 숫자의 출처를 찾을 수 없다.
      await openResult(tester, certifiedMail);
      await ask(tester, '연 60%가 넘는 이자를 받기로 하셨나요?');

      const effect = '대부업법 제8조의2 제1항';
      const rate = '대부업 등의 등록 및 금융이용자 보호에 관한 법률 시행령 제5조의2 제1항';

      await tester.scrollUntilVisible(
        find.text(effect),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(effect), findsOneWidget);
      expect(find.text(rate), findsOneWidget);
    });

    testWidgets('상한 숫자가 화면에 나온다', (tester) async {
      // 「상한이 있어요」만 말하고 얼마인지 안 말하면 아무것도 안 알려준 것이다.
      await openResult(tester, certifiedMail);
      await ask(tester, interestQuestion);

      expect(find.textContaining('연 20%'), findsOneWidget);
    });

    testWidgets('날짜를 바꾸지 않는다', (tester) async {
      // 같은 답에서 내용증명 여부만 달라져도 기한 계산은 그대로여야 한다.
      final withMail = await openResult(tester, certifiedMail);
      final a = withMail
          .read(deadlineResultsProvider(kDebtRecoveryDomainId))
          .map((d) => '${d.id}:${d.dueDate.toIso()}')
          .toList();

      final withVerbal = await openResult(tester, verbal);
      final b = withVerbal
          .read(deadlineResultsProvider(kDebtRecoveryDomainId))
          .map((d) => '${d.id}:${d.dueDate.toIso()}')
          .toList();

      expect(a, b, reason: '안내가 계산을 건드리면 안 된다');
    });
  });
}
