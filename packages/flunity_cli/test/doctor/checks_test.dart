import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/doctor.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

class _StubCheck implements Check {
  _StubCheck(this.name, this._result);
  @override
  final String name;
  final CheckResult _result;
  @override
  Future<CheckResult> run() async => _result;
}

void main() {
  test('doctor returns 0 when all checks pass', () async {
    final code = await Doctor(checks: [
      _StubCheck('a', CheckResult.ok('fine')),
      _StubCheck('b', CheckResult.ok('also fine')),
    ]).run(logger: Logger(level: Level.quiet));
    expect(code, 0);
  });

  test('doctor returns 1 when any check fails', () async {
    final code = await Doctor(checks: [
      _StubCheck('a', CheckResult.ok('fine')),
      _StubCheck('b', CheckResult.fail('broken', hint: 'fix it')),
    ]).run(logger: Logger(level: Level.quiet));
    expect(code, 1);
  });

  test('doctor returns 0 with warnings only', () async {
    final code = await Doctor(checks: [
      _StubCheck('a', CheckResult.warn('hmm')),
    ]).run(logger: Logger(level: Level.quiet));
    expect(code, 0);
  });
}
