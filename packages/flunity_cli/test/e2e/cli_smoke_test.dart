@TestOn('vm')
library;

import 'package:flunity_cli/src/runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

void main() {
  test('--version prints and exits 0', () async {
    final code =
        await runFlunityCli(['--version'], logger: Logger(level: Level.quiet));
    expect(code, 0);
  });

  test('--help exits 0', () async {
    final code =
        await runFlunityCli(['--help'], logger: Logger(level: Level.quiet));
    expect(code, 0);
  });

  test('unknown command exits 64', () async {
    final code =
        await runFlunityCli(['zomg'], logger: Logger(level: Level.quiet));
    expect(code, 64);
  });
}
