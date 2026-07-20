import 'dart:io';

import 'package:path/path.dart' as p;

class PathSafetyException implements Exception {
  PathSafetyException(this.message);
  final String message;

  @override
  String toString() => 'PathSafetyException: $message';
}

void assertPathInside({
  required String targetPath,
  required String allowedParent,
  required String operation,
  bool allowEqual = false,
}) {
  final target = _normalizedAbsolute(targetPath);
  final parent = _normalizedAbsolute(allowedParent);
  final inside = target == parent ? allowEqual : p.isWithin(parent, target);
  if (!inside) {
    throw PathSafetyException(
      'Refusing to $operation at $targetPath; expected a path inside $allowedParent.',
    );
  }
}

void assertSafeRecursiveDelete({
  required String targetPath,
  required String allowedParent,
  required String operation,
}) {
  assertPathInside(
    targetPath: targetPath,
    allowedParent: allowedParent,
    operation: operation,
  );
}

String _normalizedAbsolute(String path) {
  final normalized = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}
