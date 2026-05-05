import 'dart:io';

/// Runs an external process. Throws [ProcessException] on non-zero exit.
/// Streams stdout/stderr to the parent process so the user sees progress
/// (especially for `flutter create` and `flutter pub get`, which are slow).
Future<void> runOrThrow(
  String executable,
  List<String> args, {
  required String workingDirectory,
  Map<String, String>? environment,
}) async {
  final result = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: true, // helps when flutter is a shell wrapper
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await result.exitCode;
  if (code != 0) {
    throw ProcessException(
      executable,
      args,
      '$executable exited with $code',
      code,
    );
  }
}
