import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Runs an external process and captures its output. Injectable so
/// [UnityCli] can be unit-tested without spawning the real `unity` binary —
/// tests pass a fake that returns canned [ProcessResult]s.
typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> args, {
      String? workingDirectory,
    });

Future<ProcessResult> _defaultProcessRunner(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) => Process.run(executable, args, workingDirectory: workingDirectory);

/// `<unityProject>/Temp/UnityLockfile` exists exactly while a Unity Editor
/// process holds the project open. Batchmode refuses to start against a
/// locked project:
///
///   Aborting batchmode due to fatal error:
///   It looks like another Unity instance is running with this project open.
///
/// so this is how `flunity build` decides whether to route through the
/// connected Editor (via [UnityCli]) instead of spawning a fresh batchmode
/// instance.
bool isProjectLocked(String unityProjectPath) {
  return File(p.join(unityProjectPath, 'Temp', 'UnityLockfile')).existsSync();
}

/// Wraps one completed `unity` CLI invocation. Every `unity cmd` call in
/// this file passes `--json`, so stdout is (on success) the envelope
/// documented at https://docs.unity.com/en-us/unity-cli/unity-cli-reference:
///
///   {"success": bool, "command": str, "data": {..., "result": {...}},
///    "errors": [...], "warnings": [...]}
class UnityCliResult {
  UnityCliResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  /// Best-effort decode of the `--json` envelope. Null when stdout wasn't
  /// valid JSON (e.g. the process failed to start at all).
  Map<String, dynamic>? get envelope {
    try {
      final decoded = jsonDecode(stdout);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// `data.result` — the pipeline command's own return payload. For
  /// `editor_status` that's `{status, compiling, ...}`; for
  /// `get_build_settings` it's `{activeBuildTarget, scenes, ...}`; for
  /// `build_status` it's `{status: idle|queued|building|completed, ...}`.
  dynamic get result {
    final data = envelope?['data'];
    return data is Map ? data['result'] : null;
  }

  /// True when the process exited 0 *and* the JSON envelope agrees. Falls
  /// back to exit-code-only when stdout wasn't JSON (e.g. `unity` itself
  /// isn't installed, so we never got an envelope to read).
  bool get success {
    final env = envelope;
    if (env != null && env.containsKey('success')) {
      return exitCode == 0 && env['success'] == true;
    }
    return exitCode == 0;
  }

  /// Human-readable `errors[].message` from the envelope, falling back to
  /// raw stderr/stdout when there's no envelope to read.
  String get errorSummary {
    final errors = envelope?['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors
          .map((e) => (e is Map ? e['message'] ?? e : e).toString())
          .join('; ');
    }
    if (stderr.trim().isNotEmpty) return stderr.trim();
    return stdout.trim();
  }
}

/// Locates and drives the standalone `unity` CLI that Unity Hub installs
/// alongside the Editor (docs:
/// https://docs.unity.com/en-us/unity-cli/unity-cli-reference).
///
/// Unlike `Unity -batchmode` (which refuses to start a second instance
/// against a project another Editor already has open), this CLI can talk to
/// an *already-running* Editor over its pipeline server:
/// `unity cmd <command> --project-path <path>`. That's what lets
/// `flunity build` succeed while the developer has the project open in the
/// Editor — see `BuildCommand` in `commands/build_command.dart`.
class UnityCli {
  UnityCli({
    Map<String, String>? env,
    bool Function(String)? fileExists,
    ProcessRunner? processRunner,
  }) : _env = env ?? Platform.environment,
       _fileExists = fileExists ?? ((path) => File(path).existsSync()),
       _run = processRunner ?? _defaultProcessRunner;

  final Map<String, String> _env;
  final bool Function(String) _fileExists;
  final ProcessRunner _run;

  /// Resolves the `unity` CLI binary.
  ///
  /// Resolution order:
  ///   1. `$UNITY_CLI_PATH` — explicit override, when it points at a real file.
  ///   2. `unity` on `$PATH`.
  ///   3. `~/.unity/bin/unity` — where Unity Hub installs the standalone CLI.
  ///   4. macOS only: the Hub app bundle's own copy,
  ///      `/Applications/Unity Hub.app/Contents/Resources/cli/unity`.
  ///
  /// Returns null when none of these exist — callers fall back to batch
  /// mode (when the project isn't locked) or surface a clear error (when it
  /// is).
  String? locate() {
    final override = _env['UNITY_CLI_PATH'];
    if (override != null && override.isNotEmpty && _fileExists(override)) {
      return override;
    }

    final fromPath = _findOnPath();
    if (fromPath != null) return fromPath;

    final home = _env['HOME'] ?? _env['USERPROFILE'] ?? '';
    if (home.isNotEmpty) {
      final hubCli = p.join(home, '.unity', 'bin', 'unity');
      if (_fileExists(hubCli)) return hubCli;
    }

    // Unity Hub ships its own copy of the CLI inside the app bundle on
    // macOS; this is a fallback for machines where `~/.unity/bin` was
    // never populated (e.g. the CLI was never run once to self-install).
    const hubResourcesCli =
        '/Applications/Unity Hub.app/Contents/Resources/cli/unity';
    if (_fileExists(hubResourcesCli)) return hubResourcesCli;

    return null;
  }

  String? _findOnPath() {
    final pathVar = _env['PATH'];
    if (pathVar == null || pathVar.isEmpty) return null;
    final exeName = Platform.isWindows ? 'unity.exe' : 'unity';
    final separator = Platform.isWindows ? ';' : ':';
    for (final dir in pathVar.split(separator)) {
      if (dir.isEmpty) continue;
      final candidate = p.join(dir, exeName);
      if (_fileExists(candidate)) return candidate;
    }
    return null;
  }

  /// Whether the `unity` CLI itself is installed and locatable.
  bool get isAvailable => locate() != null;

  /// Whether a Unity Editor is connected and responsive for [projectPath],
  /// checked via the pipeline's read-only `editor_status` command.
  Future<bool> isEditorConnected({
    required String projectPath,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final result = await runCommand(
      ['editor_status'],
      projectPath: projectPath,
      timeout: timeout,
    );
    return result.success;
  }

  /// Executes an Editor menu item by path (e.g. `Flunity/Build/WebGL (Dev)`)
  /// on the connected Editor for [projectPath].
  ///
  /// The pipeline `menu` command blocks until the menu method itself
  /// returns — for a build menu item that means the *entire build* — so
  /// [timeout] should be generous. The `unity` CLI's own `--timeout` (set
  /// from this value) is what's authoritative: it returns a clean
  /// `COMMAND_FAILED` envelope on expiry rather than hanging forever.
  Future<UnityCliResult> runMenu(
    String menuPath, {
    required String projectPath,
    Duration timeout = const Duration(minutes: 30),
  }) {
    return runCommand(
      ['menu', '--path', menuPath],
      projectPath: projectPath,
      timeout: timeout,
    );
  }

  /// Runs an arbitrary `unity cmd <args>` pipeline command against the
  /// connected Editor for [projectPath] — e.g. `['build_status']` when
  /// polling an async build, or `['get_build_settings']` to read the active
  /// build target.
  Future<UnityCliResult> runCommand(
    List<String> args, {
    required String projectPath,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final unity = locate();
    if (unity == null) {
      return UnityCliResult(
        exitCode: 127,
        stdout: '',
        stderr: 'unity CLI not found',
      );
    }
    final fullArgs = [
      'cmd',
      ...args,
      '--project-path',
      projectPath,
      '--json',
      '--timeout',
      '${timeout.inSeconds}',
    ];
    try {
      final result = await _run(unity, fullArgs, workingDirectory: projectPath);
      return UnityCliResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (e) {
      return UnityCliResult(exitCode: 127, stdout: '', stderr: e.message);
    }
  }
}
