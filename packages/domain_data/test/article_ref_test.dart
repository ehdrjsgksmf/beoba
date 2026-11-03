import 'package:domain_data/domain_data.dart';
import 'package:test/test.dart';

/// 조문 참조를 읽는 규칙.
///
/// 매니페스트 생성기와 검증기가 **같은 규칙**으로 읽어야 한다. 한쪽만 고치면
/// 조용히 어긋나고, 어긋난 쪽은 「원문을 갖고 있다」를 잘못 센다.
void main() {
  group('본문 조문', () {
    test('평범한 꼴', () {
      expect(articleRefsIn('민사소송법 제470조 제1항'), {'제470조'});
      expect(articleRefsIn('민사집행법 제246조의2'), {'제246조의2'});
    });

    test('띄어 쓴 「제246조의 2」도 같은 조문이다', () {
      // **덤으로 얻은 것이라 잠가 둔다.** 국가법령정보센터가 조문을 이렇게
      // 띄어 쓰는 자리가 있고(변호사 자문 요청서의 「제64조의 5」), 정규화가
      // 없으면 원문을 갖고 있는데도 못 가진 것으로 세어진다.
      //
      // 픽스처는 **우리가 원문을 갖고 있는 조문**으로 쓴다. 안 그러면
      // 조문 꼴 전수 검사가 이 테스트 파일을 물고 늘어진다.
      expect(articleRefsIn('민사집행법 제246조의 2'), {'제246조의2'});
      expect(normalizeArticleRef('제 246 조'), '제246조');
    });

    test('한 문장에 여럿', () {
      expect(
        articleRefsIn('제2조, 제3조 및 제7조의 개정규정'),
        {'제2조', '제3조', '제7조'},
      );
    });
  });

  group('부칙', () {
    test('부칙 번호까지 한 덩어리로 읽는다', () {
      // **안쪽의 「제2조」가 따로 잡히면 안 된다.** 그러면 부칙만 인용해도
      // 본문 제2조 원문을 갖고 있는 것으로 세어진다(DECISIONS 126번).
      expect(
        articleRefsIn('민사집행법 시행령 부칙(제36056호) 제2조'),
        {'부칙(제36056호)제2조'},
      );
    });

    test('본문 제2조와 다른 문자열이다', () {
      final supplementary = articleRefsIn('부칙(제36056호) 제2조');
      final body = articleRefsIn('제2조');

      expect(supplementary.intersection(body), isEmpty);
    });

    test('본문과 부칙이 한 줄에 있어도 갈린다', () {
      expect(
        articleRefsIn('제3조와 부칙(제36056호) 제2조를 함께 본다'),
        {'제3조', '부칙(제36056호)제2조'},
      );
    });

    test('띄어쓰기가 어떻든 같은 이름이 된다', () {
      expect(
        articleRefsIn('부칙( 제36056호 ) 제 2조'),
        {'부칙(제36056호)제2조'},
      );
    });
  });

  test('조문이 아닌 것은 잡지 않는다', () {
    expect(articleRefsIn('제2025-24호 예규'), isEmpty);
    expect(articleRefsIn('형법 사문서위조·사기'), isEmpty);
  });
}
