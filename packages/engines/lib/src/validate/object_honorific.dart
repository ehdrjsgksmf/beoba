/// 사물을 높이는 말을 찾는다.
///
/// 「50,000,000원이시군요」는 **사물 존대**다. 「주문하신 커피 나오셨습니다」와 같은
/// 오류이고, 금액에 `-이시-` 를 붙일 수 없다. 높이는 대상은 사용자뿐이다.
///
/// **이 앱은 정확함을 파는데, 문법이 틀리면 그 인상이 계산까지 번진다.**
///
/// ## 좁게만 잡는다
///
/// 사물 존대를 일반적으로 잡으려면 문장의 주어가 사람인지 사물인지 알아야 하고,
/// 그건 형태소 분석 없이는 못 한다. 「무슨 일이세요?」는 멀쩡한 한국어인데
/// 「일 + 이세요」만 보고 잡으면 오탐이다.
///
/// 그래서 **틀릴 수 없는 자리만** 본다 (`KeywordMatch` 와 같은 태도다):
///
/// 1. `{value}` **바로 뒤**에 붙은 존대 조사 — 되받는 말에 끼워지는 값은
///    금액·날짜·선택지뿐이고 **사람인 적이 없다.** 여기 존대가 붙으면 무조건 오류다
/// 2. 단위 낱말에 **직접 붙은** 존대 — `원이시` · `건이시`. 이 꼴이 맞는 경우가 없다
///
/// 나머지(사물 주어 + `나오셨` · `계세요`)는 잡지 않는다. 규칙은 사람이 지킨다
/// (DECISIONS 41번).
abstract final class ObjectHonorific {
  /// 값 바로 뒤에 오면 사물을 높이는 것이 되는 꼴.
  ///
  /// `{value}이군요` 는 괜찮고 `{value}이시군요` 는 안 된다.
  /// `{value}에 받기로 하셨군요` 도 괜찮다 — 높이는 대상이 사용자다.
  static const List<String> afterValue = ['이시', '이세', '이십', '세요', '시군요'];

  /// 값이 끼워지는 자리 표시.
  static const String valueSlot = '{value}';

  /// 단위 낱말 + 존대. 이 꼴이 맞는 문장은 없다.
  ///
  /// `명이시` 는 **넣지 않는다** — 「세 명이시군요」는 사람을 세는 말이라 맞다.
  /// `일이세` 도 넣지 않는다 — 「무슨 일이세요?」는 멀쩡하다.
  static const List<String> unitPatterns = [
    '원이시',
    '원이세',
    '원이십',
    '건이시',
    '건이세',
    '장이시',
    '개이시',
    '번이시',
    '기한이시',
    '서류이시',
    '날짜이시',
  ];

  /// [text] 에서 사물을 높이는 자리를 찾는다. 없으면 null.
  static String? find(String text) {
    final slot = text.indexOf(valueSlot);
    if (slot >= 0) {
      final tail = text.substring(slot + valueSlot.length);
      for (final ending in afterValue) {
        if (tail.startsWith(ending)) return '$valueSlot$ending';
      }
    }

    for (final pattern in unitPatterns) {
      if (text.contains(pattern)) return pattern;
    }
    return null;
  }
}
