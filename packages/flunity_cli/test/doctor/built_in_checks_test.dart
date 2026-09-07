import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/checks/manifest_present_check.dart';
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
    ).writeAsStringSync('name: x\ntarget: ios');
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
    ).writeAsStringSync('name: x\ntarget: ios');
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

  test('unity_build check warns without an export', () async {
    File(
      p.join(tmp.path, 'flunity.yaml'),
    ).writeAsStringSync('name: x\ntarget: ios');
    final project = FlunityProject.loadFromManifest(
      p.join(tmp.path, 'flunity.yaml'),
    );
    expect(
      (await UnityBuildCheck(project: project).run()).severity,
      CheckSeverity.warn,
    );
  });
}
