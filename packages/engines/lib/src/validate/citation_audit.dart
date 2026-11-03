/// **인용 점검 — 우리 문장이 조문을 넘는가.**
///
/// ★★ **이건 잡아내는 장치가 아니라 사람이 볼 순서를 정하는 장치다.**
/// 표시가 없다고 맞는 것이 아니다. 「조문을 넘는가」는 기계가 못 본다 —
/// 낱말이 조문에 있어도 우리 문장이 더 넓게 말할 수 있고, 낱말이 없어도
/// 조문을 정확히 풀어 쓴 것일 수 있다.
///
/// ## 왜 있나
///
/// DECISIONS 268 · 269 · 270 — 사흘에 셋이 나왔다. 두 번이면 우연이 아니다.
/// 인용 가운데 몇 개가 조문을 넘는지 아무도 몰랐다. 이 파일은 그 숫자를
/// 게이트(`verify_domains` 검사 (al))와 점검표(`docs/인용_점검.md`)가
/// **같은 규칙으로** 세게 한다. 두 벌이면 둘이 어긋난다.
///
/// ## 이 표가 못 보는 것 (270번 ④)
///
/// **「조문에 있는데 우리가 안 말한 것」은 영원히 못 잡는다.** 없는 낱말은
/// 셀 수가 없다. 그리고 넘는 것을 걷어낼 때 조문에 있는 것까지 같이 걷히기
/// 쉽다. 그래서 손댄 인용을 따로 적는다 — 「고쳤다」는 「맞다」가 아니다.
///
/// 순수 Dart 다. 도메인 JSON 을 **날것 그대로** 받는다 — 검사기는 모델을
/// 거치지 않고 파일을 읽는다.
library;

/// 인용 한 개 — 우리 문장 한 벌 × 그 문장이 기대는 조문 원문 한 조각.
///
/// **조문 단위로 세지 않는다.** 넘치는 것은 조문이 아니라 우리 문장이다.
/// 같은 조문을 세 자리가 각각 다른 말로 옮기면 여기서는 셋이다.
class CitationRow {
  const CitationRow({
    required this.domain,
    required this.where,
    required this.kind,
    required this.cite,
    required this.lawText,
    required this.ours,
  });

  final String domain;

  /// `cautions.ct_license` 같은 자리.
  final String where;

  /// `legalBasis` 또는 `alsoBasis`.
  final String kind;
  final String cite;
  final String lawText;
  final List<OurLine> ours;

  /// 점검 기록(`review/citations.json`)이 가리키는 열쇠.
  String get key => '$domain.$where';
}

/// 사람에게 나가는 우리 문장 한 줄.
class OurLine {
  const OurLine(this.field, this.text, this.mode);
  final String field;
  final String text;

  /// `보통` 또는 `쉬운 말`.
  final String mode;
}

/// 표시할 낱말 한 갈래.
class CitationMark {
  const CitationMark(this.name, this.ours, this.law);

  final String name;

  /// 우리 문장에서 찾는 것.
  final List<String> ours;

  /// 조문에 이 중 하나가 있으면 표시하지 않는다.
  final List<String> law;
}

/// 앞의 일곱은 받은 목록이고 뒤의 넷은 단정의 전형이라 더했다.
const List<CitationMark> kCitationMarks = [
  CitationMark('유지', ['유지'], ['유지']),
  CitationMark('계속', ['계속'], ['계속']),
  CitationMark('하지 않으면', ['하지 않으면', '안 하면', '않으면'],
      ['아니하면', '않으면', '아니한 때', '아니한 경우', '아니하는 경우', '없으면']),
  CitationMark('잃는다', ['잃'], ['잃', '상실', '소멸']),
  CitationMark('된다', ['됩니다', '돼요', '된다고', '되어요'],
      ['된다', '되는', '되어', '되며', '됨', '본다', '된 ']),
  CitationMark('해야 한다', ['해야', '셔야', '어야 해', '아야 해', '여야 해'],
      ['하여야', '해야', '아야 한다', '어야 한다', '여야 한다']),
  CitationMark('할 수 있다', ['수 있'], ['수 있']),
  CitationMark('반드시', ['반드시', '무조건'], ['반드시']),
  CitationMark('자동으로', ['자동으로', '저절로', '당연히'], ['당연히', '자동']),
  CitationMark('즉시', ['즉시', '곧바로'], ['즉시', '지체 없이', '곧바로', '지체없이']),
  CitationMark('모두·전부', ['모두', '전부'], ['모두', '전부', '모든']),
];

