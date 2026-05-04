import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/templates/template_renderer.dart';
import 'package:flunity_cli/src/templates/template_vars.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class CreateCommand extends Command<int> {
  CreateCommand({required Logger logger, String? templateRootOverride})
      : _logger = logger,
        _templateRootOverride = templateRootOverride {
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
      );
  }

  final Logger _logger;
  final String? _templateRootOverride;

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

    // In Plan B both --no-bridge and default use the same flutter_webgl_basic
    // template. Plan C swaps in flutter_webgl_bridge as the default.
    const templateName = 'flutter_webgl_basic';

    final templateRoot = _resolveTemplateRoot();
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

    _logger
      ..info('')
      ..success('Created $appName/. Next steps:')
      ..info('  1. cd $appName')
      ..info('  2. fl doctor                            # verify environment')
      ..info(
        '  3. open unity_project/ in Unity, build WebGL → unity_project/Builds/WebGL/',
      )
      ..info('  4. fl webgl serve                       # start dev server')
      ..info(
        '  5. cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev',
      );
    return 0;
  }

  String _resolveTemplateRoot() {
    final override = _templateRootOverride;
    if (override != null) return override;
    // Locate templates/ relative to the executing script.
    // Works for `dart run bin/flunity.dart` AND for `pub global run` (where
    // Platform.script points into pub-cache/.../bin/flunity.dart-... .snapshot).
    final scriptPath = Platform.script.toFilePath();
    final scriptDir = p.dirname(scriptPath);
    // Normal layout: <pkg>/bin/flunity.dart → templates/ at <pkg>/templates
    final candidate = p.normalize(p.join(scriptDir, '..', 'templates'));
    if (Directory(candidate).existsSync()) return candidate;
    // Fallback for pub global activate: templates live alongside lib/ at
    // <pub-cache>/hosted/.../templates
    final altCandidate =
        p.normalize(p.join(scriptDir, '..', '..', 'templates'));
    if (Directory(altCandidate).existsSync()) return altCandidate;
    return candidate; // will surface a clear error in run() if missing
  }
}
