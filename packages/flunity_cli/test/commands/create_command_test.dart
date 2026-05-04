import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/commands/create_command.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_create_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('renders the basic template into <name>/', () async {
    // Build a tiny fake template tree so the test doesn't depend on the real one.
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    final fakeBasic =
        Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'))
          ..createSync();
    File(p.join(fakeBasic.path, 'flunity.yaml'))
        .writeAsStringSync('name: __app_name__\ntarget: webgl\n');

    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.error),
        templateRootOverride: fakeTemplateRoot.path,
      ));

    // run from a tmp cwd so output lands inside tmp
    final originalCwd = Directory.current;
    // ignore: avoid_dynamic_calls
    Directory.current = tmp;
    try {
      final code = await runner.run(['create', 'my_app']);
      expect(code, 0);

      final manifest =
          File(p.join(tmp.path, 'my_app', 'flunity.yaml')).readAsStringSync();
      expect(manifest, contains('name: my_app'));
      expect(manifest, contains('target: webgl'));
    } finally {
      Directory.current = originalCwd;
    }
  });

  test('rejects an existing directory', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'))
        .createSync();
    Directory(p.join(tmp.path, 'taken')).createSync();

    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.quiet),
        templateRootOverride: fakeTemplateRoot.path,
      ));

    final originalCwd = Directory.current;
    // ignore: avoid_dynamic_calls
    Directory.current = tmp;
    try {
      expect(await runner.run(['create', 'taken']), 73);
    } finally {
      Directory.current = originalCwd;
    }
  });

  test('rejects unsupported target', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'))
        .createSync();
    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.quiet),
        templateRootOverride: fakeTemplateRoot.path,
      ));
    expect(await runner.run(['create', '--target', 'native_android', 'x']), 64);
  });

  test('rejects invalid app name', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'))
        .createSync();
    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(CreateCommand(
        logger: Logger(level: Level.quiet),
        templateRootOverride: fakeTemplateRoot.path,
      ));
    expect(await runner.run(['create', 'My-App']), 64);
  });
}
