import 'dart:io';

import 'package:flunity_cli/src/manifest/manifest_finder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_finder_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('finds manifest in current directory', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    expect(findManifest(start: tmp.path), p.join(tmp.path, 'flunity.yaml'));
  });

  test('walks upward', () {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('name: x\ntarget: webgl');
    final nested = Directory(p.join(tmp.path, 'flutter_app', 'lib'))
      ..createSync(recursive: true);
    expect(findManifest(start: nested.path), p.join(tmp.path, 'flunity.yaml'));
  });

  test('returns null when not found', () {
    expect(findManifest(start: tmp.path), isNull);
  });
}
