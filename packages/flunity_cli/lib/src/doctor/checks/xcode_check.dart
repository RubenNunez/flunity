import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';

/// macOS-only check: Xcode + command-line tools are required to build the
/// Flutter iOS app and to embed Unity's `UnityFramework.xcframework`. We
/// shell out to `xcode-select -p` and `xcodebuild -version` and downgrade
/// to a warn if either is missing — `flunity bundle ios` still copies
/// files, but `flutter build ios` won't actually link without Xcode.
class XcodeCheck implements Check {
  @override
  String get name => 'Xcode toolchain (iOS)';

  @override
  Future<CheckResult> run() async {
    if (!Platform.isMacOS) {
      return CheckResult.fail(
        'iOS builds require macOS with Xcode installed.',
        hint: 'Switch to a macOS host or pick `--target android` instead.',
      );
    }

    try {
      final select = await Process.run('xcode-select', ['-p']);
      if (select.exitCode != 0) {
        return CheckResult.warn(
          'xcode-select did not return a developer dir.',
          hint: 'Install Xcode and run `xcode-select --install`.',
        );
      }
      final version = await Process.run('xcodebuild', ['-version']);
      if (version.exitCode != 0) {
        return CheckResult.warn(
          'xcodebuild not on PATH.',
          hint: 'Open Xcode once to accept the license, then re-run doctor.',
        );
      }
      final firstLine = (version.stdout as String).split('\n').first.trim();
      return CheckResult.ok(
        '$firstLine (developer dir: ${(select.stdout as String).trim()})',
      );
    } catch (e) {
      return CheckResult.warn(
        'Could not invoke Xcode tooling: $e',
        hint: 'Install Xcode from the App Store or Apple Developer downloads.',
      );
    }
  }
}
