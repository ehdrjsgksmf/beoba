import 'dart:convert';
import 'dart:io';

import 'mini_xml.dart';
import 'welfare_priority.dart';

/// 중앙부처 복지서비스 API 를 받아 `welfare/raw/central/` 에 쌓는다.
///
/// ```
/// dart run packages/engines/tool/fetch_welfare_central.dart
/// dart run packages/engines/tool/fetch_welfare_central.dart --limit 20   맛보기
/// dart run packages/engines/tool/fetch_welfare_central.dart --priority 1  1순위만
/// dart run packages/engines/tool/fetch_welfare_central.dart --force      다시 받기
/// ```
///
/// ## 461건을 다 받지 않는다
///
/// 한도가 창당 100회뿐이라 **순서가 곧 무엇을 갖느냐**다. 목록은 다 받아 두고
/// (한 번이면 된다), 상세는 [welfarePriority] 순으로 받는다 — 우리 사용자에게
/// 닿는 주제(서민금융·일자리·주거·법률·안전·위기, 저소득·한부모)부터.
/// 상세가 없는 건은 지운 것이 아니라 **아직 안 받은 것**이고, 구운 자료에
/// `detailFetched: false` 로 남는다.
///
/// **받기와 굽기를 나눈다.** 이 도구는 네트워크만 하고 아무것도 해석하지
/// 않는다. 해석은 `build_welfare.dart` 가 받아 둔 XML 만 보고 한다 —
/// 그래야 굽기가 결정적이고 `--check` 가 뜻을 가진다.
///
/// ## 키
///
/// `.env` 의 `DATA_GO_KR_KEY` 는 **이미 URL 인코딩된 형태**다(`%2F`·`%2B`·`%3D`).
/// `Uri.https(host, path, params)` 는 값을 다시 인코딩해서 `%252F` 를 만들고,
/// 그러면 인증이 30(미등록키)으로 떨어진다. 그래서 [Uri.parse] 로 문자열을
/// 직접 짓는다. **`serviceKey` 만 날것이다** — 한글이 들어가는 값은 따로
/// 인코딩해야 한다. 두 규칙을 섞지 않는다.
///
/// 로그에 URL 을 찍되 키는 가린다.
///
/// ## 한도
///
/// 개발계정 일 1,000회 · 초당 30회. 목록 한두 번 + 상세 건당 한 번이다.
/// 이미 받아 둔 상세는 건너뛴다 — 중간에 끊겨도 이어받는다.
Future<void> main(List<String> args) async {
  final root = _repoRoot();
  final key = _readKey(root);
  final force = args.contains('--force');
  final limit = _intArg(args, '--limit');
  // 몇 순위까지 받을지. 안 주면 다 받되 **순위 순서로** 받는다.
  final upTo = _intArg(args, '--priority');

  final rawDir = Directory('${root.path}/welfare/raw/central');
  rawDir.createSync(recursive: true);

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final budget = _Budget();

  try {
    final rows = await _fetchList(client, key, rawDir, budget, force: force);
    stdout.writeln('목록 ${rows.length}건.');

    // **순위 순으로 줄을 세운다.** 창이 닫혀도 앞쪽부터 받아 둔 셈이 된다.
    final ranked = rows
        .where((row) => upTo == null || _within(row.priority, upTo))
        .toList()
      ..sort((a, b) {
        final byRank =
            prioritySortKey(a.priority).compareTo(prioritySortKey(b.priority));
        return byRank != 0 ? byRank : a.id.compareTo(b.id);
      });

    final tally = <int, int>{};
    for (final row in rows) {
      tally[row.priority] = (tally[row.priority] ?? 0) + 1;
    }
    stdout.writeln('  1순위 ${tally[1] ?? 0}건 · 2순위 ${tally[2] ?? 0}건 · '
        '나머지 ${tally[0] ?? 0}건'
        '${upTo == null ? '' : ' → $upTo순위까지 ${ranked.length}건을 받습니다'}');

    final wanted =
        (limit == null ? ranked : ranked.take(limit)).map((r) => r.id).toList();
    var got = 0;
    var skipped = 0;

    for (final id in wanted) {
      final file = File('${rawDir.path}/detail_$id.xml.gz');
      if (!force && file.existsSync()) {
        skipped++;
        continue;
      }
      final body = await _get(
        client,
        key,
        'NationalWelfaredetailedV001',
        {'callTp': 'D', 'servId': id},
        budget,
      );
      _writeGz(file, body);
      got++;
      if (got % 25 == 0) {
        stdout.writeln('  상세 $got건 받음 · ${budget.describe()}');
      }
      if (budget.remaining == 0) {
        stdout.writeln('  남은 호출이 0입니다. 여기서 멈추고 다음에 이어받습니다.');
        break;
      }
      // 초당 30 이라고 적혀 있지만 120ms 로 돌렸더니 96회째에 429 가 났다.
      // **문서의 tps 와 실제로 참아 주는 속도는 다르다.** 넉넉히 벌린다 —
      // 하루 한 번 도는 도구가 급할 이유가 없다.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    stdout.writeln('상세 새로 받은 것 $got건 · 이미 있던 것 $skipped건');
    stdout.writeln(budget.describe());
  } on _ApiStop catch (stop) {
    stderr.writeln(stop.message);
    stderr.writeln(budget.describe());
    exit(1);
  } finally {
    client.close(force: true);
  }
}

const String _base =
    'https://apis.data.go.kr/B554287/NationalWelfareInformationsV001';

/// 한 번에 받을 수 있는 최대. 문서가 정한 값이다.
const int _pageSize = 500; // not-a-legal-number: API 페이지 크기. 법률 수치가 아니다.

/// 목록 한 줄 — 상세를 받을지 고르는 데 필요한 것만.
class _Row {
  const _Row(this.id, this.priority);
  final String id;
  final int priority;
}

/// 목록을 다 받아 servId 와 순위를 모은다.
Future<List<_Row>> _fetchList(
  HttpClient client,
  String key,
  Directory rawDir,
  _Budget budget, {
  required bool force,
}) async {
  final ids = <_Row>[];
  var page = 1;
  var total = -1;

  while (true) {
    final file = File('${rawDir.path}/list_p$page.xml.gz');
    String body;
    if (!force && file.existsSync()) {
      body = utf8.decode(gzip.decode(file.readAsBytesSync()));
    } else {
      body = await _get(
        client,
        key,
        'NationalWelfarelistV001',
        {
          'callTp': 'L',
          'pageNo': '$page',
          'numOfRows': '$_pageSize',
          // 001 서비스명 · 002 서비스내용 · 003 둘 다. 거르지 않고 다 받는다.
          'srchKeyCode': '003',
        },
        budget,
      );
      _writeGz(file, body);
    }

    final root = parseXml(body);
    total = int.parse(root.textOf('totalCount'));
    _stamp(rawDir, total);
    for (final serv in root.findAll('servList')) {
      final id = serv.textOf('servId');
      if (id.isEmpty) continue;
      ids.add(
        _Row(
          id,
          welfarePriority(
            topics: _names(serv, 'intrsThemaArray'),
            households: _names(serv, 'trgterIndvdlArray'),
            lifeStages: _names(serv, 'lifeArray'),
          ),
        ),
      );
    }
    if (ids.length >= total || root.findAll('servList').isEmpty) break;
    page++;
  }

  if (ids.length != total) {
    stderr.writeln('⚠ 목록이 $total건이라는데 ${ids.length}건만 받았습니다.');
  }
  return ids;
}

/// 한 번 부른다. **resultCode 를 먼저 본다.**
Future<String> _get(
  HttpClient client,
  String key,
  String operation,
  Map<String, String> params,
  _Budget budget,
) async {
  // serviceKey 는 이미 인코딩돼 있어 날것으로 붙인다.
  // 나머지는 값에 한글이 없는 것만 넣고 있다 — 넣게 되면 여기서 인코딩한다.
  final query = [
    'serviceKey=$key',
    for (final entry in params.entries)
      '${entry.key}=${Uri.encodeQueryComponent(entry.value)}',
  ].join('&');
  final uri = Uri.parse('$_base/$operation?$query');

  if (budget.spent == 0) {
    stdout.writeln('첫 호출 → ${uri.toString().replaceAll(key, '<키가려짐>')}');
  }

  // **429 는 멈출 이유가 아니라 기다릴 이유다.** 초당 제한에 걸린 것뿐이라
  // 잠깐 쉬면 다시 받는다. 여기서 죽으면 이미 받은 것까지 버리게 된다.
  var body = '';
  for (var attempt = 0; ; attempt++) {
    final request = await client.getUrl(uri);
    final response = await request.close();
    budget.spent++;
    budget.readHeaders(response.headers);
    body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 200) break;

    // **창이 닫혀 있다고 머리글이 말하면 다시 걸지 않는다.**
    // 초당 제한이면 잠깐 쉬어서 풀리지만, 남은 횟수가 0 이면 쉬어도 안 풀린다.
    // 물러서기만 다섯 번 하면 닫힌 창에 여섯 번을 버린다.
    final closed = response.statusCode == 429 && budget.remaining == 0;
    final retriable =
        !closed && (response.statusCode == 429 || response.statusCode >= 500);
    if (!retriable || attempt >= 5) { // not-a-legal-number: 다시 걸어 보는 횟수. 법률 수치가 아니다.
      if (closed) {
        budget.dumpHeaders();
        stdout.writeln('  응답 본문 — $body');
      }
      throw _ApiStop(
        'HTTP ${response.statusCode} 입니다. ${budget.describe()}\n'
        '429 라면 창이 열릴 때까지 기다렸다가 같은 명령을 다시 돌리세요 — '
        '이미 받아 둔 것은 건너뜁니다.',
      );
    }
    final wait = Duration(seconds: 1 << attempt); // not-a-legal-number: 기다리는 초. 1 · 2 · 4 · 8 · 16 초.
    stdout.writeln('  HTTP ${response.statusCode} — ${wait.inSeconds}초 쉬고 '
        '다시 겁니다 (${attempt + 1}번째)');
    await Future<void>.delayed(wait);
  }

  final root = parseXml(body);
  final code = root.textOf('resultCode');
  if (code != '0') {
    throw _ApiStop('resultCode=$code (${root.textOf('resultMessage')}) — '
        '${_codeMeaning[code] ?? '문서에 없는 코드입니다'}');
  }
  return body;
}

