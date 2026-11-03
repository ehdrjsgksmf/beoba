import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// **모르는 것을 모른다고 말하게 한다.**
///
/// 어림 기산일에서 나오는 것은 날짜가 아니라 범위다. 거기서 하나를 고르는 순간
/// 앱이 사실을 만들고, 사용자는 확신에 찬 거짓을 받는다.
void main() {
  const clock = FixedKstClock(KstDate(2026, 8, 15));
  const engine = DeadlineEngine(clock);

  const basis = LegalBasis(law: '민법', article: '제162조', text: '10년간 행사하지 아니하면 소멸시효가 완성한다.');
  const verified = Verification(status: VerificationStatus.verified);

  Deadline yearsAfter(int years) => Deadline(
        id: 'dl_test',
        label: '시험용 기한',
        whatIsThis: '시험용이에요',
        basisField: 'someDate',
        calcRule: CalcRule.fromBasis,
        offset: Offset(value: years, unit: TimeUnit.year),
        severity: Severity.warning,
        legalBasis: basis,
        verification: verified,
      );

  ({KstDate earliest, KstDate latest})? windowOf(Deadline d, Object? value) =>
      engine.dueWindow(d, CaseFacts({'someDate': value}));

  group('정확한 기산일 — 기존 동작이 그대로다', () {
    test('양 끝이 같다', () {
      final w = windowOf(yearsAfter(10), const KstDate(2020, 8, 15));
      expect(w!.earliest, const KstDate(2030, 8, 15));
      expect(w.latest, const KstDate(2030, 8, 15));
    });

    test('isApproximate 가 거짓이다', () {
      final r = engine.computeOne(
        yearsAfter(10),
        const CaseFacts({'someDate': KstDate(2020, 8, 15)}),
      );
      expect(r!.isApproximate, isFalse);
      expect(r.dueDateLatest, r.dueDate);
    });
  });

  group('어림 기산일 — 범위가 된다', () {
    test('월까지 알면 그 달의 폭만큼 벌어진다', () {
      final w = windowOf(yearsAfter(10), const ApproxDate(2020, 8));
      expect(w!.earliest, const KstDate(2030, 8, 1));
      expect(w.latest, const KstDate(2030, 8, 31));
    });

    test('연도만 알면 한 해만큼 벌어진다', () {
      final w = windowOf(yearsAfter(10), const ApproxDate(2020));
      expect(w!.earliest, const KstDate(2030, 1, 1));
      expect(w.latest, const KstDate(2030, 12, 31));
    });

    test('문자열로 와도 같다', () {
      // CaseFacts 는 축약 ISO 문자열을 그대로 받는다.
      expect(windowOf(yearsAfter(10), '2020-08')!.latest, const KstDate(2030, 8, 31));
      expect(windowOf(yearsAfter(10), '2020')!.latest, const KstDate(2030, 12, 31));
    });

    test('2월 말일을 지어내지 않는다', () {
      // 윤년이면 29일, 아니면 28일. KstDate 가 아는 것을 그대로 쓴다.
      expect(windowOf(yearsAfter(0), const ApproxDate(2024, 2))!.latest,
          const KstDate(2024, 2, 29));
      expect(windowOf(yearsAfter(0), const ApproxDate(2023, 2))!.latest,
          const KstDate(2023, 2, 28));
    });
  });

  group('가장 이른 날을 기준으로 센다', () {
    test('D-day 가 이른 끝에서 나온다', () {
      // 불확실할 때는 사용자에게 불리한 쪽을 기준으로 잡는다. 이른 날에 맞춰
      // 움직이면 어느 해석에서도 늦지 않는다.
      final r = engine.computeOne(
        yearsAfter(10),
        const CaseFacts({'someDate': ApproxDate(2026, 8)}),
      )!;
      expect(r.dueDate, const KstDate(2036, 8, 1));
      expect(r.daysRemaining, const KstDate(2036, 8, 1).differenceInDays(clock.today()));
    });

    test('심각도는 낮아지지 않는다', () {
      // 심각도는 결과의 무게이지 확실성이 아니다. 둘을 섞으면
      // "확실하지 않으니 덜 급하다" 는 잘못된 안심을 준다.
      final exact = engine.computeOne(
        yearsAfter(10),
        const CaseFacts({'someDate': KstDate(2020, 8, 15)}),
      )!;
      final approx = engine.computeOne(
        yearsAfter(10),
        const CaseFacts({'someDate': ApproxDate(2020)}),
      )!;
      expect(approx.severity, exact.severity);
    });
  });

  group('fromMonthEnd 는 월만 알아도 정확하다', () {
    // 말일은 월에만 달려 있고 일에는 안 달려 있다. **어림값이 정확도를 깎기만
    // 하는 것이 아니라는 증거다.** "어림값은 다 🟡" 로 뭉뚱그리면 이걸 잃는다.
    const monthEnd = Deadline(
      id: 'dl_month_end',
      label: '말일 기준 기한',
      whatIsThis: '그 달 마지막 날부터 세요',
      basisField: 'someDate',
      calcRule: CalcRule.fromMonthEnd,
      offset: Offset(value: 14, unit: TimeUnit.day),
      severity: Severity.warning,
      legalBasis: basis,
      verification: verified,
    );

    test('월까지만 알아도 양 끝이 같다', () {
      final w = windowOf(monthEnd, const ApproxDate(2026, 3));
      expect(w!.earliest, const KstDate(2026, 4, 14));
      expect(w.latest, const KstDate(2026, 4, 14));
    });

    test('그래서 확실한 기한으로 나온다', () {
      final r = engine.computeOne(
        monthEnd,
        const CaseFacts({'someDate': ApproxDate(2026, 3)}),
      )!;
      expect(r.isApproximate, isFalse, reason: '월만 알아도 말일은 하나뿐이다');
    });

    test('연도만 알면 그때는 벌어진다', () {
      final w = windowOf(monthEnd, const ApproxDate(2026));
      expect(w!.earliest, const KstDate(2026, 2, 14));
      expect(w.latest, const KstDate(2027, 1, 14));
    });
  });

  group('어림값을 모르는 엔진은 조용히 비운다', () {
    test('date() 는 정확할 때만 값을 준다', () {
      // 결과가 안 나오는 것은 정직한 실패다. 어림값으로 계산해 놓고 단정하는
      // 것이 조용한 거짓이다.
      const facts = CaseFacts({'someDate': ApproxDate(2026, 3)});
      expect(facts.date('someDate'), isNull);
      expect(facts.approxDate('someDate'), const ApproxDate(2026, 3));
    });

    test('정확한 값은 그대로 나온다', () {
      const facts = CaseFacts({'someDate': KstDate(2026, 3, 1)});
      expect(facts.date('someDate'), const KstDate(2026, 3, 1));
    });
  });
}
