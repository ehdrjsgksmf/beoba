"""압축을 켜는 정적 서버. 실제 배포와 같은 조건으로 재려고 만들었다.

py -m http.server 는 압축을 안 한다. Flutter Web 의 main.dart.js 와
canvaskit.wasm 은 압축으로 3~4배 줄어들고, 실제 배포에서는 켜져 있다.
압축 없이 잰 값은 아무도 겪지 않는 값이다.

**미리 압축해 둔다.** 요청 때 brotli 11 을 돌리면 7MB wasm 에 몇 초가
걸려서 그 시간이 「첫 화면까지」에 섞인다. 실제 배포는 미리 압축해 두므로
그쪽이 맞다.

사용: py serve_web.py <root> <port> [--no-gzip] [--brotli] [--lan]

--lan 은 **같은 와이파이의 다른 기기(폰)에서 열 수 있게** 0.0.0.0 에 묶는다.
기본은 127.0.0.1 이다 — 재려고 띄우는 서버를 실수로 남에게 열지 않는다.

★ --lan 으로 연 주소는 https 가 아니다. 브라우저가 **안전한 자리로 안 쳐서**
`navigator.clipboard` 가 아예 없고, 그래서 복사 버튼이 **반드시 되돌림으로
떨어진다**(CopyBlock 참고). 그건 고장이 아니라 그 자리의 규칙이다.
진짜 복사를 폰에서 보려면 apk 를 깔아서 본다.
"""
import functools
import gzip
import io
import mimetypes
import os
import socket
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('font/ttf', '.ttf')
mimetypes.add_type('application/json', '.json')

# 압축해도 안 줄어드는 것들. 이미 압축된 형식이다.
SKIP = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.woff', '.woff2', '.br', '.gz'}

MODE = 'gzip'          # 'none' | 'gzip' | 'brotli'
CACHE = {}             # 절대경로 -> (인코딩, 바이트)


def precompress(root):
    import brotli
    total_raw = 0
    total_out = 0
    for base, _dirs, names in os.walk(root):
        for name in names:
            path = os.path.join(base, name)
            if os.path.splitext(name)[1].lower() in SKIP:
                continue
            raw = open(path, 'rb').read()
            if MODE == 'brotli':
                body = brotli.compress(raw, quality=11)
                encoding = 'br'
            else:
                body = gzip.compress(raw, 6)
                encoding = 'gzip'
            CACHE[os.path.normcase(path)] = (encoding, body)
            total_raw += len(raw)
            total_out += len(body)
    print(f'미리 압축 {MODE}: {total_raw:,} -> {total_out:,}', flush=True)


class H(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        SimpleHTTPRequestHandler.end_headers(self)

    def log_message(self, *a):
        pass

    def send_head(self):
        if MODE == 'none':
            return SimpleHTTPRequestHandler.send_head(self)

        path = self.translate_path(self.path)
        if not os.path.isfile(path):
            return SimpleHTTPRequestHandler.send_head(self)

        hit = CACHE.get(os.path.normcase(path))
        if hit is None:
            return SimpleHTTPRequestHandler.send_head(self)

        encoding, body = hit
        accepts = self.headers.get('Accept-Encoding', '')
        if encoding not in accepts:
            return SimpleHTTPRequestHandler.send_head(self)

        # **캐시 머리글이 없으면 재방문이 재방문이 아니다.** 안 붙이면
        # 두 번째 열 때도 2.4MB 를 다시 받는다 — 그건 첫 방문 값이다.
        etag = '"%x-%x"' % (int(os.path.getmtime(path)), len(body))
        if self.headers.get('If-None-Match') == etag:
            self.send_response(304)
            self.send_header('ETag', etag)
            self.end_headers()
            return None

        self.send_response(200)
        self.send_header('Content-Type', self.guess_type(path))
        self.send_header('Content-Encoding', encoding)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Vary', 'Accept-Encoding')
        self.send_header('ETag', etag)
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        return io.BytesIO(body)


if __name__ == '__main__':
    root = sys.argv[1]
    port = int(sys.argv[2])
    if '--no-gzip' in sys.argv:
        MODE = 'none'
    elif '--brotli' in sys.argv:
        MODE = 'brotli'
    if MODE != 'none':
        precompress(root)
    host = '0.0.0.0' if '--lan' in sys.argv else '127.0.0.1'
    print(f'{port} 열림 ({MODE}) at {host}', flush=True)
    if host == '0.0.0.0':
        # 어느 주소로 들어와야 하는지 사람이 알아야 한다.
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            probe.connect(('8.8.8.8', 80))
            print(f'폰에서: http://{probe.getsockname()[0]}:{port}', flush=True)
        finally:
            probe.close()
        print('★ https 가 아니라 복사 버튼은 되돌림으로 떨어집니다.', flush=True)
    ThreadingHTTPServer(
        (host, port), functools.partial(H, directory=root)
    ).serve_forever()
