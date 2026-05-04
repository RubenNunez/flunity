import 'dart:io';

import 'package:flunity_cli/src/bridge/bridge_init.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_bridge_init_');
    File(p.join(tmp.path, 'flunity.yaml'))
        .writeAsStringSync('name: x\ntarget: webgl');
    Directory(p.join(tmp.path, 'flutter_app')).createSync();
    File(p.join(tmp.path, 'flutter_app', 'pubspec.yaml')).writeAsStringSync(
      'name: x\n\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('adds dep, creates files, leaves missing index.html alone', () async {
    final project =
        FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await initBridge(project: project, bridgeVersion: '0.1.0');
    expect(summary.depAdded, isTrue);
    expect(summary.filesCreated, isNotEmpty);
    expect(summary.indexHtmlPatched, isFalse);
    final pubspec =
        File(p.join(tmp.path, 'flutter_app/pubspec.yaml')).readAsStringSync();
    expect(pubspec, contains('flunity_bridge: ^0.1.0'));
  });

  test('idempotent without --force', () async {
    final project =
        FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final first = await initBridge(project: project, bridgeVersion: '0.1.0');
    expect(first.filesCreated, isNotEmpty);
    final second = await initBridge(project: project, bridgeVersion: '0.1.0');
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
    final summary = await initBridge(project: project, bridgeVersion: '0.1.0');
    expect(summary.indexHtmlPatched, isTrue);
    final patched =
        File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
            .readAsStringSync();
    expect(patched, contains('flunity:patch'));
  });
}
