/// 낱말 검사.
///
/// **문자열 매칭은 문맥을 모른다.** 그걸 인정하고 시작한다.
/// 여기 있는 것은 넓게 잡는 그물이 아니라 **틀릴 수 없는 것만 잡는 바닥**이다.
/// 놓치는 것은 받아들인다 — 잘못 잡는 쪽이 더 나쁘다.
///
/// 왜 그런가. 위기 안내가 잘못 뜨면 사용자는 앱이 자기 말을 못 알아듣는다고 느끼고,
/// 그다음부터는 진짜 안내도 무시한다. 안내를 한 번 놓치는 것보다 **신뢰를 잃는 것이
/// 더 크다.** 하드스톱이면 아예 쫓아낸다.
///
/// 세 겹으로 거른다:
/// 1. 패턴을 좁게 (데이터)
/// 2. 예외 낱말 — 걸린 그 패턴만 무효 (데이터)
/// 3. 부정 표현 — 걸린 자리 뒤를 본다 (코드. 한국어 문법이지 분야 지식이 아니다)
abstract final class KeywordMatch {
  /// 부정 표현을 찾아볼 범위. 패턴이 끝난 자리부터 몇 글자.
  ///
  /// 한국어는 부정이 서술어 뒤에 온다 — "협박한 적 없습니다".
  /// 너무 넓히면 다음 문장의 부정까지 끌어온다.
  static const int negationWindow = 12;

  /// 없다고 말하는 표현.
  ///
  /// `없어` 처럼 짧은 것은 넣지 않는다 — "없어지지 않아요"(= 여전히 그렇다)를
  /// 없다는 말로 읽어 버린다. 종결형만 넣는다.
  static const List<String> negations = [
    '적 없',
    '적은 없',
    '적이 없',
    '적도 없',
    '지 않',
    '않았',
    '않습니다',
    '않아요',
    '안 했',
    '안 합니다',
    '안 해',
    '아닙니다',
    '아니에요',
    '아니라',
    '없습니다',
    '없어요',
    '없었',
    '못 했',
  ];

  /// [patterns] 중 살아남은 것이 하나라도 있는가.
  static bool any(
    Iterable<String> texts,
    List<String> patterns, {
    List<String> exceptPatterns = const [],
  }) =>
      firstHit(texts, patterns, exceptPatterns: exceptPatterns) != null;

  /// 살아남은 첫 패턴. 없으면 null.
  ///
  /// **어느 문장에서 걸렸는지는 돌려주지 않는다.** 위기 신호가 걸린 문장에는 사람의
  /// 가장 사적인 말이 들어 있고, 그건 화면 밖 어디에도 남으면 안 된다.
  static String? firstHit(
    Iterable<String> texts,
    List<String> patterns, {
    List<String> exceptPatterns = const [],
  }) {
    for (final text in texts) {
      for (final pattern in patterns) {
        if (pattern.isEmpty) continue;
        if (_hitsIn(text, pattern, exceptPatterns)) return pattern;
      }
    }
    return null;
  }

  /// 예외에 덮이지 않은 채 그 낱말이 나오는가. **부정 표현은 보지 않는다.**
  ///
  /// 위기·하드스톱 검사는 "없다고 말하는지" 가 중요하지만 **어려운 말 검사는
  /// 다르다** — "송달받은 적 없습니다" 도 여전히 읽기 어렵다.
  static bool occurs(
    String text,
    String pattern, {
    List<String> exceptPatterns = const [],
  }) =>
      _hitsIn(text, pattern, exceptPatterns, checkNegation: false);

  /// 한 문장 안에서 그 패턴이 **살아 있는 채로** 나오는가.
  ///
  /// 같은 패턴이 여러 번 나올 수 있다. 하나라도 살아남으면 걸린 것이다 —
  /// "협박당한 적 없는데 어제 또 협박당했어요" 는 걸려야 한다.
  static bool _hitsIn(
    String text,
    String pattern,
    List<String> exceptPatterns, {
    bool checkNegation = true,
  }) {
    var from = 0;
    while (true) {
      final at = text.indexOf(pattern, from);
      if (at < 0) return false;
      final end = at + pattern.length;

      if (!_excepted(text, at, end, exceptPatterns) &&
          !(checkNegation && _negated(text, end))) {
        return true;
      }
      from = at + 1;
    }
  }

  /// 예외 낱말이 이 히트를 **덮고 있는가**.
  ///
  /// 겹칠 때만 무효다. 문장 저 끝에 있는 예외 낱말이 무관한 히트까지 지우면 안 된다.
  /// "혼자살고 있는데 죽고 싶어요" 에서 `혼자살` 은 `자살` 히트만 지우고
  /// `죽고 싶` 은 그대로 살린다.
  static bool _excepted(
    String text,
    int at,
    int end,
    List<String> exceptPatterns,
  ) {
    for (final except in exceptPatterns) {
      if (except.isEmpty) continue;
      var from = 0;
      while (true) {
        final exAt = text.indexOf(except, from);
        if (exAt < 0) break;
        final exEnd = exAt + except.length;
        // 두 구간이 겹치는가
        if (exAt < end && at < exEnd) return true;
        from = exAt + 1;
      }
    }
    return false;
  }

  /// 히트 바로 뒤에서 부정 표현이 오는가.
  static bool _negated(String text, int end) {
    if (end >= text.length) return false;
    final tail = text.substring(
      end,
      (end + negationWindow).clamp(end, text.length),
    );
    for (final negation in negations) {
      if (tail.contains(negation)) return true;
    }
    return false;
  }
}
