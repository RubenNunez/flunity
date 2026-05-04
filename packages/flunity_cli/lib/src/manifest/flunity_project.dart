import 'package:path/path.dart' as p;

import 'manifest_schema.dart';

enum FlunityTarget { webgl }

class FlunityProject {
  FlunityProject({
    required this.rootDir,
    required this.name,
    required this.version,
    required this.target,
    required this.paths,
    required this.webgl,
    required this.bridge,
  });

  final String rootDir;
  final String name;
  final String version;
  final FlunityTarget target;
  final FlunityPaths paths;
  final FlunityWebGLSettings webgl;
  final FlunityBridgeSettings bridge;

  static FlunityProject loadFromManifest(String manifestPath) {
    return parseManifest(manifestPath);
  }

  String get manifestPath => p.join(rootDir, 'flunity.yaml');
}

class FlunityPaths {
  FlunityPaths({
    required this.flutterApp,
    required this.unityProject,
    required this.unityBuild,
    required this.flutterAssets,
  });

  final String flutterApp;
  final String unityProject;
  final String unityBuild;
  final String flutterAssets;
}

class FlunityWebGLSettings {
  FlunityWebGLSettings({
    required this.devServer,
    required this.androidEmulatorHost,
  });

  final FlunityDevServerSettings devServer;
  final String androidEmulatorHost;
}

class FlunityDevServerSettings {
  FlunityDevServerSettings({
    required this.host,
    required this.port,
    required this.crossOriginIsolation,
    required this.hotReload,
  });

  final String host;
  final int port;
  final bool crossOriginIsolation;
  final bool hotReload;
}

class FlunityBridgeSettings {
  FlunityBridgeSettings({required this.enabled, required this.messages});

  final bool enabled;
  final List<String> messages;
}
