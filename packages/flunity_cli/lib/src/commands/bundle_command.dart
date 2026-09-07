import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:flunity_cli/src/native/bundle_native.dart';
import 'package:mason_logger/mason_logger.dart';

/// `flunity bundle <target>` — copies the Unity build artifact into the
/// Flutter app where it can be picked up by `flutter run` / `flutter build`.
///
/// Per-target behaviour:
///   - ios     → copies `Builds/ios/` into `flutter_app/ios/UnityExport/`,
///               prints next-step instructions for Xcode wiring.
///   - android → copies `Builds/android/` into `flutter_app/android/unityLibrary/`
///               and patches `settings.gradle` + `app/build.gradle`.
class BundleCommand extends Command<int> {
  BundleCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get name => 'bundle';

  @override
  String get description =>
      'Copy the Unity build into the Flutter app for the active target.';

  @override
  String get invocation => 'flunity bundle [<target>]';

  @override
  Future<int> run() async {
    final manifestPath = findManifest(start: Directory.current.path);
    if (manifestPath == null) {
      _logger.err('No flunity.yaml found. Run inside a Flunity project.');
      return 64;
    }
    final project = FlunityProject.loadFromManifest(manifestPath);

    final rest = argResults!.rest;
    final target = _resolveTarget(rest, project);
    if (target == null) return 64;

    // Read from the requested target's directory, not the manifest default.
    final buildDir = project.buildDirFor(target);
    return switch (target) {
      FlunityTarget.ios => _bundleIos(project, buildDir),
      FlunityTarget.android => _bundleAndroid(project, buildDir),
    };
  }

  Future<int> _bundleIos(FlunityProject project, String buildDir) async {
    try {
      final summary = await bundleIos(project: project, buildDir: buildDir);
      _logger.success(
        'Copied ${summary.fileCount} files → ${summary.destination}',
      );
      _logger.info('');
      _logger.info('Next steps:');
      for (final note in summary.notes) {
        _logger.info('  • $note');
      }
      return 0;
    } on BundleException catch (e) {
      _logger.err(e.message);
      return 1;
    }
  }

  Future<int> _bundleAndroid(FlunityProject project, String buildDir) async {
    try {
      final summary = await bundleAndroid(project: project, buildDir: buildDir);
      _logger.success(
        'Copied ${summary.fileCount} files → ${summary.destination}',
      );
      if (summary.gradleAlreadyWired) {
        _logger.info('settings.gradle wired up (or already had unityLibrary).');
      }
      _logger.info('');
      _logger.info('Next steps:');
      for (final note in summary.notes) {
        _logger.info('  • $note');
      }
      return 0;
    } on BundleException catch (e) {
      _logger.err(e.message);
      return 1;
    }
  }

  FlunityTarget? _resolveTarget(List<String> rest, FlunityProject project) {
    if (rest.isEmpty) return project.target;
    if (rest.length > 1) {
      _logger.err('Expected at most one positional argument: <target>.');
      return null;
    }
    return switch (rest.first) {
      'ios' => FlunityTarget.ios,
      'android' => FlunityTarget.android,
      _ => () {
        _logger.err('Unknown target "${rest.first}". Valid: ios, android.');
        return null;
      }(),
    };
  }
}
