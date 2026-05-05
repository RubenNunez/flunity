import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/bridge/bridge_init.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

const String defaultBridgeVersion = '0.1.0';

class BridgeCommand extends Command<int> {
  BridgeCommand({required Logger logger}) {
    addSubcommand(_InitSubcommand(logger: logger));
  }

  @override
  String get name => 'bridge';
  @override
  String get description =>
      'Wire flunity_bridge into the Flutter app + Unity project.';
}

class _InitSubcommand extends Command<int> {
  _InitSubcommand({required Logger logger}) : _logger = logger {
    argParser.addFlag('force',
        defaultsTo: false, help: 'Overwrite existing files.');
  }
  final Logger _logger;

  @override
  String get name => 'init';
  @override
  String get description =>
      'Initialize the Flunity bridge in the current project.';

  @override
  Future<int> run() async {
    final manifestPath = findManifest(start: p.current);
    if (manifestPath == null) {
      _logger.err('No flunity.yaml found.');
      return 64;
    }
    final project = FlunityProject.loadFromManifest(manifestPath);
    final templateRoot = await _resolveTemplateRoot();
    if (templateRoot == null) {
      _logger.err('Could not locate Flunity templates directory.');
      return 70;
    }
    final summary = await initBridge(
      project: project,
      bridgeVersion: defaultBridgeVersion,
      templateRoot: templateRoot,
      force: argResults!['force'] == true,
    );

    if (summary.depAdded) {
      _logger.success('Added flunity_bridge to flutter_app/pubspec.yaml');
    }
    for (final file in summary.filesCreated) {
      _logger.info('  + $file');
    }
    if (summary.indexHtmlPatched) {
      _logger
          .success('Patched Unity index.html with flunity_bridge.js include');
    }
    if (summary.filesCreated.isEmpty &&
        !summary.depAdded &&
        !summary.indexHtmlPatched) {
      _logger.info('Bridge already initialized. Use --force to overwrite.');
    }
    return 0;
  }

  Future<String?> _resolveTemplateRoot() async {
    try {
      final libUri = await Isolate.resolvePackageUri(
        Uri.parse('package:flunity_cli/flunity_cli.dart'),
      );
      if (libUri != null) {
        final pkgRoot = p.dirname(p.dirname(libUri.toFilePath()));
        final candidate = p.join(pkgRoot, 'templates');
        if (Directory(candidate).existsSync()) return candidate;
      }
    } catch (_) {}
    Directory? dir = Directory(p.dirname(Platform.script.toFilePath()));
    for (var i = 0; i < 8 && dir != null; i++) {
      final candidate = p.join(dir.path, 'templates', 'flutter_webgl_bridge');
      if (Directory(candidate).existsSync()) return p.join(dir.path, 'templates');
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
