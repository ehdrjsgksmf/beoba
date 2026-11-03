import 'package:beoba/src/app/router.dart';
import 'package:beoba/src/providers/domain_providers.dart';
import 'package:engines/engines.dart' show KstDate;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// 못 받은 임금 — **사업장 규모로 다시 세어 본 뒤.**
///
/// 근기법 시행령 [별표 1]이 4명 이하에 적용되는 조문을 정한다. 이 분야가
/// 그 표 밖의 돈을 세어 주고 있었는지 확인하는 자리다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const domainId = 'wage_theft';
  const answers = <String, Object?>{
    'q_work_status': 'left',
    'q_last_work_date': KstDate(2026, 8, 15),
    'q_pay_due_date': KstDate(2026, 7, 25),
  };

  Future<ProviderContainer> openResult(WidgetTester tester) async {
    final container = await pumpApp(tester);
    seedAnswers(container, domainId, answers: answers);
    container.read(routerProvider).go(Routes.result(domainId));
    await tester.pumpAndSettle();
    return container;
  }

  group('★ 규모로 갈리는 돈을 세어 주고 있지 않다', () {
    testWidgets('가산수당·연차를 근거로 쓰는 항목이 하나도 없다', (tester) async {
      final container = await pumpApp(tester);
      final domain =
          container.read(domainBundleProvider).requireValue.byId(domainId);

      // [별표 1]의 제4장 란은 셋뿐이라 가산수당도 연차도 거기 없다.
      // 4명 이하인 분에게 **받을 수 없는 돈을 세어 주면** 안 된다.
      final cited = <String>[
        for (final caution in domain.cautions) ...[
          if (caution.legalBasis case final basis?)
            '${basis.law} ${basis.article}',
          for (final also in caution.alsoBasis) '${also.law} ${also.article}',
        ],
        for (final deadline in domain.deadlines)
          '${deadline.legalBasis.law} ${deadline.legalBasis.article}',
        for (final cost in domain.costs)
          if (cost.legalBasis case final basis?) '${basis.law} ${basis.article}',
        for (final procedure in domain.procedures) ...[
          if (procedure.legalBasis case final basis?)
            '${basis.law} ${basis.article}',
          for (final also in procedure.alsoBasis) '${also.law} ${also.article}',
        ],
      ];

      // 조문 번호를 문자열로 박지 않는다 — 검증기가 소스의 조문 꼴을
      // 전수로 훑어서 매니페스트에 없는 번호를 잡는다.
      for (final number in const [56, 60]) {
        expect(cited, isNot(contains('근로기준법 제$number조')));
      }
    });

    testWidgets('★ 「작은 데라서 못 받는다」를 한 줄로 막는다', (tester) async {
      final container = await openResult(tester);
      final card = container
          .read(domainBundleProvider)
          .requireValue
          .byId(domainId)
          .cautions
          .firstWhere((c) => c.id == 'ct_size_does_not_matter');

      // 뼈대(14일·3년)는 [별표 1] 안에 있다.
      expect(card.consequence, contains('그대로 적용된다'));
      expect(card.consequence, contains('14일'));
      expect(card.consequence, contains('3년'));
      // 없는 것도 같이 말한다. 안 적으면 「전부 걸린다」로 읽힌다.
      expect(card.consequence, contains('가산수당과 연차휴가는 그 표에 없어요'));
      expect(card.alsoBasis.map((b) => b.article), contains('[별표 1]'));
    });
  });
}
