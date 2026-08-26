import 'dart:io';

import 'package:flunity_cli/src/unity/unity_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('isProjectLocked', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_lock_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('true when Temp/UnityLockfile exists', () {
      File(
        p.join(tmp.path, 'Temp', 'UnityLockfile'),
      ).createSync(recursive: true);
      expect(isProjectLocked(tmp.path), isTrue);
    });

    test('false when Temp/ exists but has no lockfile', () {
      Directory(p.join(tmp.path, 'Temp')).createSync(recursive: true);
      expect(isProjectLocked(tmp.path), isFalse);
    });

    test('false when Temp/ does not exist at all', () {
      expect(isProjectLocked(tmp.path), isFalse);
    });
  });

  group('UnityCli.locate', () {
    test('UNITY_CLI_PATH wins when set and the file exists', () {
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (path) => path == '/fake/unity',
      );
      expect(cli.locate(), '/fake/unity');
      expect(cli.isAvailable, isTrue);
    });

    test('UNITY_CLI_PATH is ignored when the file does not exist', () {
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/missing', 'PATH': '', 'HOME': ''},
        fileExists: (_) => false,
      );
      expect(cli.locate(), isNull);
      expect(cli.isAvailable, isFalse);
    });

    test('finds unity on PATH', () {
      final cli = UnityCli(
        env: {'PATH': '/usr/bin:/opt/unity/bin', 'HOME': ''},
        fileExists: (path) => path == '/opt/unity/bin/unity',
      );
      expect(cli.locate(), '/opt/unity/bin/unity');
    });

    test('falls back to ~/.unity/bin/unity when not on PATH', () {
      final cli = UnityCli(
        env: {'PATH': '/usr/bin', 'HOME': '/Users/dev'},
        fileExists: (path) => path == '/Users/dev/.unity/bin/unity',
      );
      expect(cli.locate(), '/Users/dev/.unity/bin/unity');
    });

    test('falls back to the Hub Resources CLI copy', () {
      const hubCli = '/Applications/Unity Hub.app/Contents/Resources/cli/unity';
      final cli = UnityCli(
        env: {'PATH': '/usr/bin', 'HOME': '/Users/dev'},
        fileExists: (path) => path == hubCli,
      );
      expect(cli.locate(), hubCli);
    });

    test('returns null when nothing is found anywhere', () {
      final cli = UnityCli(
        env: {'PATH': '/usr/bin', 'HOME': '/Users/dev'},
        fileExists: (_) => false,
      );
      expect(cli.locate(), isNull);
      expect(cli.isAvailable, isFalse);
    });
  });

  group('UnityCli.isEditorConnected', () {
    test('true when editor_status reports success', () async {
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          expect(args, contains('editor_status'));
          return ProcessResult(0, 0, '{"success": true}', '');
        },
      );
      expect(await cli.isEditorConnected(projectPath: '/proj'), isTrue);
    });

    test('false when editor_status times out', () async {
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          return ProcessResult(
            0,
            6,
            '{"success": false, "errors": [{"code": "COMMAND_FAILED", '
                '"message": "Pipeline command timed out"}]}',
            '',
          );
        },
      );
      expect(await cli.isEditorConnected(projectPath: '/proj'), isFalse);
    });

    test('false when the unity CLI itself is not installed', () async {
      final cli = UnityCli(
        env: {},
        fileExists: (_) => false,
        processRunner: (exe, args, {workingDirectory}) =>
            throw StateError('should never spawn a process'),
      );
      expect(await cli.isEditorConnected(projectPath: '/proj'), isFalse);
    });
  });

  group('UnityCli.runMenu', () {
    test('builds the expected `cmd menu` invocation', () async {
      List<String>? capturedArgs;
      String? capturedCwd;
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          capturedArgs = args;
          capturedCwd = workingDirectory;
          return ProcessResult(
            0,
            0,
            '{"success": true, "data": {"result": {"success": true}}}',
            '',
          );
        },
      );

      final result = await cli.runMenu(
        'Flunity/Build/WebGL (Dev)',
        projectPath: '/proj/unity_project',
        timeout: const Duration(minutes: 30),
      );

      expect(result.success, isTrue);
      expect(capturedCwd, '/proj/unity_project');
      expect(capturedArgs, [
        'cmd',
        'menu',
        '--path',
        'Flunity/Build/WebGL (Dev)',
        '--project-path',
        '/proj/unity_project',
        '--json',
        '--timeout',
        '1800',
      ]);
    });

    test('reports failure with the envelope error message', () async {
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          return ProcessResult(
            0,
            6,
            '{"success": false, "errors": [{"code": "COMMAND_FAILED", '
                '"message": "Pipeline command \'menu\' timed out after 60000ms"}]}',
            '',
          );
        },
      );

      final result = await cli.runMenu(
        'Flunity/Build/Android',
        projectPath: '/proj',
      );

      expect(result.success, isFalse);
      expect(result.errorSummary, contains('timed out'));
    });
  });

  group('UnityCli.runCommand', () {
    test('passes arbitrary args through and reads data.result', () async {
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          expect(args.sublist(0, 2), ['cmd', 'get_build_settings']);
          return ProcessResult(
            0,
            0,
            '{"success": true, "data": {"result": '
                '{"activeBuildTarget": "WebGL"}}}',
            '',
          );
        },
      );

      final result = await cli.runCommand([
        'get_build_settings',
      ], projectPath: '/proj');

      expect(result.success, isTrue);
      expect((result.result as Map)['activeBuildTarget'], 'WebGL');
    });

    test(
      'success falls back to exit-code-only when stdout is not JSON',
      () async {
        final cliOk = UnityCli(
          env: {'UNITY_CLI_PATH': '/fake/unity'},
          fileExists: (_) => true,
          processRunner: (exe, args, {workingDirectory}) async =>
              ProcessResult(0, 0, 'not json', ''),
        );
        expect(
          (await cliOk.runCommand(['x'], projectPath: '/p')).success,
          isTrue,
        );

        final cliFail = UnityCli(
          env: {'UNITY_CLI_PATH': '/fake/unity'},
          fileExists: (_) => true,
          processRunner: (exe, args, {workingDirectory}) async =>
              ProcessResult(0, 1, 'not json', 'boom'),
        );
        final result = await cliFail.runCommand(['x'], projectPath: '/p');
        expect(result.success, isFalse);
        expect(result.errorSummary, 'boom');
      },
    );

    test('exitCode 127 with a clear message when unity is not found', () async {
      final cli = UnityCli(
        env: {},
        fileExists: (_) => false,
        processRunner: (exe, args, {workingDirectory}) =>
            throw StateError('should never spawn a process'),
      );
      final result = await cli.runCommand(['x'], projectPath: '/p');
      expect(result.exitCode, 127);
      expect(result.success, isFalse);
    });

    test('a thrown ProcessException is captured, not rethrown', () async {
      final cli = UnityCli(
        env: {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          throw const ProcessException('/fake/unity', [], 'no such file', 2);
        },
      );
      final result = await cli.runCommand(['x'], projectPath: '/p');
      expect(result.success, isFalse);
      expect(result.errorSummary, contains('no such file'));
    });
  });
}