/// 사람에게 나가는 우리 문장 자리. `verification.note` 같은 속 메모는 뺀다.
/// `phrase` 도 뺀다 — 사기 알림에서 **상대가 하는 말**이다.
const List<String> kCitationTextFields = [
  'question', 'condition', 'consequence', 'label', 'whatIsThis', 'detail',
  'note', 'rule', 'lookupNote', 'why', 'text', 'truth', 'action',
];

final RegExp _quote = RegExp('「[^」]*」');

/// **길 안내 문장은 법 주장이 아니다.** 「아래 창구에서 확인할 수 있어요」는
/// 조문에 기댄 말이 아니라 사람을 창구로 보내는 말이다. 「할 수 있다」에서만
/// 빼고, 몇 곳을 뺐는지 같이 낸다.
final RegExp _guide = RegExp('창구|상담|물어보|물어볼');

final RegExp _sentenceEnd = RegExp(r'(?<=[.?!])\s+');

/// 조문에 단서가 있다.
final RegExp _proviso = RegExp('다만|그러하지 아니하|그러하지 않');

/// 단서 안에 재량이 걸려 있다 — 누군가 「인정」해야 풀린다.
final RegExp _discretion = RegExp('인정되는|인정하는|인정할|인정된|인정한');

final RegExp _saysProviso = RegExp('다만|단서|그러하지|예외|제외|빠지|빠진|빼고|뺀');
final RegExp _saysDiscretion = RegExp('인정');

bool _isBasis(Object? x) =>
    x is Map &&
    x['text'] is String &&
    (x.containsKey('law') || x.containsKey('citation') || x.containsKey('article'));

String _citeName(Map<dynamic, dynamic> b) {
  final c = b['citation'];
  if (c is String && c.isNotEmpty) return c;
  return '${b['law'] ?? ''} ${b['article'] ?? ''}'.trim();
}

/// 분야 JSON 하나에서 인용을 전부 모은다.
List<CitationRow> collectCitations(String domainId, Map<String, dynamic> json) {
  final rows = <CitationRow>[];
  final plain = (json['plain'] as Map?) ?? const {};

  void walk(Object? node, String section, Object? itemId) {
    if (node is List) {
      for (final v in node) {
        walk(v, section, itemId);
      }
      return;
    }
    if (node is! Map) return;
    final id = node['id'] ?? itemId;

    final bases = <(String, Map<dynamic, dynamic>)>[];
    for (final k in const ['legalBasis', 'basis']) {
      final b = node[k];
      if (_isBasis(b)) bases.add(('legalBasis', b as Map));
    }
    for (final b in (node['alsoBasis'] as List?) ?? const []) {
      if (_isBasis(b)) bases.add(('alsoBasis', b as Map));
    }

    if (bases.isNotEmpty) {
      final ours = <OurLine>[];
      for (final f in kCitationTextFields) {
        final v = node[f];
        if (v is! String || v.trim().isEmpty) continue;
        ours.add(OurLine(f, v, '보통'));
        final easy = plain['$section.$id.$f'];
        if (easy is String) ours.add(OurLine(f, easy, '쉬운 말'));
      }
      final where = section.isEmpty ? '$id' : '$section.$id';
      for (final (kind, b) in bases) {
        rows.add(CitationRow(
          domain: domainId,
          where: where,
          kind: kind,
          cite: _citeName(b),
          lawText: b['text'] as String,
          ours: List.unmodifiable(ours),
        ));
      }
    }

    for (final e in node.entries) {
      final k = e.key;
      if (k == 'legalBasis' || k == 'basis' || k == 'alsoBasis' ||
          k == 'verification') {
        continue;
      }
      final v = e.value;
      walk(v, section.isNotEmpty ? section : (v is List ? '$k' : section), id);
    }
  }

  for (final e in json.entries) {
    if (e.key == 'plain' || e.key == 'plainLongOk' || e.key == 'tests') continue;
    walk(e.value, e.value is List ? e.key : '', json['id']);
  }
  return rows;
}

