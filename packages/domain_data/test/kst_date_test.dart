import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

void main() {
  group('KstDate 파싱', () {
    test('ISO 문자열을 읽는다', () {
      expect(KstDate.parse('2026-08-15'), const KstDate(2026, 8, 15));
    });

    test('형식이 어긋나면 거부한다', () {
      expect(KstDate.tryParse('2026-8-15'), isNull);
      expect(KstDate.tryParse('20260815'), isNull);
      expect(KstDate.tryParse(null), isNull);
      expect(() => KstDate.parse('오늘'), throwsFormatException);
    });

    test('존재하지 않는 날짜는 거부한다', () {
      expect(KstDate.tryParse('2026-02-29'), isNull); // 평년
      expect(KstDate.tryParse('2024-02-29'), isNotNull); // 윤년
      expect(KstDate.tryParse('2026-13-01'), isNull);
    });
  });

  group('KstDate 일 단위 계산', () {
    test('월을 넘어간다', () {
      expect(const KstDate(2026, 8, 15).addDays(30), const KstDate(2026, 9, 14));
    });

    test('2월(평년)을 넘어간다 — 답변서 30일', () {
      expect(const KstDate(2026, 2, 1).addDays(30), const KstDate(2026, 3, 3));
    });

    test('2월(윤년)을 넘어간다', () {
      expect(const KstDate(2024, 2, 1).addDays(30), const KstDate(2024, 3, 2));
    });

    test('연말을 넘어간다', () {
      expect(const KstDate(2026, 12, 25).addDays(10), const KstDate(2027, 1, 4));
    });

    test('2주 = 14일 — 지급명령 이의신청', () {
      expect(const KstDate(2026, 8, 15).addWeeks(2), const KstDate(2026, 8, 29));
    });

    test('음수도 된다', () {
      expect(const KstDate(2026, 1, 1).addDays(-1), const KstDate(2025, 12, 31));
    });
  });

  group('KstDate 월·연 단위 계산 — 말일 클램프', () {
    test('1월 31일 + 1개월 = 2월 28일 (3월 3일이 아니다)', () {
      expect(const KstDate(2026, 1, 31).addMonths(1), const KstDate(2026, 2, 28));
    });

    test('윤년 1월 31일 + 1개월 = 2월 29일', () {
      expect(const KstDate(2024, 1, 31).addMonths(1), const KstDate(2024, 2, 29));
    });

    test('31일 → 30일뿐인 달', () {
      expect(const KstDate(2026, 5, 31).addMonths(1), const KstDate(2026, 6, 30));
    });

    test('2월 29일 + 1년 = 2월 28일', () {
      expect(const KstDate(2024, 2, 29).addYears(1), const KstDate(2025, 2, 28));
    });

    test('10년 뒤 — 소멸시효', () {
      expect(const KstDate(2020, 8, 15).addYears(10), const KstDate(2030, 8, 15));
    });

    test('해를 넘기는 월 가산', () {
      expect(const KstDate(2026, 11, 30).addMonths(3), const KstDate(2027, 2, 28));
    });

    test('음수 월 가산', () {
      expect(const KstDate(2026, 1, 31).addMonths(-1), const KstDate(2025, 12, 31));
    });
  });

  group('KstDate 말일·차이', () {
    test('말일을 구한다', () {
      expect(const KstDate(2026, 2, 10).endOfMonth(), const KstDate(2026, 2, 28));
      expect(const KstDate(2024, 2, 10).endOfMonth(), const KstDate(2024, 2, 29));
      expect(const KstDate(2026, 8, 1).endOfMonth(), const KstDate(2026, 8, 31));
    });

    test('상속세 패턴 — 사망일이 속한 달의 말일 + 6개월', () {
      expect(
        const KstDate(2026, 3, 15).endOfMonth().addMonths(6),
        const KstDate(2026, 9, 30),
      );
    });

    test('일수 차이는 부호를 가진다', () {
      expect(
        const KstDate(2026, 8, 29).differenceInDays(const KstDate(2026, 8, 15)),
        14,
      );
      expect(
        const KstDate(2026, 8, 1).differenceInDays(const KstDate(2026, 8, 15)),
        -14,
      );
    });

    test('타임존과 무관하게 같은 값이 나온다', () {
      expect(
        const KstDate(2026, 8, 15).toUtcMidnight(),
        DateTime.utc(2026, 8, 15),
      );
    });

    test('KST 자정은 전날 15:00Z 다', () {
      expect(
        const KstDate(2026, 8, 15).toUtcInstantAtMidnight(),
        DateTime.utc(2026, 8, 14, 15),
      );
    });
  });

  group('KstDate UTC 변환', () {
    test('UTC 15:00 은 이미 다음날 KST 다', () {
      expect(
        KstDate.fromUtcInstant(DateTime.utc(2026, 8, 14, 15)),
        const KstDate(2026, 8, 15),
      );
    });

    test('UTC 14:59 는 아직 같은 날 KST 다', () {
      expect(
        KstDate.fromUtcInstant(DateTime.utc(2026, 8, 14, 14, 59)),
        const KstDate(2026, 8, 14),
      );
    });
  });

  group('KstDate 비교', () {
    test('정렬된다', () {
      final dates = [
        const KstDate(2026, 8, 15),
        const KstDate(2025, 12, 31),
        const KstDate(2026, 1, 1),
      ]..sort();
      expect(dates.map((d) => d.toIso()), [
        '2025-12-31',
        '2026-01-01',
        '2026-08-15',
      ]);
    });

    test('연산자가 동작한다', () {
      expect(const KstDate(2026, 1, 1) < const KstDate(2026, 1, 2), isTrue);
      expect(const KstDate(2026, 1, 1) >= const KstDate(2026, 1, 1), isTrue);
    });

    test('한 자리 월·일을 0으로 채운다', () {
      expect(const KstDate(2026, 1, 5).toIso(), '2026-01-05');
    });
  });
}
