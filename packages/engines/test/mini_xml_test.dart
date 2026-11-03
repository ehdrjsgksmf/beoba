import 'package:test/test.dart';

import '../tool/mini_xml.dart';

void main() {
  group('작은 XML 읽개', () {
    test('마디와 글자를 읽는다', () {
      final root = parseXml(
        '<?xml version="1.0"?><wantedDtl><servId>WLF1</servId>'
        '<servNm>이름</servNm></wantedDtl>',
      );
      expect(root.name, 'wantedDtl');
      expect(root.textOf('servId'), 'WLF1');
      expect(root.textOf('servNm'), '이름');
    });

    test('같은 이름이 여러 번 오면 다 담는다', () {
      final root = parseXml(
        '<r><baslawList><servSeDetailNm>가법</servSeDetailNm></baslawList>'
        '<baslawList><servSeDetailNm>나법</servSeDetailNm></baslawList></r>',
      );
      expect(
        root.findAll('baslawList').map((n) => n.textOf('servSeDetailNm')),
        ['가법', '나법'],
      );
    });

    test('없는 자식은 빈 문자열', () {
      expect(parseXml('<r><a>1</a></r>').textOf('b'), '');
    });

    test('빈 태그도 읽는다', () {
      expect(parseXml('<r><a/><b>2</b></r>').textOf('b'), '2');
    });

    test('이스케이프를 한 번만 푼다', () {
      final root = parseXml('<r><a>&amp;lt;표&amp;gt;</a></r>');
      expect(root.textOf('a'), '&lt;표&gt;');
    });

    test('숫자 이름표를 푼다 — 줄바꿈으로 쓰인 &#13;', () {
      expect(parseXml('<r><a>앞&#13;뒤</a></r>').textOf('a'), '앞\r뒤');
    });

    test('모르는 이름표는 그대로 둔다', () {
      expect(parseXml('<r><a>&zzz;</a></r>').textOf('a'), '&zzz;');
    });

    test('한 겹 더 싸인 것은 따로 푼다', () {
      expect(decodeStrayEntities('&#9312; 가형'), '① 가형');
      expect(decodeStrayEntities('그냥 글'), '그냥 글');
    });

    test('못 읽는 것을 조용히 넘기지 않는다', () {
      expect(() => parseXml('<r a="1"></r>'), throwsA(isA<XmlFormatException>()));
      expect(() => parseXml('<r><a></b></r>'), throwsA(isA<XmlFormatException>()));
      expect(() => parseXml('<r><a></r>'), throwsA(isA<XmlFormatException>()));
      expect(() => parseXml('<!-- 주석 -->'), throwsA(isA<XmlFormatException>()));
    });
  });
}
