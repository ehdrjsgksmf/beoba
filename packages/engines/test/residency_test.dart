import 'package:engines/engines.dart';
import 'package:test/test.dart';

/// ★ **체류자격은 조문에 없다. 그래서 어느 방향으로도 말하지 않는다.**
///
/// 산재보험법 제6조는 「근로자를 사용하는 모든 사업 또는 사업장에 적용한다」
/// 까지만 말하고 체류자격에는 한 글자도 없다. 「미등록 외국인도 됩니다」도
/// 「불법체류자는 안 됩니다」도 **우리가 지어내는 말**이고, 틀리면 사람이
/// 신고를 못 하거나 하지 말아야 할 곳에 간다.
///
/// 이 낱말들을 막는 자리는 `SafetyFilter` 다 — 화면 문구도 도메인 JSON 도
/// 복지 자료도 한 검사가 본다. 검사를 따로 만들면 새로 생기는 자리마다
/// 붙이는 것을 잊는다.
void main() {
  group('★ 체류자격은 우리 문장에 0번', () {
    for (final sentence in const [
      '미등록 외국인도 산재가 됩니다',
      '불법체류 상태여도 신청할 수 있어요',
      '체류자격을 먼저 확인해 보세요',
      '비자 종류에 따라 달라져요',
    ]) {
      test('막는다 — $sentence', () {
        expect(SafetyFilter.scan(sentence), isNotEmpty);
      });
    }
  });

  group('★ 넓게 잡으면 오탐이 난다 — 앞뒤를 본다', () {
    test('「소비자」는 통과한다', () {
      // 「소비자」 안에 「비자」가 그대로 들어 있다. 무르기·할부·중고거래가
      // 이 낱말을 쓴다 — 여기서 걸리면 세 분야가 통째로 막힌다.
      expect(
        SafetyFilter.scan('통신판매업자와 계약을 체결한 소비자는'),
        isEmpty,
      );
    });

    test('「비자발적 이직」은 통과한다', () {
      // 실업급여의 조문 낱말이다.
      expect(SafetyFilter.scan('비자발적으로 그만두게 된 경우예요'), isEmpty);
    });
  });

  group('조문과 기관 안내문에는 그대로 있다', () {
    test('인용(quote)에서는 막지 않는다', () {
      // 출입국관리법과 복지 안내문이 이 낱말을 쓴다. 막는 것은 **우리 말**이다.
      expect(
        SafetyFilter.scan('체류자격이 있는 사람', scope: SafetyScope.quote),
        isEmpty,
      );
    });
  });
}
