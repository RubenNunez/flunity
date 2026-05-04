import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

class FlutterAssetsDeclaredCheck implements Check {
  FlutterAssetsDeclaredCheck({required this.project});
  final FlunityProject project;

  @override
  String get name => 'flutter_app/pubspec.yaml declares unity_webgl assets';

  @override
  Future<CheckResult> run() async {
    final pubspec = File(p.join(project.paths.flutterApp, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return CheckResult.fail(
        'pubspec.yaml not found at ${pubspec.path}',
        hint:
            'Run `fl create` from scratch, or add a Flutter app at this path.',
      );
    }
    final content = pubspec.readAsStringSync();
    if (!content.contains('assets/unity_webgl/')) {
      return CheckResult.warn(
        'flutter_app/pubspec.yaml does not declare assets/unity_webgl/.',
        hint:
            'Add `- assets/unity_webgl/` under `flutter: assets:` so bundled mode works.',
      );
    }
    return CheckResult.ok('Asset directory declared.');
  }
}
