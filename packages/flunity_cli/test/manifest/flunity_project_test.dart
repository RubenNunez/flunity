import 'dart:io';

import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('parses a complete manifest', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: my_app
version: 0.1.0
target: webgl
paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_build: unity_project/Builds/WebGL
  flutter_assets: flutter_app/assets/unity_webgl
webgl:
  dev_server:
    host: 127.0.0.1
    port: 8080
    cross_origin_isolation: true
    hot_reload: false
  android_emulator_host: 10.0.2.2
bridge:
  enabled: true
  messages: []
''');

    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );

    expect(project.name, 'my_app');
    expect(project.version, '0.1.0');
    expect(project.target, FlunityTarget.webgl);
    expect(project.paths.flutterApp, p.join(tmp.path, 'flutter_app'));
    expect(project.paths.unityProject, p.join(tmp.path, 'unity_project'));
    expect(
      project.paths.unityBuild,
      p.join(tmp.path, 'unity_project/Builds/WebGL'),
    );
    expect(
      project.paths.flutterAssets,
      p.join(tmp.path, 'flutter_app/assets/unity_webgl'),
    );
    expect(project.webgl.devServer.host, '127.0.0.1');
    expect(project.webgl.devServer.port, 8080);
    expect(project.webgl.devServer.crossOriginIsolation, true);
    expect(project.webgl.devServer.hotReload, false);
    expect(project.webgl.androidEmulatorHost, '10.0.2.2');
    expect(project.bridge.enabled, true);
  });

  test('applies sensible defaults to a minimal manifest', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: minimal
target: webgl
''');

    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );

    expect(project.paths.flutterApp, p.join(tmp.path, 'flutter_app'));
    expect(project.paths.unityProject, p.join(tmp.path, 'unity_project'));
    expect(project.webgl.devServer.host, '127.0.0.1');
    expect(project.webgl.devServer.port, 8080);
    expect(project.bridge.enabled, true);
  });

  test('rejects unknown target with a friendly error', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: oops
target: native_android
''');
    expect(
      () => FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml')),
      throwsA(
        isA<ManifestException>().having(
          (e) => e.message,
          'message',
          contains('native_android'),
        ),
      ),
    );
  });

  test('rejects manifest with missing name', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('target: webgl');
    expect(
      () => FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml')),
      throwsA(isA<ManifestException>()),
    );
  });
}
