import 'dart:io';

import 'package:flunity_cli/src/webgl/prepare_webgl.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_prepare_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('copies shim and patches index.html on first run', () async {
    final shim = File(p.join(tmp.path, 'flunity_bridge.js'))
      ..writeAsStringSync('// shim');
    final buildDir = Directory(p.join(tmp.path, 'WebGL'))..createSync();
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync(
      '<html><head></head><body><script>'
      'createUnityInstance(canvas, config).then((unityInstance) => { x(); });'
      '</script></body></html>',
    );

    final result = await prepareWebGLBuild(
      buildDir: buildDir.path,
      shimSourcePath: shim.path,
    );

    expect(result.shimCopied, isTrue);
    expect(result.indexHtmlPatched, isTrue);
    expect(File(p.join(buildDir.path, 'flunity_bridge.js')).existsSync(), isTrue);
    final patched =
        File(p.join(buildDir.path, 'index.html')).readAsStringSync();
    expect(patched, contains('flunity:patch v1'));
    expect(patched, contains('flunity_bridge.js'));
    expect(patched, contains('window.flunity.ready(unityInstance)'));
  });

  test('idempotent on second run', () async {
    final shim = File(p.join(tmp.path, 'flunity_bridge.js'))
      ..writeAsStringSync('// shim');
    final buildDir = Directory(p.join(tmp.path, 'WebGL'))..createSync();
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync(
      '<html><head></head><body><script>'
      'createUnityInstance(canvas, config).then((unityInstance) => { x(); });'
      '</script></body></html>',
    );

    await prepareWebGLBuild(
        buildDir: buildDir.path, shimSourcePath: shim.path);
    final r2 = await prepareWebGLBuild(
        buildDir: buildDir.path, shimSourcePath: shim.path);
    expect(r2.shimCopied, isFalse);
    expect(r2.indexHtmlPatched, isFalse);
  });
}