List<String> _sentences(String text) => text
    .split(_sentenceEnd)
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// 한 인용의 표시. **그 인용의 조문 하나와만 대조한다.**
///
/// 처음에는 그 항목의 조문 전부(legalBasis + alsoBasis)와 대조했는데, 그러면
/// 이 표를 만든 까닭인 `ct_before_moving` 을 놓쳤다 — 옆 조문 제3조의3 ⑤에
/// 「그대로 유지되며」가 다른 뜻으로 들어 있어서 넘어갔다(269번).
class CitationFlags {
  const CitationFlags(this.marks, this.guided);

  /// 낱말 이름 → 걸린 모드(`보통` · `쉬운 말`).
  final Map<String, Set<String>> marks;

  /// 길 안내라서 「할 수 있다」에서 뺀 문장 수.
  final int guided;

  bool get isEmpty => marks.isEmpty;

  /// 걸린 모드 전부.
  Set<String> get modes => {for (final v in marks.values) ...v};
}

CitationFlags flagCitation(CitationRow row) {
  final law = row.lawText;
  final found = <String, Set<String>>{};
  var guided = 0;
  for (final line in row.ours) {
    for (final s in _sentences(line.text.replaceAll(_quote, ''))) {
      for (final m in kCitationMarks) {
        if (!m.ours.any(s.contains)) continue;
        if (m.law.any(law.contains)) continue;
        if (m.name == '할 수 있다' && _guide.hasMatch(s)) {
          guided++;
          continue;
        }
        found.putIfAbsent(m.name, () => <String>{}).add(line.mode);
      }
    }
  }
  return CitationFlags(found, guided);
}

/// 조문의 단서를 우리가 어떻게 옮겼나.
///
/// ```
/// (가) 단서가 우리 문장에서 아예 사라짐   — 사람이 볼 것. 전부 잘못은 아니다
/// (나) 단서의 재량(「인정되는」)이 사라짐  — 270번 ①. 사람이 먼저 본다
/// ```
///
/// ★ **(가)는 고치기 전 `ct_license` 를 못 잡는다** — 쉬운 말이 「단서도 붙어
/// 있어요」라고 말은 해 뒀기 때문이다. (나)가 잡는다.
class ProvisoFlags {
  const ProvisoFlags({required this.dropped, required this.promised});

  /// (가) 모드별.
  final Set<String> dropped;

  /// (나) 모드별.
  final Set<String> promised;
}

ProvisoFlags? provisoOf(CitationRow row) {
  final law = row.lawText;
  if (!_proviso.hasMatch(law)) return null;
  final m = RegExp('다만[,，]?').firstMatch(law);
  final part = m == null ? law : law.substring(m.start);
  final dropped = <String>{};
  final promised = <String>{};
  for (final mode in const ['보통', '쉬운 말']) {
    final ours = row.ours.where((l) => l.mode == mode).map((l) => l.text).join(' ');
    if (ours.isEmpty) continue;
    if (!_saysProviso.hasMatch(ours)) dropped.add(mode);
    if (_discretion.hasMatch(part) && !_saysDiscretion.hasMatch(ours)) {
      promised.add(mode);
    }
  }
  return ProvisoFlags(dropped: dropped, promised: promised);
}

/// 같은 조문을 **두 분야 이상**이 인용하는 자리 — 검사 (ak).
///
/// 두 분야가 같은 조문에 기대면 **두 벌**이 생긴다. 법이 바뀌면 한쪽만 고치는
/// 사고가 나고, 같은 것을 두 말로 부르게 된다. 공통 조각(`_shared_crisis`)은
/// 분야가 아니라서 뺀다.
class SharedCitation {
  const SharedCitation(this.cite, this.byDomain);

