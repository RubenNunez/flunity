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
    // The vendored upstream exporter writes to <buildDir>/unityLibrary/
    // (a hard-coded subfolder convention). Accept either nesting so users
    // who pre-flatten the export aren't false-flagged.
    final candidates = [
      p.join(
        project.buildDir,
        'unityLibrary',
        'Unity-iPhone.xcodeproj',
        'project.pbxproj',
      ),
      p.join(project.buildDir, 'Unity-iPhone.xcodeproj', 'project.pbxproj'),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) {
        return CheckResult.ok(
          'Found Unity iOS export at ${p.dirname(p.dirname(c))}',
        );
      }
    }
    return CheckResult.warn(
      'No iOS export at ${project.buildDir}/.',
      hint: 'Run `flunity build ios` to produce the Unity Xcode export.',
    );
  }

  Future<CheckResult> _runAndroid() async {
    // Same nesting as iOS — exporter writes to <buildDir>/unityLibrary/.
    final candidates = [
      p.join(project.buildDir, 'unityLibrary', 'build.gradle'),
      p.join(project.buildDir, 'build.gradle'),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) {
        return CheckResult.ok('Found Unity Android export at ${p.dirname(c)}');
      }
    }
    return CheckResult.warn(
      'No Android export at ${project.buildDir}/.',
      hint: 'Run `flunity build android` to produce the unityLibrary module.',
    );
  }
}
