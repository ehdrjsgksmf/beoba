/// 한글로 적은 금액을 읽는다. `formatWonKorean` 의 역방향.
///
/// ## 왜 필요한가
///
/// 사람은 "오천만원" 이라고 말하지 "50000000" 이라고 말하지 않는다. 말하는 대로
/// 적게 두고, **읽은 결과를 숫자로 되돌려 보여주어 사용자가 확인**하게 한다.
///
/// ## 못 읽으면 null 이다. 0 이 아니다
///
/// **금액이 소리 없이 0 이 되는 것이 가장 나쁘다.** 인지대·상한 판단이 통째로
/// 틀리는데 사용자는 자기가 0 을 넣었다는 사실조차 모른다. 못 읽으면 값을 만들지
/// 않고, 화면이 "이렇게 읽었어요 / 다시 적어 주세요" 로 되묻는다.
///
/// ## 십·백·천은 수를 만들고, 만·억·조·원은 크기를 못박는다
///
/// 이 구분이 애매한 입력을 가른다.
///
/// ```
/// 만원 칸에 "오천"     → 5,000만원   (십·백·천은 그냥 숫자 5000 이다)
/// 만원 칸에 "오천만"   → 5,000만원   (만 이 붙으면 절대 금액)
/// 만원 칸에 "1000원"  → 1,000원      (원 이 붙으면 절대 금액)
/// 원 칸에   "오천"     → 5,000원
/// ```
///
/// 근거 — 만원 칸에 `5000` 을 넣으면 5천만원이다. `오천` 은 `5000` 을 소리 나는
/// 대로 적은 것뿐이므로 같은 답이 나와야 한다. **칸의 단위를 글자가 바꾸려면
/// 글자가 단위를 말해야 한다.**
library;

/// 한자어 숫자.
const Map<String, int> _digits = {
  '영': 0,
  '공': 0,
  '일': 1,
  '이': 2,
  '삼': 3,
  '사': 4,
  '오': 5,
  '육': 6,
  '륙': 6,
  '칠': 7,
  '팔': 8,
  '구': 9,
};

/// 네 자리 안의 자리. **수를 만들 뿐 크기를 못박지 않는다.**
const Map<String, int> _smallUnits = {'십': 10, '백': 100, '천': 1000};

/// 네 자리씩 끊는 단위. **크기를 못박는다.**
/// 값은 한국어 자릿수이지 법률 수치가 아니다.
const Map<String, int> _bigUnits = {
  '만': 10000, // not-a-legal-number: 한국어 자릿수
  '억': 100000000, // not-a-legal-number: 한국어 자릿수
  '조': 1000000000000, // not-a-legal-number: 한국어 자릿수
};

/// 아라비아 숫자를 이어 붙일 수 있는 최대 자릿수. 조 단위를 넘으면 읽지 않는다.
const int _maxArabic = 999999999999; // not-a-legal-number: 자릿수 한계

/// 원 단위임을 못박는 글자.
const Set<String> _wonMarks = {'원'};

/// 읽은 결과.
class KoreanAmount {
  const KoreanAmount._(this.won, {required this.unitWasExplicit});

  /// 원 단위 금액.
  final int won;

  /// 글자가 스스로 단위를 말했는가. 아니면 칸의 단위를 따랐다.
  final bool unitWasExplicit;
}

/// [text] 를 원 단위 금액으로 읽는다. 못 읽으면 **null**.
///
/// [unit] 은 칸의 단위다 — 만원 칸이면 `10000`, 원 칸이면 `1`. 글자에 단위가
/// 없을 때만 쓰인다.
///
/// 빈 문자열도 null 이다. "아직 안 적었다" 와 "못 읽었다" 는 화면이 가른다.
KoreanAmount? parseKoreanWon(String text, {required int unit}) {
  final cleaned = text.replaceAll(RegExp(r'[\s,]'), '');
  if (cleaned.isEmpty) return null;

  var total = 0; // 확정된 큰 단위들의 합
  var group = 0; // 지금 네 자리 묶음
  var current = 0; // 아직 자리를 못 받은 수
  var sawDigit = false;
  var explicit = false;
  var arabic = 0;
  var inArabic = false;
  /// 직전에 본 큰 단위. 뒤에 오는 것은 이보다 작아야 한다.
  var lastBig = 1 << 62;

  void flushArabic() {
    if (!inArabic) return;
    current = arabic;
    arabic = 0;
    inArabic = false;
  }

  for (final char in cleaned.split('')) {
    final code = char.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) {
      arabic = arabic * 10 + (code - 0x30);
      if (arabic > _maxArabic) return null; // 자릿수가 터졌다
      inArabic = true;
      sawDigit = true;
      continue;
    }
    flushArabic();

    final digit = _digits[char];
    if (digit != null) {
      // "오오" 처럼 숫자가 연달아 오면 읽는 법이 하나로 정해지지 않는다.
      if (current != 0) return null;
      current = digit;
      sawDigit = true;
      continue;
    }

    final small = _smallUnits[char];
    if (small != null) {
      // "십" 은 "일십" 이다. 앞에 수가 없으면 1 로 읽는다.
      group += (current == 0 ? 1 : current) * small;
      current = 0;
      sawDigit = true;
      continue;
    }

    final big = _bigUnits[char];
    if (big != null) {
      // 큰 단위는 **반드시 작아지는 순서**로 온다 — 억 다음에 만이지 그 반대가
      // 아니다. "만억" · "만만" 은 읽는 법이 없다. 추측하지 않고 되묻는다.
      if (big >= lastBig) return null;
      lastBig = big;

      // "만원" 은 1만원이다. 앞에 수가 없으면 1 로 읽는다.
      final chunk = group + current;
      total += (chunk == 0 ? 1 : chunk) * big;
      group = 0;
      current = 0;
      explicit = true;
      sawDigit = true;
      continue;
    }

    if (_wonMarks.contains(char)) {
      explicit = true;
      continue;
    }

    // 읽는 법을 모르는 글자. **추측하지 않는다.**
    return null;
  }

  flushArabic();
  if (!sawDigit) return null;

  final value = total + group + current;
  if (value <= 0) return null;

  return KoreanAmount._(
    explicit ? value : value * unit,
    unitWasExplicit: explicit,
  );
}
