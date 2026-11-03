import 'dart:convert';
import 'dart:io';

import 'package:domain_data/domain_data.dart' show articleRefsIn;

import 'law_file_name.dart';

/// 법령 매니페스트를 만든다.
///
/// **우리가 인용한 조문이 어느 법령 몇 호 몇 시행일자 판본에서 나온 것인지**를
/// 기계가 알게 하는 파일이다. 매주 개정 확인을 사람 기억이 아니라 이 파일로 한다.
///
/// ```
/// dart run tool/build_law_manifest.dart          만들어서 씀
/// dart run tool/build_law_manifest.dart --check  달라진 게 있으면 실패 (CI)
/// ```
///
/// ## 손으로 쓰지 않는 것
///
/// `articles[].usedBy` 는 **도메인 JSON 의 `legalBasis` 에서 역으로 뽑는다.**
/// 사람이 적으면 반드시 어긋난다.
///
/// ## 손으로 쓰는 것
///
/// `assets/laws/overrides.json` — 파일명이 PDF 내용과 다를 때, 그리고 데이터가
/// 약칭으로 인용할 때. 파일명만 믿으면 안 되는 경우가 실제로 있다
/// (소액사건심판법이 그렇다).
///
/// ## law/ 가 없으면 아무것도 쓰지 않는다
///
/// PDF 는 `.gitignore` 대상이라 CI 에는 없다. 없는 채로 돌리면 매니페스트가
/// 통째로 비워질 텐데, 그건 "법령이 하나도 없다" 는 거짓이 커밋되는 일이다.
Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final root = _repoRoot();

  final lawDir = Directory('${root.path}/law');
  if (!lawDir.existsSync()) {
    stderr.writeln('law/ 가 없습니다. PDF 원본이 있는 곳에서 돌리세요.');
    exit(2);
  }

  final pdfs = lawDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.pdf'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (pdfs.isEmpty) {
    stderr.writeln('law/ 에 PDF 가 없습니다. 빈 매니페스트를 쓰지 않습니다.');
    exit(2);
  }

  final overrides = _readOverrides(root, 'laws');
  // 파일명이 애초에 규칙을 안 따르는 것들. 예규·고시가 그렇다.
  final byFileName = _readOverrides(root, 'files');
  final laws = <_Law>[];
  final skipped = <String>[];

  // **이름 규칙에 맞는 것만 읽지 않는다.** 그러면 다음 파일에서 또 뚫린다.
  // 다 읽고, 못 넣은 것을 **이유와 함께** 센다(DECISIONS 118번).
  final notLaw = _readOverrides(root, 'notLaw').keys.toSet();
  final annexFiles = <String, String>{};   // 별표 이름표 → 파일명
  final notLawFiles = <String>[];

  final parsedFiles = <LawFileName>[];
  for (final pdf in pdfs) {
    final name = pdf.uri.pathSegments.last;

    // (1) 법령이 아니라고 사람이 적어 둔 것.
    if (notLaw.contains(name)) {
      notLawFiles.add(name);
      continue;
    }

    // (2) 별표는 법령이 아니라 별표다. `tables` 로 간다.
    final annex = parseAnnexFileName(name);
    if (annex != null) {
      annexFiles[annex] = name;
      continue;
    }

    // (3) 법령. 파일명이 규칙을 안 따르면 `files` 가 덮는다.
    final parsed = parseLawFileName(name) ?? _fromFileOverride(name, byFileName);
    if (parsed == null) {
      skipped.add(name);
      continue;
    }
    parsedFiles.add(parsed);
  }

  // 같은 법령명이 둘이면 여기서 멈춘다. overrides 는 이름으로 찾고 인용은
  // 먼저 온 파일에 붙으므로, 그대로 두면 **정렬 순서가 판본을 정한다.**
  final duplicates = duplicateLawNames(parsedFiles);
  if (duplicates.isNotEmpty) {
    stderr.writeln('같은 법령명의 PDF 가 둘 이상입니다. 판본이 섞입니다:');
    for (final entry in duplicates.entries) {
      stderr.writeln('  ${entry.key} — ${entry.value.join(' / ')}');
    }
    stderr.writeln('낡은 판본을 law/ 에서 치우고 다시 돌리세요.');
    exit(2);
  }

  for (final parsed in parsedFiles) {
    laws.add(
      _Law.from(parsed)
          .withOverride(overrides[parsed.name])
          .withOverride(byFileName[parsed.sourceFile]),
    );
  }

  // **파일 이름은 사람이 붙인 것이라 규칙이 없다.** 같은 자리에서 세 번
  // 걸렸다 — 고시 번호의 붙임표, 용어집이 인용한 조문, 별표 표시가 맨 뒤
  // 괄호에 붙은 것. 그래서 판본만은 **원문 머리글에서 다시 읽어 대조한다**
  // (DECISIONS 165번).
  //
  // 한글은 안 읽힌다 — 국가법령정보센터 PDF 가 ToUnicode 없는 글꼴을 써서
  // 숫자와 괄호만 남는다. 그래서 **이름은 여전히 파일에서** 오고, 번호와
  // 시행일만 원문으로 검산한다. 그 둘이 `overrides.json` 이 손으로 덮어
  // 쓰던 값이고, 틀리면 조용히 낡은 판본을 인용하게 되는 자리다.
  final headers = <String, String>{};
  var headerRead = 0;
  final headerless = <String>[];
  for (final law in laws) {
    final text = _firstPageText('${lawDir.path}/${law.sourceFile}');
    if (text == null) {
      headers.clear();
      break;
    }
    headers[law.sourceFile] = text;
  }
  if (headers.isEmpty && laws.isNotEmpty) {
    stdout.writeln('원문 머리글을 못 읽었습니다 — pdftotext(poppler)가 없습니다. '
        '판본 대조를 건너뜁니다.');
  }
  final headerMismatch = <String>[];
  for (final law in laws) {
    final text = headers[law.sourceFile];
    if (text == null) continue;
    final head = _lawHeader.firstMatch(text);
    if (head == null) {
      headerless.add(law.sourceFile);
      continue;
    }
    headerRead++;
    final effective = '${head.group(1)}-${head.group(2)!.padLeft(2, '0')}'
        '-${head.group(3)!.padLeft(2, '0')}';
    final number = head.group(4)!;
    // 파일 이름은 `제03066호`, 원문 머리글은 `제3066호`. 앞자리 0 은 사람이
    // 자릿수를 맞춘 것이라 판본 차이가 아니다.
    final want = law.number.replaceAll('제', '').replaceAll('호', '');
    if (_bareNumber(number) != _bareNumber(want) ||
        effective != law.effective) {
      headerMismatch.add('${law.sourceFile} — '
          '원문 머리글 제$number호 시행 $effective / '
          '우리 기록 ${law.number} 시행 ${law.effective}');
    }
  }
  if (headerMismatch.isNotEmpty) {
    stderr.writeln('원문 머리글과 판본이 어긋납니다:');
    for (final line in headerMismatch) {
      stderr.writeln('  ✘ $line');
    }
    stderr.writeln('파일을 새로 받거나 overrides.json 의 number·effective 를 고치세요.');
    exit(1);
  }

  // 도메인이 실제로 인용한 조문을 모은다.
  final citations = _collectCitations(root);
  final aliasOf = <String, String>{
    for (final law in laws)
      for (final alias in law.aliases) alias: law.name,
  };

  final unsourced = <String, Set<String>>{};
  for (final citation in citations) {
    final lawName = aliasOf[citation.law] ?? citation.law;
    final law = laws.where((l) => l.name == lawName).firstOrNull;
    if (law == null) {
      (unsourced[citation.law] ??= <String>{}).addAll(citation.articles);
      continue;
    }
    for (final article in citation.articles) {
      (law.articles[article] ??= <String>{}).add(citation.usedBy);
    }
  }

  // **인용한 조문마다 원문에 헌재 결정 표시가 붙어 있는지 본다.**
  //
  // 조문 본문에는 표시가 없다. 「10년을 경과하면 소멸된다」로 그대로 서 있고
  // 위헌 사실은 조문 아래 대괄호에만 있다. 그래서 **인용만 하면 정확히 반대로
  // 읽힌다.** 검사기는 `law/` 가 없어 이걸 못 보니 여기서 적어 둔다.
  var markScanned = 0;
  for (final law in laws) {
    if (law.articles.isEmpty) continue;
    final text = _fullText('${lawDir.path}/${law.sourceFile}');
    if (text == null) continue;
    final bodies = _articleBodies(text);
    for (final ref in law.articles.keys) {
      final body = bodies[ref];
      if (body == null) continue;
      markScanned++;
      final kind = _courtMarkKind.firstMatch(body)?.group(1);
      if (kind != null) law.courtMarks[ref] = kind;
    }
  }
  final markFound =
      laws.fold<int>(0, (sum, l) => sum + l.courtMarks.length);
  stdout.writeln('헌재 결정 표시 — 조문 $markScanned개를 원문과 대조 · '
      '표시가 붙은 것 $markFound개');

  final today = _today();
  final manifest = <String, Object?>{
    '_': [
      '생성물이다. 손으로 고치지 않는다.',
      'dart run packages/domain_data/tool/build_law_manifest.dart',
      '',
      'PDF 원본은 law/ 에 있고 저장소에 올라가지 않는다.',
      '금요일 개정 확인 대상은 아래 laws[] 전체다. 기준은 number + effective.',
    ],
    'generatedAt': today,
    'laws': [
      for (final law in laws) law.toJson(today),
    ],
    'unsourced': [
      for (final entry in (unsourced.keys.toList()..sort()))
        {
          'law': entry,
          'articles': unsourced[entry]!.toList()..sort(),
          'note': '인용하고 있으나 원본 PDF 를 아직 안 받았다',
        },
    ],
    if (skipped.isNotEmpty) 'unparsedFiles': skipped,
  };

  // **별표는 별표 단위로 판본을 단다.** 법령 단위로 묶으면 낡은 별표를 못 본다.
  final tables = _readOverrides(root, 'tables');
  for (final entry in tables.entries) {
    final file = annexFiles.remove(entry.key);
    if (file != null) entry.value['sourceFile'] = file;
  }
  manifest['tables'] = tables;

  // 못 넣은 것을 갈래별로 남긴다. **조용히 사라지지 않게.**
  final unregistered = annexFiles.keys.toList()..sort();
  manifest['unfiled'] = {
    '_': '법령으로도 별표로도 못 넣은 PDF. 셋째(unreadableName)가 0이어야 한다.',
    // **분모를 여기 적는다.** 검사기는 `law/` 를 못 본다 — PDF 는
    // 저장소에 없고 CI 에는 아예 디렉터리가 없다. 검사기가 직접 세면
    // CI 에서 0이 나오고, 그건 「못 넣은 것이 없다」와 구별이 안
    // 된다. 그래서 **세는 쪽이 적어 준다.** 지금까지 이 수는 생성기
    // stdout 에만 있었다.
    'scanned': pdfs.length,
    'notLaw': notLawFiles,
    'annexNotRegistered': unregistered,
    'unreadableName': skipped,
  };

  // ── 세지 않은 파일 ────────────────────────────────────────────────
  //
  // **지금까지 세 번 다 「조용히 빠졌다」가 문제였다.** 고시 번호의 붙임표,
  // 용어집이 인용한 조문, 별표 표시가 맨 뒤 괄호에 붙은 것 — 셋 다 등록
  // 수가 줄었는데 아무도 몰랐다.
  //
  // 그래서 **등록된 것이 아니라 세지 않은 것을 센다.** law/ 안의 PDF 하나
  // 하나가 어느 칸엔가 들어가야 하고, 어디에도 안 들어간 것이 하나라도
  // 있으면 이름을 찍고 실패한다(DECISIONS 166번).
  //
  // 안 쓰는 참고 자료는 `overrides.json` 의 `ignore` 에 **이름을 하나씩**
  // 적어서 뺀다. 와일드카드로 빼면 그 순간 다시 침묵이 된다.
  final ignore = _readOverrides(root, 'ignore');
  final registeredTables = tables.values
      .where((t) => t['sourceFile'] != null)
      .length;
  final ignored = <String>[];
  final leftover = <String>[];
  for (final key in unregistered) {
    (ignore.containsKey(key) ? ignored : leftover).add(key);
  }
  // `notLaw` 는 이미 이름으로 적어 둔 목록이라 그 자체가 ignore 다.
  final counted =
      laws.length + registeredTables + notLawFiles.length + ignored.length;
  if (leftover.isNotEmpty || skipped.isNotEmpty || counted != pdfs.length) {
    stderr.writeln('세지 않은 파일이 있습니다 — '
        'PDF ${pdfs.length}개 중 ${pdfs.length - counted}개.');
    for (final name in [...leftover, ...skipped]) {
      stderr.writeln('  ✘ $name');
    }
    stderr.writeln('tables 에 등록하거나 overrides.json 의 ignore 에 '
        '이름을 적으세요. 와일드카드로 빼지 마세요.');
    exit(1);
  }

  final encoded = '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';

  final target = File('${root.path}/packages/domain_data/assets/laws/manifest.json');

  if (check) {
    final current = target.existsSync() ? target.readAsStringSync() : '';
    // 생성일만 다른 것은 차이가 아니다.
    if (_withoutTimestamp(current) == _withoutTimestamp(encoded)) {
      stdout.writeln('매니페스트가 최신입니다.');
      return;
    }
    stderr.writeln('매니페스트가 낡았습니다. 다시 만들어 커밋하세요.');
    exit(1);
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(encoded);

  final articleCount =
      laws.fold<int>(0, (sum, law) => sum + law.articles.length);
  final unused = laws.where((l) => l.articles.isEmpty).length;
  stdout
    ..writeln('법령 ${laws.length}개 · 별표 ${tables.length}개 · '
        '인용된 조문 $articleCount개')
    ..writeln('PDF ${pdfs.length}개 중 못 넣은 것 — '
        '법령이 아님 ${notLawFiles.length} · '
        '등록 안 된 별표 ${annexFiles.length} · '
        '이름을 못 읽음 ${skipped.length}')
    ..writeln('원문 머리글로 판본을 대조한 것 $headerRead개 · '
        '머리글 꼴이 달라 못 읽은 것 ${headerless.length}개')
    ..writeln('아직 아무도 안 쓰는 법령 $unused개')
    ..writeln('원본을 못 받은 인용 ${unsourced.length}건')
    ..writeln('→ ${target.path}');
  if (headerless.isNotEmpty) {
    // **못 읽은 것도 이름을 찍는다.** 예규·개정문·별표는 머리글 꼴이 달라
    // 아직 못 읽는다. 세어 두지 않으면 대조가 다 도는 줄 알게 된다.
    stdout.writeln('머리글을 못 읽은 파일 ${headerless.length}개: '
        '${headerless.join(' / ')}');
  }
}

