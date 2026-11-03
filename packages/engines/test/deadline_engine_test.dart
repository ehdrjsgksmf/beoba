import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  rollForwardTests();

  const clock = FixedKstClock(KstDate(2026, 8, 15));
  // 이 파일은 **기간 계산**만 본다. 민법 제161조(말일이 토·일이면 익일)는 달력에
  // 달려 있어서 섞으면 어느 규칙이 틀렸는지 알 수 없다. 제161조는 아래 따로 잠근다.
  const engine = DeadlineEngine(clock, holidays: OpenEveryDayRule());

  group('DeadlineEngine — calcRule 4종', () {
    test('from_basis — 기산일 + offset', () {
      final deadline = deadlineFixture(id: 'dl', offsetValue: 2, offsetUnit: TimeUnit.week);
      final result = engine.computeOne(
        deadline,
        const CaseFacts({'basisDate': KstDate(2026, 8, 15)}),
      );
      expect(result!.dueDate, const KstDate(2026, 8, 29));
    });

    test('from_month_end — 기산일이 속한 달의 말일 + offset (상속세 패턴)', () {
      final deadline = deadlineFixture(
        id: 'dl',
        calcRule: CalcRule.fromMonthEnd,
        offsetValue: 6,
        offsetUnit: TimeUnit.month,
      );
      final result = engine.computeOne(
        deadline,
        const CaseFacts({'basisDate': KstDate(2026, 3, 15)}),
      );
      expect(result!.dueDate, const KstDate(2026, 9, 30));
    });

    test('from_known_date — "안 날" 필드를 우선한다', () {
      final deadline = deadlineFixture(
        id: 'dl',
        calcRule: CalcRule.fromKnownDate,
        knownDateField: 'knownAt',
        offsetValue: 3,
        offsetUnit: TimeUnit.month,
      );
      final result = engine.computeOne(
        deadline,
        const CaseFacts({
          'basisDate': KstDate(2026, 1, 1),
          'knownAt': KstDate(2026, 5, 31),
        }),
      );
      expect(result!.dueDate, const KstDate(2026, 8, 31));
    });

    test('from_known_date — "안 날"이 없으면 기산일로 대신한다', () {
      final deadline = deadlineFixture(
        id: 'dl',
        calcRule: CalcRule.fromKnownDate,
        knownDateField: 'knownAt',
        offsetValue: 3,
        offsetUnit: TimeUnit.month,
      );
      final result = engine.computeOne(
        deadline,
        const CaseFacts({'basisDate': KstDate(2026, 1, 31)}),
      );
      expect(result!.dueDate, const KstDate(2026, 4, 30));
    });

    test('fixed_annual — 올해 날짜가 지났으면 내년', () {
      final passed = deadlineFixture(
        id: 'dl_passed',
        calcRule: CalcRule.fixedAnnual,
        fixedMonth: 3,
        fixedDay: 31,
      );
      final upcoming = deadlineFixture(
        id: 'dl_upcoming',
        calcRule: CalcRule.fixedAnnual,
        fixedMonth: 12,
        fixedDay: 31,
      );
      expect(
        engine.computeOne(passed, const CaseFacts())!.dueDate,
        const KstDate(2027, 3, 31),
      );
      expect(
        engine.computeOne(upcoming, const CaseFacts())!.dueDate,
        const KstDate(2026, 12, 31),
      );
    });
  });

  group('DeadlineEngine — 경계', () {
    test('월말을 넘기면 클램프한다', () {
      final deadline = deadlineFixture(
        id: 'dl',
        offsetValue: 1,
        offsetUnit: TimeUnit.month,
      );
      final result = engine.computeOne(
        deadline,
        const CaseFacts({'basisDate': KstDate(2026, 1, 31)}),
      );
      expect(result!.dueDate, const KstDate(2026, 2, 28));
    });

    test('윤년을 지나도 맞는다', () {
      final deadline = deadlineFixture(
        id: 'dl',
        offsetValue: 30,
        offsetUnit: TimeUnit.day,
      );
      final result = engine.computeOne(
        deadline,
        const CaseFacts({'basisDate': KstDate(2024, 2, 1)}),
      );
      expect(result!.dueDate, const KstDate(2024, 3, 2));
    });
  });

  group('DeadlineEngine — 남은 일수', () {
    test('D-14', () {
      final result = engine.computeOne(
        deadlineFixture(id: 'dl', offsetValue: 2, offsetUnit: TimeUnit.week),
        const CaseFacts({'basisDate': KstDate(2026, 8, 15)}),
      );
      expect(result!.daysRemaining, 14);
      expect(result.dDay, 'D-14');
      expect(result.isOverdue, isFalse);
    });

    test('이미 지난 기한은 음수', () {
      final result = engine.computeOne(
        deadlineFixture(id: 'dl', offsetValue: 2, offsetUnit: TimeUnit.week),
        const CaseFacts({'basisDate': KstDate(2026, 7, 1)}),
      );
      expect(result!.daysRemaining, lessThan(0));
      expect(result.isOverdue, isTrue);
      expect(result.dDay, startsWith('D+'));
    });

    test('오늘이 기한이면 D-DAY', () {
      final result = engine.computeOne(
        deadlineFixture(id: 'dl', offsetValue: 0, offsetUnit: TimeUnit.day),
        const CaseFacts({'basisDate': KstDate(2026, 8, 15)}),
      );
      expect(result!.dDay, 'D-DAY');
      expect(result.isToday, isTrue);
    });
  });

  group('DeadlineEngine — 목록 계산', () {
    test('기산일이 없으면 조용히 제외한다 (에러가 아니다)', () {
      final domain = domainFixture(deadlines: [deadlineFixture(id: 'dl')]);
      expect(engine.compute(domain, const CaseFacts()), isEmpty);
    });

    test('showIf 를 만족하지 않으면 제외한다', () {
      final domain = domainFixture(
        deadlines: [
          deadlineFixture(
            id: 'dl',
            showIf: {
              '==': [
                {'var': 'courtDocument'},
                'payment_order',
              ],
            },
          ),
        ],
      );
      const facts = CaseFacts({
        'basisDate': KstDate(2026, 8, 15),
        'courtDocument': 'none',
      });
      expect(engine.compute(domain, facts), isEmpty);

      final matching = facts.merge({'courtDocument': 'payment_order'});
      expect(engine.compute(domain, matching), hasLength(1));
    });

    test('정렬: severity DESC → 남은 일수 ASC → id ASC', () {
      final domain = domainFixture(
        deadlines: [
          deadlineFixture(id: 'b_info', severity: Severity.info, offsetValue: 1),
          deadlineFixture(id: 'a_critical_late', offsetValue: 30),
          deadlineFixture(id: 'a_critical_soon', offsetValue: 3),
          deadlineFixture(
            id: 'c_warning',
            severity: Severity.warning,
            offsetValue: 2,
          ),
        ],
      );
      final results = engine.compute(
        domain,
        const CaseFacts({'basisDate': KstDate(2026, 8, 15)}),
      );
      expect(results.map((r) => r.id), [
        'a_critical_soon',
        'a_critical_late',
        'c_warning',
        'b_info',
      ]);
    });

    test('근거 조문이 결과에 실린다', () {
      final result = engine.computeOne(
        deadlineFixture(id: 'dl'),
        const CaseFacts({'basisDate': KstDate(2026, 8, 15)}),
      );
      expect(result!.basis.citation, '테스트법 제1조');
    });
  });
}

