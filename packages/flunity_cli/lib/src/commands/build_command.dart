import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:flunity_cli/src/unity/unity_cli.dart';
import 'package:flunity_cli/src/unity/unity_locator.dart';
import 'package:flunity_cli/src/utils/path_safety.dart';
import 'package:flunity_cli/src/utils/process_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// `flunity build <target>` — produces the per-target build artifact at
/// `<unityBuilds>/<target>/`.
///
/// The actual build logic lives in the Unity Editor scripts shipped with the
/// templates (`FlunityWebGLBuilder` / `FlunityBatchmode` / `FlunityMenu`).
/// This command is the host-side launcher, and picks one of two routes:
///
///   - **Batch mode** (the original path): spawns a fresh `Unity -batchmode`
///     process. Fails if another Editor already has the project open
///     (`Temp/UnityLockfile` exists) — Unity refuses to start a second
///     instance against a locked project.
///   - **Connected Editor**: when the project is locked *and* the
///     standalone `unity` CLI (shipped by Unity Hub, see [UnityCli]) is
///     available, drives the already-running Editor instead — either by
///     invoking one of Flunity's own `Flunity/Build/...` menu items (which
///     already do the right per-target setup), or, when no menu item covers
///     the target, by falling back to the generic `unity cmd build` +
///     `build_status` polling.
///
/// `--batch` forces the batch-mode route unconditionally.
class BuildCommand extends Command<int> {
  BuildCommand({
    required Logger logger,
    UnityCli? unityCli,
    Duration? connectedBuildPollInterval,
  }) : _logger = logger,
       _unityCli = unityCli ?? UnityCli(),
       _connectedBuildPollInterval =
           connectedBuildPollInterval ?? const Duration(seconds: 5) {
    argParser
      ..addOption(
        'unity',
        help:
            'Path to the Unity Editor binary. Defaults to \$UNITY_PATH or the '
            'highest version detected in Unity Hub install locations. '
            '(Batch mode only — ignored when building through a connected '
            'Editor.)',
      )
      ..addFlag(
        'simulator',
        negatable: false,
        help:
            'iOS only: target the Simulator SDK instead of the Device SDK. '
            'Equivalent to flipping Player Settings → iOS → Target SDK = '
            '"Simulator SDK" for this build only.',
      )
      ..addFlag(
        'release',
        negatable: false,
        help:
            'WebGL only: optimized IL2CPP player (slow compile). '
            'Default WebGL builds are development players for fast iteration; '
            'ship Android/iOS with `flunity build android|ios` instead.',
      )
      ..addFlag(
        'batch',
        negatable: false,
        help:
            'Force batch mode even when the project is locked by an open '
            'Unity Editor. Reproduces the classic "another Unity instance is '
            'running with this project open" failure unless you quit the '
            'Editor first — use this to opt out of the connected-Editor path.',
      )
      ..addOption(
        'timeout',
        defaultsTo: '30',
        help:
            'Minutes to wait for a connected-Editor build to finish before '
            'giving up. Only applies when the project is locked and the '
            '`unity` CLI drives the open Editor instead of batch mode.',
      );
  }

  final Logger _logger;
  final UnityCli _unityCli;

  /// Delay between `build_status` polls in the generic connected-Editor
  /// fallback. Overridable (test-only) so polling tests don't burn real
  /// wall-clock seconds.
  final Duration _connectedBuildPollInterval;

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

    final simulator = argResults!['simulator'] == true;
    if (simulator && target != FlunityTarget.ios) {
      _logger.err('--simulator is only valid with --target ios.');
      return 64;
    }

    final release = argResults!['release'] == true;
    if (release && target != FlunityTarget.webgl) {
      _logger.err('--release is only valid with target webgl.');
      return 64;
    }

    final forceBatch = argResults!['batch'] == true;
    final locked = isProjectLocked(project.paths.unityProject);

    var useConnectedEditor = false;
    String? unityPath;

    if (locked && forceBatch) {
      _logger.warn(
        'This project is locked by an open Unity Editor '
        '(${project.paths.unityProject}/Temp/UnityLockfile exists), but '
        '--batch forces batch mode anyway — Unity will likely refuse to '
        'start a second instance against it.',
      );
    }

    if (locked && !forceBatch) {
      if (!_unityCli.isAvailable) {
        _logger
          ..err(
            'Unity Editor has this project open '
            '(${project.paths.unityProject}/Temp/UnityLockfile exists), and '
            'the standalone `unity` CLI is not installed, so `flunity build` '
            'cannot drive the open Editor instead of batch mode.',
          )
          ..info(
            'Update Unity Hub to get the `unity` CLI — '
            'https://docs.unity.com/en-us/unity-cli/unity-cli-reference — '
            'or quit the Unity Editor and re-run `flunity build ${target.name}`.',
          )
          ..info(
            'Or pass --batch to force a batch-mode attempt anyway (it will '
            'fail while the Editor is open).',
          );
        return 70;
      }

      final connected = await _unityCli.isEditorConnected(
        projectPath: project.paths.unityProject,
      );
      if (connected) {
        useConnectedEditor = true;
      } else {
        _logger.warn(
          'Temp/UnityLockfile is present but no responsive Unity Editor '
          'answered (checked via `unity cmd editor_status`) — this may be a '
          'stale lock left behind by a crashed session. Falling back to a '
          'batch-mode attempt.',
        );
      }
    }

