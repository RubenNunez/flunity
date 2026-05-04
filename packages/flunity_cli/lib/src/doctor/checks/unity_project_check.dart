import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';

class UnityProjectCheck implements Check {
  UnityProjectCheck({required this.project});
  final FlunityProject project;

  @override
  String get name => 'unity_project/ exists';

  @override
  Future<CheckResult> run() async {
    final exists = Directory(project.paths.unityProject).existsSync();
    return exists
        ? CheckResult.ok(project.paths.unityProject)
        : CheckResult.fail(
            'Missing: ${project.paths.unityProject}',
            hint: 'Open Unity and create a project at this path.',
          );
  }
}
