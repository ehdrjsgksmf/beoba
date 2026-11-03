/// 쉬운 한국어 한 벌이 지켜야 하는 것.
///
/// **쉬운 말 작업에서 제일 흔한 사고는 어려운 낱말이 아니라 미끄러진 어미다.**
/// 「~할 수 있어요」가 「~하면 돼요」로, 「~일 수 있어요」가 「~예요」로 간다.
/// 짧게 쓰려다 조건절을 지우면 그 자리가 곧 단정이 된다.
///
/// 그래서 이 검사는 **원래 문장과 나란히 놓고 잰다.** 쉬운 문장 하나만 보면
/// 「~예요」가 잘못인지 알 수 없다 — 원래가 「~예요」였으면 맞고 「~일 수
/// 있어요」였으면 틀렸다. 원본이 없는 검사는 이 사고를 못 잡는다.
///
/// ## ★★ 이 검사가 못 보는 것 — 통과했다고 맞은 것이 아니다
///
/// **어미 강도는 보지만 주어와 동사가 바뀐 것은 못 본다.**
///
/// ```
/// 보통    장관이 … 정지시킬 것을 요청할 수 있다고 적혀 있어요   강도 0
/// 쉬운 말  운전면허를 정지시킬 수 있다고 적혀 있어요           강도 0   ← 통과
/// ```
///
/// 둘 다 「수 있」이라 강도가 같다. 그런데 「**요청할** 수 있다」가 「**정지시킬**
/// 수 있다」가 됐다. 같은 까닭으로 조문의 단서(「~인정되는 경우에는 그러하지
/// 아니하다」)가 「~하지 않아요」라는 약속으로 바뀐 것도 못 본다 — 그 문장의
/// 어미는 원래부터 단정이었으니까(DECISIONS 270번).
///
/// **쉬운 말은 조문에서 두 번 옮긴 것이라 두 배로 샌다.** 이 검사를 믿고 넘어가지
/// 말고, 쉬운 말 한 벌은 사람이 조문과 나란히 놓고 한 번 더 본다.
library;

/// 한 문장의 상한. **숫자는 여기 한 곳에만 있다.**
const int kPlainMaxChars = 40;

/// 무엇에 걸렸는가. 세어서 보고하려고 이름을 붙인다.
enum PlainRule {
  /// 한 문장이 [kPlainMaxChars] 자를 넘었다.
  tooLong,

  /// 서술어를 이어 붙였다 — 「~하고,」·「~하며」·「~하면서」.
  joined,

  /// 시키는 말이 됐다. 쉬운 말에서는 어느 경우에도 안 된다.
  order,

  /// 이중부정.
  doubleNegative,

  /// 이중피동. 줄일 것이 아니라 틀린 것이다.
  doublePassive,

  /// ★ 원래 문장보다 단정해졌다.
  moreAssertive,

  /// ★ 원래 문장이 열어 둔 「수 있」이 사라졌다.
  lostHedge,

  /// 어려운 법률 용어를 우리 마음대로 바꿨다.
  lostTerm,
}

class PlainIssue {
  const PlainIssue(this.rule, this.message);

  final PlainRule rule;
  final String message;

  @override
  String toString() => message;
}

/// 시키는 말.
final RegExp _order = RegExp(
  r'(세요|십시오|해야 (해요|합니다|돼요|됩니다)|[가-힣]면 (돼요|됩니다|되세요))',
);

/// 「그럴 수 있다」쪽으로 여는 말.
final RegExp _maybe = RegExp(r'(수 있|수도 있|것 같|는지|을지|ㄹ지|일지|모르|아마)');

/// ★ 원래 문장이 열어 둔 자리. 쉬운 말이 이걸 닫으면 단정이 된다.
final RegExp _can = RegExp(r'수 있|수도 있');

final RegExp _doubleNegative =
    RegExp(r'(않으면 안|없지 않|아니라고 할 수 없|없는 것은 아니|못 하는 것은 아니)');

final RegExp _doublePassive =
    RegExp(r'(되어|지어|보여|쓰여|불려|나뉘어|모아)(지|져|졌)');

final RegExp _joined = RegExp(r'([가-힣]고,|[가-힣]며|[가-힣]면서)');

/// 세기만 하는 것 — 단순 피동. **막지 않는다.**
///
/// 「최소화」는 0으로 만들라는 말이 아니다. 넓게 막으면 오탐이 나고, 오탐이
/// 나면 검사가 무뎌진다(DECISIONS 39번). 다만 이중피동은 위에서 막는다.
final RegExp _passive = RegExp(r'(되[는나어었다서지]|돼[요서]|됩니다|된다|[가-힣](아|어|여)(지|져|졌))');

class PlainKoreanCheck {
  const PlainKoreanCheck();