/// 축 한 칸을 이름 집합으로. 응답은 `"서민금융,주거"` 꼴이다.
Set<String> _names(XmlNode node, String tag) => {
      for (final part in node.textOf(tag).split(','))
        if (part.trim().isNotEmpty) part.trim(),
    };

/// 순위 [priority] 가 [upTo] 순위 안에 드는가. **0 은 맨 뒤다.**
bool _within(int priority, int upTo) =>
    prioritySortKey(priority) <= prioritySortKey(upTo);

const Map<String, String> _codeMeaning = {
  '04': 'HTTP 오류',
  '10': '파라미터 오류',
  '12': '없는 서비스입니다',
  '20': '접근 거부',
  '22': '호출 한도를 넘었습니다. 오늘은 여기까지입니다',
  '30': '등록 안 된 키입니다. 키를 다시 인코딩해서 보냈는지 보세요 (%252F)',
  '31': '키 기간이 지났습니다',
  '99': '알 수 없는 오류',
};

class _ApiStop implements Exception {
  _ApiStop(this.message);
  final String message;
}

/// 몇 번 불렀고 몇 번 남았나.
///
/// **문서는 일 1,000회라고 적어 두었지만 응답 머리글은 다르게 말한다.**
/// 실제로 온 것은 `X-RateLimit-Limit: 100` · `X-RateLimit-Remaining: 0` 이었고,
/// 102회째부터 429 가 났다. 문서를 믿고 세지 말고 **응답이 말하는 것을 센다.**
/// 창(窓)이 얼마짜리인지는 머리글이 말해 주지 않아 [_ApiStop] 메시지로만 남긴다.
class _Budget {
  int spent = 0;