/// 법령 PDF 첫 장의 머리글.
///
/// ```
/// [시행 2026. 3. 17.] [법률 제21454호, 2026. 3. 17., 일부개정]
///   → 한글이 빠져 나오면  [ 2026. 3. 17.] [ 21454, 2026. 3. 17., ]
/// ```
final RegExp _lawHeader = RegExp(
  r'\[\s*(\d{4})\.\s*(\d{1,2})\.\s*(\d{1,2})\.?\s*\]\s*'
  r'\[\s*(\d[\d\-]*)\s*,',
);

/// PDF 첫 장의 글자. poppler 가 없으면 null.
///
/// **한글은 안 나온다.** 국가법령정보센터 PDF 가 ToUnicode 없는 글꼴을 써서
/// 숫자·괄호·마침표만 남는다. 우리가 필요한 것(번호·시행일)은 전부 숫자다.
String? _firstPageText(String path) {
  ProcessResult result;
  try {
    result = Process.runSync(
      'pdftotext',
      ['-f', '1', '-l', '1', '-layout', path, '-'],
      stdoutEncoding: latin1,
      stderrEncoding: latin1,
    );
  } on ProcessException {
    return null;
  }
  if (result.exitCode != 0) return null;
  return result.stdout as String;
}

/// 조문 원문에 붙은 헌법재판소 결정 표시.
///
/// **조문 본문에는 아무 표시가 없다.** 위헌으로 본 부분이 있어도 본문은 그대로
/// 서 있고, 사실은 조문 아래 대괄호에만 적힌다. 그래서 조문만 인용하면 정확히
/// 반대로 읽힌다 — 제999조 제2항이 그 자리다.
final RegExp _courtMarkKind =
    RegExp(r'\[(단순위헌|헌법불합치|한정위헌|한정합헌|위헌)[,\s]');

