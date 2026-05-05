import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

/// Verifies the Unity build artifact at `<project.buildDir>/` looks
/// plausible for the active target.
///
/// Target-specific signal files:
///   - webgl   → index.html (and the `flunity:patch` marker once prepared).
///   - ios     → Unity-iPhone.xcodeproj/project.pbxproj.
///   - android → build.gradle at the export root.
class UnityBuildCheck implements Check {
  UnityBuildCheck({required this.project});
  final FlunityProject project;

  @override
  String get name => 'Unity ${project.target.name} build';

  @override
  Future<CheckResult> run() async {
    return switch (project.target) {
      FlunityTarget.webgl => _runWebGL(),
      FlunityTarget.ios => _runIos(),
      FlunityTarget.android => _runAndroid(),
    };
  }

  Future<CheckResult> _runWebGL() async {
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

  Future<CheckResult> _runIos() async {
    final pbxproj = File(
      p.join(project.buildDir, 'Unity-iPhone.xcodeproj', 'project.pbxproj'),
    );
    if (!pbxproj.existsSync()) {
      return CheckResult.warn(
        'No iOS export at ${project.buildDir}/.',
        hint: 'Run `flunity build ios` to produce the Unity Xcode export.',
      );
    }
    return CheckResult.ok('Found Unity iOS export at ${project.buildDir}');
  }

  Future<CheckResult> _runAndroid() async {
    final gradleFile = File(p.join(project.buildDir, 'build.gradle'));
    if (!gradleFile.existsSync()) {
      return CheckResult.warn(
        'No Android export at ${project.buildDir}/.',
        hint: 'Run `flunity build android` to produce the unityLibrary module.',
      );
    }
    return CheckResult.ok('Found Unity Android export at ${project.buildDir}');
  }
}
