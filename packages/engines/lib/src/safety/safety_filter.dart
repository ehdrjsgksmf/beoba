/// 문구 검사 범위.
enum SafetyScope {
  /// 앱이 **직접 말하는** 문구. 전체 금지어를 적용한다.
  strict,

  /// 사기꾼 멘트·체크리스트 등 **인용문**.
  ///
  /// "정부지원금 100% 받아 드립니다" 같은 문장은 인용이지 앱의 주장이 아니다.
  /// 다만 1인칭 단정 표현은 인용에서도 허용하지 않는다.
  ///
  /// **이 면제는 검수된 데이터(verification 있음)에만 주어진다.**
  /// 강제는 `SchemaValidator` 가 한다.
  quote,

  /// 앱이 **"우리는 하지 않는다"** 고 밝히는 문구.
  ///
  /// "승소 가능성은 안내하지 않습니다" 는 예측이 아니라 예측을 하지 않겠다는 선언인데,
  /// 부분 문자열 검사는 부정문을 구분하지 못해 `승소` 하나로 걸린다. 고지 문구를
  /// 못 실으면 오히려 사용자가 앱의 한계를 모른 채 쓴다.
  ///
  /// 그래서 **`승소` 라는 낱말 하나만** 풀어 준다. 단정 표현
  /// (`가능성이 높습니다` · `유리합니다` · `이길 수 있` …)은 그대로 막으므로
  /// "승소 가능성이 높습니다" 는 이 scope 에서도 통과하지 못한다.
  ///
  /// **데이터에는 이 scope 를 줄 수 없다.** `kFieldScopes` 에 넣지 않는다 —
  /// 앱이 손으로 쓴 고지 문구에만 쓴다.
  disclaimer,
}

class SafetyViolation {
  const SafetyViolation({
    required this.pattern,
    required this.start,
    required this.end,
    required this.excerpt,
    this.where,
  });

  final String pattern;
  final int start;
  final int end;

  /// 걸린 부분의 앞뒤를 붙인 조각.
  final String excerpt;

  /// 어느 필드에서 났는지.
  final String? where;

  @override
  String toString() =>
      '${where == null ? '' : '$where: '}"$excerpt" — 금지 표현 /$pattern/';
}

class SafetyViolationException implements Exception {
  const SafetyViolationException(this.violations);

  final List<SafetyViolation> violations;

  @override
  String toString() =>
      '사용자에게 보일 수 없는 문구입니다:\n  ${violations.join('\n  ')}';
}

/// 법률 판단으로 읽힐 수 있는 표현을 걸러 낸다.
///
/// 이 앱은 승패를 예측하지 않고 유불리를 평가하지 않는다.
/// **정적 문구도 예외 없이 통과해야 한다.**
class SafetyFilter {
  const SafetyFilter._();

