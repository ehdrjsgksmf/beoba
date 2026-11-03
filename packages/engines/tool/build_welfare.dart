import 'dart:convert';
import 'dart:io';

import 'package:engines/engines.dart' show SafetyFilter, scopeFor;

import 'mini_xml.dart';
import 'welfare_priority.dart';

/// 복지 자료 CSV 를 앱이 읽을 JSON 으로 굽는다.
///
/// ```
/// dart run packages/engines/tool/build_welfare.dart          만들어서 씀
/// dart run packages/engines/tool/build_welfare.dart --check  달라진 게 있으면 실패 (CI)
/// ```
///
/// ## 왜 앱이 API 를 직접 안 부르는가
///
/// 공공데이터 API 는 키를 붙여야 한다. 앱에서 부르면 그 키가 브라우저 번들에
/// 그대로 들어가고, 웹에서는 CORS 로 막혀 아예 못 부른다. 그리고 네트워크가
/// 끊긴 사람에게 복지 목록이 안 나오면 안 된다 — 법령·공휴일과 같은 규칙이다.
/// **커밋된 JSON 이 진짜 데이터다.**
///
/// 나중에 API 로 갈아탈 때 바뀌는 것은 [_readRows] 하나다.
///
/// ## welfare/ 가 없으면 아무것도 쓰지 않는다
///
/// CSV 는 `.gitignore` 대상이라 CI 에는 없다. 없는 채로 돌리면 목록이 통째로
/// 비워질 텐데, 그건 "복지제도가 하나도 없다" 는 거짓이 커밋되는 일이다.
///
/// ## 문장을 고쳐 쓰지 않는다
///
/// 청소는 [_clean] 이 하는 셋까지다 — 앞뒤 공백, 연속 공백, 하이픈 목록.
/// 법령 원문과 같은 규칙이다. 어절 하나도 바꾸지 않는다.
Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final root = _repoRoot();

  final dir = Directory('${root.path}/welfare');
  if (!dir.existsSync()) {
    stderr.writeln('welfare/ 가 없습니다. CSV 원본이 있는 곳에서 돌리세요.');
    exit(2);
  }

  // **물러난 자료도 읽는다. 지우지 않기 때문이다.**
  //
  // 중앙부처 CSV 는 API 목록에 밀렸다 — 겹치는 362건은 API 가 상세를 갖고
  // 있으니 API 가 이긴다. 그런데 **CSV 에만 있는 5건은 지울 수 없다.**
  // 없어진 제도인지 API 목록이 빠뜨린 것인지 우리가 확인할 방법이 없고,
  // 지우면 후자일 때 영영 잃는다(DECISIONS 235번).
  //
  // 그래서 파일을 `welfare/legacy/` 로 옮기고 **여기서도 읽는다.** 폴더
  // 이름이 곧 「이건 물러난 자료다」라는 표시이고, 구운 JSON 에도 그 표시가
  // 따라간다. 안 읽게 만들면 다음 사람이 파일이 왜 거기 있는지 모른다.
  final legacyDir = Directory('${dir.path}/legacy');
  List<File> csvsIn(Directory d) => !d.existsSync()
      ? const <File>[]
      : (d
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.csv'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)));

  final retiredCsvs = csvsIn(legacyDir);
  final csvs = [...csvsIn(dir), ...retiredCsvs];

  if (csvs.isEmpty) {
    stderr.writeln('welfare/ 에 CSV 가 없습니다. 빈 목록을 쓰지 않습니다.');
    exit(2);
  }

  final public = _pick(csvs, _publicPrefix);
  final private = _pick(csvs, _privatePrefix);
  if (public == null || private == null) {
    stderr.writeln('welfare/ 에서 두 자료를 못 찾았습니다.\n'
        '  공공: $_publicPrefix*.csv\n'
        '  민간: $_privatePrefix*.csv\n'
        '있는 파일: ${csvs.map(_baseName).join(', ')}');
    exit(2);
  }
  final publicRetired = retiredCsvs.contains(public);

  final outDir = Directory('${root.path}/packages/domain_data/assets/welfare');
  outDir.createSync(recursive: true);

  var changed = false;
  final publicData = _bakePublic(public, retired: publicRetired);
  final privateData = _bakePrivate(private);
  changed |= _write(
    File('${outDir.path}/public_services.json'),
    publicData,
    check: check,
  );
  changed |= _write(
    File('${outDir.path}/private_services.json'),
    privateData,
    check: check,
  );
  final baked = <Map<String, Object?>>[privateData];

  // 중앙부처는 API 에서 온다. 아직 안 받았으면 **없는 대로 둔다** —
  // 빈 목록을 구워 놓으면 「중앙부처 제도가 하나도 없다」가 커밋된다.
  final rawDir = Directory('${root.path}/welfare/raw/central');
  if (rawDir.existsSync()) {
    final centralData = _bakeCentral(rawDir, _knownLaws(root));
    baked.add(centralData);
    changed |= _write(
      File('${outDir.path}/central.json'),
      centralData,
      check: check,
    );
  } else {
    stdout.writeln('welfare/raw/central/ 이 없어 central.json 은 건너뜁니다. '
        'fetch_welfare_central.dart 를 먼저 돌리세요.');
  }

  changed |= _write(
    File('${outDir.path}/axes.json'),
    _bakeAxes(baked),
    check: check,
  );

  if (check && changed) {
    stderr.writeln('구운 JSON 이 CSV 와 어긋납니다. '
        'dart run packages/engines/tool/build_welfare.dart 를 돌리고 커밋하세요.');
    exit(1);
  }
}

