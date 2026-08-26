import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/commands/build_command.dart';
import 'package:flunity_cli/src/unity/unity_cli.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Writes a throwaway script that exits 0 and ignores every argument, to
/// stand in for Unity's batch-mode binary. `--unity` just needs *something*
/// real to spawn so batch-mode tests exercise `runOrThrow`'s actual
/// `Process.start` call without launching real Unity or tripping over the
/// target executable's own argument parsing (a bare `dart`/`true` binary
/// either doesn't exist everywhere or chokes on `-batchmode`-style flags).
String _writeFakeUnityBinary(Directory dir) {
  if (Platform.isWindows) {
    final script = File(p.join(dir.path, 'fake_unity.bat'));
    script.writeAsStringSync('@echo off\r\nexit /b 0\r\n');
    return script.path;
  }
  final script = File(p.join(dir.path, 'fake_unity.sh'));
  script.writeAsStringSync('#!/bin/sh\nexit 0\n');
  Process.runSync('chmod', ['+x', script.path]);
  return script.path;
}

void main() {
  late Directory tmp;
  late Directory unityProjectDir;
  late Directory originalCwd;
  late String fakeUnityBinary;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_build_');
    unityProjectDir = Directory(p.join(tmp.path, 'unity_project'))
      ..createSync(recursive: true);
    originalCwd = Directory.current;
    fakeUnityBinary = _writeFakeUnityBinary(tmp);
  });

  tearDown(() {
    Directory.current = originalCwd;
    tmp.deleteSync(recursive: true);
  });

  void writeManifest({String target = 'webgl'}) {
    File(p.join(tmp.path, 'flunity.yaml')).writeAsStringSync('''
name: my_app
version: 0.1.0
target: $target
paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_builds: unity_project/Builds
  flutter_assets: flutter_app/assets/unity_webgl
webgl:
  dev_server:
    host: 127.0.0.1
    port: 8080
    cross_origin_isolation: true
    hot_reload: false
  android_emulator_host: 10.0.2.2
bridge:
  enabled: true
  messages: []
''');
  }

  void lockProject() {
    File(
      p.join(unityProjectDir.path, 'Temp', 'UnityLockfile'),
    ).createSync(recursive: true);
  }

  CommandRunner<int> runnerWith(UnityCli unityCli) =>
      CommandRunner<int>('flunity', 'test')..addCommand(
        BuildCommand(
          logger: Logger(level: Level.quiet),
          unityCli: unityCli,
          // Keep the build_status poll loop from burning real wall-clock
          // seconds in tests.
          connectedBuildPollInterval: const Duration(milliseconds: 1),
        ),
      );

  /// A [UnityCli] that fails the test if anything on it is ever touched —
  /// for asserting a branch that must not probe the connected Editor at all.
  UnityCli untouchableUnityCli() => UnityCli(
    env: const {},
    fileExists: (_) => throw StateError('UnityCli.locate() should not run'),
    processRunner: (exe, args, {workingDirectory}) =>
        throw StateError('should never spawn a process: $args'),
  );

  Future<int> run(List<String> args, {UnityCli? unityCli}) async {
    Directory.current = tmp;
    final code = await runnerWith(
      unityCli ?? untouchableUnityCli(),
    ).run(['build', ...args]);
    return code ?? -1;
  }

  group('unlocked project', () {
    test('uses batch mode and never probes the connected Editor', () async {
      writeManifest();
      final code = await run(['webgl', '--unity', fakeUnityBinary]);
      // The fake "Unity" binary exits 0 without producing a build artifact,
      // so we expect the batch-mode branch to run to completion and then
      // fail the artifact check — proving batch mode (not the connected
      // Editor, which `untouchableUnityCli` would have thrown for) executed.
      expect(code, 1);
    });
  });

  group('--batch', () {
    test('forces batch mode even when the project is locked', () async {
      writeManifest();
      lockProject();
      final code = await run(['webgl', '--unity', fakeUnityBinary, '--batch']);
      expect(code, 1); // fake binary → batch path → empty artifact
    });
  });

  group('locked, no Unity CLI', () {
    test('fails fast with a helpful message', () async {
      writeManifest();
      lockProject();
      final unityCli = UnityCli(
        env: const {},
        fileExists: (_) => false,
        processRunner: (exe, args, {workingDirectory}) =>
            throw StateError('should never spawn a process'),
      );
      final code = await run(['webgl'], unityCli: unityCli);
      expect(code, 70);
    });
  });

  group('locked, Unity CLI available, Editor connected', () {
    test('webgl drives the connected Editor via its menu item', () async {
      writeManifest();
      lockProject();
      final calls = <List<String>>[];
      final unityCli = UnityCli(
        env: const {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          calls.add(args);
          if (args.contains('editor_status')) {
            return ProcessResult(0, 0, '{"success": true}', '');
          }
          if (args.contains('menu')) {
            // Simulate the build artifact the real Unity menu item would
            // have produced.
            File(
              p.join(unityProjectDir.path, 'Builds', 'webgl', 'index.html'),
            ).createSync(recursive: true);
            return ProcessResult(0, 0, '{"success": true}', '');
          }
          throw StateError('unexpected call: $args');
        },
      );

      final code = await run(['webgl'], unityCli: unityCli);

      expect(code, 0);
      expect(
        calls.any(
          (a) => a.contains('menu') && a.contains('Flunity/Build/WebGL (Dev)'),
        ),
        isTrue,
      );
      // WebGL's own builder switches target itself with no dialog risk, so
      // we must not have spent a round trip on get_build_settings for it.
      expect(calls.any((a) => a.contains('get_build_settings')), isFalse);
    });

    test('webgl --release uses the Release menu item', () async {
      writeManifest();
      lockProject();
      final calls = <List<String>>[];
      final unityCli = UnityCli(
        env: const {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          calls.add(args);
          if (args.contains('editor_status')) {
            return ProcessResult(0, 0, '{"success": true}', '');
          }
          File(
            p.join(unityProjectDir.path, 'Builds', 'webgl', 'index.html'),
          ).createSync(recursive: true);
          return ProcessResult(0, 0, '{"success": true}', '');
        },
      );

      final code = await run(['webgl', '--release'], unityCli: unityCli);

      expect(code, 0);
      expect(
        calls.any((a) => a.contains('Flunity/Build/WebGL (Release)')),
        isTrue,
      );
    });

    test(
      'ios fails fast when the active build target does not match',
      () async {
        writeManifest(target: 'ios');
        lockProject();
        final calls = <List<String>>[];
        final unityCli = UnityCli(
          env: const {'UNITY_CLI_PATH': '/fake/unity'},
          fileExists: (_) => true,
          processRunner: (exe, args, {workingDirectory}) async {
            calls.add(args);
            if (args.contains('editor_status')) {
              return ProcessResult(0, 0, '{"success": true}', '');
            }
            if (args.contains('get_build_settings')) {
              return ProcessResult(
                0,
                0,
                '{"success": true, "data": {"result": '
                    '{"activeBuildTarget": "WebGL"}}}',
                '',
              );
            }
            throw StateError('menu must not run on a target mismatch: $args');
          },
        );

        final code = await run(['ios'], unityCli: unityCli);

        expect(code, 1);
        expect(calls.any((a) => a.contains('menu')), isFalse);
      },
    );

    test('ios --simulator drives the Simulator menu item on a match', () async {
      writeManifest(target: 'ios');
      lockProject();
      final calls = <List<String>>[];
      final unityCli = UnityCli(
        env: const {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          calls.add(args);
          if (args.contains('editor_status')) {
            return ProcessResult(0, 0, '{"success": true}', '');
          }
          if (args.contains('get_build_settings')) {
            return ProcessResult(
              0,
              0,
              '{"success": true, "data": {"result": '
                  '{"activeBuildTarget": "iOS"}}}',
              '',
            );
          }
          if (args.contains('menu')) {
            File(
              p.join(
                unityProjectDir.path,
                'Builds',
                'ios',
                'unityLibrary',
                'Unity-iPhone.xcodeproj',
                'project.pbxproj',
              ),
            ).createSync(recursive: true);
            return ProcessResult(0, 0, '{"success": true}', '');
          }
          throw StateError('unexpected call: $args');
        },
      );

      final code = await run(['ios', '--simulator'], unityCli: unityCli);

      expect(code, 0);
      expect(
        calls.any(
          (a) =>
              a.contains('menu') && a.contains('Flunity/Build/iOS (Simulator)'),
        ),
        isTrue,
      );
    });

    test(
      'android has no menu route and falls back to unity cmd build + polling',
      () async {
        writeManifest(target: 'android');
        lockProject();
        final calls = <List<String>>[];
        var statusPolls = 0;
        final unityCli = UnityCli(
          env: const {'UNITY_CLI_PATH': '/fake/unity'},
          fileExists: (_) => true,
          processRunner: (exe, args, {workingDirectory}) async {
            calls.add(args);
            if (args.contains('editor_status')) {
              return ProcessResult(0, 0, '{"success": true}', '');
            }
            if (args.contains('get_build_settings')) {
              return ProcessResult(
                0,
                0,
                '{"success": true, "data": {"result": '
                    '{"activeBuildTarget": "Android"}}}',
                '',
              );
            }
            if (args.contains('build')) {
              return ProcessResult(0, 0, '{"success": true}', '');
            }
            if (args.contains('build_status')) {
              statusPolls++;
              final status = statusPolls < 2 ? 'building' : 'completed';
              if (status == 'completed') {
                File(
                  p.join(
                    unityProjectDir.path,
                    'Builds',
                    'android',
                    'unityLibrary',
                    'build.gradle',
                  ),
                ).createSync(recursive: true);
              }
              return ProcessResult(
                0,
                0,
                '{"success": true, "data": {"result": {"status": "$status"}}}',
                '',
              );
            }
            throw StateError('unexpected call: $args');
          },
        );

        final code = await run([
          'android',
          '--timeout',
          '1',
        ], unityCli: unityCli);

        expect(code, 0);
        expect(
          calls.any(
            (a) =>
                a.contains('build') &&
                a.contains('--target') &&
                a.contains('Android'),
          ),
          isTrue,
        );
        expect(calls.any((a) => a.contains('menu')), isFalse);
      },
    );
  });

  group('locked, Unity CLI available, Editor NOT connected', () {
    test('falls back to a batch-mode attempt (stale lock)', () async {
      writeManifest();
      lockProject();
      final calls = <List<String>>[];
      final unityCli = UnityCli(
        env: const {'UNITY_CLI_PATH': '/fake/unity'},
        fileExists: (_) => true,
        processRunner: (exe, args, {workingDirectory}) async {
          calls.add(args);
          return ProcessResult(
            0,
            6,
            '{"success": false, "errors": [{"message": "timed out"}]}',
            '',
          );
        },
      );

      final code = await run([
        'webgl',
        '--unity',
        fakeUnityBinary,
      ], unityCli: unityCli);

      // Stale-lock fallback: only editor_status was tried against the
      // Editor, then it fell through to the (fake) batch binary, which
      // exits 0 without producing an artifact.
      expect(code, 1);
      expect(calls.length, 1);
      expect(calls.single, contains('editor_status'));
    });
  });

  group('argument validation', () {
    test('--simulator is rejected outside ios', () async {
      writeManifest();
      final code = await run(['webgl', '--simulator']);
      expect(code, 64);
    });

    test('--release is rejected outside webgl', () async {
      writeManifest(target: 'ios');
      final code = await run(['ios', '--release']);
      expect(code, 64);
    });
  });
}
