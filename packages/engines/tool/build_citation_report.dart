// 인용 점검표를 뽑는다 → docs/인용_점검.md
//
// **게이트와 같은 규칙으로 뽑는다.** 셈은 `citation_audit.dart` 한 곳에만
// 있고, 검사 (al)도 그것을 쓴다. 표와 게이트가 다른 숫자를 말하는 날이
// 오면 안 된다.
//
// 사람의 판단(손댄 자리 · 헛표시 판단)은 `packages/domain_data/review/
// citations.json` 에 있다. 표를 다시 뽑아도 판단은 안 사라진다.
//
//   dart run packages/engines/tool/build_citation_report.dart
//   dart run packages/engines/tool/build_citation_report.dart --counts
//
// `--counts` 는 분야별 표시 수를 JSON 으로 낸다 — 장부의 `flagged` 를 내려
// 박을 때 쓴다.
import 'dart:convert';
import 'dart:io';

import 'package:engines/engines.dart';

const _order = ['보통', '쉬운 말'];

void main(List<String> args) {
  final root = Directory.current;
  final domains = Directory('${root.path}/packages/domain_data/assets/domains');
  final reviewFile = File('${root.path}/packages/domain_data/review/citations.json');
  if (!domains.existsSync() || !reviewFile.existsSync()) {
    stderr.writeln('저장소 맨 위에서 돌려 주세요 — 분야 폴더나 장부를 못 찾았습니다');
    exit(2);
  }

  final files = domains
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final rows = <CitationRow>[];
  for (final f in files) {
    final id = f.uri.pathSegments.last.replaceAll('.json', '');
    rows.addAll(collectCitations(
      id,
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    ));
  }

  final review = jsonDecode(reviewFile.readAsStringSync()) as Map<String, dynamic>;
  final reviewed = Map<String, dynamic>.of(review['reviewed'] as Map<String, dynamic>)
    ..remove('_');
  String? whyOf(String key) => (reviewed[key] as Map?)?['why'] as String?;
  String? resultOf(String key) => (reviewed[key] as Map?)?['result'] as String?;
  List<MapEntry<String, dynamic>> withResult(String r) =>
      reviewed.entries.where((e) => (e.value as Map)['result'] == r).toList();

  final flags = {for (final r in rows) r: flagCitation(r)};
  final provisos = {for (final r in rows) r: provisoOf(r)};
  final marked = rows.where((r) => !flags[r]!.isEmpty).toList();
  final guided = flags.values.fold<int>(0, (a, f) => a + f.guided);

  // **안 본 자리의 인용**만 센다 — 톱니가 보는 숫자다(273번).
  final byDomain = <String, int>{
    for (final f in files) f.uri.pathSegments.last.replaceAll('.json', ''): 0,
  };
  for (final r in marked) {
    if (reviewed.containsKey(r.key)) continue;
    byDomain[r.domain] = byDomain[r.domain]! + 1;
  }
  final unreviewed = byDomain.values.fold<int>(0, (a, b) => a + b);
  final markedKeys = {for (final r in marked) r.key};
  // **자리로도 센다.** 사람은 자리 단위로 보므로 진도는 이쪽이 읽기 쉽다.
  final unreviewedKeys = markedKeys.where((k) => !reviewed.containsKey(k)).length;

  if (args.contains('--counts')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(byDomain));
    return;
  }

  List<CitationRow> mode(bool Function(Set<String>) test) =>
      marked.where((r) => test(flags[r]!.modes)).toList();
  final onlyPlain = mode((m) => m.length == 1 && m.contains('쉬운 말'));
  final both = mode((m) => m.length == 2);
  final onlyNormal = mode((m) => m.length == 1 && m.contains('보통'));

  final promised = <String>{};
  final dropped = <String>{};
  var withProviso = 0;
  for (final r in rows) {
    final p = provisos[r];
    if (p == null) continue;
    withProviso++;
    if (p.promised.isNotEmpty) promised.add(r.key);
    if (p.dropped.isNotEmpty) dropped.add(r.key);
  }

  final head = Process.runSync('git', ['rev-parse', '--short', 'HEAD'])
      .stdout
      .toString()
      .trim();

  final out = StringBuffer();
  void w([String line = '']) => out.writeln(line);

  w('# 인용 점검 — 우리 문장이 조문을 넘는가');
  w();
  w('뽑은 커밋 `$head` · 뽑는 명령 `dart run packages/engines/tool/build_citation_report.dart`');
  w();
  w('**데이터가 바뀌면 다시 뽑습니다.** 아래 세 숫자(인용 전체 · 표시된 것 · 안 본 자리)는');
  w('검사 (al)이 실제 셈과 맞대 봅니다 — 어긋나면 게이트가 빨개집니다.');
  w();
  w('> ★★ **이건 잡아내는 장치가 아니라 사람이 볼 순서를 정하는 장치입니다.**');
  w('> **표시가 없다고 맞는 게 아닙니다.** 「조문을 넘는가」는 기계가 못 봅니다 —');
  w('> 낱말이 조문에 있어도 우리 문장이 조문보다 넓게 말할 수 있고, 낱말이 없어도');
  w('> 조문을 정확히 풀어 쓴 것일 수 있습니다.');
  w('>');
  w('> ★★ **이 표가 영원히 못 보는 것 — 조문에 있는데 우리가 안 말한 것**(270번 ④).');
  w('> 없는 낱말은 셀 수가 없습니다. 그리고 넘는 것을 고칠 때 조문에 있는 것까지');
  w('> 같이 걷히기 쉽습니다. **「고쳤다」는 「맞다」가 아닙니다** — 그래서 손댄 자리를');
  w('> 맨 앞에 둡니다.');
  w();

  w('## 숫자');
  w();
  w('```');
  w('인용 전체   ${rows.length}');
  w('표시된 것   ${marked.length}   (자리 ${markedKeys.length}곳)');
  w('  쉬운 말에서만   ${onlyPlain.length}');
  w('  두 모드 다      ${both.length}');
  w('  보통에서만      ${onlyNormal.length}');
  w('표시 안 된 것 ${rows.length - marked.length}');
  w('');
  w('★ 사람이 본 자리   ${reviewed.length}곳   (누적 — 표시가 사라져도 안 지웁니다)');
  w('  고쳤다      ${withResult('고쳤다').length}');
  w('  헛표시다     ${withResult('헛표시다').length}');
  w('  두고 본다    ${withResult('두고 본다').length}');
  w('안 본 자리   $unreviewedKeys곳   (인용 $unreviewed개)   ← 앞으로 내려갈 숫자입니다');
  w('');
  w('단서가 있는 조문에 기댄 인용   $withProviso');
  w('  (나) 단서의 재량이 사라진 항목   ${promised.length}');
  w('  (가) 단서가 우리 문장에 없는 항목 ${dropped.length}');
  w('');
  w('길 안내라서 「할 수 있다」에서 뺀 문장   $guided');
  w('```');
  w();
  w('★★ **표시 수는 진도를 못 잽니다.** 낱말을 세는 숫자라 고치다 낱말이 늘면 같이 늡니다');
  w('(실제로 그랬습니다 — 273번). 진도를 재는 것은 **안 본 자리**이고, 그것이 한 방향으로만');
  w('갑니다 — 사람이 보면 내려가고, 새 문장이 표시를 만들면 올라갑니다.');
  w();
  w('분야별 **안 본 자리의 인용 수** — 장부의 `unreviewed` 가 이것과 같아야 합니다.');
  w('**이 숫자는 법률 수치가 아니라 우리가 남긴 빚입니다.**');
  w();
  w('```');
  for (final e in byDomain.entries) {
    w('${e.key.padRight(24)}${e.value}');
  }
  w('```');
  w();

  w('## 세는 법');
  w();
  w('```');
  w('인용 한 개   우리 문장 한 벌 × 그 문장이 기대는 조문 원문 한 조각');
  w('             (legalBasis 하나 · alsoBasis 하나하나가 각각 한 개)');
  w('우리 문장     그 항목의 사람에게 나가는 글. 쉬운 말 한 벌이 있으면 그것도 봅니다');
  w('             verification.note 같은 속 메모는 안 봅니다');
  w('표시        아래 낱말이 우리 문장에 있는데 **그 인용의 조문 원문**에 그 뜻의');
  w('             말이 없으면 표시합니다. 「…」 안은 조문을 옮긴 것이라 안 봅니다');
  w('```');
  w();
  w('```');
  for (final m in kCitationMarks) {
    w('${m.name.padRight(10)} 우리 문장: ${m.ours.join(' · ')}');
    w('${''.padRight(10)} 조문에 이 중 하나가 있으면 표시 안 함: ${m.law.join(' · ')}');
  }
  w('```');
  w();
  w('★ **처음 규칙은 이 표를 만든 까닭을 놓쳤습니다.** 처음에는 그 항목의 조문 전부와');
  w('대조했는데, `deposit_return.ct_before_moving` 의 옛 문장 「유지된다고 법에');
  w('있어요」가 표시되지 않았습니다 — 옆 조문 제3조의3 ⑤에 「그대로 유지되며」가 다른');
  w('뜻으로 들어 있어서입니다. 그래서 인용 하나를 자기 조문과만 대조합니다(269번).');
  w();
  w('★ 헌재 표시 검사 (ac)가 세는 「인용 조문 N개」는 **서로 다른 조문**의 수입니다.');
  w('여기서 세는 것은 **우리 문장과 조문의 짝**입니다 — 넘치는 것은 조문이 아니라 우리');
  w('문장이라서입니다.');
  w();

  void row(CitationRow r, {bool repeatOurs = true}) {
    final f = flags[r]!;
    final tag = f.isEmpty
        ? ''
        : ' ⚑ ${kCitationMarks.where((m) => f.marks.containsKey(m.name)).map((m) => '${m.name}(${_order.where(f.marks[m.name]!.contains).join('·')})').join(' · ')}';
    w('#### `${r.domain}` · `${r.where}`$tag');
    w();
    if (repeatOurs) {
      w('**우리 문장**');
      w();
      if (r.ours.isEmpty) w('- (사람에게 나가는 우리 문장이 이 항목에 없습니다)');
      for (final l in r.ours) {
        w('- `${l.field}` (${l.mode}) ${l.text.replaceAll('\n', ' ')}');
      }
    } else {
      w('**우리 문장** — 위와 같음');
    }
    w();
    w('**조문 원문** — ${r.cite} (${r.kind})');
    w();
    for (final line in r.lawText.split('\n')) {
      w(line.trim().isEmpty ? '>' : '> $line');
    }
    w();
    final note = whyOf(r.key);
    if (note != null) {
      w('**사람이 본 결론** — [${resultOf(r.key)}] $note');
      w();
    }
  }

  void block(List<CitationRow> items) {
    String? last;
    for (final r in items) {
      row(r, repeatOurs: r.key != last);
      last = r.key;
    }
  }

  w('## 사람이 볼 순서');
  w();
  w('```');
  w('0  안 본 자리                        톱니가 보는 것. 여기부터 비운다');
  w('1  고친 자리                        「고쳤다」는 「맞다」가 아니다 (270 ④)');
  w('2  단서의 재량이 사라진 자리 (나)     안심시키는 잘못이 더 위험하다 (270 ①)');
  w('3  쉬운 말에서만 표시');
  w('4  두 모드 다 표시');
  w('5  보통에서만 표시');
  w('6  단서가 우리 문장에 없는 자리 (가)   사람이 볼 것. 고칠 것이 아니다');
  w('```');
  w();

  w('### 0. 안 본 자리 — $unreviewedKeys곳 (인용 $unreviewed개)');
  w();
  w('표시가 붙었는데 장부에 결론이 없는 자리입니다. **여기가 0이 되면 한 바퀴 돈 것입니다.**');
  w();
  final restKeys = (markedKeys.where((k) => !reviewed.containsKey(k)).toList()..sort());
  for (final k in restKeys) {
    w('- `$k`');
  }
  if (restKeys.isEmpty) w('- (없습니다)');
  w();

  w('### 1. 고친 자리 — ${withResult('고쳤다').length}곳');
  w();
  w('**「고쳤다」는 「맞다」가 아닙니다**(270 ④) — 넘는 것을 걷어낼 때 조문에 있는 것까지 같이');
  w('걷히기 쉽습니다. 다음 점검에서 여기부터 봅니다.');
  w();
  for (final e in withResult('고쳤다')) {
    final t = e.value as Map<String, dynamic>;
    final here = rows.where((r) => r.key == e.key).toList();
    final still = here.where((r) => !flags[r]!.isEmpty).length;
    w('- `${e.key}` — ${t['at']} · `${t['commit']}` · DECISIONS ${t['decision']}');
    w('  ${t['why']}');
    w('  지금 이 자리 인용 ${here.length}개 중 표시 $still개.');
  }
  w();
  for (final r in const ['두고 본다', '헛표시다']) {
    w('#### 곁들여 — 「$r」 ${withResult(r).length}곳');
    w();
    for (final e in withResult(r)) {
      w('- `${e.key}` — ${(e.value as Map)['at']}');
      w('  ${(e.value as Map)['why']}');
    }
    w();
  }

  w('### 2. 단서의 재량이 사라진 자리 (나) — ${promised.length}곳');
  w();
  w('조문의 단서에 「인정되는 경우」가 있는데 우리 문장에 「인정」이 없는 자리입니다.');
  w('★ `ct_license` 를 잡은 것이 이 규칙입니다 — (가)는 못 잡았습니다.');
  w();
  for (final k in promised.toList()..sort()) {
    final n = whyOf(k);
    w('- `$k`${n == null ? ' — (아직 사람이 안 봄)' : ' — [${resultOf(k)}] $n'}');
  }
  w();

  w('### 3. 쉬운 말에서만 표시 — ${onlyPlain.length}개');
  w();
  w('보통은 조문에서 한 번 옮긴 것이고 쉬운 말은 그 위에서 한 번 더 옮긴 것입니다.');
  w('**두 번 옮기면 두 배로 샙니다.** 쉬운 말 검사는 어미 강도만 봐서 주어와 동사가');
  w('바뀐 것을 못 봅니다(270번).');
  w();
  w('★★ **2026-09-16 에 열여섯 자리를 다 봤습니다. 진짜는 하나였습니다** — 나머지는 문장을');
  w('쪼개다 「해야 한다」가 새로 걸린 여덟과, 풀이·길 안내에서 「수 있」이 걸린 일곱입니다.');
  w('**쉬운 말이 두 배로 샐 거라고 걱정했는데 안 샜습니다**(273번).');
  w();
  block(onlyPlain);

  w('### 4. 두 모드 다 표시 — ${both.length}개');
  w();
  block(both);

  w('### 5. 보통에서만 표시 — ${onlyNormal.length}개');
  w();
  block(onlyNormal);

  w('### 6. 단서가 우리 문장에 없는 자리 (가) — ${dropped.length}곳');
  w();
  w('**사람이 볼 것 ${dropped.length}개입니다. 고칠 것 ${dropped.length}개가 아닙니다.** 우리가');
  w('말하는 것과 무관한 단서도 있습니다 — 그 구별은 사람이 합니다.');
  w();
  for (final k in dropped.toList()..sort()) {
    w('- `$k`');
  }
  w();

  final rest = rows.where((r) => flags[r]!.isEmpty).toList();
  w('## 표시 안 된 것 — ${rest.length}개');
  w();
  w('**표시가 없다고 맞는 게 아닙니다.** 순서가 뒤일 뿐입니다.');
  w();
  block(rest);

  File('${root.path}/docs/인용_점검.md').writeAsStringSync(out.toString());
  stdout.writeln('docs/인용_점검.md — 인용 ${rows.length} · 표시 ${marked.length} '
      '· 본 자리 ${reviewed.length} (고쳤다 ${withResult('고쳤다').length} · '
      '헛표시다 ${withResult('헛표시다').length} · 두고 본다 ${withResult('두고 본다').length}) '
      '· 안 본 자리 $unreviewed · (나) ${promised.length} · (가) ${dropped.length}');
}
