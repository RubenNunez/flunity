import 'dart:io';

import 'package:flunity_cli/src/webgl/dev_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('stub WebGL build serves with correct headers + shim is fetchable',
      () async {
    final stubRoot = p.join(
      Directory.current.path,
      'test',
      'e2e',
      'stub_webgl',
    );
    final server = await UnityDevServer.start(rootDir: stubRoot, port: 0);
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    Future<HttpClientResponse> get(String path) async {
      final req = await client
          .getUrl(Uri.parse('http://${server.host}:${server.port}$path'));
      return req.close();
    }

    final indexResp = await get('/index.html');
    expect(indexResp.statusCode, 200);
    expect(
        indexResp.headers.value('cross-origin-opener-policy'), 'same-origin');
    expect(indexResp.headers.value('cross-origin-embedder-policy'),
        'require-corp');

    final shimResp = await get('/flunity_bridge.js');
    expect(shimResp.statusCode, 200);
    expect(shimResp.headers.contentType?.mimeType, 'application/javascript');

    final stubResp = await get('/stub_unity_instance.js');
    expect(stubResp.statusCode, 200);
  });
}
