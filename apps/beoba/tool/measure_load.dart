// 첫 화면까지 몇 초, 몇 바이트가 오갔나. 압축 전후를 같은 조건으로 잰다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const chrome = r'C:\Program Files\Google\Chrome\Application\chrome.exe';

late WebSocket ws;
var _id = 0;
final _waiting = <int, Completer<Map<String, dynamic>>>{};

var totalBytes = 0;
final encodings = <String, String>{};
final sizes = <String, int>{};
final _urlOf = <String, String>{};

Future<Map<String, dynamic>> send(String method, [Map<String, dynamic>? p]) {
  final id = ++_id;
  final c = Completer<Map<String, dynamic>>();
  _waiting[id] = c;
  ws.add(jsonEncode({'id': id, 'method': method, 'params': p ?? {}}));
  return c.future;
}

Future<Object?> eval(String expr) async {
  final r = await send('Runtime.evaluate',
      {'expression': expr, 'returnByValue': true, 'awaitPromise': true});
  return ((r['result'] as Map)['result'] as Map)['value'];
}

Future<void> main(List<String> args) async {
  final url = args[0];
  final profile = args[1];
  final label = args[2];
  final throttle = args.length > 3 ? args[3] : null;
  final waitMs = args.length > 4 ? int.parse(args[4]) : 120000; // not-a-legal-number: 기다리는 밀리초. 법률 수치가 아니다.

  final proc = await Process.start(chrome, [
    '--remote-debugging-port=9335',
    '--user-data-dir=$profile',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
    '--headless=new',
    '--window-size=400,860',
    'about:blank',
  ]);

  String? wsUrl;
  final client = HttpClient();
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      final req =
          await client.getUrl(Uri.parse('http://127.0.0.1:9335/json/list'));
      final res = await req.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as List;
      for (final t in body.cast<Map<String, dynamic>>()) {
        if (t['type'] == 'page') wsUrl = t['webSocketDebuggerUrl'] as String;
      }
      if (wsUrl != null) break;
    } on Object {
      // 아직
    }
  }
  if (wsUrl == null) {
    stderr.writeln('크롬을 못 잡았습니다');
    proc.kill();
    exit(1);
  }

  ws = await WebSocket.connect(wsUrl);
  ws.listen((d) {
    final m = jsonDecode(d as String) as Map<String, dynamic>;
    if (m['id'] is int) {
      _waiting.remove(m['id'])?.complete(m);
      return;
    }
    final params = m['params'] as Map<String, dynamic>?;
    if (params == null) return;

    if (m['method'] == 'Network.responseReceived') {
      final response = params['response'] as Map<String, dynamic>;
      final requestUrl = response['url'] as String;
      _urlOf[params['requestId'] as String] = requestUrl;
      final headers = (response['headers'] as Map).map(
        (k, v) => MapEntry(k.toString().toLowerCase(), v.toString()),
      );
      encodings[requestUrl] = headers['content-encoding'] ?? '(없음)';
    }
    if (m['method'] == 'Network.loadingFinished') {
      final n = (params['encodedDataLength'] as num).toInt();
      totalBytes += n;
      final requestUrl = _urlOf[params['requestId'] as String] ?? '?';
      sizes[requestUrl] = (sizes[requestUrl] ?? 0) + n;
    }
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  // 두 번째 방문을 재려면 캐시를 남긴다. CACHE=keep.
  await send('Network.setCacheDisabled', {
    'cacheDisabled': Platform.environment['CACHE'] != 'keep',
  });
  if (throttle != null) {
    final parts = throttle.split(',');
    await send('Network.emulateNetworkConditions', {
      'offline': false,
      'latency': double.parse(parts[0]),
      'downloadThroughput': double.parse(parts[1]),
      'uploadThroughput': double.parse(parts[1]) / 2,
    });
  }
  await send('Page.addScriptToEvaluateOnNewDocument', {
    'source': '''
      window.__frame = null;
      addEventListener('flutter-first-frame', function () {
        if (window.__frame == null) window.__frame = performance.now();
      });
    ''',
  });

  // TWICE=1 이면 한 번 열고 나서 **같은 창에서 다시 연다.** 두 번째 값이
  // 캐시가 더운 상태다. 크롬을 죽였다 켜면 캐시가 디스크에 안 남아 첫
  // 방문과 같은 값이 나온다 — 그건 재방문이 아니다.
  if (Platform.environment['TWICE'] == '1') {
    await send('Page.navigate', {'url': url});
    for (var i = 0; i < 800; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await eval('window.__frame') != null) break;
    }
    totalBytes = 0;
    sizes.clear();
  }

  await send('Page.navigate', {'url': url});
  final sw = Stopwatch()..start();

  Object? frame;
  while (sw.elapsedMilliseconds < waitMs) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    frame = await eval('window.__frame');
    if (frame != null) break;
  }

  stdout.writeln('LABEL|$label');
  stdout.writeln('FIRSTFRAME|${frame == null ? "안 뜸" : "${(frame as num).round()}ms"}');
  stdout.writeln('BYTES|$totalBytes');

  final big = sizes.entries.toList()
    ..sort((a, b) => b.value - a.value);
  for (final e in big.take(6)) {
    final name = e.key.split('/').last;
    stdout.writeln('FILE|$name|${e.value}|${encodings[e.key] ?? "?"}');
  }

  proc.kill();
  exit(0);
}