/// 민법 제161조가 엔진을 통과해 실제로 날짜를 미는지.
///
/// **기간 계산과 섞지 않는다.** 위 그룹들은 `OpenEveryDayRule` 로 이 규칙을 끄고
/// 돌린다 — 그래야 어느 규칙이 틀렸는지 알 수 있다.
void rollForwardTests() {
  const clock = FixedKstClock(KstDate(2026, 8, 1));
  const engine = DeadlineEngine(clock);

  group('DeadlineEngine — 제161조', () {
    /// 2026-08-01(토) + 2주 = 2026-08-15(토) → 2026-08-17(월)
    DeadlineResult resultOf() => engine.computeOne(
          deadlineFixture(id: 'dl', offsetValue: 2, offsetUnit: TimeUnit.week),
          const CaseFacts({'basisDate': KstDate(2026, 8, 1)}),
        )!;

    test('말일이 토요일이면 월요일로 민다', () {
      expect(resultOf().dueDate, const KstDate(2026, 8, 17));
    });

    test('밀기 전 날짜를 남긴다', () {
      // 아무 설명 없이 날짜만 바뀌면 사용자는 계산이 틀렸다고 생각한다.
      expect(resultOf().rolledFrom, const KstDate(2026, 8, 15));
      expect(resultOf().wasRolled, isTrue);
    });

    test('남은 일수도 민 날짜로 센다', () {
      expect(resultOf().daysRemaining, 16);
    });

    test('안 밀렸으면 rolledFrom 이 없다', () {
      final result = engine.computeOne(
        deadlineFixture(id: 'dl', offsetValue: 3, offsetUnit: TimeUnit.day),
        const CaseFacts({'basisDate': KstDate(2026, 8, 10)}),
      )!;
      expect(result.dueDate, const KstDate(2026, 8, 13));
      expect(result.wasRolled, isFalse);
    });
  });
}
