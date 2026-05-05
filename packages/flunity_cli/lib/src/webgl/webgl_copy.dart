import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;

class WebGLCopyException implements Exception {
  WebGLCopyException(this.message);
  final String message;
  @override
  String toString() => 'WebGLCopyException: $message';
}

class WebGLCopySummary {
  WebGLCopySummary({
    required this.destination,
    required this.fileCount,
    required this.totalBytes,
    required this.buildHash,
  });
  final String destination;
  final int fileCount;
  final int totalBytes;
  final String buildHash;
}

Future<WebGLCopySummary> copyWebGLBuild({
  required FlunityProject project,
  bool clean = false,
}) async {
  final src = Directory(project.buildDir);
  if (!src.existsSync() || !File(p.join(src.path, 'index.html')).existsSync()) {
    throw WebGLCopyException(
      'No Unity WebGL build at ${src.path}/index.html — build first.',
    );
  }
  final dst = Directory(project.paths.flutterAssets);
  if (!dst.existsSync()) dst.createSync(recursive: true);

  if (clean) {
    for (final entity in dst.listSync()) {
      if (entity is File && entity.path.endsWith('.gitkeep')) continue;
      entity.deleteSync(recursive: true);
    }
  }

  var fileCount = 0;
  var totalBytes = 0;
  final hasher = AccumulatingHash();
  for (final entity in src.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: src.path);
    final destFile = File(p.join(dst.path, rel));
    destFile.parent.createSync(recursive: true);
    final bytes = entity.readAsBytesSync();
    destFile.writeAsBytesSync(bytes);
    fileCount += 1;
    totalBytes += bytes.length;
    hasher.add(rel);
    hasher.addBytes(bytes);
  }

  final buildHash = hasher.finalize();
  final manifest = <String, Object>{
    'build_hash': buildHash,
    'file_count': fileCount,
    'total_bytes': totalBytes,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  };
  File(
    p.join(dst.path, 'flunity_webgl_manifest.json'),
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));

  return WebGLCopySummary(
    destination: dst.path,
    fileCount: fileCount,
    totalBytes: totalBytes,
    buildHash: buildHash,
  );
}

class AccumulatingHash {
  AccumulatingHash() : _bytes = <int>[];
  final List<int> _bytes;
  void add(String s) => _bytes.addAll(utf8.encode('$s\n'));
  void addBytes(List<int> b) => _bytes.addAll(b);
  String finalize() => sha256.convert(_bytes).toString();
}