  /// 앱이 직접 말할 때 금지되는 표현.
  static const List<String> strictPatterns = [
    // **돈이 얼마나 돌아올지는 아무도 모른다.** 전기통신금융사기 특별법
    // 제10조 제2항이 「소멸채권 금액에 각 피해자의 피해금액의 총피해금액에
    // 대한 비율을 곱한 금액」이라고 적어 두었다 — 계좌에 남은 돈을 나눈다는
    // 뜻이다. 총피해금액도 소멸채권액도 우리는 모른다(DECISIONS 178번).
    //
    // **「전액」 한 낱말로 막지 않는다.** 근로기준법 제43조가 「그 전액을
    // 지급하여야 한다」이고 그 문장은 옳다. 막는 것은 **다 돌아온다는 단정**
    // 이다 — 넓게 잡으면 오탐이 나고, 오탐이 나면 검사가 무뎌진다(39번).
    r'전액 돌려',
    r'전액을 돌려',
    r'전액 환급',
    r'다 돌려받',
    r'모두 돌려받',
    // 무엇에 당했는지도 우리가 정하지 않는다. 창구도 우리가 고르지 않는다.
    r'보이스피싱입니다',
    r'보이스피싱이에요',
    r'사기당하셨',
    r'경찰에 신고하세요',
    // 재촉은 우리 몫이 아니다. 날짜를 세어 보여주는 것이 우리 몫이다.
    r'지금 당장',
    r'서두르세요',
    r'승소',
    r'이길 수 있',
    r'유리합니다',
    r'가능성이 높습니다',
    r'100%',
    r'확실히',
    r'무조건',
    r'반드시 받',
    r'주장하세요',
    r'걱정하지',
    r'제 생각에',
    // **판정은 기관이 한다.** 「정당한 이유 없이」(근로기준법 제23조 제1항)를
    // 가르는 것은 노동위원회이고, 조문이 그렇게 적어 두었다. 우리가 그 판정을
    // 미리 말하면 그 순간 법률 판단이 된다(DECISIONS 157번).
    //
    // 조문 원문에는 이 낱말들이 그대로 들어 있다 — 그래서 `quote` 에는 안 넣는다.
    // 막는 것은 **우리 말**이다.
    r'부당해고입니다',
    r'부당해고예요',
    r'무효입니다',
    r'무효예요',
    r'위법입니다',
    r'위법이에요',
    r'사장이 잘못',
    r'사업주가 잘못',
    r'고소하세요',
    // **업무상 재해인지도 우리가 정하지 않는다.** 산업재해보상보험법 제37조
    // 제1항 단서가 「업무와 재해 사이에 상당인과관계가 없는 경우에는 그러하지
    // 아니하다」이고, 그 판단은 근로복지공단이 한다(DECISIONS 226번).
    //
    // 조문 원문에는 「업무상의 재해로 본다」가 그대로 있다 — 그래서 `quote` 에는
    // 안 넣는다. 막는 것은 **우리 말**이다.
    r'산재입니다',
    r'산재예요',
    r'산재 처리 됩니다',
    r'산재로 인정',
    r'인정받으실 수 있',
    // **없다는 말을 우리가 하지 않는다.** 사업주 확인이나 날인은 제41조
    // 제1항에 없지만, 없다는 말을 우리가 하는 것과 조문이 하는 것은 다르다.
    r'회사 동의 없이',
    r'사업주 동의 없이',
    // 시키는 말은 우리 몫이 아니다. 조문에 적힌 절차를 그대로 낸다.
    r'신청하세요',
    // **아직 아무것도 판단되지 않은 상대다.** 중고거래에서 돈만 받고 물건을
    // 안 보낸 사람이 죄가 되는지는 수사기관이 본다(DECISIONS 230번).
    //
    // 조문 원문에는 「기망」·「범죄」가 그대로 있다 — 그래서 `quote` 에는 안 넣는다.
    r'사기꾼',
    r'범인',
    // ★ **체류자격은 조문에 없다. 어느 방향으로도 말하지 않는다**
    // (DECISIONS 234번). 산재보험법 제6조는 「근로자를 사용하는 모든 사업
    // 또는 사업장에 적용한다」까지만 말하고 체류자격에는 아무 말이 없다.
    // 「미등록 외국인도 됩니다」도, 「불법체류자는 안 됩니다」도 우리 말이다.
    //
    // 조문(출입국관리법)과 기관 안내문에는 이 낱말이 그대로 있다 —
    // 그래서 `quote` 에는 안 넣는다. 막는 것은 **우리 말**이다.
    //
    // 「비자」는 **앞뒤를 봐야 한다.** 「소비자」 안에 그대로 들어 있고
    // 「비자발적 이직」은 실업급여의 조문 낱말이다. 넓게 잡으면 오탐이 나고,
    // 오탐이 나면 검사가 무뎌진다([39번](#39)).
    r'체류',
    r'미등록',
    r'(?<!소)비자(?!발적|금)',
    // 「도움받으실 수 있습니다」는 창구 안내다. 막는 것은 **돈·권리를 받는다는
    // 단정**이라 앞말로 가른다 — 오탐은 예외 패턴으로 구조로 막는다(DECISIONS 46번).
    r'(?<!도움|상담|안내|지원)받으실 수 있습니다',
  ];