    if (!useConnectedEditor) {
      unityPath =
          (argResults!['unity'] as String?) ??
          UnityLocator.locate(projectPath: project.paths.unityProject);
      if (unityPath == null) {
        _logger
          ..err('Could not locate a Unity Editor binary.')
          ..info(
            'Set UNITY_PATH to your Unity binary, or pass --unity '
            '/path/to/Unity.app/Contents/MacOS/Unity.',
          );
        return 70;
      }
    }

    try {
      assertSafeRecursiveDelete(
        targetPath: project.buildDir,
        allowedParent: project.rootDir,
        operation: 'clean Unity build output',
      );
    } on PathSafetyException catch (e) {
      _logger.err(e.message);
      return 64;
    }

    final exportDir = Directory(project.buildDir);
    if (exportDir.existsSync()) {
      // Unity refuses to overwrite an existing iOS export directory in some
      // versions; the cleanest path is to wipe it first. WebGL is happy
      // either way, but consistency wins. Wiping it also means a stale
      // artifact from a previous run can't produce a false-positive
      // "success" if this run fails silently.
      exportDir.deleteSync(recursive: true);
    }
    exportDir.createSync(recursive: true);

    if (useConnectedEditor) {
      final timeoutMinutes =
          int.tryParse(argResults!['timeout'] as String? ?? '') ?? 30;
      return _buildViaConnectedEditor(
        project: project,
        target: target,
        simulator: simulator,
        release: release,
        timeout: Duration(minutes: timeoutMinutes),
      );
    }

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
      if (target == FlunityTarget.ios) ...[
        '-flunitySdk',
        simulator ? 'simulator' : 'device',
      ],
      if (target == FlunityTarget.webgl && release) '-release',
      '-logFile',
      '-',
    ];

    _logger.info('Running Unity batchmode: $unityPath ${args.join(' ')}');
    try {
      await runOrThrow(unityPath!, args, workingDirectory: project.rootDir);
    } on ProcessException catch (e) {
      _logger.err('Unity build failed: ${e.message}');
      return 1;
    }

    return _reportArtifactResult(project, target);
  }

  /// Drives the build through the already-connected Unity Editor instead of
  /// batch mode. See the class doc for the menu-item-vs-fallback routing.
  Future<int> _buildViaConnectedEditor({
    required FlunityProject project,
    required FlunityTarget target,
    required bool simulator,
    required bool release,
    required Duration timeout,
  }) async {
    // iOS's and Android's `Flunity/Build/...` menu items run
    // ProjectExportChecker's PreCheck* unconditionally, which pops a
    // *blocking* EditorUtility.DisplayDialog ("Export incomplete — Can't
    // export until you change the build target to X") when the Editor's
    // active build target doesn't already match — and a modal dialog on the
    // Editor's main thread hangs every subsequent `unity cmd` call until a
    // human dismisses it by hand. We fail fast on a mismatch instead of
    // risking that hang. WebGL's own menu handler switches targets itself
    // with no dialog (see FlunityWebGLBuilder.BuildWebGLInternal), so it's
    // exempt from this check.
    if (target != FlunityTarget.webgl) {
      final mismatch = await _checkActiveBuildTarget(
        project: project,
        target: target,
      );
      if (mismatch != null) return mismatch;
    }

    final menuPath = _connectedEditorMenuPath(
      target,
      simulator: simulator,
      release: release,
    );

    if (menuPath != null) {
      _logger.info(
        'Unity Editor has this project open — building via the connected '
        'Editor ($menuPath).',
      );
      final progress = _logger.progress(
        'Waiting for Unity (this can take several minutes)',
      );
      final result = await _unityCli.runMenu(
        menuPath,
        projectPath: project.paths.unityProject,
        timeout: timeout,
      );
      if (result.success) {
        progress.complete();
      } else {
        progress.fail();
        _logger.err('Connected-Editor build failed: ${result.errorSummary}');
      }
    } else {
      // No Flunity menu item drives this target through the connected
      // Editor yet (currently just Android — see FlunityMenu.cs, whose
      // Android export also needs FlunityBatchmode.ApplyAndroidExportSettings
      // for a correct Gradle "Export Project" output, which only the
      // batch-mode path applies today).
      _logger.warn(
        'No Flunity menu item drives ${target.name} through the connected '
        'Editor yet; falling back to the generic `unity cmd build`. This '
        'path does not run Flunity\'s per-target export setup, so verify '
        'the result — or quit the Editor and use --batch for a '
        'guaranteed-correct build.',
      );
      final fallbackOk = await _buildViaConnectedEditorFallback(
        project: project,
        target: target,
        timeout: timeout,
      );
      if (!fallbackOk) {
        _logger.err('Connected-Editor fallback build did not complete.');
      }
    }

    return _reportArtifactResult(project, target);
  }

  /// Reads the Editor's active build target via the read-only
  /// `get_build_settings` pipeline command and compares it against what
  /// [target] needs. Returns a non-null exit code when the command should
  /// stop (mismatch, or ambiguous), null to proceed.
  Future<int?> _checkActiveBuildTarget({
    required FlunityProject project,
    required FlunityTarget target,
  }) async {
    final wanted = _unityBuildTargetFlag(target);
    final status = await _unityCli.runCommand([
      'get_build_settings',
    ], projectPath: project.paths.unityProject);
    final result = status.result;
    final active = status.success && result is Map
        ? result['activeBuildTarget'] as String?
        : null;

    if (active == null) {
      _logger.warn(
        'Could not confirm the Editor\'s active build target '
        '(${status.errorSummary}); attempting the build anyway.',
      );
      return null;
    }
    if (active != wanted) {
      _logger
        ..err(
          'Unity Editor\'s active build target is "$active", but '
          '`flunity build ${target.name}` needs "$wanted".',
        )
        ..info(
          'Switch platform inside the Editor (File → Build Profiles, select '
          '$wanted → Switch Platform) and re-run. Flunity\'s $wanted export '
          'checker shows a blocking dialog on a mismatch instead of failing '
          'cleanly, which would hang this command, so we check first instead '
          'of switching it for you — that operation triggers a full '
          'reimport.',
        )
        ..info('Or quit the Editor and re-run with --batch.');
      return 1;
    }
    return null;
  }

  /// Generic fallback for targets with no dedicated Flunity menu item:
  /// triggers the connected Editor's own async `build` pipeline command and
  /// polls `build_status` until it reports `completed` or [timeout] elapses.
  ///
  /// `completed` only means the build *finished*, not that it succeeded —
  /// the caller's artifact check on disk is the authoritative pass/fail
  /// signal, matching the menu route.
  Future<bool> _buildViaConnectedEditorFallback({
    required FlunityProject project,
    required FlunityTarget target,
    required Duration timeout,
  }) async {
    final start = await _unityCli.runCommand(
      [
        'build',
        '--target',
        _unityBuildTargetFlag(target),
        '--outputPath',
        project.buildDir,
        '--confirm',
        'true',
      ],
      projectPath: project.paths.unityProject,
      timeout: const Duration(seconds: 30),
    );
    if (!start.success) {
      _logger.err('Could not start the build: ${start.errorSummary}');
      return false;
    }

    final progress = _logger.progress(
      'Waiting for Unity to finish building ${target.name}',
    );
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_connectedBuildPollInterval);
      final status = await _unityCli.runCommand(
        ['build_status'],
        projectPath: project.paths.unityProject,
        timeout: const Duration(seconds: 30),
      );
      if (!status.success) {
        progress.fail();
        _logger.err(
          'Lost contact with the Editor while polling: ${status.errorSummary}',
        );
        return false;
      }
      final result = status.result;
      final buildStatus = result is Map ? result['status'] as String? : null;
      if (buildStatus == 'completed') {
        progress.complete();
        return true;
      }
    }
    progress.fail();
    _logger.err(
      'Timed out after ${timeout.inMinutes} min waiting for the build to '
      'finish.',
    );
    return false;
  }

  int _reportArtifactResult(FlunityProject project, FlunityTarget target) {
    final exportDir = Directory(project.buildDir);
    if (!exportDir.existsSync() || exportDir.listSync().isEmpty) {
      _logger.err(
        'Build finished but ${project.buildDir} is empty. Check the Unity '
        'log above (or the Editor Console, for a connected-Editor build).',
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

  /// Menu item path for the connected-Editor route, or null when no
  /// Flunity menu item covers this (target, variant) combination yet — see
  /// `Assets/Editor/Flunity/FlunityMenu.cs` / `FlunityWebGLBuilder.cs` in
  /// `templates/unity_bridge_basic/` (the source of truth for what ships).
  String? _connectedEditorMenuPath(
    FlunityTarget target, {
    required bool simulator,
    required bool release,
  }) {
    return switch (target) {
      FlunityTarget.webgl =>
        release ? 'Flunity/Build/WebGL (Release)' : 'Flunity/Build/WebGL (Dev)',
      FlunityTarget.ios =>
        simulator
            ? 'Flunity/Build/iOS (Simulator)'
            : 'Flunity/Build/iOS (Device)',
      FlunityTarget.android => null,
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
