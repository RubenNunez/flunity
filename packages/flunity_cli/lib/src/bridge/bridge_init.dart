import 'dart:io';

import 'package:flunity_cli/src/bridge/index_html_patcher.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/utils/pubspec_editor.dart';
import 'package:path/path.dart' as p;

class BridgeInitException implements Exception {
  BridgeInitException(this.message);
  final String message;
  @override
  String toString() => 'BridgeInitException: $message';
}

class BridgeInitSummary {
  BridgeInitSummary({
    required this.depAdded,
    required this.filesCreated,
    required this.indexHtmlPatched,
  });
  final bool depAdded;
  final List<String> filesCreated;
  final bool indexHtmlPatched;
}

/// Wires up the Flunity bridge inside an existing project. Idempotent: re-running
/// without --force is a no-op for already-existing files. With force, overwrites.
Future<BridgeInitSummary> initBridge({
  required FlunityProject project,
  required String bridgeVersion,
  bool force = false,
}) async {
  final pubspecPath = p.join(project.paths.flutterApp, 'pubspec.yaml');
  final depAdded = ensurePubspecDependency(
    pubspecPath: pubspecPath,
    name: 'flunity_bridge',
    constraint: '^$bridgeVersion',
  );

  // Create lib/unity/ scaffolding.
  final unityDir = Directory(p.join(project.paths.flutterApp, 'lib', 'unity'))
    ..createSync(recursive: true);
  final created = <String>[];
  final files = <String, String>{
    'unity_webgl_screen.dart': _screenSrc,
    'unity_webgl_bridge.dart': _bridgeSrc,
    'unity_webgl_config.dart': _configSrc,
  };
  for (final entry in files.entries) {
    final f = File(p.join(unityDir.path, entry.key));
    if (f.existsSync() && !force) continue;
    f.writeAsStringSync(entry.value);
    created.add(f.path);
  }

  // Copy FlunityBridge.cs (and demo) into Unity Assets/Scripts/.
  final scriptsDir =
      Directory(p.join(project.paths.unityProject, 'Assets', 'Scripts'))
        ..createSync(recursive: true);
  final csFiles = <String, String>{
    'FlunityBridge.cs': _bridgeCsPlaceholder,
    'FlunityBridgeDemo.cs': _bridgeDemoPlaceholder,
  };
  for (final entry in csFiles.entries) {
    final f = File(p.join(scriptsDir.path, entry.key));
    if (f.existsSync() && !force) continue;
    f.writeAsStringSync(entry.value);
    created.add(f.path);
  }

  // Patch Unity index.html if it exists.
  var patched = false;
  final indexHtml = File(p.join(project.paths.unityBuild, 'index.html'));
  if (indexHtml.existsSync()) {
    final original = indexHtml.readAsStringSync();
    final updated = patchUnityIndexHtml(original);
    if (updated != original) {
      indexHtml.writeAsStringSync(updated);
      patched = true;
    }
  }

  return BridgeInitSummary(
    depAdded: depAdded,
    filesCreated: created,
    indexHtmlPatched: patched,
  );
}

const String _screenSrc = r'''
import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';
import 'unity_webgl_config.dart';

class UnityWebGLScreen extends StatelessWidget {
  const UnityWebGLScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unity')),
      body: FlunityWebGLView(
        config: resolveFlunityConfig(),
        onMessage: (m) {
          // Plan C wires real handlers; for now just log.
          debugPrint('Flunity message: ${m.type}');
        },
      ),
    );
  }
}
''';

const String _bridgeSrc = '''
// Plan C polishes this file with typed message helpers.
''';

const String _configSrc = '''
import 'package:flunity_bridge/flunity_bridge.dart';

FlunityWebGLConfig resolveFlunityConfig() {
  const mode = String.fromEnvironment('FLUNITY_MODE', defaultValue: 'bundled');
  if (mode == 'dev') {
    const host = String.fromEnvironment('FLUNITY_DEV_HOST', defaultValue: '127.0.0.1');
    const port = int.fromEnvironment('FLUNITY_DEV_PORT', defaultValue: 8080);
    return FlunityWebGLConfig.dev(host: host, port: port);
  }
  return FlunityWebGLConfig.bundled();
}
''';

const String _bridgeCsPlaceholder = '''
// Plan C ships the real FlunityBridge.cs. This placeholder is here so
// `bridge init` produces a project Unity will compile.
public static class FlunityBridge {}
''';

const String _bridgeDemoPlaceholder = '''
// Plan C ships the real FlunityBridgeDemo.cs.
''';
