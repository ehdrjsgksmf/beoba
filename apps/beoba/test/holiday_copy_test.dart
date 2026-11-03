import 'package:beoba/src/providers/domain_providers.dart';
import 'package:beoba/src/screens/result/sections/period_rule_section.dart';
import 'package:domain_data/domain_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// **없는 것을 말하는 자리.**
///
/// 쉬는 날 표는 몇 해까지만 있다. 그 뒤 날짜는 토·일만 미는데, 조용히 그러면
/// 사용자는 자기 기한이 어디까지 반영된 것인지 모른다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rules = [
    LegalBasis(
      law: '민법',
      article: '제161조',
      text: '기간의 말일이 토요일 또는 공휴일에 해당한 때에는 기간은 그 익일로 만료한다.',
    ),
  ];

  group('어디까지 반영했는지 말한다', () {
    testWidgets('표가 있으면 몇 년까지인지 적는다', (tester) async {
      await pumpWidgetOnly(
        tester,
        const PeriodRuleSection(rules: rules, lastCoveredYear: 2027),
      );

      expect(find.textContaining(PeriodRuleSection.coverage(2027)), findsOneWidget);
      expect(find.text(PeriodRuleSection.intro), findsOneWidget);
    });

    testWidgets('표가 없으면 토·일만 민다고 적는다', (tester) async {
      await pumpWidgetOnly(tester, const PeriodRuleSection(rules: rules));

      expect(find.text(PeriodRuleSection.introWeekendOnly), findsOneWidget);
      expect(find.textContaining('쉬는 날이면'), findsNothing);
    });

    testWidgets('데이터를 넣어도 임시공휴일 문구는 남는다', (tester) async {
      // 규정 제2조 제11호는 국무회의로 그때그때 정해져 **미래는 영영 모른다.**
      await pumpWidgetOnly(
        tester,
        const PeriodRuleSection(rules: rules, lastCoveredYear: 2027),
      );

      expect(find.textContaining('쉬는 날이 갑자기 생기면'), findsOneWidget);
      expect(find.textContaining('빨라지지는 않으니'), findsOneWidget);
    });
  });

  group('앱이 실제로 표를 들고 있다', () {
    testWidgets('부트스트랩이 세 해를 읽는다', (tester) async {
      final container = await pumpApp(tester);
      final holidays =
          container.read(domainBundleProvider).requireValue.holidays;

      expect(holidays.years, {2025, 2026, 2027});
      expect(holidays.lastCoveredYear, 2027);
      expect(holidays.isClosed(const KstDate(2026, 3, 2)), isTrue);
      // 표 밖의 평일은 열린 날이다. **모르는 것을 아는 척하지 않는다.**
      expect(holidays.isClosed(const KstDate(2030, 1, 1)), isFalse);
    });
  });
}
