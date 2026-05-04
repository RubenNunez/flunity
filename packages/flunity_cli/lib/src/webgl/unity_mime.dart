import 'package:path/path.dart' as p;

const Map<String, String> _unityTypes = {
  '.wasm': 'application/wasm',
  '.data': 'application/octet-stream',
  '.framework.js': 'application/javascript',
  '.symbols.json': 'application/json',
};

/// Looks up a Unity-specific MIME type for [filename]. Strips `.br` / `.gz`
/// suffixes before matching so precompressed assets get the underlying type.
/// Returns null when nothing matches.
String? unityMimeType(String filename) {
  var name = filename.toLowerCase();
  if (name.endsWith('.br') || name.endsWith('.gz')) {
    name = name.substring(0, name.length - 3);
  }
  for (final entry in _unityTypes.entries) {
    if (name.endsWith(entry.key)) return entry.value;
  }
  final ext = p.extension(name);
  return _fallbackTypes[ext];
}

const Map<String, String> _fallbackTypes = {
  '.html': 'text/html; charset=utf-8',
  '.htm': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
};

/// Returns the encoding (`br` or `gzip`) implied by the filename's compression
/// suffix, or null if uncompressed.
String? unityContentEncoding(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.br')) return 'br';
  if (lower.endsWith('.gz')) return 'gzip';
  return null;
}