const String _publicPrefix = '한국사회보장정보원_복지서비스정보_';
const String _privatePrefix = '한국사회보장정보원_민간복지서비스정보_';

// ───────────────────────────── 공공 ─────────────────────────────

/// 중앙부처 복지서비스 — **목록과 링크까지만.**
///
/// 이 자료에는 나이·지역·소득 축이 없다. 지원대상도 조건도 안 들어 있다.
/// 그러니 「당신은 대상입니다」로 가는 길이 아예 없고, 그게 지금은 안전하다.
/// 상세는 `openPart` 로 이름만 남긴다.
Map<String, Object?> _bakePublic(File csv, {bool retired = false}) {
  final rows = _readRows(csv);
  final services = <Map<String, Object?>>[];
  final excluded = <Map<String, Object?>>[];
  final released = _dateInFileName(csv);

  for (final row in rows) {
    final id = _clean(row['서비스아이디'] ?? '');
    final name = _clean(row['서비스명'] ?? '');
    final ministry = _clean(row['소관부처명'] ?? '');
    final fields = <String, String>{
      'name': name,
      'summary': _clean(row['서비스요약'] ?? ''),
      'org': _clean(row['소관조직명'] ?? ''),
      'site': _clean(row['사이트'] ?? ''),
      'contact': _clean(row['대표문의'] ?? ''),
    };

    final blocked = _scan('PublicWelfareService', fields);
    if (blocked != null) {
      excluded.add({
        'id': id,
        'name': name,
        'field': blocked.field,
        'reason': blocked.reason,
      });
      continue;
    }

    services.add({
      'id': id,
      'name': name,
      'summary': fields['summary'],
      'url': _clean(row['서비스URL'] ?? ''),
      'ministry': ministry,
      'org': fields['org'],
      'site': fields['site'],
      'contact': fields['contact'],
      'baseYear': int.parse(_clean(row['기준연도'] ?? '')),
      'notice': {
        'agency': ministry,
        // 행마다 최종수정일이 따로 있다. 이 항목의 날짜다.
        'checkedAt': _clean(row['최종수정일'] ?? ''),
        'dateScope': 'record',
        'dataset': '복지서비스정보',
      },
    });
  }

  services.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  return {
    'dataset': '복지서비스정보',
    'source': '한국사회보장정보원',
    'releasedAt': released,
    // 이름만 남긴다. 데이터가 없으니 화면에 한 글자도 안 쓴다.
    // **덧붙인다. 갈아치우지 않는다.** 축이 없다는 사실은 물러난 뒤에도
    // 그대로다 — 지우면 나중에 이 자료를 다시 볼 때 그걸 또 알아내야 한다.
    'openPart': retired
        ? '$_axisOpenPart / $_retiredOpenPart'
        : _axisOpenPart,
    // **물러난 자료라는 표시.** 파일을 안 지웠으니 데이터가 스스로 말해야
    // 한다 — 다음 사람이 이 목록을 보고 「왜 화면에 안 나오지」 하지 않게.
    if (retired) 'retired': true,
    if (retired) 'retiredWhy': _retiredWhy,
    'services': services,
    'excluded': excluded,
  };
}

