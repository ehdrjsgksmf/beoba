import 'dart:convert';
import 'dart:io';

/// `docs/개인정보처리방침.md` 하나에서 **방침이 놓일 자리 둘을 굽는다.**
///
/// ```
/// dart run packages/engines/tool/build_privacy_page.dart          만들어서 씀
/// dart run packages/engines/tool/build_privacy_page.dart --check  달라지면 실패
/// ```
///
/// ## 왜 한 장을 따로 굽는가
///
/// 방침이 있어야 할 자리는 셋인데 성격이 둘이다.
///
/// - 앱 안 · 웹앱 안 — 같은 라우트가 [policyJsonPath] 를 읽어 그린다
/// - **정적 페이지 한 장** — 스토어 심사자와 기관 담당자에게 줄 주소
///
/// 셋째가 왜 따로 필요한지가 중요하다. 그 사람들은 **앱과 무관하게 열리는
/// 주소**를 본다. Flutter 라우트로만 두면 방침 한 장을 보려고 앱 번들을 통째로
/// 받아야 한다. **그 사람은 안 기다린다.** 그래서 Flutter 없이 열리는 한 장을
/// 따로 굽는다.
///
/// ## 손으로 베껴 쓰지 않는다
///
/// 「같은 사실이 두 곳에 있으면 반드시 한쪽이 뒤처진다」(DECISIONS 126번).
/// 그래서 원본은 [policySourcePath] 하나뿐이고 나머지는 전부 생성물이다.
/// 어긋나면 `verify_domains.dart` 의 검사 (ah) 가 빨간불을 켠다 —
/// **CI 에서 도는 첫 생성기다.** 원본이 `.gitignore` 가 아니라 커밋돼 있어서
/// `--check` 를 CI 에서 돌릴 수 있다.
///
/// ## 바깥에서 아무것도 안 가져온다
///
/// 글꼴도 그림도 스크립트도 없다. 하나라도 부르면 **방침 3절과 5절이 그
/// 자리에서 거짓이 된다.** 굽는 결과가 `apps/beoba/web/` 에 들어가므로
/// 검사 (ah) 의 바깥 주소 스캔이 그대로 이 파일도 훑는다.
///
/// ## 모르는 문법을 만나면 멈춘다
///
/// 방침이 쓰는 마크다운은 다섯뿐이다 — `# ` · `## ` · `- ` · 문단 ·
/// **한 줄 전체가 굵은 줄**. 그 밖의 것을 만나면 [FormatException] 을 던지고
/// 아무것도 쓰지 않는다. 조용히 흘려보내면 화면에 별표가 그대로 찍히거나
/// 문단이 사라지는데, 방침은 그러면 안 되는 글이다.
Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final root = _repoRoot();

  final source = File('${root.path}/$policySourcePath');
  if (!source.existsSync()) {
    stderr.writeln('$policySourcePath 가 없습니다. 원본이 있어야 굽습니다.');
    exit(2);
  }

  final blocks = parsePolicy(source.readAsStringSync());
  if (blocks.isEmpty) {
    stderr.writeln('$policySourcePath 에서 읽어 낸 덩어리가 0개입니다. '
        '빈 방침을 쓰지 않습니다.');
    exit(2);
  }

  var stale = false;
  for (final MapEntry(key: path, value: text) in bakePolicy(blocks).entries) {
    final out = File('${root.path}/$path');
    final before = out.existsSync() ? out.readAsStringSync() : null;
    if (check) {
      if (before == text) {
        stdout.writeln('✅ $path');
        continue;
      }
      stderr.writeln('✘ $path 가 $policySourcePath 와 다릅니다. 다시 구워서 커밋하세요.');
      stale = true;
      continue;
    }
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(text);
    // **글자 수가 아니라 바이트로 잰다.** 한글은 UTF-8 에서 한 글자가 세
    // 바이트라 글자 수로 재면 실제로 받는 양을 1/3 로 속인다.
    final bytes = out.lengthSync();
    stdout.writeln('$path — $bytes 바이트 (${(bytes / 1024).toStringAsFixed(1)} KB)'
        '${before == text ? ' · 그대로' : ''}');
  }

  if (stale) exit(1);
  if (!check) {
    final heads = blocks.where(
      (b) => b.kind == PolicyKind.title || b.kind == PolicyKind.section,
    );
    stdout.writeln('덩어리 ${blocks.length}개 · 제목 ${heads.length}개');
  }
}

