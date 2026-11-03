/// 용어 표시는 **찾는 것이 아니라 표시하는 것**이다.
///
/// 걸림말(브로커 경보)이 분야를 가로질러 오탐을 낸 이유는 **사용자가 쓴 글**을
/// 훑을 수밖에 없었기 때문이다. 어쩔 수 없었다.
///
/// 용어 풀이는 다르다. 밑줄을 그을 문장은 **우리가 쓴 문장**이다. 훑을 이유가
/// 없다. 우리가 쓸 때 표시하면 된다.
///
/// ```
/// ✘ 용어집 키로 화면 문자열을 검색해서 자동으로 밑줄을 붙인다
/// ⭕ 문장 안에 토큰을 박는다 →  [[소가]]
/// ```
///
/// 이 한 줄이 `주소가` ⊃ `소가` · `생각하다` ⊃ `각하` · `확정신고` ⊃ `확정` ·
/// `인용문` ⊃ `인용` 문제를 **설계 단계에서 통째로 없앤다.** 골든셋으로 막는
/// 것이 아니라 막을 것이 애초에 생기지 않는다.
library;

/// 문장 한 토막. [term] 이 있으면 그 자리는 밑줄이다.
class TermSpan {
  const TermSpan(this.text, {this.term});

  /// 화면에 그릴 글자. 토큰이면 대괄호를 뗀 낱말 그대로다.
  final String text;

  /// 용어집 키. 평범한 글자면 null.
  final String? term;

  bool get isTerm => term != null;

  @override
  bool operator ==(Object other) =>
      other is TermSpan && other.text == text && other.term == term;

  @override
  int get hashCode => Object.hash(text, term);

  @override
  String toString() => isTerm ? 'TermSpan[[$text]]' : 'TermSpan($text)';
}

/// `[[낱말]]` 만 토큰으로 본다.
///
/// 안쪽에 대괄호·줄바꿈이 들어갈 일이 없으므로 좁게 잡는다. 넓게 잡으면
/// 조문 원문의 대괄호가 걸린다.
final RegExp _token = RegExp(r'\[\[([^\[\]\n]+)\]\]');

/// 문장을 토막으로 가른다. 토큰이 없으면 길이 1짜리 목록이다.
List<TermSpan> parseTerms(String source) {
  if (!source.contains('[[')) return [TermSpan(source)];

  final spans = <TermSpan>[];
  var at = 0;
  for (final match in _token.allMatches(source)) {
    if (match.start > at) {
      spans.add(TermSpan(source.substring(at, match.start)));
    }
    final word = match.group(1)!;
    spans.add(TermSpan(word, term: word));
    at = match.end;
  }
  if (at < source.length) spans.add(TermSpan(source.substring(at)));
  return spans;
}

/// 대괄호를 뗀 문장. **검사는 전부 이걸 본다.**
///
/// 금지어·어려운 말·조사 검사가 원문을 보면 `[[` 때문에 낱말이 갈라진다.
/// 사용자가 읽는 것도 이쪽이다.
String stripTerms(String source) =>
    source.contains('[[') ? source.replaceAllMapped(_token, (m) => m.group(1)!) : source;

/// 문장에 박힌 용어집 키. 나온 순서 그대로, 중복도 그대로 둔다.
List<String> termsIn(String source) =>
    [for (final m in _token.allMatches(source)) m.group(1)!];

/// 짝이 안 맞는 대괄호가 남았는가. **화면에 `[[` 가 새는 것을 막는다.**
bool hasStrayBrackets(String source) =>
    stripTerms(source).contains('[[') || stripTerms(source).contains(']]');
