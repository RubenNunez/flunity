import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:flunity_cli/src/unity/unity_locator.dart';
import 'package:flunity_cli/src/utils/process_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// `flunity build <target>` — runs Unity in batch mode to produce the
/// per-target build artifact at `<unityBuilds>/<target>/`.
///
/// The actual build logic lives in the Unity Editor scripts shipped with the
/// templates (`FlunityWebGLBuilder` / `FlunityBatchmode`). This command is
/// just the host-side launcher: locate Unity, assemble the right CLI args,
/// stream output, and surface non-zero exit codes.
class BuildCommand extends Command<int> {
  BuildCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'unity',
      help:
          'Path to the Unity Editor binary. Defaults to \$UNITY_PATH or the '
          'highest version detected in Unity Hub install locations.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'build';

  @override
  String get description =>
      'Build the Unity project for the active target (webgl|ios|android).';

  @override
  String get invocation => 'flunity build [<target>]';

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

    final unityPath =
        (argResults!['unity'] as String?) ?? UnityLocator.locate();
    if (unityPath == null) {
      _logger
        ..err('Could not locate a Unity Editor binary.')
        ..info(
          'Set UNITY_PATH to your Unity binary, or pass --unity '
          '/path/to/Unity.app/Contents/MacOS/Unity.',
        );
      return 70;
    }

    final exportDir = Directory(project.buildDir);
    if (exportDir.existsSync()) {
      // Unity refuses to overwrite an existing iOS export directory in some
      // versions; the cleanest path is to wipe it first. WebGL is happy
      // either way, but consistency wins.
      exportDir.deleteSync(recursive: true);
    }
    exportDir.createSync(recursive: true);

    final args = [
      '-batchmode',
      '-nographics',
      '-quit',
      '-projectPath',
      project.paths.unityProject,
      '-buildTarget',
      _unityBuildTargetFlag(target),
      '-executeMethod',
      _unityExecuteMethod(target),
      '-exportPath',
      project.buildDir,
      '-logFile',
      '-',
    ];

    _logger.info('Running Unity batchmode: $unityPath ${args.join(' ')}');
    try {
      await runOrThrow(unityPath, args, workingDirectory: project.rootDir);
    } on ProcessException catch (e) {
      _logger.err('Unity build failed: ${e.message}');
      return 1;
    }

    if (!exportDir.existsSync() || exportDir.listSync().isEmpty) {
      _logger.err(
        'Unity exited successfully but ${project.buildDir} is empty. '
        'Check the Unity log above.',
      );
      return 1;
    }

    _logger.success('Unity build complete → ${project.buildDir}');
    if (target != FlunityTarget.webgl) {
      _logger.info(
        'Next: flunity bundle ${target.name} to copy this into flutter_app/.',
      );
    }
    return 0;
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

  String _unityBuildTargetFlag(FlunityTarget target) => switch (target) {
    FlunityTarget.webgl => 'WebGL',
    FlunityTarget.ios => 'iOS',
    FlunityTarget.android => 'Android',
  };

  String _unityExecuteMethod(FlunityTarget target) => switch (target) {
    FlunityTarget.webgl => 'FlunityWebGLBuilder.BuildWebGL',
    FlunityTarget.ios => 'FlunityBatchmode.ExportProjectIos',
    FlunityTarget.android => 'FlunityBatchmode.ExportProjectAndroid',
  };
}
