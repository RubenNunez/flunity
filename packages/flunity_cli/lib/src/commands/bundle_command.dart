import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:flunity_cli/src/native/bundle_native.dart';
import 'package:flunity_cli/src/webgl/prepare_webgl.dart';
import 'package:flunity_cli/src/webgl/webgl_copy.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

/// `flunity bundle <target>` — copies the Unity build artifact into the
/// Flutter app where it can be picked up by `flutter run` / `flutter build`.
///
/// Per-target behaviour:
///   - webgl   → copies `Builds/webgl/` into `flutter_app/assets/unity_webgl/`
///               (delegates to the existing `webgl copy` flow).
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

    return switch (target) {
      FlunityTarget.webgl => _bundleWebGL(project),
      FlunityTarget.ios => _bundleIos(project),
      FlunityTarget.android => _bundleAndroid(project),
    };
  }

  Future<int> _bundleWebGL(FlunityProject project) async {
    await prepareWebGLBuild(
      buildDir: project.buildDir,
      shimSourcePath: p.join(
        project.paths.unityProject,
        'Assets',
        'Plugins',
        'WebGL',
        'flunity_bridge.js',
      ),
    );
    try {
      final summary = await copyWebGLBuild(project: project, clean: false);
      _logger
        ..success(
          'Copied ${summary.fileCount} files (${summary.totalBytes} bytes) → ${summary.destination}',
        )
        ..info('Build hash: ${summary.buildHash}');
      return 0;
    } on WebGLCopyException catch (e) {
      _logger.err(e.message);
      return 1;
    }
  }

  Future<int> _bundleIos(FlunityProject project) async {
    try {
      final summary = await bundleIos(project: project);
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

  Future<int> _bundleAndroid(FlunityProject project) async {
    try {
      final summary = await bundleAndroid(project: project);
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
      'webgl' => FlunityTarget.webgl,
      'ios' => FlunityTarget.ios,
      'android' => FlunityTarget.android,
      _ => () {
        _logger.err(
          'Unknown target "${rest.first}". Valid: webgl, ios, android.',
        );
        return null;
      }(),
    };
  }
}