/// 원본. **유일한 진짜다.**
const String policySourcePath = 'docs/개인정보처리방침.md';

/// 스토어 심사자와 기관 담당자에게 줄 한 장.
///
/// **`privacy.html` 이라고 이름 붙이지 않는다.** Cloudflare Pages 는 `/privacy`
/// 요청이 오면 `privacy.html` 을 먼저 내준다. 그러면 앱의 `/privacy` 라우트가
/// 서버에서 가로채여 **새로고침한 사람만 앱 밖으로 떨어진다.** 이름을 갈라
/// 두면 그 일이 아예 안 생긴다.
const String policyHtmlPath = 'apps/beoba/web/privacy-policy.html';

/// 앱 안과 웹앱 안이 같이 읽는 자리.
const String policyJsonPath = 'apps/beoba/assets/policy/privacy.json';

/// 방침 문서에서 **우리끼리 보는 기록**이 시작하는 자리.
///
/// 검사기도 이 상수를 쓴다. 따로 두면 한쪽만 고쳐져 조용히 어긋난다.
const String policyPrivateMark = '<!-- 아래는 우리끼리 보는 기록입니다';

/// 굽는 것 전부. 자리 → 내용.
Map<String, String> bakePolicy(List<PolicyBlock> blocks) => {
      policyHtmlPath: renderPolicyHtml(blocks),
      policyJsonPath: renderPolicyJson(blocks),
    };

/// 덩어리 하나의 종류.
enum PolicyKind { title, section, strong, para, item }

/// 방침의 덩어리 하나. **속에 문법이 없다** — 글자뿐이다.
class PolicyBlock {
  const PolicyBlock(this.kind, this.text);

  final PolicyKind kind;
  final String text;
}

/// 사람이 읽는 부분만 덩어리로 자른다.
///
/// [policyPrivateMark] 아래는 우리끼리 보는 기록이라 **아예 읽지 않는다.**
/// 화면에 나가면 안 되는 글이다.
///
/// 줄바꿈으로 문단을 나누지 않는다 — 원본은 쉬운 말 검사에 맞추려고 짧게 접어
/// 놓았을 뿐이고, 읽는 사람에게는 빈 줄까지가 한 문단이다.
List<PolicyBlock> parsePolicy(String markdown) {
  final blocks = <PolicyBlock>[];
  final buffer = <String>[];

  void flush() {
    if (buffer.isEmpty) return;
    blocks.add(PolicyBlock(PolicyKind.para, buffer.join(' ')));
    buffer.clear();
  }

  final lines = markdown.split(policyPrivateMark).first.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    final where = '$policySourcePath:${i + 1}';

    if (line.isEmpty || line == '---') {
      flush();
      continue;
    }
    if (line.startsWith('# ')) {
      flush();
      blocks.add(
        PolicyBlock(PolicyKind.title, _plain(line.substring(2), where)),
      );
      continue;
    }
    if (line.startsWith('## ')) {
      flush();
      blocks.add(
        PolicyBlock(PolicyKind.section, _plain(line.substring(3), where)),
      );
      continue;
    }
    if (line.startsWith('- ')) {
      flush();
      blocks.add(PolicyBlock(PolicyKind.item, _plain(line.substring(2), where)));
      continue;
    }
    // **줄 전체가 굵으면 그 줄이 한 덩어리다.** 문단 속에 굵은 조각을 두면
    // 그리는 쪽마다 서식을 따로 짜야 하는데, 방침에서 굵은 줄은 언제나 문장
    // 하나였다. 반쪽만 굵은 줄은 [_plain] 이 막는다.
    if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
      final inner = line.substring(2, line.length - 2);
      if (!inner.contains('**')) {
        flush();
        blocks.add(PolicyBlock(PolicyKind.strong, _plain(inner, where)));
        continue;
      }
    }
    buffer.add(_plain(line, where));
  }
  flush();
  return blocks;
}

