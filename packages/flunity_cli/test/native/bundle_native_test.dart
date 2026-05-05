import 'dart:io';

import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/native/bundle_native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late FlunityProject project;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_bundle_');
    final flutterApp = Directory(p.join(tmp.path, 'flutter_app'))..createSync();
    Directory(p.join(flutterApp.path, 'ios')).createSync();
    Directory(p.join(flutterApp.path, 'android')).createSync();
    Directory(p.join(flutterApp.path, 'android', 'app')).createSync();
    File(
      p.join(flutterApp.path, 'android', 'settings.gradle'),
    ).writeAsStringSync('include ":app"\n');
    File(
      p.join(flutterApp.path, 'android', 'app', 'build.gradle'),
    ).writeAsStringSync('android {}\ndependencies {\n}\n');

    final unityProject = Directory(p.join(tmp.path, 'unity_project'))
      ..createSync();
    Directory(p.join(unityProject.path, 'Builds')).createSync();

    project = FlunityProject(
      rootDir: tmp.path,
      name: 'demo',
      version: '0.1.0',
      target: FlunityTarget.android,
      paths: FlunityPaths(
        flutterApp: flutterApp.path,
        unityProject: unityProject.path,
        unityBuilds: p.join(unityProject.path, 'Builds'),
        flutterAssets: p.join(flutterApp.path, 'assets', 'unity_webgl'),
      ),
      webgl: FlunityWebGLSettings(
        devServer: FlunityDevServerSettings(
          host: '127.0.0.1',
          port: 8080,
          crossOriginIsolation: true,
          hotReload: false,
        ),
        androidEmulatorHost: '10.0.2.2',
      ),
      bridge: FlunityBridgeSettings(enabled: true, messages: const []),
    );
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('bundleAndroid copies build dir + patches gradle files', () async {
    final buildDir = Directory(project.buildDir)..createSync(recursive: true);
    File(
      p.join(buildDir.path, 'build.gradle'),
    ).writeAsStringSync('// unityLibrary build.gradle');
    Directory(p.join(buildDir.path, 'src', 'main')).createSync(recursive: true);
    File(
      p.join(buildDir.path, 'src', 'main', 'AndroidManifest.xml'),
    ).writeAsStringSync('<manifest/>');

    final summary = await bundleAndroid(project: project);

    expect(summary.target, FlunityTarget.android);
    expect(summary.fileCount, 2);
    expect(summary.gradleAlreadyWired, isTrue);

    final settings = File(
      p.join(project.paths.flutterApp, 'android', 'settings.gradle'),
    ).readAsStringSync();
    expect(settings, contains(':unityLibrary'));

    final appBuild = File(
      p.join(project.paths.flutterApp, 'android', 'app', 'build.gradle'),
    ).readAsStringSync();
    expect(appBuild, contains('implementation project(":unityLibrary")'));

    final dest = File(
      p.join(
        project.paths.flutterApp,
        'android',
        'unityLibrary',
        'build.gradle',
      ),
    );
    expect(dest.existsSync(), isTrue);
  });

  test('bundleAndroid throws when build dir is missing', () async {
    expect(
      () => bundleAndroid(project: project),
      throwsA(isA<BundleException>()),
    );
  });

  test('bundleAndroid is idempotent on settings.gradle', () async {
    final buildDir = Directory(project.buildDir)..createSync(recursive: true);
    File(p.join(buildDir.path, 'build.gradle')).writeAsStringSync('');

    await bundleAndroid(project: project);
    await bundleAndroid(project: project);

    final settings = File(
      p.join(project.paths.flutterApp, 'android', 'settings.gradle'),
    ).readAsStringSync();
    final occurrences = ':unityLibrary'.allMatches(settings).length;
    expect(occurrences, greaterThanOrEqualTo(1));
    // The second include block should not be re-added.
    final includes =
        'include ":unityLibrary"'.allMatches(settings).length +
        "include ':unityLibrary'".allMatches(settings).length;
    expect(includes, lessThanOrEqualTo(1));
  });
}
