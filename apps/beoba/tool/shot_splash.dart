// 기다리는 화면이 릴리스에서 실제로 보이는가. 켜고, 찍고, 잰다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const chrome = r'C:\Program Files\Google\Chrome\Application\chrome.exe';

late WebSocket ws;
var _id = 0;
final _waiting = <int, Completer<Map<String, dynamic>>>{};

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

Future<void> shot(String path) async {
  final r = await send('Page.captureScreenshot', {'format': 'png'});
  final data = (r['result'] as Map)['data'] as String;
  File(path).writeAsBytesSync(base64Decode(data));
}

Future<void> main(List<String> args) async {
  final url = args[0];
  final profile = args[1];
  final outDir = args[2];
  final scheme = args[3]; // light | dark
  final throttle = args.length > 4 ? args[4] : null;

  final proc = await Process.start(chrome, [
    '--remote-debugging-port=9334',
    '--user-data-dir=$profile',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
    '--window-size=400,860',
    'about:blank',
  ]);

  String? wsUrl;
  final client = HttpClient();
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      final req =
          await client.getUrl(Uri.parse('http://127.0.0.1:9334/json/list'));
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
    if (m['id'] is int) _waiting.remove(m['id'])?.complete(m);
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  await send('Emulation.setEmulatedMedia', {
    'features': [
      {'name': 'prefers-color-scheme', 'value': scheme},
      {
        'name': 'prefers-reduced-motion',
        'value': Platform.environment['MOTION'] ?? 'no-preference',
      },
    ],
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
      window.__mark = {};
      window.__op = {};
      addEventListener('flutter-first-frame', function () {
        if (window.__mark.frame == null) window.__mark.frame = performance.now();
      });
      [60, 120, 180, 240, 300, 420, 600].forEach(function (t) {
        setTimeout(function () {
          var el = document.getElementById('beoba-splash');
          window.__op[t] = el
              ? getComputedStyle(el).opacity + '@' + Math.round(performance.now())
              : 'gone';
        }, t);
      });
    ''',
  });

  await send('Page.navigate', {'url': url});
  final sw = Stopwatch()..start();

  final stops = <int, String>{
    150: '0.15초',
    1200: '1.2초',
    9000: '9초',
    21000: '21초', // not-a-legal-number: 찍는 시각(밀리초). 법률 수치가 아니다.
    41000: '41초', // not-a-legal-number: 찍는 시각(밀리초). 법률 수치가 아니다.
  };
  for (final entry in stops.entries) {
    while (sw.elapsedMilliseconds < entry.key) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    final gone = await eval("!document.getElementById('beoba-splash')");
    final note =
        await eval("(document.getElementById('beoba-splash-note')||{}).textContent");
    await shot('$outDir/$scheme-${entry.key}.png');
    stdout.writeln('SHOT|$scheme|${entry.value}|기다리는 화면 '
        '${gone == true ? "없음" : "있음"}|늘어난 줄: ${note ?? "-"}');
    if (gone == true && entry.key >= 1200) break;
  }

  final reduced =
      await eval("matchMedia('(prefers-reduced-motion: reduce)').matches");
  stdout.writeln('REDUCED|$reduced');
  stdout.writeln('OPACITY|${jsonEncode(await eval('window.__op'))}');
  final frame = await eval('window.__mark.frame');
  stdout.writeln('FRAME|$scheme|$frame');
  await ws.close();
  proc.kill();
  exit(0);
}
