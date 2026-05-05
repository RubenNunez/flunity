import 'dart:async';
import 'dart:io';

import 'package:http_multi_server/http_multi_server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'unity_mime.dart';

class UnityDevServer {
  UnityDevServer._(this._server, this.rootDir);
  final HttpServer _server;
  final String rootDir;

  String get host => '127.0.0.1';
  int get port => _server.port;

  static Future<UnityDevServer> start({
    required String rootDir,
    int port = 8080,
  }) async {
    final handler = const shelf.Pipeline()
        .addMiddleware(_unityHeadersMiddleware)
        .addHandler(_buildHandler(rootDir));
    final server = await HttpMultiServer.loopback(port);
    shelf_io.serveRequests(server, handler);
    return UnityDevServer._(server, rootDir);
  }

  Future<void> stop() => _server.close(force: true);
}

shelf.Handler _buildHandler(String rootDir) {
  final root = Directory(rootDir).absolute.path;
  return (shelf.Request request) async {
    final urlPath = Uri.decodeComponent(request.url.path);
    final cleanPath = urlPath.isEmpty ? 'index.html' : urlPath;
    final filePath = p.normalize(p.join(root, cleanPath));
    if (!p.isWithin(root, filePath) && filePath != root) {
      return shelf.Response.forbidden('Path escapes root');
    }

    final accept = request.headers[HttpHeaders.acceptEncodingHeader] ?? '';
    final precompressed = await _resolvePrecompressed(filePath, accept);
    final servedFile = precompressed?.file ?? File(filePath);
    if (!servedFile.existsSync()) {
      return shelf.Response.notFound('Not found: $cleanPath');
    }

    final headers = <String, String>{};
    final mime = unityMimeType(p.basename(filePath));
    if (mime != null) headers[HttpHeaders.contentTypeHeader] = mime;
    if (precompressed != null) {
      headers[HttpHeaders.contentEncodingHeader] = precompressed.encoding;
      headers[HttpHeaders.varyHeader] = 'Accept-Encoding';
    } else {
      // The URL itself ends in .br or .gz (Unity's compressed builds reference
      // files by their compressed name directly). Set Content-Encoding so the
      // browser decompresses on the fly instead of treating the bytes as opaque.
      final encoding = unityContentEncoding(p.basename(filePath));
      if (encoding != null) {
        headers[HttpHeaders.contentEncodingHeader] = encoding;
        headers[HttpHeaders.varyHeader] = 'Accept-Encoding';
      }
    }
    headers[HttpHeaders.cacheControlHeader] = 'no-store';

    final length = await servedFile.length();
    headers[HttpHeaders.contentLengthHeader] = '$length';

    return shelf.Response.ok(servedFile.openRead(), headers: headers);
  };
}

class _Precompressed {
  _Precompressed(this.file, this.encoding);
  final File file;
  final String encoding;
}

Future<_Precompressed?> _resolvePrecompressed(
    String filePath, String acceptEncoding) async {
  if (acceptEncoding.contains('br')) {
    final candidate = File('$filePath.br');
    if (candidate.existsSync()) return _Precompressed(candidate, 'br');
  }
  if (acceptEncoding.contains('gzip')) {
    final candidate = File('$filePath.gz');
    if (candidate.existsSync()) return _Precompressed(candidate, 'gzip');
  }
  return null;
}

shelf.Handler _unityHeadersMiddleware(shelf.Handler inner) {
  return (shelf.Request request) async {
    final response = await inner(request);
    return response.change(headers: <String, String>{
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
  };
}
