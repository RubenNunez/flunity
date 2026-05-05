import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/doctor/checks/android_sdk_check.dart';
import 'package:test/test.dart';

void main() {
  test('warns when ANDROID_HOME is unset', () async {
    final result = await AndroidSdkCheck(env: const {}).run();
    expect(result.severity, CheckSeverity.warn);
    expect(result.message, contains('ANDROID_HOME'));
  });

  test('warns when ANDROID_HOME points at missing dir', () async {
    final result = await AndroidSdkCheck(
      env: {'ANDROID_HOME': '/nope'},
      fileExists: (_) => false,
    ).run();
    expect(result.severity, CheckSeverity.warn);
    expect(result.message, contains('does not exist'));
  });

  test('warns when NDK is missing', () async {
    final result = await AndroidSdkCheck(
      env: {'ANDROID_HOME': '/sdk'},
      fileExists: (path) => path == '/sdk',
    ).run();
    expect(result.severity, CheckSeverity.warn);
    expect(result.message, contains('No NDK'));
  });

  test('passes when SDK + NDK both present', () async {
    final result = await AndroidSdkCheck(
      env: {'ANDROID_HOME': '/sdk'},
      fileExists: (_) => true,
    ).run();
    expect(result.severity, CheckSeverity.ok);
  });

  test('honours ANDROID_NDK_HOME override', () async {
    final result = await AndroidSdkCheck(
      env: {'ANDROID_HOME': '/sdk', 'ANDROID_NDK_HOME': '/custom-ndk'},
      fileExists: (path) => path == '/sdk' || path == '/custom-ndk',
    ).run();
    expect(result.severity, CheckSeverity.ok);
    expect(result.message, contains('/custom-ndk'));
  });
}
