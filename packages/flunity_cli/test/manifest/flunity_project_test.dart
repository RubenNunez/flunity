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
target: ios
paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_builds: unity_project/Builds
bridge:
  enabled: true
  messages: []
''');

    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );

    expect(project.name, 'my_app');
    expect(project.version, '0.1.0');
    expect(project.target, FlunityTarget.ios);
    expect(project.isNative, isTrue);
    expect(project.paths.flutterApp, p.join(tmp.path, 'flutter_app'));
    expect(project.paths.unityProject, p.join(tmp.path, 'unity_project'));
    expect(
      project.paths.unityBuilds,
      p.join(tmp.path, 'unity_project', 'Builds'),
    );
    expect(
      project.buildDir,
      p.join(tmp.path, 'unity_project', 'Builds', 'ios'),
    );
    expect(project.paths.unityBuildOverride, isNull);
    expect(project.bridge.enabled, true);
  });

  test('parses target: ios', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: my_ios_app
target: ios
''');
    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );
    expect(project.target, FlunityTarget.ios);
    expect(project.isIos, isTrue);
    expect(project.isNative, isTrue);
    expect(
      project.buildDir,
      p.join(tmp.path, 'unity_project', 'Builds', 'ios'),
    );
  });

  test('parses target: android', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: my_android_app
target: android
''');
    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );
    expect(project.target, FlunityTarget.android);
    expect(project.isAndroid, isTrue);
    expect(project.isNative, isTrue);
    expect(
      project.buildDir,
      p.join(tmp.path, 'unity_project', 'Builds', 'android'),
    );
  });

  test('applies sensible defaults to a minimal manifest', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: minimal
target: android
''');

    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );

    expect(project.paths.flutterApp, p.join(tmp.path, 'flutter_app'));
    expect(project.paths.unityProject, p.join(tmp.path, 'unity_project'));
    expect(
      project.paths.unityBuilds,
      p.join(tmp.path, 'unity_project', 'Builds'),
    );
    expect(
      project.buildDir,
      p.join(tmp.path, 'unity_project', 'Builds', 'android'),
    );
    expect(project.bridge.enabled, true);
  });

  test(
    'legacy unity_build override survives — overrides per-target derivation',
    () {
      File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: legacy
target: ios
paths:
  unity_build: unity_project/Builds/Export
''');
      final project = FlunityProject.loadFromManifest(
        p.join(tmp.path, 'flunity.yaml'),
      );
      expect(
        project.paths.unityBuildOverride,
        p.join(tmp.path, 'unity_project', 'Builds', 'Export'),
      );
      // buildDir returns the override, not the per-target derivation.
      expect(
        project.buildDir,
        p.join(tmp.path, 'unity_project', 'Builds', 'Export'),
      );
    },
  );

  test('rejects unknown target with a friendly error', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: oops
target: windows
''');
    expect(
      () => FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml')),
      throwsA(
        isA<ManifestException>().having(
          (e) => e.message,
          'message',
          allOf(contains('windows'), contains('ios, android')),
        ),
      ),
    );
  });

  test('rejects pre-Plan F target name native_android', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: oops
target: native_android
''');
    expect(
      () => FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml')),
      throwsA(isA<ManifestException>()),
    );
  });

  test('rejects manifest with missing name', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('target: ios');
    expect(
      () => FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml')),
      throwsA(isA<ManifestException>()),
    );
  });
}