/// 이 자료에 아예 없는 것 — 매칭 축(나이·지역·소득). 이름만 남긴다.
const String _axisOpenPart = '중앙부처 복지서비스 상세(지원대상·조건)';

/// 중앙부처 CSV 가 물러난 이유. **화면에 안 나간다. 데이터를 읽는 사람에게 쓴다.**
const String _retiredWhy =
    '중앙부처 API 목록(461건)이 이 자료를 대신한다 — 겹치는 362건은 API 가 '
    '상세를 갖고 있어서 API 가 이긴다. 이 파일은 지우지 않고 남긴다. '
    'CSV 에만 있는 5건의 상태를 우리가 확인할 수 없기 때문이다(DECISIONS 235번). '
    '이 목록은 화면에 한 줄도 안 그린다.';

/// 확인 안 된 자리. **이 자료에서 제일 중요한 한 줄이다.**
const String _retiredOpenPart =
    'CSV 에만 있고 중앙부처 API 목록에 없는 5건의 상태 — 없어진 제도인지 '
    'API 목록이 빠뜨린 것인지 확인 안 됨. 화면에 안 올린다';

// ───────────────────────────── 민간 ─────────────────────────────

/// 민간 복지서비스 — 지원대상·지원내용·신청방법·제출서류가 있다.
///
/// 세 축은 자주 비어 있다. **빈 축을 지우지 않는다.** 안 적힌 것을 「해당 없음」
/// 으로 바꾸면 축을 하나만 골라도 목록의 3분의 1이 사라지고, 사라지는 쪽은
/// 대상을 좁게 적지 않은 기관 — 누구나 신청해 볼 수 있는 사업들이다.
/// 대신 안 적힌 축의 이름을 `unstatedAxes` 로 남긴다.
Map<String, Object?> _bakePrivate(File csv) {
  final rows = _readRows(csv);
  final services = <Map<String, Object?>>[];
  final excluded = <Map<String, Object?>>[];
  final released = _dateInFileName(csv);

  for (final row in rows) {
    final org = _clean(row['기관명'] ?? '');
    final name = _clean(row['사업명'] ?? '');
    final id = 'prv_${_stableId('$org|$name')}';

    final axes = <String, List<String>>{
      'lifeStages': _split(row['생애주기']),
      'households': _split(row['가구상황']),
      'topics': _split(row['관심주제']),
    };
    final unstated = [
      for (final entry in axes.entries)
        if (entry.value.isEmpty) _axisNames[entry.key]!,
    ];

    final fields = <String, String>{
      'org': org,
      'name': name,
      'purpose': _clean(row['사업목적'] ?? ''),
      'target': _clean(row['지원대상'] ?? ''),
      'benefit': _clean(row['지원내용'] ?? ''),
      'howToApply': _clean(row['신청방법'] ?? ''),
      'documents': _clean(row['제출서류'] ?? ''),
      'etc': _clean(row['기타'] ?? ''),
    };

    final blocked = _scan('PrivateWelfareService', fields);
    if (blocked != null) {
      excluded.add({
        'id': id,
        'name': '$org — $name',
        'field': blocked.field,
        'reason': blocked.reason,
      });
      continue;
    }

    services.add({
      'id': id,
      ...fields,
      'periodFrom': _clean(row['사업시작일'] ?? ''),
      'periodTo': _clean(row['사업종료일'] ?? ''),
      ...axes,
      'unstatedAxes': unstated,
      'notice': {
        'agency': org,
        // **이 자료에는 항목별 최종수정일 칸이 없다.** 없는 칸을 있는 것처럼
        // 적지 않는다. 자료를 내려받은 판본의 날짜 하나뿐이고, 그렇다고 말한다.
        'checkedAt': released,
        'dateScope': 'dataset',
        'dataset': '민간복지서비스정보',
      },
    });
  }

  services.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  return {
    'dataset': '민간복지서비스정보',
    'source': '한국사회보장정보원',
    'releasedAt': released,
    'openPart': null,
    'services': services,
    'excluded': excluded,
  };
}

