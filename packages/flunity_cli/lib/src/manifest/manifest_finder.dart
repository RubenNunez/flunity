import 'dart:io';

import 'package:path/path.dart' as p;

/// Walks upward from [start] looking for a `flunity.yaml`. Returns the path
/// or `null` if none was found before reaching the filesystem root.
String? findManifest({required String start}) {
  Directory dir = Directory(p.absolute(start));
  while (true) {
    final candidate = File(p.join(dir.path, 'flunity.yaml'));
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}