  /// 응답 머리글이 말한 값. 못 받았으면 null.
  int? limit;
  int? remaining;

  /// 마지막 응답의 머리글 전부.
  ///
  /// **창이 언제 열리는지를 한 번은 눈으로 봐야 한다.** 「45분쯤 뒤에 열리더라」는
  /// 한 번 본 것이지 잰 것이 아니었고, 실제로 열두 시간이 지나도 안 열린 적이
  /// 있다. 머리글에 `reset`·`retry-after` 가 있으면 추측을 그만둘 수 있다.
  final Map<String, String> lastHeaders = {};

  void readHeaders(HttpHeaders headers) {
    limit = int.tryParse(headers.value('x-ratelimit-limit') ?? '') ?? limit;
    remaining =
        int.tryParse(headers.value('x-ratelimit-remaining') ?? '') ?? remaining;
    lastHeaders.clear();
    headers.forEach((name, values) => lastHeaders[name] = values.join(', '));
  }

  /// 닫힌 창을 만났을 때 머리글을 통째로 찍는다. **읽는 것만 골라 찍으면
  /// 안 읽는 것이 있다는 사실을 영영 모른다.**
  void dumpHeaders() {
    stdout.writeln('  응답 머리글 — 창이 언제 열리는지 말해 주는 칸을 찾습니다:');
    for (final entry in lastHeaders.entries) {
      stdout.writeln('    ${entry.key}: ${entry.value}');
    }
  }

