import 'domain.dart';

/// 쉬운 말이 **대신할 수 있는 자리**. 여기 없는 자리는 못 바꾼다.
///
/// 키는 묶음 이름(빈 문자열이면 분야 자체), 값은 그 묶음에서 바꿔도 되는 필드다.
///
/// ★ **조문 원문과 이름은 여기 없다.** `legalBasis.text` · `alsoBasis[].text` 는
/// 법이 쓴 말이라 한 글자도 못 바꾸고, 기관 이름(`sayThis.agency`)과 서식
/// 이름(`sayThis.form`)은 **창구에서 그 말을 그대로 써야 해서** 못 바꾼다.
/// 목록을 뺄셈으로 만들지 않고 **허용하는 자리만 적는다** — 새 필드가 생겨도
/// 저절로 열리지 않는다.
///
/// `label` 도 여기 없다. 이름은 문장이 아니라 이름표다 — 쉽게 바꾸는 것이
/// 아니라 짧게 두는 것이 맞고, 짧은 이름표를 또 하나 만들면 같은 것을 두 이름으로
/// 부르게 된다.
const Map<String, Set<String>> kPlainTargets = <String, Set<String>>{
  '': <String>{'description'},
  'intake': <String>{'text', 'whyAsk'},
  'cautions': <String>{'question', 'condition', 'consequence'},
  'procedures': <String>{'whatIsThis', 'detail'},
  'limitationRules': <String>{'note'},
};

/// 쉬운 말 한 벌을 실제로 끼워 넣는다.
///
/// **화면이 이걸 부르지 않는다.** 프로바이더가 분야를 통째로 갈아끼우고,
/// 화면은 자기가 어느 벌을 보고 있는지 모른다 — 그래야 쉬운 말을 켤 때
/// 고칠 화면이 하나도 없다.
extension PlainKorean on Domain {
  /// 쉬운 말 한 벌이 없으면 **자기 자신을 그대로 돌려준다.**
  Domain inPlainKorean() {
    if (plain.isEmpty) return this;

    String? at(String section, String id, String field) =>
        plain['$section.$id.$field'];

    return copyWith(
      description: plain['description'] ?? description,
      intake: [
        for (final q in intake)
          q.copyWith(
            text: at('intake', q.id, 'text') ?? q.text,
            whyAsk: at('intake', q.id, 'whyAsk') ?? q.whyAsk,
          ),
      ],
      cautions: [
        for (final c in cautions)
          c.copyWith(
            question: at('cautions', c.id, 'question') ?? c.question,
            condition: at('cautions', c.id, 'condition') ?? c.condition,
            consequence: at('cautions', c.id, 'consequence') ?? c.consequence,
          ),
      ],
      procedures: [
        for (final p in procedures)
          p.copyWith(
            whatIsThis: at('procedures', p.id, 'whatIsThis') ?? p.whatIsThis,
            detail: at('procedures', p.id, 'detail') ?? p.detail,
          ),
      ],
      limitationRules: [
        for (final r in limitationRules)
          r.copyWith(note: at('limitationRules', r.id, 'note') ?? r.note),
      ],
    );
  }
}