const Map<String, String> _axisNames = {
  'lifeStages': '생애주기',
  'households': '가구상황',
  'topics': '관심주제',
};

// ───────────────────────────── 청소 ─────────────────────────────

/// 하이픈 목록. **양옆 중 한쪽이 공백일 때만** 줄바꿈으로 바꾼다.
///
/// 좁게 잡은 이유가 있다. 이 자료에는 하이픈이 세 가지로 쓰인다:
///
/// ```
/// "중학생: 180만원 - 고등학생: 240만원"   목록 → 줄바꿈
/// "전화 문의: 1577-6635- 연중 접수"       전화번호 + 목록 → 뒤엣것만
/// "하이원-꿈장학" · "E-mail"              한 낱말 → 그대로 둔다
/// ```
///
/// 양쪽이 다 글자면 목록인지 낱말인지 자료가 말해 주지 않는다. 갈라 놓으면
/// 없던 줄이 생기고, 그건 문장을 고쳐 쓰는 것이다. 애매하면 안 건드린다.
final RegExp _bulletHyphen = RegExp(r'\s+-\s*|\s*-\s+');

/// 앞뒤 공백 · 연속 공백 · 하이픈 목록. **여기까지다.**
///
/// [splitHyphenLists] 를 끄는 자리가 있다. **자료가 줄을 알려 주면 우리가
/// 추측하지 않는다** — API 응답은 `&#13;`(CR)로 줄을 나눠서 보낸다. 거기에
/// 하이픈 규칙까지 걸면 셈식이 잘린다:
///
/// ```
/// 소득평가액 = {0.7 X (근로소득 - 116만원)} + 기타 소득
///                              ↑ 목록이 아니라 뺄셈
/// ```
///
/// CSV 에는 줄바꿈이 아예 없어서 하이픈 말고는 단서가 없다. 그래서 켠다.
String _clean(String raw, {bool splitHyphenLists = true}) {
  // CR 하나짜리도 줄바꿈이다. API 가 그걸로 줄을 나눈다.
  var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (splitHyphenLists) text = text.replaceAll(_bulletHyphen, '\n');
  // 줄 안의 연속 공백만 줄인다. 줄바꿈은 살린다.
  text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');
  text = text.split('\n').map((line) => line.trim()).join('\n');
  // 빈 줄이 이어지면 하나로. 목록 사이가 벌어지는 것뿐이라 뜻이 안 바뀐다.
  text = text.replaceAll(RegExp(r'\n{2,}'), '\n');
  return text.trim();
}

