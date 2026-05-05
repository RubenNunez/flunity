import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:flunity_cli/src/webgl/dev_server.dart';
import 'package:flunity_cli/src/webgl/prepare_webgl.dart';
import 'package:flunity_cli/src/webgl/webgl_copy.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class WebGLCommand extends Command<int> {
  WebGLCommand({required Logger logger}) : _logger = logger {
    addSubcommand(_ServeSubcommand(logger: _logger));
    addSubcommand(_CopySubcommand(logger: _logger));
    addSubcommand(_CleanSubcommand(logger: _logger));
    addSubcommand(_PrepareSubcommand(logger: _logger));
  }

  final Logger _logger;

  @override
  String get name => 'webgl';
  @override
  String get description => 'Serve, copy, or clean Unity WebGL builds.';
}

class _ServeSubcommand extends Command<int> {
  _ServeSubcommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption('host', help: 'Override manifest host.')
      ..addOption('port', help: 'Override manifest port.')
      ..addFlag('open', defaultsTo: false, help: 'Open the URL in a browser.');
  }

  final Logger _logger;

  @override
  String get name => 'serve';
  @override
  String get description => 'Start the local Unity WebGL dev server.';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;

    final host =
        (argResults!['host'] as String?) ?? project.webgl.devServer.host;
    final port = int.tryParse((argResults!['port'] as String?) ?? '') ??
        project.webgl.devServer.port;
    final indexHtml = File('${project.paths.unityBuild}/index.html');
    if (!indexHtml.existsSync()) {
      _logger.err('No Unity WebGL build at ${project.paths.unityBuild}/.');
      _logger.info('Build WebGL from Unity, then re-run.');
      return 1;
    }

    final shimSourcePath = p.join(
      project.paths.unityProject,
      'Assets',
      'Plugins',
      'WebGL',
      'flunity_bridge.js',
    );
    await prepareWebGLBuild(
      buildDir: project.paths.unityBuild,
      shimSourcePath: shimSourcePath,
    );

    final server = await UnityDevServer.start(
      rootDir: project.paths.unityBuild,
      port: port,
    );
    final url = 'http://$host:${server.port}/';
    _logger.success('Serving $url (root: ${project.paths.unityBuild})');
    _logger.info('Press Ctrl+C to stop.');

    if (argResults!['open'] == true) {
      await _openUrl(url);
    }

    final completer = Completer<void>();
    ProcessSignal.sigint.watch().listen((_) {
      _logger.info('\nStopping…');
      completer.complete();
    });
    await completer.future;
    await server.stop();
    return 0;
  }

  Future<void> _openUrl(String url) async {
    final cmd = Platform.isMacOS
        ? ['open', url]
        : Platform.isWindows
            ? ['cmd', '/c', 'start', '', url]
            : ['xdg-open', url];
    try {
      await Process.start(cmd.first, cmd.skip(1).toList(), runInShell: true);
    } catch (_) {
      // best-effort
    }
  }
}

class _CopySubcommand extends Command<int> {
  _CopySubcommand({required Logger logger}) : _logger = logger {
    argParser.addFlag('clean',
        defaultsTo: false, help: 'Remove destination first.');
  }

  final Logger _logger;

  @override
  String get name => 'copy';
  @override
  String get description =>
      'Copy the Unity WebGL build into flutter_app/assets/unity_webgl/.';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;
    await prepareWebGLBuild(
      buildDir: project.paths.unityBuild,
      shimSourcePath: p.join(
        project.paths.unityProject,
        'Assets',
        'Plugins',
        'WebGL',
        'flunity_bridge.js',
      ),
    );
    try {
      final summary = await copyWebGLBuild(
        project: project,
        clean: argResults!['clean'] == true,
      );
      _logger.success(
        'Copied ${summary.fileCount} files (${summary.totalBytes} bytes) → ${summary.destination}',
      );
      _logger.info('Build hash: ${summary.buildHash}');
      return 0;
    } on WebGLCopyException catch (e) {
      _logger.err(e.message);
      return 1;
    }
  }
}

class _CleanSubcommand extends Command<int> {
  _CleanSubcommand({required Logger logger}) : _logger = logger;
  final Logger _logger;

  @override
  String get name => 'clean';
  @override
  String get description =>
      'Remove flutter_app/assets/unity_webgl/ contents (preserves .gitkeep).';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;
    final destination = Directory(project.paths.flutterAssets);
    if (!destination.existsSync()) {
      _logger.info('Already clean: ${destination.path}');
      return 0;
    }
    for (final entity in destination.listSync()) {
      if (entity is File && entity.path.endsWith('.gitkeep')) continue;
      entity.deleteSync(recursive: true);
    }
    _logger.success('Cleaned ${destination.path}');
    return 0;
  }
}

class _PrepareSubcommand extends Command<int> {
  _PrepareSubcommand({required Logger logger}) : _logger = logger;
  final Logger _logger;

  @override
  String get name => 'prepare';
  @override
  String get description =>
      'Patch the Unity WebGL build (index.html + JS shim) for the Flunity bridge.';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;
    final summary = await prepareWebGLBuild(
      buildDir: project.paths.unityBuild,
      shimSourcePath: p.join(
        project.paths.unityProject,
        'Assets',
        'Plugins',
        'WebGL',
        'flunity_bridge.js',
      ),
    );
    if (summary.shimCopied) {
      _logger.info('Copied flunity_bridge.js into build dir');
    }
    if (summary.indexHtmlPatched) {
      _logger.info('Patched index.html with bridge wiring');
    }
    if (!summary.shimCopied && !summary.indexHtmlPatched) {
      _logger.info('Build already prepared.');
    }
    return 0;
  }
}

FlunityProject? _loadProjectOrDie(Logger logger) {
  final manifestPath = findManifest(start: Directory.current.path);
  if (manifestPath == null) {
    logger.err('No flunity.yaml found. Run inside a Flunity project.');
    return null;
  }
  return FlunityProject.loadFromManifest(manifestPath);
}
