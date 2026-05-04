import 'dart:io';

import 'package:path/path.dart' as p;

class TemplateException implements Exception {
  TemplateException(this.message);
  final String message;
  @override
  String toString() => 'TemplateException: $message';
}

/// Recursively copies [from] → [to], substituting `__key__` placeholders in
/// file contents AND in file/directory names with values from [variables].
///
/// Refuses to overwrite existing destination files unless [force] is true.
/// Throws a [TemplateException] if a placeholder has no matching variable.
Future<void> renderTemplate({
  required String from,
  required String to,
  required Map<String, String> variables,
  bool force = false,
}) async {
  final source = Directory(from);
  if (!source.existsSync()) {
    throw TemplateException('Template directory not found: $from');
  }
  await _renderDirectory(source, Directory(to), variables, force);
}

Future<void> _renderDirectory(
  Directory source,
  Directory destination,
  Map<String, String> vars,
  bool force,
) async {
  if (!destination.existsSync()) destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final substitutedName = _substitute(p.basename(entity.path), vars);
    final destPath = p.join(destination.path, substitutedName);
    if (entity is Directory) {
      await _renderDirectory(entity, Directory(destPath), vars, force);
    } else if (entity is File) {
      final destFile = File(destPath);
      if (destFile.existsSync() && !force) {
        throw TemplateException(
          'Refusing to overwrite existing file: $destPath (use force=true)',
        );
      }
      final content = _substitute(entity.readAsStringSync(), vars);
      destFile.writeAsStringSync(content);
    }
  }
}

final RegExp _placeholder = RegExp(r'__([a-zA-Z][a-zA-Z0-9_]*?)__');

String _substitute(String input, Map<String, String> vars) {
  return input.replaceAllMapped(_placeholder, (m) {
    final key = m.group(1)!;
    final value = vars[key];
    if (value == null) {
      throw TemplateException('Missing template variable: $key');
    }
    return value;
  });
}
