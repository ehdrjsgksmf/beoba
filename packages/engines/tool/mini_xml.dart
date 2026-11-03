/// 아주 작은 XML 읽개. **공공데이터 응답 하나만 읽으려고 만들었다.**
///
/// `package:xml` 을 안 붙인 이유 — 이 응답에는 속성도, 이름공간도, CDATA 도,
/// 처리 지시도 없다. 태그와 글자뿐이다. 그만큼만 읽고, 못 읽는 것을 만나면
/// **조용히 넘기지 않고 던진다.**
///
/// 못 읽는 것: 속성 · CDATA · 주석 · 이름공간. 응답 모양이 바뀌면 여기서 멈춘다.
class XmlNode {
  XmlNode(this.name);

  final String name;
  final List<XmlNode> children = [];
  final StringBuffer _text = StringBuffer();

  /// 이 마디의 글자. 자식 마디의 글자는 안 담는다.
  String get text => _text.toString();

  /// 이름이 [name] 인 자식들.
  List<XmlNode> findAll(String name) =>
      [for (final child in children) if (child.name == name) child];

  /// 이름이 [name] 인 첫 자식. 없으면 null.
  XmlNode? find(String name) {
    for (final child in children) {
      if (child.name == name) return child;
    }
    return null;
  }

  /// 이름이 [name] 인 첫 자식의 글자. 없으면 빈 문자열.
  ///
  /// **없는 것과 빈 것을 같게 다룬다.** 이 API 는 값이 없으면 태그를 아예
  /// 안 보내고, 어떤 자리에서는 빈 태그를 보낸다. 둘을 갈라 봐야 할 자리가
  /// 아직 없다.
  String textOf(String name) => find(name)?.text ?? '';

  @override
  String toString() => '<$name> (${children.length}개)';
}

class XmlFormatException implements Exception {
  XmlFormatException(this.message, this.offset);
  final String message;
  final int offset;

  @override
  String toString() => 'XML 을 읽지 못했습니다 ($offset번째 글자): $message';
}

/// 뿌리 마디를 돌려준다. 선언(`<?xml … ?>`)은 건너뛴다.
XmlNode parseXml(String source) {
  final stack = <XmlNode>[];
  XmlNode? root;
  var i = 0;

  while (i < source.length) {
    final open = source.indexOf('<', i);
    if (open < 0) break;

    if (open > i) {
      final text = source.substring(i, open);
      if (stack.isNotEmpty) {
        stack.last._text.write(unescapeXml(text));
      } else if (text.trim().isNotEmpty) {
        throw XmlFormatException('뿌리 밖에 글자가 있습니다', i);
      }
    }

    final close = source.indexOf('>', open);
    if (close < 0) throw XmlFormatException('닫히지 않은 태그', open);
    final tag = source.substring(open + 1, close);

    if (tag.startsWith('?')) {
      i = close + 1;
      continue;
    }
    if (tag.startsWith('!')) {
      throw XmlFormatException('주석·DOCTYPE·CDATA 는 못 읽습니다', open);
    }

    if (tag.startsWith('/')) {
      final name = tag.substring(1).trim();
      if (stack.isEmpty || stack.last.name != name) {
        throw XmlFormatException('짝이 안 맞는 닫는 태그 </$name>', open);
      }
      stack.removeLast();
      i = close + 1;
      continue;
    }

    final selfClosing = tag.endsWith('/');
    final body = selfClosing ? tag.substring(0, tag.length - 1) : tag;
    if (body.contains(' ') || body.contains('\t') || body.contains('\n')) {
      throw XmlFormatException('속성이 붙은 태그는 못 읽습니다: <$body>', open);
    }
    if (body.isEmpty) throw XmlFormatException('이름 없는 태그', open);

    final node = XmlNode(body);
    if (stack.isEmpty) {
      if (root != null) throw XmlFormatException('뿌리가 둘입니다', open);
      root = node;
    } else {
      stack.last.children.add(node);
    }
    if (!selfClosing) stack.add(node);
    i = close + 1;
  }

  if (stack.isNotEmpty) {
    throw XmlFormatException('안 닫힌 태그 <${stack.last.name}>', source.length);
  }
  if (root == null) throw XmlFormatException('뿌리 마디가 없습니다', 0);
  return root;
}

final RegExp _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);');

/// 이 자료에 **실제로 나오는** 이름표만 적는다.
///
/// HTML 이름표는 이천 개가 넘는데 다 적을 일이 아니다. 안 적은 것은 그대로
/// 두므로 화면에서 눈에 띄고, 그때 여기 한 줄 더한다. 세어 보니 열한 가지가
/// 나왔다 — 따옴표 넷 · 셈 기호 넷 · 화살표 둘 · 가운뎃점.
const Map<String, String> _named = {
  'lt': '<',
  'gt': '>',
  'amp': '&',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'middot': '·',
  'times': '×',
  'divide': '÷',
  'sim': '∼',
  'ge': '≥',
  'rarr': '→',
  'harr': '↔',
};

/// XML 이스케이프를 한 번 푼다.
///
/// **한 번만 판다.** `&amp;` 를 먼저 풀고 다시 훑으면 `&amp;lt;` 가 `<` 가 된다.
/// 한 벌로 훑어서 그 사고를 원천 차단한다.
///
/// 모르는 이름표는 **그대로 둔다.** 지우면 무엇이 있었는지 알 수 없게 된다.
String unescapeXml(String source) =>
    source.replaceAllMapped(_entity, (match) {
      final token = match.group(1)!;
      if (token.startsWith('#x')) {
        final code = int.tryParse(token.substring(2), radix: 16);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      if (token.startsWith('#')) {
        final code = int.tryParse(token.substring(1));
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      return _named[token] ?? match.group(0)!;
    });

/// **한 겹 더 싸인 이름표를 푼다.** 원문이 두 번 이스케이프해서 보낸 자리다.
///
/// 응답에 `&amp;#9312;` 가 그대로 온다. XML 을 한 번 풀면 `&#9312;` 라는
/// **글자 여덟 개**가 남고, 그대로 화면에 내면 사람이 읽을 수 없다. 원래
/// 뜻은 `①` 이다.
///
/// **이건 문장을 고쳐 쓰는 것이 아니라 덜 푼 것을 마저 푸는 것이다.**
/// 어절 하나 안 바뀐다. [unescapeXml] 과 따로 두는 이유는, 이것이 XML 규칙이
/// 아니라 **이 자료의 사정**이기 때문이다 — 다른 출처에 함부로 적용하지 않는다.
String decodeStrayEntities(String source) =>
    source.contains('&#') ? unescapeXml(source) : source;
