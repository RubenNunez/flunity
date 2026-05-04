import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'flunity_project.dart';

class ManifestException implements Exception {
  ManifestException(this.message);
  final String message;
  @override
  String toString() => 'ManifestException: $message';
}

FlunityProject parseManifest(String manifestPath) {
  final file = File(manifestPath);
  if (!file.existsSync()) {
    throw ManifestException('Manifest not found: $manifestPath');
  }
  final rootDir = p.dirname(file.absolute.path);
  final dynamic doc = loadYaml(file.readAsStringSync());
  if (doc is! YamlMap) {
    throw ManifestException('Manifest must be a YAML map at top level.');
  }

  final name = _requireString(doc, 'name');
  final version = _optionalString(doc, 'version') ?? '0.1.0';
  final targetStr = _requireString(doc, 'target');
  final target = switch (targetStr) {
    'webgl' => FlunityTarget.webgl,
    _ => throw ManifestException(
        'Unknown target "$targetStr" — only "webgl" is supported in v1.',
      ),
  };

  final pathsMap = doc['paths'] as YamlMap?;
  final paths = FlunityPaths(
    flutterApp: _resolvePath(rootDir, pathsMap, 'flutter_app', 'flutter_app'),
    unityProject:
        _resolvePath(rootDir, pathsMap, 'unity_project', 'unity_project'),
    unityBuild: _resolvePath(
        rootDir, pathsMap, 'unity_build', 'unity_project/Builds/WebGL'),
    flutterAssets: _resolvePath(
        rootDir, pathsMap, 'flutter_assets', 'flutter_app/assets/unity_webgl'),
  );

  final webglMap = doc['webgl'] as YamlMap?;
  final devServerMap = webglMap?['dev_server'] as YamlMap?;
  final webgl = FlunityWebGLSettings(
    devServer: FlunityDevServerSettings(
      host: (devServerMap?['host'] as String?) ?? '127.0.0.1',
      port: (devServerMap?['port'] as int?) ?? 8080,
      crossOriginIsolation:
          (devServerMap?['cross_origin_isolation'] as bool?) ?? true,
      hotReload: (devServerMap?['hot_reload'] as bool?) ?? false,
    ),
    androidEmulatorHost:
        (webglMap?['android_emulator_host'] as String?) ?? '10.0.2.2',
  );

  final bridgeMap = doc['bridge'] as YamlMap?;
  final messages = (bridgeMap?['messages'] as YamlList?)
          ?.map((e) => e.toString())
          .toList() ??
      const <String>[];
  final bridge = FlunityBridgeSettings(
    enabled: (bridgeMap?['enabled'] as bool?) ?? true,
    messages: messages,
  );

  return FlunityProject(
    rootDir: rootDir,
    name: name,
    version: version,
    target: target,
    paths: paths,
    webgl: webgl,
    bridge: bridge,
  );
}

String _requireString(YamlMap doc, String key) {
  final value = doc[key];
  if (value is! String || value.isEmpty) {
    throw ManifestException('Manifest is missing required string "$key".');
  }
  return value;
}

String? _optionalString(YamlMap doc, String key) {
  final value = doc[key];
  return value is String ? value : null;
}

String _resolvePath(
    String rootDir, YamlMap? pathsMap, String key, String fallback) {
  final raw = (pathsMap?[key] as String?) ?? fallback;
  return p.normalize(p.join(rootDir, raw));
}
