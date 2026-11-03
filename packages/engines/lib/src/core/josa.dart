/// 앞말의 받침을 보고 조사를 고른다.
///
/// ## 왜 함수가 필요한가
///
/// 조사를 문자열로 이어 붙이면 **낱말이 늘어날 때마다 다시 틀린다.**
/// 「인지대은」이 실제로 화면에 나갔다. 한 곳을 고쳐도 다음 낱말에서 또 나온다.
/// 낱말이 아니라 구조를 고치는 자리다 (DECISIONS 46).
///
/// ## 다만 **첫 번째 답은 조사를 없애는 것이다**
///
/// ```
/// 인지대는 5,000원으로 계산됩니다   ← 조사가 둘
/// 인지대 5,000원                    ← 조사가 없다
/// ```
///
/// 짧고, 틀릴 자리가 없고, 숫자가 앞으로 나온다. 이 함수는 **없앨 수 없는
/// 자리에만** 쓴다.
///
/// ## 규칙
///
/// 받침이 있으면 앞엣것, 없으면 뒤엣것이다. 예외가 하나 있다 —
/// `으로/로` 는 받침 ㄹ 을 **받침 없는 것처럼** 다룬다 (서울로 · 판결로).
library;

/// 앞말에 따라 갈리는 조사 짝.
enum Josa {
  /// 은 / 는
  topic('은', '는'),

  /// 이 / 가
  subject('이', '가'),

  /// 을 / 를
  object('을', '를'),

  /// 과 / 와
  with_('과', '와'),

  /// 으로 / 로. **받침 ㄹ 은 받침 없는 쪽이다.**
  by('으로', '로'),

  /// 이라 / 라
  called('이라', '라');

  const Josa(this.afterFinal, this.afterVowel);

  /// 받침이 있을 때.
  final String afterFinal;

  /// 받침이 없을 때.
  final String afterVowel;

  /// `word` 뒤에 붙일 조사.
  String after(String word) {
    final coda = _codaOf(word);
    if (coda == _Coda.none) return afterVowel;
    // ㄹ 만 따로 갈리는 것은 `으로/로` 뿐이다.
    if (coda == _Coda.rieul && this == Josa.by) return afterVowel;
    return afterFinal;
  }
}

/// 낱말과 조사를 붙여 준다.
///
/// ```dart
/// withJosa('인지대', Josa.topic)  // 인지대는
/// withJosa('판결', Josa.by)       // 판결로
/// ```
String withJosa(String word, Josa josa) => '$word${josa.after(word)}';

/// 받침의 종류. ㄹ 만 따로 세는 이유는 `으로/로` 하나 때문이다.
enum _Coda { none, rieul, other }

/// 마지막 **소리 나는** 글자의 받침.
///
/// 괄호·따옴표·마침표로 끝나는 말이 흔해서 뒤에서부터 건너뛴다.
/// 「기산일이 2026년 8월 15일」처럼 숫자로 끝나면 **읽는 소리**로 판정한다 —
/// 3(삼)·6(육)은 받침이 있고 2(이)·4(사)는 없다.
_Coda _codaOf(String word) {
  for (var i = word.length - 1; i >= 0; i--) {
    final code = word.codeUnitAt(i);

    const hangulStart = 0xAC00;
    const hangulEnd = 0xD7A3;
    if (code >= hangulStart && code <= hangulEnd) {
      final finalIndex = (code - hangulStart) % 28;
      if (finalIndex == 0) return _Coda.none;
      // 자모 순서에서 ㄹ 은 여덟 번째 종성이다.
      return finalIndex == 8 ? _Coda.rieul : _Coda.other;
    }

    if (code >= 0x30 && code <= 0x39) return _digitCoda[code - 0x30]!;

    // 괄호·쉼표·공백 따위는 건너뛰고 그 앞 글자를 본다.
    if (_skippable.contains(code)) continue;

    // 한글도 숫자도 아니면(영문·한자) 알 수 없다. **받침이 있는 쪽으로 둔다** —
    // 「lease이라면」이 어색해도 「lease라면」보다 덜 틀린다.
    return _Coda.other;
  }
  return _Coda.other;
}

/// 한자어 숫자의 받침. 0 영 · 1 일 · 3 삼 · 6 육 · 7 칠 · 8 팔 에 받침이 있고
/// 그중 1·7·8 은 ㄹ 이다.
const Map<int, _Coda> _digitCoda = {
  0: _Coda.other, // 영
  1: _Coda.rieul, // 일
  2: _Coda.none, // 이
  3: _Coda.other, // 삼
  4: _Coda.none, // 사
  5: _Coda.none, // 오
  6: _Coda.other, // 육
  7: _Coda.rieul, // 칠
  8: _Coda.rieul, // 팔
  9: _Coda.none, // 구
};

/// 소리 나지 않는 꼬리. 여기서 멈추지 않고 앞 글자를 본다.
const Set<int> _skippable = {
  0x20, // 공백
  0x29, // )
  0x5D, // ]
  0x7D, // }
  0x2E, // .
  0x2C, // ,
  0x300D, // 」
  0x2019, // ’
  0x201D, // ”
  0xFF09, // ）
};