/// 남은 마크다운 문법이 없는지 보고 글자만 돌려준다.
///
/// 새 문법을 쓰고 싶으면 **여기와 그리는 쪽 둘을 같이 고친다.** 통과시켜 두면
/// 어느 화면에서는 별표가 찍히고 어느 화면에서는 안 찍힌다.
String _plain(String text, String where) {
  const banned = <String, String>{
    '**': '굵게 — 줄 전체가 굵을 때만 됩니다',
    '`': '코드',
    '[': '링크',
    '<': '태그',
    '|': '표',
    '> ': '인용',
  };
  for (final MapEntry(key: mark, value: name) in banned.entries) {
    if (!text.contains(mark)) continue;
    throw FormatException(
      '$where — 굽는 도구가 모르는 문법입니다: $name (`$mark`). '
      '문법을 늘리려면 build_privacy_page.dart 의 _plain 과 그리는 쪽 둘을 '
      '같이 고치세요.',
      text,
    );
  }
  return text;
}

/// Flutter 없이 열리는 한 장.
///
/// 바깥에서 가져오는 것이 하나도 없다 — 글꼴은 기기에 있는 것을 쓰고, 스타일은
/// 이 안에 들어 있고, 스크립트는 없다.
String renderPolicyHtml(List<PolicyBlock> blocks) {
  final title = blocks
      .firstWhere(
        (b) => b.kind == PolicyKind.title,
        orElse: () => const PolicyBlock(PolicyKind.title, '개인정보처리방침'),
      )
      .text;

  final body = StringBuffer();
  var inList = false;
  void closeList() {
    if (!inList) return;
    body.writeln('  </ul>');
    inList = false;
  }

  for (final block in blocks) {
    if (block.kind != PolicyKind.item) closeList();
    switch (block.kind) {
      case PolicyKind.title:
        body.writeln('  <h1>${_escape(block.text)}</h1>');
      case PolicyKind.section:
        body.writeln('  <h2>${_escape(block.text)}</h2>');
      case PolicyKind.strong:
        body.writeln('  <p class="strong">${_escape(block.text)}</p>');
      case PolicyKind.para:
        body.writeln('  <p>${_escape(block.text)}</p>');
      case PolicyKind.item:
        if (!inList) {
          body.writeln('  <ul>');
          inList = true;
        }
        body.writeln('    <li>${_escape(block.text)}</li>');
    }
  }
  closeList();

  return '<!doctype html>\n'
      '<html lang="ko">\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      '<title>${_escape(title)}</title>\n'
      '<!-- 생성물이다. 손으로 고치지 않는다.\n'
      '     dart run packages/engines/tool/build_privacy_page.dart\n'
      '     원본: $policySourcePath -->\n'
      '<style>\n'
      '$_css'
      '</style>\n'
      '</head>\n'
      '<body>\n'
      '<main>\n'
      '${body.toString().trimRight()}\n'
      '</main>\n'
      '</body>\n'
      '</html>\n';
}

/// 스타일. **바깥 글꼴을 부르지 않는다** — 기기에 있는 것만 쓴다.
///
/// `word-break: keep-all` 이 한글 낱말을 가운데서 자르지 않게 한다.
const String _css = '''
:root { color-scheme: light }
* { box-sizing: border-box }
body {
  margin: 0;
  padding: 28px 20px 64px;
  background: #ffffff;
  color: #1a1d21;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Malgun Gothic",
    "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
  font-size: 16px;
  line-height: 1.72;
  word-break: keep-all;
}
main { max-width: 34rem; margin: 0 auto }
h1 { margin: 0 0 22px; font-size: 23px; font-weight: 800; letter-spacing: -0.6px }
h2 {
  margin: 34px 0 10px;
  padding-top: 18px;
  border-top: 1px solid #e3e6ea;
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.3px;
  color: #1f3a5f;
}
p { margin: 0 0 12px; color: #4a5057 }
p.strong { color: #1a1d21; font-weight: 700 }
ul { margin: 0 0 12px; padding-left: 20px; color: #4a5057 }
li { margin-bottom: 4px }
''';

/// 앱과 웹앱이 같이 읽는 자리.
///
/// 앱은 마크다운을 그리지 않는다. **문법이 다 벗겨진 덩어리**를 받아
/// `SafeText` 로 한 줄씩 그린다 — 이 리포에서 문구가 지나는 길은 그 하나다.
String renderPolicyJson(List<PolicyBlock> blocks) {
  final data = <String, Object?>{
    '_': <String>[
      '생성물이다. 손으로 고치지 않는다.',
      'dart run packages/engines/tool/build_privacy_page.dart',
      '원본: $policySourcePath',
    ],
    'blocks': <Map<String, String>>[
      for (final block in blocks) {'kind': block.kind.name, 'text': block.text},
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(data)}\n';
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

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