List<String> _split(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return const [];
  return [
    for (final part in text.split(RegExp('[,;]')))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

// ───────────────────────── 문구 검사 ─────────────────────────

class _Blocked {
  const _Blocked(this.field, this.reason);
  final String field;
  final String reason;
}

/// 기관이 알려 준 말도 **화면에 나가는 글자다.** 검사를 건너뛰지 않는다.
///
/// scope 는 [scopeFor] 가 정한다 — 코드에 고정돼 있어 자료가 안전장치를 못 끈다.
/// 인용이라 `quote` 이지만, 인용에서도 막는 말이 있다.
_Blocked? _scan(String typeName, Map<String, String> fields) {
  for (final entry in fields.entries) {
    final scope = scopeFor(typeName, entry.key);
    final violations = SafetyFilter.scan(entry.value, scope: scope);
    if (violations.isEmpty) continue;
    final first = violations.first;
    return _Blocked(
      entry.key,
      '${scope.name} 에서 막는 표현입니다: "${first.excerpt}" (/${first.pattern}/)',
    );
  }
  return null;
}

// ───────────────────────────── CSV ─────────────────────────────

/// CSV 한 장을 이름표 붙은 행 목록으로. RFC 4180 (따옴표 안의 쉼표·줄바꿈).
///
/// **API 로 갈아탈 때 바뀌는 곳은 여기 하나다.**
List<Map<String, String>> _readRows(File csv) {
  final bytes = csv.readAsBytesSync();
  String text;
  try {
    text = const Utf8Decoder().convert(bytes);
  } on FormatException {
    stderr.writeln('${_baseName(csv)} 이 UTF-8 이 아닙니다. '
        '공공데이터포털 CSV 는 CP949 로 옵니다 — UTF-8 로 저장한 뒤 다시 돌리세요.');
    exit(2);
  }
  if (text.startsWith('﻿')) text = text.substring(1);

  final table = _parseCsv(text);
  if (table.length < 2) {
    stderr.writeln('${_baseName(csv)} 에 행이 없습니다.');
    exit(2);
  }
  final header = table.first;
  return [
    for (final row in table.skip(1))
      if (row.any((cell) => cell.trim().isNotEmpty))
        {
          for (var i = 0; i < header.length; i++)
            header[i]: i < row.length ? row[i] : '',
        },
  ];
}

List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
      continue;
    }
    switch (ch) {
      case '"':
        quoted = true;
      case ',':
        row.add(cell.toString());
        cell.clear();
      case '\r':
        break;
      case '\n':
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      default:
        cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

// ───────────────────────────── 잡일 ─────────────────────────────

/// 파일 이름 끝의 `_20250722` 를 `2025-07-22` 로.
String _dateInFileName(File csv) {
  final match =
      RegExp(r'_(\d{4})(\d{2})(\d{2})\.csv$').firstMatch(_baseName(csv));
  if (match == null) {
    stderr.writeln('${_baseName(csv)} 이름에 판본 날짜가 없습니다 (…_YYYYMMDD.csv).');
    exit(2);
  }
  return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
}

/// `기관명|사업명` 에서 만드는 고정 id (FNV-1a 64bit).
///
/// 민간 자료에는 아이디 칸이 없다. 줄 번호를 쓰면 자료가 한 줄만 늘어도 전부
/// 밀린다 — 즐겨찾기가 다른 사업을 가리키게 된다.
String _stableId(String key) {
    var hash = BigInt.parse('14695981039346656037'); // not-a-legal-number: FNV-1a 해시 상수. 법률 수치가 아니다.
    final prime = BigInt.parse('1099511628211'); // not-a-legal-number: FNV-1a 소수. 법률 수치가 아니다.
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final byte in utf8.encode(key)) {
    hash = (hash ^ BigInt.from(byte)) & mask;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0').substring(0, 12);
}

File? _pick(List<File> files, String prefix) {
  for (final file in files) {
    if (_baseName(file).startsWith(prefix)) return file;
  }
  return null;
}

String _baseName(File file) => file.uri.pathSegments.last;

bool _write(File out, Map<String, Object?> data, {required bool check}) {
  final text = '${const JsonEncoder.withIndent('  ').convert(data)}\n';
  final before = out.existsSync() ? out.readAsStringSync() : null;
  final list = data['services'] as List?;
  final services = list == null ? '' : ' — ${list.length}건';
  final excluded =
      (data['excluded'] as List? ?? const []).cast<Map<String, Object?>>();

  if (check) {
    if (before == text) {
      stdout.writeln('✅ ${_baseName(out)}$services');
      return false;
    }
    stderr.writeln('✘ ${_baseName(out)} 이 CSV 와 다릅니다.');
    return true;
  }

  out.writeAsStringSync(text);
  stdout.writeln('${_baseName(out)}$services'
      '${excluded.isEmpty ? '' : ' (뺀 것 ${excluded.length}건)'}');
  for (final row in excluded) {
    stdout.writeln('  ✘ ${row['name']} — ${row['field']}: ${row['reason']}');
  }
  return before != text;
}

/// 매니페스트에 있는 법령 이름. **근거법령을 맞대 볼 자리다.**
Set<String> _knownLaws(Directory root) {
  final file =
      File('${root.path}/packages/domain_data/assets/laws/manifest.json');
  if (!file.existsSync()) return const {};
  final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final law in (manifest['laws'] as List).cast<Map<String, dynamic>>())
      normalizeLawName(law['name']! as String),
  };
}