  String describe() {
    final said = limit == null
        ? '머리글이 한도를 안 알려 줬습니다'
        : '머리글이 말한 한도 $limit회 · 남은 것 ${remaining ?? '?'}회';
    return '호출 $spent회 · $said';
  }
}

void _writeGz(File file, String body) =>
    file.writeAsBytesSync(gzip.encode(utf8.encode(body)));

/// **받은 날을 파일에 적어 둔다.** 굽는 쪽이 오늘 날짜를 쓰면 안 된다.
///
/// `build_welfare.dart --check` 는 CSV·XML 이 그대로면 결과가 그대로여야
/// 뜻이 있다. 굽는 자리에서 `DateTime.now()` 를 부르면 하루만 지나도 어긋난
/// 것처럼 보인다. 날짜는 **받은 쪽이 한 번** 적고, 굽는 쪽은 읽기만 한다.
void _stamp(Directory rawDir, int total) {
  final file = File('${rawDir.path}/fetched.json');
  if (file.existsSync()) {
    final before = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (before['totalCount'] == total) return;
  }
  final now = DateTime.now();
  final date = '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
          'fetchedAt': date,
          'totalCount': total,
        })}\n',
  );
}

String _pad(int value) => value.toString().padLeft(2, '0');

/// `.env` 에서 키 한 줄. **없으면 거기서 멈춘다.**
///
/// 조용히 0건을 굽는 것이 제일 나쁘다 — 다음 사람은 API 가 빈 줄 안다.
String _readKey(Directory root) {
  final env = File('${root.path}/.env');
  if (!env.existsSync()) {
    stderr.writeln('.env 가 없습니다. .env.example 을 보고 만드세요.');
    exit(2);
  }
  for (final line in env.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final at = trimmed.indexOf('=');
    if (at < 0) continue;
    if (trimmed.substring(0, at).trim() != 'DATA_GO_KR_KEY') continue;
    final value = trimmed.substring(at + 1).trim();
    if (value.isEmpty) break;
    return value;
  }
  stderr.writeln('.env 에 DATA_GO_KR_KEY 가 없습니다(또는 비어 있습니다).');
  exit(2);
}

int? _intArg(List<String> args, String name) {
  final at = args.indexOf(name);
  if (at < 0 || at + 1 >= args.length) return null;
  return int.tryParse(args[at + 1]);
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
