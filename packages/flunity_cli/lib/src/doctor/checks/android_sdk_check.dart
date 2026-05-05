import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:path/path.dart' as p;

/// Android SDK + NDK probe. The Unity Android exporter produces a Gradle
/// module that depends on the host's Android SDK / NDK; we verify the
/// usual env vars resolve to actual directories so users get a clear
/// failure message before kicking off a 5-minute Unity build.
///
/// We accept `ANDROID_HOME` (canonical) or `ANDROID_SDK_ROOT` (deprecated
/// but still common). NDK lookup honors `ANDROID_NDK_HOME` then falls back
/// to scanning `<sdk>/ndk/<version>` directories.
class AndroidSdkCheck implements Check {
  AndroidSdkCheck({Map<String, String>? env, this.fileExists})
    : env = env ?? Platform.environment;

  final Map<String, String> env;
  final bool Function(String)? fileExists;

  bool _exists(String path) =>
      fileExists?.call(path) ?? Directory(path).existsSync();

  @override
  String get name => 'Android SDK + NDK';

  @override
  Future<CheckResult> run() async {
    final sdk = env['ANDROID_HOME'] ?? env['ANDROID_SDK_ROOT'];
    if (sdk == null || sdk.isEmpty) {
      return CheckResult.warn(
        'ANDROID_HOME / ANDROID_SDK_ROOT not set.',
        hint:
            'Install Android Studio (or sdkmanager) and export ANDROID_HOME '
            'pointing at the SDK root.',
      );
    }
    if (!_exists(sdk)) {
      return CheckResult.warn(
        'ANDROID_HOME points at $sdk, but that directory does not exist.',
        hint: 'Re-export ANDROID_HOME or reinstall the Android SDK.',
      );
    }

    final ndkDir = env['ANDROID_NDK_HOME'] ?? p.join(sdk, 'ndk');
    if (!_exists(ndkDir)) {
      return CheckResult.warn(
        'No NDK at $ndkDir.',
        hint:
            'Install NDK 27 (or newer) via Android Studio → SDK Manager → '
            'SDK Tools, or export ANDROID_NDK_HOME directly.',
      );
    }

    return CheckResult.ok('SDK at $sdk, NDK at $ndkDir');
  }
}