/// 조문 머리. 쪽 맨 왼쪽에서만 시작한다 — 들여쓴 항·호는 조문이 아니다.
final RegExp _articleHead = RegExp(r'^제(\d+)조(의\d+)?\(', multiLine: false);

/// PDF 전문. poppler 가 없으면 null.
///
/// 머리글만 읽는 [_firstPageText] 와 달리 **한글까지 읽는다.** `-enc UTF-8` 을
/// 주면 국가법령정보센터 PDF 의 본문이 그대로 나온다.
String? _fullText(String path) {
  ProcessResult result;
  try {
    result = Process.runSync(
      'pdftotext',
      ['-enc', 'UTF-8', '-layout', path, '-'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException {
    return null;
  }
  if (result.exitCode != 0) return null;
  return result.stdout as String;
}

/// 조문 머리로 잘라 `제N조` → 그 조문의 글자.
///
/// 같은 머리가 두 번 나오면(목차와 본문) **긴 쪽을 남긴다.**
Map<String, String> _articleBodies(String text) {
  final lines = text.split('\n');
  final starts = <(int, String)>[];
  for (var i = 0; i < lines.length; i++) {
    final m = _articleHead.firstMatch(lines[i]);
    if (m != null) starts.add((i, '제${m.group(1)}조${m.group(2) ?? ''}'));
  }
  final out = <String, String>{};
  for (var n = 0; n < starts.length; n++) {
    final end = n + 1 < starts.length ? starts[n + 1].$1 : lines.length;
    final body = lines.sublist(starts[n].$1, end).join('\n');
    final ref = starts[n].$2;
    if ((out[ref] ?? '').length < body.length) out[ref] = body;
  }
  return out;
}

/// 앞자리 0 을 뗀 법령 번호. `제03066호` 와 `제3066호` 는 같은 판본이다.
String _bareNumber(String raw) =>
    raw.split('-').map((p) => p.replaceFirst(RegExp(r'^0+'), '')).join('-');

class _Law {
  _Law({
    required this.name,
    required this.kind,
    required this.number,
    required this.effective,
    required this.sourceFile,
  });

  /// 파일명에서 읽은 판본을 그대로 옮긴다. 규칙은 `law_file_name.dart` 에 있다.
  factory _Law.from(LawFileName parsed) => _Law(
        name: parsed.name,
        kind: parsed.kind,
        number: parsed.number,
        effective: parsed.effective,
        sourceFile: parsed.sourceFile,
      );

  final String name;
  final String kind;
  String number;
  String effective;
  final String sourceFile;
  /// overrides.json 이 채운다. 생성자에서 받지 않는다.
  List<String> aliases = const [];
  String? note;

  /// 조문 → 그 조문을 쓰는 곳들.
  final Map<String, Set<String>> articles = {};

  /// 조문 → 원문에 붙은 헌재 결정 표시(`단순위헌` · `헌법불합치` …).
  ///
  /// **검사기는 이걸 스스로 못 본다.** `law/` 가 CI 에 없어서다. 그래서
  /// 원문을 가진 쪽이 적어 두고 검사 (ac)가 읽는다 — `unfiled.scanned` 와
  /// 같은 꼴이다.
  final Map<String, String> courtMarks = {};

  _Law withOverride(Map<String, dynamic>? override) {
    if (override == null) return this;
    number = override['number'] as String? ?? number;
    effective = override['effective'] as String? ?? effective;
    note = override['note'] as String?;
    aliases = (override['aliases'] as List<dynamic>? ?? const [])
        .cast<String>();
    return this;
  }

  Map<String, Object?> toJson(String today) => {
        'name': name,
        'kind': kind,
        'number': number,
        'effective': effective,
        // 오늘 시행 중인가. `effective` 가 오늘보다 뒤면 아직 아니다.
        'inForceAsOf': effective.compareTo(today) <= 0,
        'sourceFile': sourceFile,
        if (aliases.isNotEmpty) 'aliases': aliases,
        if (note != null) 'note': note,
        'articles': [
          for (final ref in articles.keys.toList()..sort(_byArticleNumber))
            {
              'ref': ref,
              'usedBy': articles[ref]!.toList()..sort(),
              if (courtMarks[ref] != null) 'courtMark': courtMarks[ref],
            },
        ],
      };
}

/// `제157조` 보다 `제160조` 가 뒤에 오도록. 문자열 정렬이면 제10조가 제9조 앞이다.
int _byArticleNumber(String a, String b) {
  int number(String ref) {
    // 「부칙(제36056호)제2조」에서 세어야 하는 것은 2다. 앞의 36056 을 집으면
    // 부칙이 목록 맨 뒤로 밀려 본문과 나란히 안 보인다.
    final article = RegExp(r'제(\d+)조').allMatches(ref).lastOrNull;
    return int.tryParse(article?.group(1) ?? '') ?? 0;
  }
  final byNumber = number(a).compareTo(number(b));
  return byNumber != 0 ? byNumber : a.compareTo(b);
}

class _Citation {
  const _Citation({
    required this.law,
    required this.articles,
    required this.usedBy,
  });

  final String law;
  final Set<String> articles;
  final String usedBy;
}

/// 도메인 JSON 을 훑어 `legalBasis` 를 모은다.
///
/// **사람이 적지 않는다.** 인용을 고치면 매니페스트도 따라 바뀌어야 하고,
/// 그걸 사람 기억에 맡기면 반드시 어긋난다.
List<_Citation> _collectCitations(Directory root) {
  final dir = Directory('${root.path}/packages/domain_data/assets/domains');
  final citations = <_Citation>[];

  // 용어집도 조문을 인용한다. 여기서 빠뜨리면 시트에 실린 원문이
  // **어느 판본에서 나온 것인지 아무도 모르는 채로** 화면에 나간다.
  final glossary = File(
    '${root.path}/packages/domain_data/assets/glossary/terms.json',
  );

  for (final file in [
    ...dir.listSync().whereType<File>(),
    if (glossary.existsSync()) glossary,
  ]) {
    if (!file.path.endsWith('.json')) continue;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final domainId = json['id'] as String? ?? file.uri.pathSegments.last;

    void walk(Object? node, String path) {
      if (node is Map<String, dynamic>) {
        final law = node['law'];
        final article = node['article'];
        if (law is String && article is String) {
          final refs = _articleRefs(article);
          if (refs.isNotEmpty) {
            citations.add(
              _Citation(law: law, articles: refs, usedBy: path),
            );
          }
        }
        for (final entry in node.entries) {
          if (entry.key == 'law' || entry.key == 'article') continue;
          final id = node['id'];
          // 루트의 id 는 이미 경로 첫머리에 있다. 두 번 붙이지 않는다.
          final next =
              id is String && !path.endsWith(id) ? '$path.$id' : path;
          walk(entry.value, entry.key == 'legalBasis' ? next : '$next.${entry.key}');
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item, path);
        }
      }
    }

    walk(json, domainId);
  }

  // **화면에 안 나가지만 화면 문구를 짓게 만든 조문.**
  //
  // 변호사법 제112조 제3호가 그랬다 — 방어선 문장이 그 조문 때문에 서 있는데
  // 조문 자체는 화면에 안 나가니 인용이 없었고, 그래서 원문 없이도 통과했다.
  // **근거가 화면에 안 보인다고 근거가 아닌 것은 아니다.**
  final groundwork = _readOverrides(root, 'groundwork');
  for (final entry in groundwork.entries) {
    final articles = (entry.value['articles'] as List<dynamic>? ?? const [])
        .cast<String>();
    for (final article in articles) {
      final refs = _articleRefs(article);
      if (refs.isEmpty) continue;
      citations.add(
        _Citation(law: entry.key, articles: refs, usedBy: '(화면 문구의 근거)'),
      );
    }
  }

  return citations;
}

/// `제2조 제10호 · 제11호 · 제4조 제1항` → `{제2조, 제4조}`
///
/// **조 단위로 모은다.** 개정은 조 단위로 일어나므로 항·호까지 나눠 봐야
/// 확인할 대상이 늘기만 한다.
/// 조문 참조는 `article_ref.dart` 가 정한다. **두 도구가 같은 규칙을 쓴다** —
/// 따로 두면 한쪽만 고쳐져 조용히 어긋난다(DECISIONS 126번).
Set<String> _articleRefs(String article) => articleRefsIn(article);

Map<String, Map<String, dynamic>> _readOverrides(Directory root, String key) {
  final file =
      File('${root.path}/packages/domain_data/assets/laws/overrides.json');
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final section = json[key] as Map<String, dynamic>? ?? {};
  return section
      .map((key, value) => MapEntry(key, value as Map<String, dynamic>));
}

/// 파일명 규칙을 안 따르는 PDF. `overrides.json` 의 `files` 가 판본을 적어 준다.
///
/// **넘겨 버리면 인용해도 매니페스트에 안 잡힌다.** 예규를 근거로 쓰는 순간
/// 「매니페스트에 없습니다」로 빌드가 깨지거나, 더 나쁘게는 아무 말 없이 빠진다.
LawFileName? _fromFileOverride(
  String fileName,
  Map<String, Map<String, dynamic>> byFileName,
) {
  final override = byFileName[fileName];
  if (override == null) return null;
  final name = override['name'] as String?;
  final number = override['number'] as String?;
  final effective = override['effective'] as String?;
  if (name == null || number == null || effective == null) {
    stderr.writeln('overrides.json files."$fileName" 에 name·number·effective 가 '
        '모두 있어야 합니다.');
    exit(2);
  }
  return LawFileName(
    name: name,
    kind: override['kind'] as String? ?? '예규',
    number: number,
    effective: effective,
    sourceFile: fileName,
  );
}

String _today() {
  // 생성 시각은 사람이 읽는 값이다. 계산에 쓰지 않는다.
  // ignore: avoid_dynamic_calls
  final now = DateTime.now();
  return '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
}

String _pad(int value) => value.toString().padLeft(2, '0');

String _withoutTimestamp(String json) =>
    json.replaceAll(RegExp(r'"generatedAt": "[^"]*"'), '');

Directory _repoRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    if (Directory('${dir.path}/packages/domain_data').existsSync() &&
        File('${dir.path}/melos.yaml').existsSync()) {
      return dir;
    }
    if (Directory('${dir.path}/packages/domain_data/assets/domains')
        .existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('리포 루트를 찾지 못했습니다 (from ${Directory.current.path})');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
