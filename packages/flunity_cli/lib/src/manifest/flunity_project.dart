import 'package:path/path.dart' as p;

import 'manifest_schema.dart';

enum FlunityTarget { ios, android }

class FlunityProject {
  FlunityProject({
    required this.rootDir,
    required this.name,
    required this.version,
    required this.target,
    required this.paths,
    required this.bridge,
  });

  final String rootDir;
  final String name;
  final String version;
  final FlunityTarget target;
  final FlunityPaths paths;
  final FlunityBridgeSettings bridge;

  static FlunityProject loadFromManifest(String manifestPath) {
    return parseManifest(manifestPath);
  }

  String get manifestPath => p.join(rootDir, 'flunity.yaml');

  bool get isIos => target == FlunityTarget.ios;
  bool get isAndroid => target == FlunityTarget.android;
  bool get isNative => isIos || isAndroid;

  /// The Unity build artifact directory for the active [target].
  ///
  /// Resolution order:
  ///   1. `paths.unityBuildOverride` (legacy `unity_build:` field) wins.
  ///   2. Otherwise `<paths.unityBuilds>/<target.name>` —
  ///      e.g. `Builds/ios`, `Builds/android`.
  String get buildDir => buildDirFor(target);

  /// Build directory for an explicitly requested [target].
  ///
  /// A project can iterate on several targets at once, so the manifest's
  /// `target` is only the default.
  /// `unity_build_override`, when set, pins every target to one directory.
  String buildDirFor(FlunityTarget requested) {
    final override = paths.unityBuildOverride;
    if (override != null) return override;
    return p.join(paths.unityBuilds, requested.name);
  }
}

class FlunityPaths {
  FlunityPaths({
    required this.flutterApp,
    required this.unityProject,
    required this.unityBuilds,
    this.unityBuildOverride,
  });

  /// The Flutter app directory.
  final String flutterApp;

  /// The Unity project root.
  final String unityProject;

  /// Parent directory containing per-target build outputs.
  /// Per-target builds live at `<unityBuilds>/<target.name>` (lowercase).
  final String unityBuilds;

  /// Legacy `unity_build:` field. When set, overrides the per-target
  /// derivation in [FlunityProject.buildDir]. Accepted for backward
  /// compatibility with manifests written before Plan F.
  final String? unityBuildOverride;
}

class FlunityBridgeSettings {
  FlunityBridgeSettings({required this.enabled, required this.messages});

  final bool enabled;
  final List<String> messages;
}
