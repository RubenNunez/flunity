import 'dart:io';

import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

/// Result of a native bundle operation: where the artifact landed and how
/// many files were copied. Returned to the CLI for user-facing messaging.
class BundleSummary {
  BundleSummary({
    required this.target,
    required this.destination,
    required this.fileCount,
    required this.gradleAlreadyWired,
    required this.notes,
  });

  final FlunityTarget target;
  final String destination;
  final int fileCount;

  /// Android-only: true if `settings.gradle[.kts]` already had `unityLibrary`.
  /// On iOS this is always true (no auto-wiring on iOS — printed instructions).
  final bool gradleAlreadyWired;

  /// Free-form follow-up steps the user still needs to perform manually.
  final List<String> notes;
}

class BundleException implements Exception {
  BundleException(this.message);
  final String message;
  @override
  String toString() => 'BundleException: $message';
}

/// Copies the iOS Unity export (`UnityFramework.xcframework` + dependencies)
/// into the Flutter app's `ios/` directory.
///
/// We do NOT mutate `project.pbxproj` automatically — Xcode project files
/// are fragile to text-edit and the canonical path requires the `xcodeproj`
/// Ruby gem. The user gets a printable checklist in the returned notes.
Future<BundleSummary> bundleIos({required FlunityProject project}) async {
  final source = Directory(project.buildDir);
  if (!source.existsSync()) {
    throw BundleException(
      'No Unity iOS build at ${project.buildDir}. Run `flunity build ios` first.',
    );
  }

  final destination = Directory(p.join(project.paths.flutterApp, 'ios'));
  if (!destination.existsSync()) {
    throw BundleException(
      'Flutter iOS scaffold missing at ${destination.path}. '
      'Run `flutter create` inside flutter_app first.',
    );
  }

  // The Unity iOS exporter produces an Xcode project tree. Its core
  // artifact for embedding is `UnityFramework.xcframework`. We copy the
  // entire tree into `flutter_app/ios/UnityExport/` so the user can drag
  // the framework into Xcode without leaking Unity's intermediate files
  // into Runner/.
  final destDir = Directory(p.join(destination.path, 'UnityExport'));
  if (destDir.existsSync()) {
    destDir.deleteSync(recursive: true);
  }
  destDir.createSync(recursive: true);

  final fileCount = await _copyTree(source, destDir);

  return BundleSummary(
    target: FlunityTarget.ios,
    destination: destDir.path,
    fileCount: fileCount,
    gradleAlreadyWired: true,
    notes: [
      'Open ${p.join(destination.path, 'Runner.xcworkspace')} in Xcode.',
      'Drag UnityExport/Unity-iPhone.xcodeproj into the Runner project as a sub-project.',
      'Under Runner target → Frameworks, Libraries, and Embedded Content, add UnityFramework.xcframework as "Embed & Sign".',
    ],
  );
}

/// Copies the Android Unity export (`unityLibrary/` Gradle module) into the
/// Flutter app's `android/` directory and best-effort wires it into
/// `settings.gradle[.kts]` and the app's `build.gradle[.kts]`.
Future<BundleSummary> bundleAndroid({required FlunityProject project}) async {
  final source = Directory(project.buildDir);
  if (!source.existsSync()) {
    throw BundleException(
      'No Unity Android build at ${project.buildDir}. Run `flunity build android` first.',
    );
  }

  final androidDir = Directory(p.join(project.paths.flutterApp, 'android'));
  if (!androidDir.existsSync()) {
    throw BundleException(
      'Flutter Android scaffold missing at ${androidDir.path}. '
      'Run `flutter create` inside flutter_app first.',
    );
  }

  final dest = Directory(p.join(androidDir.path, 'unityLibrary'));
  if (dest.existsSync()) {
    dest.deleteSync(recursive: true);
  }
  dest.createSync(recursive: true);
  final fileCount = await _copyTree(source, dest);

  final wiredSettings = _patchAndroidSettingsGradle(androidDir);
  _patchAndroidAppBuildGradle(androidDir);

  final notes = <String>[];
  if (!wiredSettings) {
    notes.add(
      'Could not auto-wire android/settings.gradle. Add: include ":unityLibrary" '
      'and project(":unityLibrary").projectDir = file("./unityLibrary").',
    );
  }
  notes.add(
    'Make sure your android/app/build.gradle has dependency '
    'implementation project(":unityLibrary").',
  );

  return BundleSummary(
    target: FlunityTarget.android,
    destination: dest.path,
    fileCount: fileCount,
    gradleAlreadyWired: wiredSettings,
    notes: notes,
  );
}

Future<int> _copyTree(Directory source, Directory destination) async {
  var count = 0;
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: source.path);
    final destPath = p.join(destination.path, rel);
    if (entity is Directory) {
      Directory(destPath).createSync(recursive: true);
    } else if (entity is File) {
      Directory(p.dirname(destPath)).createSync(recursive: true);
      await entity.copy(destPath);
      count++;
    }
  }
  return count;
}

/// Inserts an `include ":unityLibrary"` directive into `settings.gradle`
/// (or `settings.gradle.kts`) if it isn't already present. Returns true if
/// the file already had the wiring or we successfully added it.
bool _patchAndroidSettingsGradle(Directory androidDir) {
  for (final fileName in ['settings.gradle', 'settings.gradle.kts']) {
    final f = File(p.join(androidDir.path, fileName));
    if (!f.existsSync()) continue;
    final content = f.readAsStringSync();
    if (content.contains('":unityLibrary"') ||
        content.contains("':unityLibrary'")) {
      return true;
    }
    final isKts = fileName.endsWith('.kts');
    final block = isKts
        ? '\n\ninclude(":unityLibrary")\nproject(":unityLibrary").projectDir = file("./unityLibrary")\n'
        : '\n\ninclude ":unityLibrary"\nproject(":unityLibrary").projectDir = file("./unityLibrary")\n';
    f.writeAsStringSync(content.trimRight() + block);
    return true;
  }
  return false;
}

/// Adds `implementation project(":unityLibrary")` to the app's
/// build.gradle dependencies block if it isn't already present.
void _patchAndroidAppBuildGradle(Directory androidDir) {
  for (final fileName in ['app/build.gradle', 'app/build.gradle.kts']) {
    final f = File(p.join(androidDir.path, fileName));
    if (!f.existsSync()) continue;
    final content = f.readAsStringSync();
    if (content.contains('":unityLibrary"') ||
        content.contains("':unityLibrary'")) {
      return;
    }
    final isKts = fileName.endsWith('.kts');
    final dep = isKts
        ? '    implementation(project(":unityLibrary"))'
        : '    implementation project(":unityLibrary")';
    final pattern = RegExp(r'(dependencies\s*\{)');
    final match = pattern.firstMatch(content);
    if (match == null) return;
    final patched = content.replaceFirst(pattern, '${match.group(1)}\n$dep');
    f.writeAsStringSync(patched);
    return;
  }
}
