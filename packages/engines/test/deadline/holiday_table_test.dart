import 'dart:convert';
import 'dart:io';

import 'package:domain_data/domain_data.dart';
import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// 쉬는 날 표. **틀린 날을 넣느니 빼는 게 맞다.**
///
/// ```
/// 공휴일을 적게 알면      → 덜 민다 → 기한이 이르다 → 안전
/// 공휴일을 **잘못 넣으면** → 더 민다 → 기한이 늦다  → 위험
/// ```
///
/// 68번은 「안 민 쪽이 언제나 진짜 기한보다 앞이라 늦지 않는다」였다. 데이터를
/// 넣는 순간 그 보장이 사라지므로 여기서 다시 세운다.
void main() {
  final calendars = _load();
  final table = TableHolidayRule(calendars);

  group('2026년 골든셋 — 규정과 대조를 마친 22건', () {
    /// 사람이 규정 제2조·제3조로 하나하나 대조한 목록이다.
    /// **이 목록이 줄어들면 대조하지 않은 데이터가 들어온 것이다.**
    const golden = <String>[
      '2026-01-01', // 1월1일
      '2026-02-16', '2026-02-17', '2026-02-18', // 설날
      '2026-03-01', // 삼일절(일)
      '2026-03-02', // 대체 — 제3조①1호
      '2026-05-01', // 노동절. **2026년에 새로 생겼다**
      '2026-05-05', // 어린이날
      '2026-05-24', // 부처님오신날(일)
      '2026-05-25', // 대체
      '2026-06-03', // 전국동시지방선거
      '2026-06-06', // 현충일(토) — **대체 없음**
      '2026-07-17', // 제헌절. **2026년에 새로 생겼다**
      '2026-08-15', // 광복절(토)
      '2026-08-17', // 대체 — 8/16이 일요일이라 그다음 평일
      '2026-09-24', '2026-09-25', '2026-09-26', // 추석
      '2026-10-03', // 개천절(토)
      '2026-10-05', // 대체
      '2026-10-09', // 한글날
      '2026-12-25', // 기독탄신일
    ];

    test('22건이 그대로 있다', () {
      final days = calendars
          .firstWhere((c) => c.year == 2026)
          .days
          .map((d) => d.date.toIso())
          .toList();
      expect(days, golden);
    });

    test('전부 닫힌 날로 잡힌다', () {
      for (final iso in golden) {
        expect(table.isClosed(_date(iso)), isTrue, reason: iso);
      }
    });

    test('현충일이 토요일인데 대체가 없다', () {
      // 제3조①1호가 열거하는 호에 **제8호(현충일)가 없다.** 열거를 잘못 읽으면
      // 여기서 틀린다 — 이 검사가 재계산의 제일 좋은 시험이다.
      expect(_date('2026-06-06').isWeekend, isTrue);
      expect(table.isClosed(_date('2026-06-08')), isFalse, reason: '월요일');
      expect(table.isClosed(_date('2026-06-09')), isFalse, reason: '화요일');
    });

    test('제헌절이 들어 있다', () {
      // 2026.5.11. 시행 개정으로 새로 공휴일이 됐다. **옛 규정만 아는 코드는
      // 이 날을 뺀다.**
      expect(table.isClosed(_date('2026-07-17')), isTrue);
    });

    test('노동절이 들어 있다', () {
      expect(table.isClosed(_date('2026-05-01')), isTrue);
    });
  });

  group('표가 없는 해 — 토·일만 민다', () {
    test('아는 해와 모르는 해를 가른다', () {
      expect(table.covers(2026), isTrue);
      expect(table.covers(2030), isFalse);
      expect(table.lastCoveredYear, 2027);
    });

    test('모르는 해의 평일은 열린 날로 둔다', () {
      // **모르는 것을 아는 척하면 기한이 뒤로 밀리고, 그쪽이 위험하다.**
      expect(table.isClosed(const KstDate(2030, 1, 1)), isFalse);
      // 토·일은 달력에서 나오므로 표가 없어도 본다.
      expect(table.isClosed(const KstDate(2030, 1, 5)), isTrue); // 일요일
    });
  });

  group('안전 방향 — 넣어서 기한이 이르게 나오면 안 된다', () {
    test('표를 넣으면 기한은 같거나 뒤로만 간다', () {
      // 민법 제161조는 **뒤로만** 민다. 표를 넣었는데 앞으로 당겨지는 날이
      // 하나라도 있으면 계산이 틀린 것이다.
      const weekendOnly = WeekendHolidayRule();
      var checked = 0;

      for (final calendar in calendars) {
        for (var month = 1; month <= 12; month++) {
          final last = KstDate.daysInMonth(calendar.year, month);
          for (var day = 1; day <= last; day++) {
            final due = KstDate(calendar.year, month, day);
            final before = CivilPeriod.rollForward(due, weekendOnly);
            final after = CivilPeriod.rollForward(due, table);
            expect(
              after.compareTo(before),
              greaterThanOrEqualTo(0),
              reason: '${due.toIso()} — 표를 넣었더니 기한이 앞으로 당겨졌습니다',
            );
            checked++;
          }
        }
      }
      expect(checked, greaterThan(1000));
    });

    test('실제로 밀리는 날이 있다', () {
      // 위 검사는 「같아도」 통과한다. 표가 아무 일도 안 하고 있지는 않은지 본다.
      final rolled = CivilPeriod.rollForward(_date('2026-03-02'), table);
      expect(rolled, _date('2026-03-03'));
    });
  });

  group('표가 비면 토·일만 미는 것과 같다', () {
    test('빈 표는 주말 규칙과 같은 답을 낸다', () {
      final empty = TableHolidayRule(const []);
      expect(empty.length, 0);
      expect(empty.lastCoveredYear, isNull);
      expect(empty.isClosed(_date('2026-03-02')), isFalse);
      expect(empty.isClosed(_date('2026-03-01')), isTrue); // 일요일
    });
  });
}

KstDate _date(String iso) => KstDate(
      int.parse(iso.substring(0, 4)),
      int.parse(iso.substring(5, 7)),
      int.parse(iso.substring(8)),
    );

List<HolidayCalendar> _load() {
  final dir = Directory('${_root()}/packages/domain_data/assets/holidays');
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      if (file.path.endsWith('.json'))
        HolidayCalendar.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        ),
  ];
}

String _root() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    if (Directory('${dir.path}/packages/domain_data').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('저장소 뿌리를 못 찾았습니다');
}
