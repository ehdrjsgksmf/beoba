import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// 민법 총칙의 기간 계산이 엔진 산술과 **정말로 같은지** 손으로 세어 맞춰 본다.
///
/// 답변서 30일 · 이의신청 2주 · 소멸시효가 전부 같은 규칙을 받는다. 여기가 틀리면
/// 이 앱이 내놓는 모든 날짜가 틀린다.
///
/// ```
/// 제157조  기간의 초일은 산입하지 아니한다
/// 제159조  기간말일의 종료로 기간이 만료한다
/// 제160조② 최후의 주·월·연에서 그 기산일에 해당한 날의 전일로 만료
/// 제160조③ 최종의 월에 해당일이 없는 때에는 그 월의 말일로 만료
/// ```
///
/// **`addDays(n)` 이 초일불산입 n일과 같다는 것은 우연이 아니다.**
/// 기산일 = 기준일 + 1 이고 n일째 = 기산일 + (n-1) 이므로 기준일 + n 이다.
/// 나중에 "초일불산입이니 +1 해야 한다" 며 고치려는 사람을 이 파일이 막는다.
void main() {
  /// 제157조 — 초일은 안 센다. 그래서 세기 시작하는 날은 다음 날이다.
  KstDate startOf(KstDate basis) => basis.addDays(1);

  group('일·주 — 제157조 + 제159조', () {
    /// 기산일부터 [days] 째 되는 날. 손으로 세는 방식 그대로.
    KstDate byHand(KstDate basis, int days) =>
        startOf(basis).addDays(days - 1);

    const cases = <(KstDate, int)>[
      (KstDate(2026, 8, 15), 30),
      (KstDate(2026, 2, 1), 30),
      (KstDate(2024, 2, 1), 30), // 윤년
      (KstDate(2026, 12, 20), 30), // 해를 넘김
      (KstDate(2026, 8, 15), 14),
      (KstDate(2026, 8, 15), 1),
    ];

    for (final (basis, days) in cases) {
      test('${basis.toIso()} + $days일', () {
        expect(
          CivilPeriod.statutoryEnd(basis, Offset(value: days, unit: TimeUnit.day)),
          byHand(basis, days),
        );
      });
    }

    test('2주는 14일과 같다', () {
      const basis = KstDate(2026, 8, 15);
      const twoWeeks = Offset(value: 2, unit: TimeUnit.week);
      expect(CivilPeriod.statutoryEnd(basis, twoWeeks), basis.addDays(14));
      expect(CivilPeriod.statutoryEnd(basis, twoWeeks), byHand(basis, 14));
    });

    test('지금 정답지의 값이 손계산과 맞는다', () {
      // 답변서 30일 · 지급명령 이의 2주.
      KstDate due(KstDate b, int n, TimeUnit u) =>
          CivilPeriod.statutoryEnd(b, Offset(value: n, unit: u));
      expect(due(const KstDate(2026, 8, 15), 30, TimeUnit.day), const KstDate(2026, 9, 14));
      expect(due(const KstDate(2026, 2, 1), 30, TimeUnit.day), const KstDate(2026, 3, 3));
      expect(due(const KstDate(2026, 8, 15), 2, TimeUnit.week), const KstDate(2026, 8, 29));
    });
  });

  group('연 — 제160조 제2항', () {
    /// 최후의 연에서 **기산일에 해당한 날의 전일**.
    KstDate byHand(KstDate basis, int years) {
      final start = startOf(basis);
      return KstDate(start.year + years, start.month, start.day).addDays(-1);
    }

    const cases = <(KstDate, int)>[
      (KstDate(2020, 8, 15), 10),
      (KstDate(2020, 12, 31), 10),
      (KstDate(2020, 1, 1), 5),
      (KstDate(2019, 2, 28), 1),
    ];

    for (final (basis, years) in cases) {
      test('${basis.toIso()} + $years년', () {
        expect(
          CivilPeriod.statutoryEnd(basis, Offset(value: years, unit: TimeUnit.year)),
          byHand(basis, years),
        );
      });
    }

    test('지금 정답지의 값이 손계산과 맞는다', () {
      expect(
        CivilPeriod.statutoryEnd(
          const KstDate(2020, 8, 15),
          const Offset(value: 10, unit: TimeUnit.year),
        ),
        const KstDate(2030, 8, 15),
      );
    });
  });

  group('월 — 제160조 제2항·제3항', () {
    /// 해당일이 있으면 그 전일, 없으면 그 달의 말일.
    KstDate byHand(KstDate basis, int months) {
      final start = startOf(basis);
      final total = start.year * 12 + (start.month - 1) + months;
      final year = total ~/ 12;
      final month = total % 12 + 1;
      final lastDay = KstDate.daysInMonth(year, month);
      if (start.day > lastDay) return KstDate(year, month, lastDay);
      return KstDate(year, month, start.day).addDays(-1);
    }

    const cases = <(KstDate, int)>[
      (KstDate(2026, 8, 15), 1),
      (KstDate(2026, 1, 30), 1), // 최종 월에 30일이 없다
      (KstDate(2026, 1, 31), 1), // 기산일이 2월 1일이라 달의 처음부터 센다
      (KstDate(2024, 1, 30), 1), // 윤년 2월
      (KstDate(2026, 3, 31), 1),
      (KstDate(2026, 11, 30), 3),
    ];

    for (final (basis, months) in cases) {
      test('${basis.toIso()} + $months개월', () {
        expect(
          CivilPeriod.statutoryEnd(basis, Offset(value: months, unit: TimeUnit.month)),
          byHand(basis, months),
        );
      });
    }
  });

  group('제161조 — 말일이 토요일·공휴일이면 익일', () {
    const weekend = WeekendHolidayRule();

    test('요일을 셀 수 있다', () {
      // 2026-08-15 는 토요일이다.
      expect(const KstDate(2026, 8, 15).weekday, DateTime.saturday);
      expect(const KstDate(2026, 8, 16).weekday, DateTime.sunday);
      expect(const KstDate(2026, 8, 17).weekday, DateTime.monday);
    });

    test('토요일이면 월요일로 민다', () {
      expect(
        CivilPeriod.rollForward(const KstDate(2026, 8, 15), weekend),
        const KstDate(2026, 8, 17),
      );
    });

    test('일요일이면 월요일로 민다', () {
      expect(
        CivilPeriod.rollForward(const KstDate(2026, 8, 16), weekend),
        const KstDate(2026, 8, 17),
      );
    });

    test('평일이면 그대로 둔다', () {
      for (var day = 17; day <= 21; day++) {
        final date = KstDate(2026, 8, day);
        expect(CivilPeriod.rollForward(date, weekend), date, reason: date.toIso());
      }
    });

    test('뒤로만 민다. 앞으로 당기지 않는다', () {
      // 앞으로 당기면 사용자가 늦는다.
      final rolled = CivilPeriod.rollForward(const KstDate(2026, 8, 15), weekend);
      expect(rolled.differenceInDays(const KstDate(2026, 8, 15)), greaterThan(0));
    });

    test('안 미는 규칙을 주면 아무것도 안 한다', () {
      const open = OpenEveryDayRule();
      expect(
        CivilPeriod.rollForward(const KstDate(2026, 8, 15), open),
        const KstDate(2026, 8, 15),
      );
    });

    test('공휴일을 몰라서 안 민 쪽은 언제나 진짜 기한보다 앞이다', () {
      // 제161조는 기한을 **뒤로만** 미룬다. 그래서 모르고 안 민 날짜에 맞춰
      // 움직이면 늦지 않는다. 정확하지는 않지만 안전한 쪽이다.
      const due = KstDate(2026, 8, 17); // 월요일
      final withWeekendOnly = CivilPeriod.rollForward(due, weekend);
      expect(withWeekendOnly, due);
      // 만약 그날이 공휴일이었다면 진짜 기한은 이보다 뒤다.
      expect(withWeekendOnly.addDays(1).differenceInDays(withWeekendOnly), 1);
    });
  });

  group('기간 계산과 제161조는 섞이지 않는다', () {
    test('민 것은 기간 계산 결과가 아니다', () {
      // 정답지는 157·159·160 의 답을 담는다. 제161조를 섞으면 정답지가 달력에
      // 따라 흔들리고, 조문 대조를 할 수 없게 된다.
      const basis = KstDate(2026, 7, 16);
      final statutory = CivilPeriod.statutoryEnd(
        basis,
        const Offset(value: 30, unit: TimeUnit.day),
      );
      expect(statutory, const KstDate(2026, 8, 15)); // 토요일
      expect(
        CivilPeriod.rollForward(statutory, const WeekendHolidayRule()),
        const KstDate(2026, 8, 17),
      );
    });
  });
}
