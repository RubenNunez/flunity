enum CheckSeverity { ok, warn, fail }

class CheckResult {
  CheckResult({required this.severity, required this.message, this.hint});
  final CheckSeverity severity;
  final String message;
  final String? hint;

  factory CheckResult.ok(String message) =>
      CheckResult(severity: CheckSeverity.ok, message: message);
  factory CheckResult.warn(String message, {String? hint}) =>
      CheckResult(severity: CheckSeverity.warn, message: message, hint: hint);
  factory CheckResult.fail(String message, {String? hint}) =>
      CheckResult(severity: CheckSeverity.fail, message: message, hint: hint);
}

abstract class Check {
  String get name;
  Future<CheckResult> run();
}
