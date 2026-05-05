import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:pub_semver/pub_semver.dart';

class FlutterSdkCheck implements Check {
  FlutterSdkCheck({this.minimumVersion});
  final Version? minimumVersion;
  static final _minimum = Version(3, 38, 0);

  @override
  String get name => 'Flutter SDK';

  @override
  Future<CheckResult> run() async {
    try {
      final result = await Process.run('flutter', ['--version', '--machine']);
      if (result.exitCode != 0) {
        return CheckResult.fail(
          'Could not run `flutter --version`.',
          hint: 'Is Flutter installed and on PATH?',
        );
      }
      final output = result.stdout.toString();
      final match = RegExp(
        r'"frameworkVersion"\s*:\s*"([^"]+)"',
      ).firstMatch(output);
      if (match == null) {
        return CheckResult.warn('Could not parse Flutter version.');
      }
      final v = Version.parse(match.group(1)!.split('-').first);
      final minimum = minimumVersion ?? _minimum;
      if (v < minimum) {
        return CheckResult.fail(
          'Flutter $v < required $minimum.',
          hint: 'Upgrade with `flutter upgrade`.',
        );
      }
      return CheckResult.ok('$v');
    } catch (e) {
      return CheckResult.fail(
        'Could not detect Flutter: $e',
        hint: 'Install Flutter from https://flutter.dev/',
      );
    }
  }
}
