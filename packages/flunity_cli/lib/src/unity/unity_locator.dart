import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves a Unity Editor binary on the host machine.
///
/// Resolution order:
///   1. `UNITY_PATH` environment variable, if set and pointing at a real file.
///   2. Auto-detection from common Unity Hub install locations:
///      - macOS:   `/Applications/Unity/Hub/Editor/<version>/Unity.app/Contents/MacOS/Unity`
///                 plus the `~/Applications` variant.
///      - Linux:   `~/Unity/Hub/Editor/<version>/Editor/Unity`
///      - Windows: `C:\Program Files\Unity\Hub\Editor\<version>\Editor\Unity.exe`
///
/// When [projectPath] is given we FIRST look for the exact editor version the
/// project was authored with (`ProjectSettings/ProjectVersion.txt`). Opening a
/// project with a newer editor silently upgrades it, so an exact match wins
/// over "newest installed".
///
/// Only when the project's version is not installed (or no project path is
/// given) do we fall back to the highest-versioned install.
/// Returns null when nothing can be located — callers should ask the user
/// to set `UNITY_PATH` explicitly.
class UnityLocator {
  static String? locate({
    Map<String, String>? env,
    bool Function(String)? fileExists,
    String? projectPath,
  }) {
    env ??= Platform.environment;
    fileExists ??= (path) => File(path).existsSync();

    final fromEnv = env['UNITY_PATH'];
    if (fromEnv != null && fromEnv.isNotEmpty && fileExists(fromEnv)) {
      return fromEnv;
    }

    final candidates = _hubInstallDirs(env);

    // exact project version first — never silently upgrade the project
    final wanted = projectPath == null
        ? null
        : projectEditorVersion(projectPath);
    if (wanted != null) {
      for (final hubDir in candidates) {
        final exe = _editorExecutable(hubDir, wanted);
        if (fileExists(exe)) return exe;
      }
    }

    for (final hubDir in candidates) {
      final dir = Directory(hubDir);
      if (!dir.existsSync()) continue;
      final versions =
          dir
              .listSync()
              .whereType<Directory>()
              .map((d) => p.basename(d.path))
              .toList()
            ..sort(_compareUnityVersions);
      for (final version in versions.reversed) {
        final exe = _editorExecutable(hubDir, version);
        if (fileExists(exe)) return exe;
      }
    }
    return null;
  }

  /// The editor version a Unity project was last opened with, read from
  /// `ProjectSettings/ProjectVersion.txt` (`m_EditorVersion: 6000.3.5f2`).
  static String? projectEditorVersion(String projectPath) {
    final file = File(
      p.join(projectPath, 'ProjectSettings', 'ProjectVersion.txt'),
    );
    if (!file.existsSync()) return null;
    for (final line in file.readAsLinesSync()) {
      final match = RegExp(r'^m_EditorVersion:\s*(\S+)').firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static List<String> _hubInstallDirs(Map<String, String> env) {
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    if (Platform.isMacOS) {
      return [
        '/Applications/Unity/Hub/Editor',
        if (home.isNotEmpty)
          p.join(home, 'Applications', 'Unity', 'Hub', 'Editor'),
      ];
    }
    if (Platform.isWindows) {
      return [r'C:\Program Files\Unity\Hub\Editor'];
    }
    return [if (home.isNotEmpty) p.join(home, 'Unity', 'Hub', 'Editor')];
  }

  static String _editorExecutable(String hubDir, String version) {
    if (Platform.isMacOS) {
      return p.join(hubDir, version, 'Unity.app', 'Contents', 'MacOS', 'Unity');
    }
    if (Platform.isWindows) {
      return p.join(hubDir, version, 'Editor', 'Unity.exe');
    }
    return p.join(hubDir, version, 'Editor', 'Unity');
  }

  /// Compare Unity version strings like `6000.0.22f1`, `2022.3.62f1`. We
  /// sort by major.minor.patch numerically, then by the trailing tag (`f1`,
  /// `b3`, …) lexically.
  static int _compareUnityVersions(String a, String b) {
    final parsedA = _parseVersion(a);
    final parsedB = _parseVersion(b);
    for (var i = 0; i < parsedA.length && i < parsedB.length; i++) {
      final cmp = parsedA[i].compareTo(parsedB[i]);
      if (cmp != 0) return cmp;
    }
    return a.compareTo(b);
  }

  static List<int> _parseVersion(String version) {
    final cleaned = version.replaceAll(RegExp(r'[a-zA-Z].*$'), '');
    return cleaned
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList(growable: false);
  }
}
