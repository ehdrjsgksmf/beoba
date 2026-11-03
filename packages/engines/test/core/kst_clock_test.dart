import 'package:engines/engines.dart';
import 'package:test/test.dart';

void main() {
  group('FixedKstClock', () {
    test('정해진 날짜를 그대로 돌려준다', () {
      const clock = FixedKstClock(KstDate(2026, 8, 15));
      expect(clock.today(), const KstDate(2026, 8, 15));
    });

    test('UTC 시각은 그 날 KST 자정이다', () {
      const clock = FixedKstClock(KstDate(2026, 8, 15));
      expect(clock.nowUtc(), DateTime.utc(2026, 8, 14, 15));
    });
  });

  group('SystemKstClock', () {
    test('오늘은 지금 UTC 시각을 KST 로 옮긴 날짜다', () {
      const clock = SystemKstClock();
      expect(clock.today(), KstDate.fromUtcInstant(clock.nowUtc()));
    });

    test('UTC 기준보다 하루 앞서거나 같다', () {
      const clock = SystemKstClock();
      final utcNow = clock.nowUtc();
      final diff = clock
          .today()
          .differenceInDays(KstDate(utcNow.year, utcNow.month, utcNow.day));
      expect(diff, anyOf(0, 1));
    });
  });
}
