import 'dart:io';

import 'package:flunity_cli/src/bridge/bridge_init.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String templateRoot;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_bridge_init_');
    File(p.join(tmp.path, 'flunity.yaml'))
        .writeAsStringSync('name: x\ntarget: webgl');
    Directory(p.join(tmp.path, 'flutter_app')).createSync();
    File(p.join(tmp.path, 'flutter_app', 'pubspec.yaml')).writeAsStringSync(
      'name: x\n\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );

    // Build a minimal fake template tree under tmp/templates/.
    templateRoot = p.join(tmp.path, 'templates');
    final libUnity = Directory(
      p.join(
          templateRoot, 'flutter_webgl_bridge', 'flutter_app', 'lib', 'unity'),
    )..createSync(recursive: true);
    File(p.join(libUnity.path, 'unity_webgl_screen.dart'))
        .writeAsStringSync('// screen');
    File(p.join(libUnity.path, 'unity_webgl_config.dart'))
        .writeAsStringSync('// config');

    final scripts = Directory(p.join(
      templateRoot,
      'unity_bridge_basic',
      'unity_project',
      'Assets',
      'Scripts',
    ))
      ..createSync(recursive: true);
    File(p.join(scripts.path, 'FlunityBridge.cs')).writeAsStringSync('// cs');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('adds dep, copies template files, leaves missing index.html alone',
      () async {
    final project =
        FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(summary.depAdded, isTrue);
    expect(summary.filesCreated, isNotEmpty);
    expect(summary.indexHtmlPatched, isFalse);
    expect(
      File(p.join(tmp.path, 'flutter_app/lib/unity/unity_webgl_screen.dart'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(tmp.path, 'unity_project/Assets/Scripts/FlunityBridge.cs'))
          .existsSync(),
      isTrue,
    );
  });

  test('idempotent without --force', () async {
    final project =
        FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final first = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(first.filesCreated, isNotEmpty);
    final second = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(second.filesCreated, isEmpty);
    expect(second.depAdded, isFalse);
  });

  test('patches index.html if present', () async {
    Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
        .createSync(recursive: true);
    File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
        .writeAsStringSync('<html><body></body></html>');
    final project =
        FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(summary.indexHtmlPatched, isTrue);
    final patched =
        File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
            .readAsStringSync();
    expect(patched, contains('flunity:patch'));
  });
}