Directory _repoRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
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

// ───────────────────────── 중앙부처 (API) ─────────────────────────

/// 받아 둔 XML 을 굽는다. **네트워크를 부르지 않는다.**
///
/// 받기는 `fetch_welfare_central.dart` 가 한다. 여기서는 `welfare/raw/central/`
/// 에 있는 것만 읽는다 — 그래야 굽기가 결정적이고 `--check` 가 뜻을 가진다.
///
/// ## 목록에 있는 건 다 담는다
///
/// 상세를 안 받은 건도 **이름·요약·복지로 링크까지는 담는다.** 안 담으면
/// 다음 사람이 「목록이 461건인데 왜 196건이지」에서 시작한다. 지운 것이
/// 아니라 아직 안 받은 것이고, `detailFetched: false` 가 그렇다고 말한다.
Map<String, Object?> _bakeCentral(Directory rawDir, Set<String> knownLaws) {
  final stampFile = File('${rawDir.path}/fetched.json');
  if (!stampFile.existsSync()) {
    stderr.writeln('welfare/raw/central/fetched.json 이 없습니다. '
        '먼저 fetch_welfare_central.dart 를 돌리세요.');
    exit(2);
  }
  final stamp = jsonDecode(stampFile.readAsStringSync()) as Map<String, dynamic>;
  final fetchedAt = stamp['fetchedAt']! as String;
  final totalCount = stamp['totalCount']! as int;

  // ── 목록 ──
  final listRows = <String, XmlNode>{};
  final pages = rawDir
      .listSync()
      .whereType<File>()
      .where((f) => _baseName(f).startsWith('list_p'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final page in pages) {
    for (final serv in parseXml(_readGz(page)).findAll('servList')) {
      listRows[serv.textOf('servId')] = serv;
    }
  }

  // ── 상세 ──
  final detailRows = <String, XmlNode>{};
  for (final file in rawDir.listSync().whereType<File>()) {
    if (!_baseName(file).startsWith('detail_')) continue;
    final dtl = parseXml(_readGz(file));
    detailRows[dtl.textOf('servId')] = dtl;
  }

  final services = <Map<String, Object?>>[];
  final excluded = <Map<String, Object?>>[];
  final matched = <String>{};
  final notTaken = <String>{};

  for (final entry in listRows.entries) {
    final id = entry.key;
    final list = entry.value;
    final dtl = detailRows[id];

    final axes = <String, List<String>>{
      'lifeStages': _splitAxis(dtl, list, 'lifeArray'),
      'households': _splitAxis(dtl, list, 'trgterIndvdlArray'),
      'topics': _splitAxis(dtl, list, 'intrsThemaArray'),
    };
    final unstated = [
      for (final axis in axes.entries)
        if (axis.value.isEmpty) _axisNames[axis.key]!,
    ];

    final ministry = _api(dtl?.textOf('jurMnofNm') ?? '').isNotEmpty
        ? _api(dtl!.textOf('jurMnofNm'))
        : _api(list.textOf('jurMnofNm'));

    final laws = [
      for (final row in dtl?.findAll('baslawList') ?? const <XmlNode>[])
        if (_api(row.textOf('servSeDetailNm')).isNotEmpty)
          _api(row.textOf('servSeDetailNm')),
    ];
    for (final law in laws) {
      (knownLaws.contains(normalizeLawName(law)) ? matched : notTaken).add(law);
    }

    final fields = <String, String>{
      'name': _api(dtl?.textOf('servNm') ?? list.textOf('servNm')),
      'summary':
          _api(list.textOf('servDgst')) .isNotEmpty
              ? _api(list.textOf('servDgst'))
              : _api(dtl?.textOf('wlfareInfoOutlCn') ?? ''),
      'org': _api(list.textOf('jurOrgNm')),
      'contact': _api(dtl?.textOf('rprsCtadr') ?? list.textOf('rprsCtadr')),
      'target': _api(dtl?.textOf('tgtrDtlCn') ?? ''),
      'criteria': _api(dtl?.textOf('slctCritCn') ?? ''),
      'benefit': _api(dtl?.textOf('alwServCn') ?? ''),
    };

    final blocked = _scan('CentralWelfareService', fields);
    if (blocked != null) {
      excluded.add({
        'id': id,
        'name': fields['name'],
        'field': blocked.field,
        'reason': blocked.reason,
      });
      continue;
    }

    services.add({
      'id': id,
      ...fields,
      'url': _api(list.textOf('servDtlLink')),
      'ministry': ministry,
      'detailFetched': dtl != null,
      'priority': welfarePriority(
        topics: axes['topics']!.toSet(),
        households: axes['households']!.toSet(),
        lifeStages: axes['lifeStages']!.toSet(),
      ),
      'howToApply': _links(dtl, 'applmetList'),
      'inquiries': _links(dtl, 'inqplCtadrList'),
      'homepages': _links(dtl, 'inqplHmpgReldList'),
      'forms': _links(dtl, 'basfrmList'),
      'laws': laws,
      'baseYear': int.tryParse(_api(dtl?.textOf('crtrYr') ?? '')),
      'cycle': _api(dtl?.textOf('sprtCycNm') ?? list.textOf('sprtCycNm')),
      'provision': _api(dtl?.textOf('srvPvsnNm') ?? list.textOf('srvPvsnNm')),
      'onlineApply': list.textOf('onapPsbltYn') == 'Y',
      // 복지로 조회수. 목록 응답에만 있고 461건 전부에 있다.
      'views': int.tryParse(list.textOf('inqNum')) ?? 0,
      ...axes,
      'unstatedAxes': unstated,
      'notice': {
        'agency': ministry,
        // 이 API 에는 항목별 최종수정일 칸이 없다. 받은 날 하나뿐이다.
        'checkedAt': fetchedAt,
        'dateScope': 'dataset',
        'dataset': '중앙부처복지서비스',
      },
    });
  }

  services.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  final fetched = services.where((s) => s['detailFetched'] == true).length;
  return {
    'dataset': '중앙부처복지서비스',
    'source': '한국사회보장정보원 · 공공데이터포털',
    'releasedAt': fetchedAt,
    // **키는 안 적는다.** 어디서 왔는지만 적는다.
    'operations': ['NationalWelfarelistV001', 'NationalWelfaredetailedV001'],
    'totalCount': totalCount,
    'detailFetchedCount': fetched,
    'openPart': '지자체복지서비스 API (오퍼레이션·지역 파라미터 미확인)',
    'services': services,
    'excluded': excluded,
    'matchedLaws': matched.toList()..sort(),
    'lawsNotTaken': notTaken.toList()..sort(),
    'lawsNotTakenWhy': '우리 분야와 안 이어지는 복지 전용 법령입니다. '
        '법령 139개가 200개가 되면 매주 판본 대조가 무너집니다. '
        '버리지 않고 적어 둡니다 — 1순위 상세를 다 받은 뒤 다시 셉니다.',
  };
}

/// 상세에 있으면 상세를, 없으면 목록을 쓴다.
///
/// **두 응답이 같은 축을 조금 다르게 적는다** — 목록은 `영유아,아동`,
/// 상세는 `영유아, 아동` (사이에 공백). 나눈 뒤 `trim` 하므로 같아진다.
List<String> _splitAxis(XmlNode? detail, XmlNode list, String tag) {
  final fromDetail = detail?.textOf(tag) ?? '';
  return _split(fromDetail.trim().isNotEmpty ? fromDetail : list.textOf(tag));
}

List<Map<String, Object?>> _links(XmlNode? detail, String tag) => [
      for (final row in detail?.findAll(tag) ?? const <XmlNode>[])
        {
          'name': _api(row.textOf('servSeDetailNm')),
          'value': _api(row.textOf('servSeDetailLink')),
        },
    ];

/// API 에서 온 글자 한 칸. **덜 푼 이름표를 마저 풀고, 그다음 청소한다.**
///
/// 순서가 중요하다. `&amp;#9312;` 는 XML 을 풀면 `&#9312;` 라는 글자 여덟 개가
/// 되고, 그걸 먼저 `①` 로 되돌린 다음에 공백·하이픈을 다듬어야 줄이 제대로 선다.
String _api(String raw) =>
    _clean(decodeStrayEntities(raw), splitHyphenLists: false);

String _readGz(File file) => utf8.decode(gzip.decode(file.readAsBytesSync()));

/// 법령 이름을 맞대 보기 위한 꼴. **띄어쓰기와 가운뎃점만 지운다.**
///
/// 약칭은 손대지 않는다 — 「아이돌봄 지원법」과 「아이돌봄지원법」은 같은 법이지만
/// 「국민기초생활 보장법」과 「기초생활보장법」은 우리가 판단할 일이 아니다.
/// **못 맞춘 것은 버리지 않고 목록으로 남긴다**(`unmatchedLaws`).
String normalizeLawName(String name) =>
    name.replaceAll(RegExp(r'[\s·ㆍ]'), '');

// ───────────────────────────── 대조표 ─────────────────────────────

/// 세 축의 이름이 출처마다 같은지 **세어서 적어 둔다.**
///
/// 안 만들면 나중에 두 출처를 같은 축으로 못 거른다. 그런데 **손으로 적으면
/// 반드시 어긋난다** — 구운 자료에서 뽑는다.
///
/// ## 코드와 이름은 다른 층이다
///
/// 요청은 **코드**로 보내고(`lifeArray=007`) 응답은 **이름**으로 온다
/// (`lifeArray="아동,청소년"`). 활용가이드에는 코드 범위만 있고 코드↔이름
/// 대조가 없다. **우리가 짝을 지어 보지 않는다** — 틀리면 엉뚱한 사람에게
/// 엉뚱한 제도가 간다. `openPart` 로 이름만 남긴다.
///
/// 문서가 말하는 것: 지자체 관심주제는 14종, 중앙부처는 16종이다. 같은 축
/// 이름을 쓰지만 **가짓수가 다르다.**
Map<String, Object?> _bakeAxes(List<Map<String, Object?>> catalogs) {
  const names = {
    'lifeStages': '생애주기',
    'households': '가구상황',
    'topics': '관심주제',
  };

  final axes = <Map<String, Object?>>[];
  for (final entry in names.entries) {
    final byDataset = <String, List<String>>{};
    for (final catalog in catalogs) {
      final values = <String>{};
      for (final raw in (catalog['services']! as List)) {
        final service = raw as Map<String, Object?>;
        values.addAll((service[entry.key] as List? ?? const []).cast<String>());
      }
      byDataset[catalog['dataset']! as String] = values.toList()..sort();
    }
    final all = <String>{for (final list in byDataset.values) ...list}.toList()
      ..sort();
    axes.add({
      'key': entry.key,
      'name': entry.value,
      'values': [
        for (final value in all)
          {
            'name': value,
            'seenIn': [
              for (final row in byDataset.entries)
                if (row.value.contains(value)) row.key,
            ],
          },
      ],
    });
  }

  return {
    'note': '요청은 코드로 보내고 응답은 이름으로 옵니다. '
        '**받아 놓고 이름으로 거르는 데는 이 대응이 필요 없습니다** — '
        '지금 아무것도 막고 있지 않습니다. 요청 필터를 쓸 때만 필요합니다.',
    'openPart': '축 코드 ↔ 이름 대조 (활용가이드에 코드 범위만 있음. '
        '요청 필터를 쓸 때만 막힙니다)',
    'axes': axes,
  };
}