  /// 인용문에서도 허용하지 않는 표현 = 앱의 1인칭 단정·조언.
  ///
  /// **`승소` 라는 낱말 하나는 여기 없다.** 인용은 우리 말이 아니고, 낱말은
  /// 단정이 아니다. 실제로 복지제도 안내문에서 걸렸다 —
  /// 「단, 승소가액 2억원 이상 … 사건은 제외」는 무료법률구조의 **지원 제외
  /// 기준**이고, 우리가 「이길 수 있어요」라고 말하는 것의 정반대다. 빼면
  /// 그 기준을 모르는 채 신청하게 된다(DECISIONS 201번).
  ///
  /// 조문 원문에 「무효」가 있어도 `quote` 에 안 넣은 것과 같은 자리다.
  /// 막는 것은 여전히 **문장**이다 — 「맡기시면 승소합니다」는 인용에서도
  /// 그대로 막힌다. 낱말을 문장으로 좁혔을 뿐 구멍을 낸 것이 아니다.
  static const List<String> quotePatterns = [
    r'승소합니다',
    r'승소해 드',
    r'승소시켜',
    r'이길 수 있',
    r'유리합니다',
    r'가능성이 높습니다',
    r'주장하세요',
    r'걱정하지',
    r'제 생각에',
  ];

  /// 고지 문구에서 금지되는 표현.
  ///
  /// [strictPatterns] 에서 `승소` 하나만 뺐다. 단정·조언은 그대로 막는다.
  /// 목록을 뺄셈으로 만들지 않고 직접 적는다 — 무엇이 허용되는지 눈으로 보여야 한다.
  static const List<String> disclaimerPatterns = [
    // **돈이 얼마나 돌아올지는 아무도 모른다.** 전기통신금융사기 특별법
    // 제10조 제2항이 「소멸채권 금액에 각 피해자의 피해금액의 총피해금액에
    // 대한 비율을 곱한 금액」이라고 적어 두었다 — 계좌에 남은 돈을 나눈다는
    // 뜻이다. 총피해금액도 소멸채권액도 우리는 모른다(DECISIONS 178번).
    //
    // **「전액」 한 낱말로 막지 않는다.** 근로기준법 제43조가 「그 전액을
    // 지급하여야 한다」이고 그 문장은 옳다. 막는 것은 **다 돌아온다는 단정**
    // 이다 — 넓게 잡으면 오탐이 나고, 오탐이 나면 검사가 무뎌진다(39번).
    r'전액 돌려',
    r'전액을 돌려',
    r'전액 환급',
    r'다 돌려받',
    r'모두 돌려받',
    // 무엇에 당했는지도 우리가 정하지 않는다. 창구도 우리가 고르지 않는다.
    r'보이스피싱입니다',
    r'보이스피싱이에요',
    r'사기당하셨',
    r'경찰에 신고하세요',
    // 재촉은 우리 몫이 아니다. 날짜를 세어 보여주는 것이 우리 몫이다.
    r'지금 당장',
    r'서두르세요',
    r'이길 수 있',
    r'유리합니다',
    r'가능성이 높습니다',
    r'100%',
    r'확실히',
    r'무조건',
    r'반드시 받',
    r'주장하세요',
    r'걱정하지',
    r'제 생각에',
    // **판정은 기관이 한다.** 「정당한 이유 없이」(근로기준법 제23조 제1항)를
    // 가르는 것은 노동위원회이고, 조문이 그렇게 적어 두었다. 우리가 그 판정을
    // 미리 말하면 그 순간 법률 판단이 된다(DECISIONS 157번).
    //
    // 조문 원문에는 이 낱말들이 그대로 들어 있다 — 그래서 `quote` 에는 안 넣는다.
    // 막는 것은 **우리 말**이다.
    r'부당해고입니다',
    r'부당해고예요',
    r'무효입니다',
    r'무효예요',
    r'위법입니다',
    r'위법이에요',
    r'사장이 잘못',
    r'사업주가 잘못',
    r'고소하세요',
    // **업무상 재해인지도 우리가 정하지 않는다.** 산업재해보상보험법 제37조
    // 제1항 단서가 「업무와 재해 사이에 상당인과관계가 없는 경우에는 그러하지
    // 아니하다」이고, 그 판단은 근로복지공단이 한다(DECISIONS 226번).
    //
    // 조문 원문에는 「업무상의 재해로 본다」가 그대로 있다 — 그래서 `quote` 에는
    // 안 넣는다. 막는 것은 **우리 말**이다.
    r'산재입니다',
    r'산재예요',
    r'산재 처리 됩니다',
    r'산재로 인정',
    r'인정받으실 수 있',
    // **없다는 말을 우리가 하지 않는다.** 사업주 확인이나 날인은 제41조
    // 제1항에 없지만, 없다는 말을 우리가 하는 것과 조문이 하는 것은 다르다.
    r'회사 동의 없이',
    r'사업주 동의 없이',
    // 시키는 말은 우리 몫이 아니다. 조문에 적힌 절차를 그대로 낸다.
    r'신청하세요',
    // **아직 아무것도 판단되지 않은 상대다.** 중고거래에서 돈만 받고 물건을
    // 안 보낸 사람이 죄가 되는지는 수사기관이 본다(DECISIONS 230번).
    //
    // 조문 원문에는 「기망」·「범죄」가 그대로 있다 — 그래서 `quote` 에는 안 넣는다.
    r'사기꾼',
    r'범인',
    // 체류자격은 조문에 없다. 고지 문구에서도 말하지 않는다(234번).
    r'체류',
    r'미등록',
    r'(?<!소)비자(?!발적|금)',
    // 「도움받으실 수 있습니다」는 창구 안내다. 막는 것은 **돈·권리를 받는다는
    // 단정**이라 앞말로 가른다 — 오탐은 예외 패턴으로 구조로 막는다(DECISIONS 46번).
    r'(?<!도움|상담|안내|지원)받으실 수 있습니다',
  ];

