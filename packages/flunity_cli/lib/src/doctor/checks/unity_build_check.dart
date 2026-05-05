import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

class UnityBuildCheck implements Check {
  UnityBuildCheck({required this.project});
  final FlunityProject project;

  @override
  String get name => 'Unity WebGL build';

  @override
  Future<CheckResult> run() async {
    final indexHtml = File(p.join(project.buildDir, 'index.html'));
    if (!indexHtml.existsSync()) {
      return CheckResult.warn(
        'No build at ${project.buildDir}/index.html',
        hint: 'Build WebGL from Unity into ${project.buildDir}/.',
      );
    }
    final content = indexHtml.readAsStringSync();
    if (!content.contains('flunity:patch')) {
      return CheckResult.ok(
        'Found at ${indexHtml.path} (will auto-prepare on `flunity webgl serve`)',
      );
    }
    return CheckResult.ok('Found at ${indexHtml.path} (prepared)');
  }
}
