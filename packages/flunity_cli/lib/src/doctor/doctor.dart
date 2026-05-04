import 'package:mason_logger/mason_logger.dart';

import 'check.dart';

class Doctor {
  Doctor({required this.checks});
  final List<Check> checks;

  Future<int> run({required Logger logger}) async {
    var hasFail = false;
    var hasWarn = false;
    for (final check in checks) {
      final result = await check.run();
      final glyph = switch (result.severity) {
        CheckSeverity.ok => lightGreen.wrap('✓'),
        CheckSeverity.warn => yellow.wrap('⚠'),
        CheckSeverity.fail => lightRed.wrap('✗'),
      };
      logger.info('$glyph ${check.name}: ${result.message}');
      if (result.hint != null) {
        logger.info('    ↳ ${darkGray.wrap(result.hint!)}');
      }
      if (result.severity == CheckSeverity.fail) hasFail = true;
      if (result.severity == CheckSeverity.warn) hasWarn = true;
    }
    if (hasFail) return 1;
    if (hasWarn) return 0;
    return 0;
  }
}
