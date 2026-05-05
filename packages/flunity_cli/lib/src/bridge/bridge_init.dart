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
  required String templateRoot,
  bool force = false,
}) async {
  final pubspecPath = p.join(project.paths.flutterApp, 'pubspec.yaml');
  final depAdded = ensurePubspecDependency(
    pubspecPath: pubspecPath,
    name: 'flunity_bridge',
    constraint: '^$bridgeVersion',
  );

  final created = <String>[];

  // Copy lib/unity/ scaffolding from the flutter_webgl_bridge template.
  final libUnityDart = p.join(
    templateRoot,
    'flutter_webgl_bridge',
    'flutter_app',
    'lib',
    'unity',
  );
  if (Directory(libUnityDart).existsSync()) {
    final destLibUnity = Directory(
      p.join(project.paths.flutterApp, 'lib', 'unity'),
    )..createSync(recursive: true);
    for (final entity in Directory(libUnityDart).listSync()) {
      if (entity is! File) continue;
      final destFile = File(p.join(destLibUnity.path, p.basename(entity.path)));
      if (destFile.existsSync() && !force) continue;
      destFile.writeAsStringSync(entity.readAsStringSync());
      created.add(destFile.path);
    }
  }

  // Copy Unity Assets/ from unity_bridge_basic.
  final unityAssetsSrc = Directory(
    p.join(templateRoot, 'unity_bridge_basic', 'unity_project', 'Assets'),
  );
  if (unityAssetsSrc.existsSync()) {
    final destAssets = Directory(p.join(project.paths.unityProject, 'Assets'))
      ..createSync(recursive: true);
    _copyTree(unityAssetsSrc, destAssets, force, created);
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

void _copyTree(Directory src, Directory dst, bool force, List<String> created) {
  if (!dst.existsSync()) dst.createSync(recursive: true);
  for (final entity in src.listSync()) {
    if (entity is Directory) {
      _copyTree(
        entity,
        Directory(p.join(dst.path, p.basename(entity.path))),
        force,
        created,
      );
    } else if (entity is File) {
      final destFile = File(p.join(dst.path, p.basename(entity.path)));
      if (destFile.existsSync() && !force) continue;
      destFile.writeAsBytesSync(entity.readAsBytesSync());
      created.add(destFile.path);
    }
  }
}
