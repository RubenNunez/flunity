import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/platform/android_cleartext_patcher.dart';
import 'package:flunity_cli/src/platform/ios_ats_patcher.dart';
import 'package:flunity_cli/src/templates/template_renderer.dart';
import 'package:flunity_cli/src/templates/template_vars.dart';
import 'package:flunity_cli/src/utils/process_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class CreateCommand extends Command<int> {
  CreateCommand({
    required Logger logger,
    String? templateRootOverride,
    bool skipFlutterCreate = false,
  })  : _logger = logger,
        _templateRootOverride = templateRootOverride,
        _skipFlutterCreate = skipFlutterCreate {
    argParser
      ..addOption(
        'target',
        defaultsTo: 'webgl',
        help: 'Target platform. v1 only supports "webgl".',
      )
      ..addOption(
        'org',
        defaultsTo: 'com.example',
        help: 'Reverse-DNS organization for the bundle ID.',
      )
      ..addFlag(
        'no-bridge',
        negatable: false,
        help: 'Use the basic template without bridge wiring.',
      )
      ..addOption(
        'bridge-path',
        help: 'Absolute path to a local flunity_bridge package. '
            'When omitted, Flunity tries to auto-detect from the activated CLI location. '
            'Once flunity_bridge is on pub.dev, this option will go away.',
      );
  }

  final Logger _logger;
  final String? _templateRootOverride;
  final bool _skipFlutterCreate;

  @override
  String get name => 'create';

  @override
  String get description => 'Scaffold a new Flunity project.';

  @override
  String get invocation => 'flunity create <name> [options]';

  @override
  Future<int> run() async {
    final restArgs = argResults!.rest;
    if (restArgs.length != 1) {
      _logger.err('Expected exactly one positional argument: <name>');
      return 64;
    }
    final appName = restArgs.first;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(appName)) {
      _logger.err(
        'App name must be lower_snake_case starting with a letter (got "$appName").',
      );
      return 64;
    }
    final target = argResults!['target'] as String;
    if (target != 'webgl') {
      _logger.err(
        'Target "$target" is not supported in v1. See docs/native-roadmap.md.',
      );
      return 64;
    }

    final templateName = (argResults!['no-bridge'] == true)
        ? 'flutter_webgl_basic'
        : 'flutter_webgl_bridge';

    final templateRoot = await _resolveTemplateRoot();
    if (templateRoot == null) {
      _logger.err(
        'Could not locate the Flunity templates directory. '
        'Reinstall flunity_cli with `dart pub global activate flunity_cli`.',
      );
      return 70;
    }
    final templatePath = p.join(templateRoot, templateName);
    if (!Directory(templatePath).existsSync()) {
      _logger.err('Template not found at $templatePath');
      return 70;
    }

    final outputPath = p.absolute(appName);
    if (Directory(outputPath).existsSync()) {
      _logger.err('Directory already exists: $outputPath');
      return 73;
    }

    final variables = buildTemplateVariables(
      appName: appName,
      org: argResults!['org'] as String,
    );

    final progress = _logger.progress('Rendering $templateName → $outputPath');
    try {
      await renderTemplate(
        from: templatePath,
        to: outputPath,
        variables: variables,
      );
      progress.complete('Rendered $appName/');
    } catch (e) {
      progress.fail();
      _logger.err('Failed to render template: $e');
      return 70;
    }

    if (!_skipFlutterCreate) {
      final flutterAppDir = p.join(outputPath, 'flutter_app');

      // Step 1: pubspec_overrides.yaml FIRST — `flutter create` runs
      // `pub get` as its last step, and pub get fails without the override
      // (flunity_bridge isn't on pub.dev yet).
      final bridgePath =
          (argResults!['bridge-path'] as String?) ?? _detectFlunityBridgePath();
      if (bridgePath != null) {
        File(p.join(flutterAppDir, 'pubspec_overrides.yaml'))
            .writeAsStringSync('''
dependency_overrides:
  flunity_bridge:
    path: $bridgePath
''');
      } else {
        _logger.warn(
          'flunity_bridge path not detected; flutter create will fail '
          'when pub get runs. Re-run with --bridge-path /absolute/path/to/flunity_bridge.',
        );
      }

      // Step 2: flutter create (generates ios/, android/, macos/, etc.).
      // This also runs pub get internally, picking up the override above.
      _logger.info('');
      final flutterCreate = _logger.progress(
        'Generating platform projects via flutter create',
      );
      try {
        await runOrThrow(
          'flutter',
          [
            'create',
            '--org',
            argResults!['org'] as String,
            '--project-name',
            appName,
            '--platforms',
            'ios,android,macos',
            '.',
          ],
          workingDirectory: flutterAppDir,
        );
        flutterCreate.complete('Platform projects ready');
      } catch (e) {
        flutterCreate.fail();
        _logger.err('flutter create failed: $e');
        return 70;
      }

      // Step 3: iOS ATS + Android cleartext patchers.
      IosAtsPatcher.patch(p.join(flutterAppDir, 'ios', 'Runner', 'Info.plist'));
      AndroidCleartextPatcher.patch(
        androidAppDir: p.join(flutterAppDir, 'android', 'app'),
      );

      // Step 4: flutter pub get to refresh after the patchers (no-op if
      // nothing changed, but Android manifest changes can affect pub).
      final pubGet = _logger.progress('flutter pub get');
      try {
        await runOrThrow(
          'flutter',
          ['pub', 'get'],
          workingDirectory: flutterAppDir,
        );
        pubGet.complete('Dependencies resolved');
      } catch (e) {
        pubGet.fail();
        _logger.err('flutter pub get failed: $e');
        return 70;
      }
    }

    _logger
      ..info('')
      ..success('Created $appName/. Next steps:')
      ..info('  1. cd $appName')
      ..info('  2. flunity doctor                       # verify environment')
      ..info(
        '  3. open unity_project/ in Unity, build WebGL → unity_project/Builds/WebGL/',
      )
      ..info('  4. flunity webgl serve                  # start dev server')
      ..info(
        '  5. cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev',
      );
    return 0;
  }

  /// Locates the package's `templates/` directory.
  ///
  /// We try two strategies in order:
  /// 1. `Isolate.resolvePackageUri` — works under `dart run` in JIT mode.
  /// 2. Walk upward from `Platform.script` until we find a directory that
  ///    contains `templates/flutter_webgl_basic/`. This is robust against
  ///    AOT snapshots produced by `pub global activate`, where the script
  ///    lives several directories below the package root.
  Future<String?> _resolveTemplateRoot() async {
    final override = _templateRootOverride;
    if (override != null) return override;

    try {
      final libUri = await Isolate.resolvePackageUri(
        Uri.parse('package:flunity_cli/flunity_cli.dart'),
      );
      if (libUri != null) {
        final pkgRoot = p.dirname(p.dirname(libUri.toFilePath()));
        final candidate = p.join(pkgRoot, 'templates');
        if (Directory(candidate).existsSync()) return candidate;
      }
    } catch (_) {
      // Fall through to the walk-upward strategy.
    }

    Directory? dir = Directory(p.dirname(Platform.script.toFilePath()));
    for (var i = 0; i < 8 && dir != null; i++) {
      final candidate = p.join(dir.path, 'templates', 'flutter_webgl_basic');
      if (Directory(candidate).existsSync()) {
        return p.join(dir.path, 'templates');
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Tries to find the local `flunity_bridge` package — useful when running
  /// from a path-source-activated CLI. Walks up from Platform.script looking
  /// for `packages/flunity_bridge/pubspec.yaml`.
  String? _detectFlunityBridgePath() {
    Directory? dir = Directory(p.dirname(Platform.script.toFilePath()));
    for (var i = 0; i < 8 && dir != null; i++) {
      final candidate = p.join(dir.path, 'packages', 'flunity_bridge');
      if (Directory(candidate).existsSync() &&
          File(p.join(candidate, 'pubspec.yaml')).existsSync()) {
        return candidate;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