  /// 띄어쓰기를 고른 인용 이름. 항까지 살린다 — 항이 다르면 다른 글이다.
  final String cite;

  /// 분야 → 그 분야의 인용들.
  final Map<String, List<CitationRow>> byDomain;
}

String _citeKey(String cite) => cite.replaceAll(RegExp(r'\s+'), ' ').trim();

List<SharedCitation> sharedCitations(List<CitationRow> rows) {
  final by = <String, Map<String, List<CitationRow>>>{};
  for (final r in rows) {
    if (r.domain.startsWith('_')) continue;
    by
        .putIfAbsent(_citeKey(r.cite), () => {})
        .putIfAbsent(r.domain, () => [])
        .add(r);
  }
  return [
    for (final e in (by.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
      if (e.value.length >= 2) SharedCitation(e.key, e.value),
  ];
}

final RegExp _paragraphMark = RegExp(r'^[\s①-⑳]+');

String _normExcerpt(String t) =>
    t.replaceFirst(_paragraphMark, '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// ① **겹치는 부분의 글자가 다른** 원문 조각 쌍.
///
/// 처음에는 「원문 조각이 분야마다 같아야 한다」로 셌고 셋이 걸렸다. 그런데
/// 셋 다 사고가 날 수 없는 자리였다.
///
/// ```
/// 같다                    괜찮다
/// 한쪽이 다른 쪽의 앞부분   괜찮다 — 발췌 길이만 다르다 (가사소송수수료규칙 제3조 ①)
/// 안 겹친다               괜찮다 — 표의 다른 줄이다   (송달료 업무처리요령 [별표 1])
/// 겹치는데 글자가 다르다    빨간불 — 한쪽만 고친 흔적이다
/// ```
///
/// 「한쪽만 고치는 사고」는 **같은 글을 두 곳이 옮겨 적었을 때만** 난다.
/// 발췌가 짧다고 억지로 맞추면 카드에 필요 없는 조문이 붙고 밀도가 터진다.
/// 항 번호(①)가 앞에 붙고 안 붙고는 같은 글로 본다.
List<(String, String)> excerptConflicts(SharedCitation s) {
  final texts = {
    for (final rs in s.byDomain.values)
      for (final r in rs) r.lawText,
  }.toList();
  final out = <(String, String)>[];
  for (var i = 0; i < texts.length; i++) {
    for (var j = i + 1; j < texts.length; j++) {
      final a = _normExcerpt(texts[i]);
      final b = _normExcerpt(texts[j]);
      if (a == b || a.startsWith(b) || b.startsWith(a)) continue;
      if (a.isEmpty || b.isEmpty || a.codeUnitAt(0) != b.codeUnitAt(0)) continue;
      out.add((texts[i], texts[j]));
    }
  }
  return out;
}

/// ② 분야 사이에 **우리 문장이 하나도 안 겹치는가.**
///
/// 같은 조문에 기댄 우리 문장이 분야마다 다르면 이유가 있어야 한다. 이유가
/// 있는 경우가 흔하다 — 근로기준법 제23조 제2항은 해고 분야에서는 「4명 이하
/// 사업장에도 걸리는 조항」이고 산재에서는 「요양 중 해고 금지」다. 같은 항이
/// **다른 물음에 답한다.** 그래서 막지 않고 이유를 적게 한다(`plainLongOk` 꼴).
bool wordingDiverges(SharedCitation s) {
  String block(CitationRow r) =>
      r.ours.where((l) => l.mode == '보통').map((l) => l.text).join(' / ');
  final sets = [
    for (final rs in s.byDomain.values) {for (final r in rs) block(r)},
  ];
  var shared = sets.first;
  for (final x in sets.skip(1)) {
    shared = shared.intersection(x);
  }
  return shared.isEmpty;
}