  static final Map<SafetyScope, List<RegExp>> _compiled = {
    SafetyScope.strict: strictPatterns.map(RegExp.new).toList(),
    SafetyScope.quote: quotePatterns.map(RegExp.new).toList(),
    SafetyScope.disclaimer: disclaimerPatterns.map(RegExp.new).toList(),
  };

  static bool isSafe(String text, {SafetyScope scope = SafetyScope.strict}) =>
      scan(text, scope: scope).isEmpty;

  static List<SafetyViolation> scan(
    String text, {
    SafetyScope scope = SafetyScope.strict,
    String? where,
  }) {
    final violations = <SafetyViolation>[];
    for (final pattern in _compiled[scope]!) {
      for (final match in pattern.allMatches(text)) {
        violations.add(
          SafetyViolation(
            pattern: pattern.pattern,
            start: match.start,
            end: match.end,
            excerpt: _excerpt(text, match.start, match.end),
            where: where,
          ),
        );
      }
    }
    return violations;
  }

  /// 위반이면 던진다. 위젯 빌드 시점에 부른다.
  static void assertSafe(
    String text, {
    SafetyScope scope = SafetyScope.strict,
    String? where,
  }) {
    final violations = scan(text, scope: scope, where: where);
    if (violations.isNotEmpty) {
      throw SafetyViolationException(violations);
    }
  }

  static String _excerpt(String text, int start, int end) {
    const padding = 12;
    final from = (start - padding).clamp(0, text.length);
    final to = (end + padding).clamp(0, text.length);
    final prefix = from > 0 ? '…' : '';
    final suffix = to < text.length ? '…' : '';
    return '$prefix${text.substring(from, to)}$suffix';
  }
}
