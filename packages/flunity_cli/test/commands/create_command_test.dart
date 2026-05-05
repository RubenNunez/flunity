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

  test('renders the bridge template into <name>/ by default', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    final fakeBasic = Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'),
    )..createSync();
    File(
      p.join(fakeBasic.path, 'flunity.yaml'),
    ).writeAsStringSync('# basic\nname: __app_name__\ntarget: webgl\n');
    final fakeBridge = Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge'),
    )..createSync();
    File(
      p.join(fakeBridge.path, 'flunity.yaml'),
    ).writeAsStringSync('# bridge\nname: __app_name__\ntarget: webgl\n');

    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(
        CreateCommand(
          logger: Logger(level: Level.error),
          templateRootOverride: fakeTemplateRoot.path,
          skipFlutterCreate: true,
        ),
      );

    final originalCwd = Directory.current;
    Directory.current = tmp;
    try {
      final code = await runner.run(['create', 'my_app']);
      expect(code, 0);
      final manifest = File(
        p.join(tmp.path, 'my_app', 'flunity.yaml'),
      ).readAsStringSync();
      expect(manifest, contains('# bridge'));
    } finally {
      Directory.current = originalCwd;
    }
  });

  test('--no-bridge picks the basic template', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    final fakeBasic = Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'),
    )..createSync();
    File(
      p.join(fakeBasic.path, 'flunity.yaml'),
    ).writeAsStringSync('# basic\nname: __app_name__\ntarget: webgl\n');
    Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge'),
    ).createSync();

    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(
        CreateCommand(
          logger: Logger(level: Level.error),
          templateRootOverride: fakeTemplateRoot.path,
          skipFlutterCreate: true,
        ),
      );

    final originalCwd = Directory.current;
    Directory.current = tmp;
    try {
      final code = await runner.run(['create', '--no-bridge', 'my_app']);
      expect(code, 0);
      final manifest = File(
        p.join(tmp.path, 'my_app', 'flunity.yaml'),
      ).readAsStringSync();
      expect(manifest, contains('# basic'));
    } finally {
      Directory.current = originalCwd;
    }
  });

  test('rejects an existing directory', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'),
    ).createSync();
    Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge'),
    ).createSync();
    Directory(p.join(tmp.path, 'taken')).createSync();

    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(
        CreateCommand(
          logger: Logger(level: Level.quiet),
          templateRootOverride: fakeTemplateRoot.path,
          skipFlutterCreate: true,
        ),
      );

    final originalCwd = Directory.current;
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
    Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'),
    ).createSync();
    Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge'),
    ).createSync();
    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(
        CreateCommand(
          logger: Logger(level: Level.quiet),
          templateRootOverride: fakeTemplateRoot.path,
          skipFlutterCreate: true,
        ),
      );
    expect(await runner.run(['create', '--target', 'native_android', 'x']), 64);
  });

  test('rejects invalid app name', () async {
    final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))
      ..createSync();
    Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'),
    ).createSync();
    Directory(
      p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge'),
    ).createSync();
    final runner = CommandRunner<int>('flunity', 'test')
      ..addCommand(
        CreateCommand(
          logger: Logger(level: Level.quiet),
          templateRootOverride: fakeTemplateRoot.path,
          skipFlutterCreate: true,
        ),
      );
    expect(await runner.run(['create', 'My-App']), 64);
  });
}