  /// 문장으로 자른다. `[[낱말]]` 표시는 화면에 안 나가므로 떼고 센다.
  static List<String> sentences(String text) => bare(text)
      .split(RegExp(r'(?<=[.?!])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static String bare(String text) =>
      text.replaceAll('[[', '').replaceAll(']]', '');

  /// 어미 강도. 0 그럴 수 있다 · 1 그렇다 · 2 그렇게 하라.
  ///
  /// **글 한 벌을 통째로 잰다. 문장마다 재지 않는다.** 문장마다 재서 제일 센
  /// 것을 고르면 「그래서 여쭤봅니다」 같은 곁말 하나에 글 전체가 단정으로
  /// 찍힌다. 우리가 보려는 것은 **그 안내가 열어 둔 자리를 쉬운 말이
  /// 닫았는가**이지 곁말의 어미가 아니다.
  static int level(String text) {
    if (_order.hasMatch(text)) return 2;
    if (_maybe.hasMatch(text)) return 0;
    return 1;
  }

  /// 단순 피동이 몇 곳인가. 막지 않고 센다.
  static int passiveCount(String text) => _passive.allMatches(text).length;

  /// [plain] 이 [original] 을 대신해도 되는가.
  ///
  /// [terms] 는 용어집 낱말이다. 원래 문장이 쓴 말이 쉬운 말에서 사라지면
  /// 걸린다 — **바꾸는 것이 아니라 옆에 풀이를 다는 것**이 규칙이다.
  /// 「소멸시효」를 「기한」으로 바꿔 버리면 창구에서 그 말을 못 쓴다.
  ///
  /// [longOk] 는 **이 자리에서만 40자 규칙을 놓아 주는 이유**다.
  ///
  /// ★ **40자는 수단이지 목적이 아니다.** 목적은 한국어가 서툰 분이 읽을 수
  /// 있게 하는 것이고, 거기서 주범은 어려운 낱말이다. 열거를 담은 문장은
  /// 40자 아래로 쪼개려면 서술어를 되풀이해야 해서 **쪼갤수록 길어진다** —
  /// 수단을 지키다 목적을 잃는 자리다. 그런 자리에서는 낱말만 쉽게 바꾸고
  /// 문장은 그대로 둔다(DECISIONS 265번).
  ///
  /// **놓아 주는 것은 [PlainRule.tooLong] 하나뿐이다.** 이어 붙임·시키는
  /// 말·이중피동·단정해짐은 길이와 상관없이 그대로 막는다 — 그것들은
  /// 「길어서 생긴 일」이 아니라 뜻이 달라지는 일이다.
  ///
  /// 이유가 비어 있으면 **놓아 주지 않는다.** 빈 이유를 눈감으면 이유를
  /// 요구하는 뜻이 없어진다.
  List<PlainIssue> check({
    required String original,
    required String plain,
    List<String> terms = const [],
    String? longOk,
  }) {
    final lengthWaived = longOk != null && longOk.trim().isNotEmpty;
    final issues = <PlainIssue>[];

    for (final sentence in sentences(plain)) {
      if (sentence.length > kPlainMaxChars && !lengthWaived) {
        issues.add(PlainIssue(
          PlainRule.tooLong,
          '한 문장이 ${sentence.length}자입니다. $kPlainMaxChars자 아래로 '
              '자르세요: "$sentence"',
        ));
      }
      if (_joined.hasMatch(sentence)) {
        issues.add(PlainIssue(
          PlainRule.joined,
          '서술어를 이어 붙였습니다. 문장을 나누세요: "$sentence"',
        ));
      }
      if (_order.hasMatch(sentence)) {
        issues.add(PlainIssue(
          PlainRule.order,
          '시키는 말입니다. 조문에 적힌 것을 그대로 냅니다: "$sentence"',
        ));
      }
    }

    if (_doubleNegative.hasMatch(plain)) {
      issues.add(const PlainIssue(PlainRule.doubleNegative, '이중부정입니다. 곧게 쓰세요'));
    }
    if (_doublePassive.hasMatch(plain)) {
      issues.add(const PlainIssue(PlainRule.doublePassive, '이중피동입니다'));
    }

    final was = level(original);
    final now = level(plain);
    if (now > was) {
      issues.add(PlainIssue(
        PlainRule.moreAssertive,
        '원래 문장보다 단정합니다(강도 $was → $now)',
      ));
    }
    if (_can.hasMatch(original) && !_can.hasMatch(plain)) {
      issues.add(const PlainIssue(
        PlainRule.lostHedge,
        '원래 문장의 「수 있」이 사라졌습니다. 열어 둔 자리를 닫으면 단정이 됩니다',
      ));
    }

    final bareOriginal = bare(original);
    final barePlain = bare(plain);
    for (final term in terms) {
      if (!bareOriginal.contains(term)) continue;
      if (barePlain.contains(term)) continue;
      issues.add(PlainIssue(
        PlainRule.lostTerm,
        '「$term」이 사라졌습니다. 어려운 말은 바꾸는 것이 아니라 옆에 풀이를 '
            '답니다 — 창구에서 그 말을 그대로 써야 합니다',
      ));
    }

    return issues;
  }
}
