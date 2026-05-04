import 'dart:io';

import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/webgl/webgl_copy.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_copy_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('copies build dir to flutter_assets and writes manifest hash', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final buildDir = Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
      ..createSync(recursive: true);
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync('<html/>');
    File(p.join(buildDir.path, 'app.wasm')).writeAsBytesSync(<int>[1, 2, 3]);

    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await copyWebGLBuild(project: project);

    expect(summary.fileCount, 2);
    expect(summary.totalBytes, greaterThan(0));
    expect(File(p.join(project.paths.flutterAssets, 'index.html')).existsSync(), isTrue);
    expect(File(p.join(project.paths.flutterAssets, 'app.wasm')).existsSync(), isTrue);
    expect(File(p.join(project.paths.flutterAssets, 'flunity_webgl_manifest.json')).existsSync(), isTrue);
    expect(summary.buildHash.length, 64);
  });

  test('clean=true removes prior contents (except .gitkeep)', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final buildDir = Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
      ..createSync(recursive: true);
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync('<html/>');

    final dest = Directory(p.join(tmp.path, 'flutter_app/assets/unity_webgl'))
      ..createSync(recursive: true);
    File(p.join(dest.path, 'old.txt')).writeAsStringSync('old');
    File(p.join(dest.path, '.gitkeep')).writeAsStringSync('');

    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    await copyWebGLBuild(project: project, clean: true);

    expect(File(p.join(dest.path, 'old.txt')).existsSync(), isFalse);
    expect(File(p.join(dest.path, '.gitkeep')).existsSync(), isTrue);
    expect(File(p.join(dest.path, 'index.html')).existsSync(), isTrue);
  });

  test('throws when build dir is missing', () async {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    expect(
      () => copyWebGLBuild(project: project),
      throwsA(isA<WebGLCopyException>()),
    );
  });
}
