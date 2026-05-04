import 'dart:io';

/// Adds a dependency line to a Flutter app's pubspec.yaml if missing.
/// Returns true when a change was made.
bool ensurePubspecDependency({
  required String pubspecPath,
  required String name,
  required String constraint,
}) {
  final file = File(pubspecPath);
  if (!file.existsSync()) {
    throw FileSystemException('pubspec.yaml not found', pubspecPath);
  }
  final lines = file.readAsLinesSync();

  // Already present?
  for (final line in lines) {
    if (RegExp('^  $name:').hasMatch(line)) return false;
  }

  // Find the dependencies: top-level key.
  final depsIdx = lines.indexWhere((l) => l.trim() == 'dependencies:');
  if (depsIdx < 0) {
    throw StateError('Could not locate `dependencies:` section in $pubspecPath');
  }
  // Insert immediately after `dependencies:` line.
  lines.insert(depsIdx + 1, '  $name: $constraint');
  file.writeAsStringSync('${lines.join('\n')}\n');
  return true;
}
