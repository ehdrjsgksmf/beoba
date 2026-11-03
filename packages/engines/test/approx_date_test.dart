import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

/// 정밀도를 값이 직접 들고 다닌다. **보정하지 않는다.**
void main() {
  group('저장 형식은 ISO 축약', () {
    const cases = <String, ApproxDate>{
      '2023-03-15': ApproxDate(2023, 3, 15),
      '2023-03': ApproxDate(2023, 3),
      '2023': ApproxDate(2023),
    };

    cases.forEach((text, value) {
      test('"$text" 를 왕복한다', () {
        expect(ApproxDate.tryParse(text), value);
        expect(value.toIso(), text);
      });
    });

    test('읽을 수 없으면 null 이다', () {
      for (final bad in ['', '  ', '23-03', '2023-3', '2023-13', '2023-02-30', '어제']) {
        expect(ApproxDate.tryParse(bad), isNull, reason: bad);
      }
    });
  });

  group('정밀도', () {
    test('아는 만큼만 정밀도가 올라간다', () {
      expect(const ApproxDate(2023, 3, 15).precision, DatePrecision.day);
      expect(const ApproxDate(2023, 3).precision, DatePrecision.month);
      expect(const ApproxDate(2023).precision, DatePrecision.year);
    });

    test('정확할 때만 exact 가 값을 준다', () {
      // 어림값을 날짜인 척 내주지 않는 것이 이 게터의 일이다.
      expect(const ApproxDate(2023, 3, 15).exact, const KstDate(2023, 3, 15));
      expect(const ApproxDate(2023, 3).exact, isNull);
      expect(const ApproxDate(2023).exact, isNull);
    });
  });

  group('범위 — 보정하지 않고 양 끝을 준다', () {
    test('월까지 알면 그 달의 처음과 끝', () {
      expect(const ApproxDate(2023, 3).earliest, const KstDate(2023, 3, 1));
      expect(const ApproxDate(2023, 3).latest, const KstDate(2023, 3, 31));
    });

    test('연도만 알면 그 해의 처음과 끝', () {
      expect(const ApproxDate(2023).earliest, const KstDate(2023, 1, 1));
      expect(const ApproxDate(2023).latest, const KstDate(2023, 12, 31));
    });

    test('윤년 2월을 지어내지 않는다', () {
      expect(const ApproxDate(2024, 2).latest, const KstDate(2024, 2, 29));
      expect(const ApproxDate(2023, 2).latest, const KstDate(2023, 2, 28));
    });

    test('저장된 값 자체는 그대로 남는다', () {
      // earliest·latest 는 계산할 때 파생될 뿐이다. 월 중간이나 월말로
      // 채워 넣으면 앱이 사실을 만든다.
      const value = ApproxDate(2023, 3);
      expect(value.toIso(), '2023-03');
      expect(value.month, 3);
      expect(value.day, isNull);
    });
  });

  test('연도는 반드시 안다', () {
    // 연도를 모르면 어떤 계산도 못 한다. 그건 어림값이 아니라 답하지 않은 것이다.
    expect(const ApproxDate(2023).year, 2023);
    expect(() => ApproxDate(2023, null, 15), throwsA(isA<AssertionError>()));
  });

  test('정밀도를 낮출 수 있다', () {
    const exact = ApproxDate(2023, 3, 15);
    expect(exact.coarsen(DatePrecision.month), const ApproxDate(2023, 3));
    expect(exact.coarsen(DatePrecision.year), const ApproxDate(2023));
  });

  test('이른 쪽부터 정렬된다', () {
    final list = [
      const ApproxDate(2023, 5),
      const ApproxDate(2023),
      const ApproxDate(2023, 1, 1),
    ]..sort();
    // 시작이 같으면 좁은 쪽이 앞이다 — 2023 과 2023-01-01 은 둘 다 1월 1일에
    // 시작하지만 2023 은 연말까지 벌어진다.
    expect(list.map((d) => d.toIso()), ['2023-01-01', '2023', '2023-05']);
  });
}
