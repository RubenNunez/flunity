import 'dart:io';

import 'package:flunity_cli/src/webgl/dev_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flunity_serve_');
    File(p.join(root.path, 'index.html'))
        .writeAsStringSync('<!doctype html><title>x</title>');
    File(p.join(root.path, 'app.wasm')).writeAsBytesSync(<int>[0, 1, 2]);
    File(p.join(root.path, 'app.wasm.br'))
        .writeAsBytesSync(List<int>.filled(8, 0xff));
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('serves index.html with COOP/COEP headers and HTML mime', () async {
    final server = await UnityDevServer.start(rootDir: root.path, port: 0);
    addTearDown(server.stop);
    final r = await _get('http://${server.host}:${server.port}/index.html');
    expect(r.statusCode, 200);
    expect(r.headers.value('cross-origin-opener-policy'), 'same-origin');
    expect(r.headers.value('cross-origin-embedder-policy'), 'require-corp');
    expect(r.headers.contentType?.mimeType, 'text/html');
  });

  test('serves .wasm with application/wasm', () async {
    final server = await UnityDevServer.start(rootDir: root.path, port: 0);
    addTearDown(server.stop);
    final r = await _get('http://${server.host}:${server.port}/app.wasm');
    expect(r.statusCode, 200);
    expect(r.headers.contentType.toString(), 'application/wasm');
  });

  test('precompressed .wasm.br served at /app.wasm with Content-Encoding: br',
      () async {
    final server = await UnityDevServer.start(rootDir: root.path, port: 0);
    addTearDown(server.stop);
    final r = await _get('http://${server.host}:${server.port}/app.wasm',
        acceptEncoding: 'br, gzip');
    expect(r.statusCode, 200);
    expect(r.headers.value('content-encoding'), 'br');
    expect(r.headers.contentType?.mimeType, 'application/wasm');
  });
}

Future<HttpClientResponse> _get(String url, {String? acceptEncoding}) async {
  final client = HttpClient();
  client.autoUncompress = false;
  final req = await client.getUrl(Uri.parse(url));
  if (acceptEncoding != null) {
    req.headers.set(HttpHeaders.acceptEncodingHeader, acceptEncoding);
  }
  return req.close();
}
