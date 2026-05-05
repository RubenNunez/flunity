import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/checks/flutter_assets_declared_check.dart';
import 'package:flunity_cli/src/doctor/checks/manifest_present_check.dart';
import 'package:flunity_cli/src/doctor/checks/port_available_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_build_check.dart';
import 'package:flunity_cli/src/doctor/checks/unity_project_check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_doctor_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('manifest present check finds flunity.yaml', () async {
    File(
      p.join(tmp.path, 'flunity.yaml'),
    ).writeAsStringSync('name: x\ntarget: webgl');
    final r = await ManifestPresentCheck(cwd: tmp.path).run();
    expect(r.severity, CheckSeverity.ok);
  });

  test('manifest present check fails when missing', () async {
    final r = await ManifestPresentCheck(cwd: tmp.path).run();
    expect(r.severity, CheckSeverity.fail);
  });

  test('unity_project check', () async {
    File(
      p.join(tmp.path, 'flunity.yaml'),
    ).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );
    expect(
      (await UnityProjectCheck(project: project).run()).severity,
      CheckSeverity.fail,
    );
    Directory(p.join(tmp.path, 'unity_project')).createSync();
    expect(
      (await UnityProjectCheck(project: project).run()).severity,
      CheckSeverity.ok,
    );
  });

  test('unity_build check warns without index.html', () async {
    File(
      p.join(tmp.path, 'flunity.yaml'),
    ).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );
    expect(
      (await UnityBuildCheck(project: project).run()).severity,
      CheckSeverity.warn,
    );
    Directory(
      p.join(tmp.path, 'unity_project/Builds/webgl'),
    ).createSync(recursive: true);
    File(
      p.join(tmp.path, 'unity_project/Builds/webgl/index.html'),
    ).writeAsStringSync('<html/>');
    expect(
      (await UnityBuildCheck(project: project).run()).severity,
      CheckSeverity.ok,
    );
  });

  test('flutter_assets_declared check', () async {
    File(
      p.join(tmp.path, 'flunity.yaml'),
    ).writeAsStringSync('name: x\ntarget: webgl');
    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );
    Directory(p.join(tmp.path, 'flutter_app')).createSync();
    final pubspec = File(p.join(tmp.path, 'flutter_app/pubspec.yaml'));
    pubspec.writeAsStringSync(
      'name: a\nflutter:\n  uses-material-design: true\n',
    );
    expect(
      (await FlutterAssetsDeclaredCheck(project: project).run()).severity,
      CheckSeverity.warn,
    );
    pubspec.writeAsStringSync(
      'name: a\nflutter:\n  assets:\n    - assets/unity_webgl/\n',
    );
    expect(
      (await FlutterAssetsDeclaredCheck(project: project).run()).severity,
      CheckSeverity.ok,
    );
  });

  test('port_available check', () async {
    final r = await PortAvailableCheck(host: '127.0.0.1', port: 0).run();
    expect(r.severity, CheckSeverity.ok); // port 0 always free
  });
}
