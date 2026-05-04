import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:pub_semver/pub_semver.dart';

class DartSdkCheck implements Check {
  static final _minimum = Version(3, 5, 0);

  @override
  String get name => 'Dart SDK';

  @override
  Future<CheckResult> run() async {
    final v = Version.parse(Platform.version.split(' ').first);
    if (v < _minimum) {
      return CheckResult.fail('Dart $v < required $_minimum.',
          hint: 'Upgrade Flutter (Dart ships with Flutter).');
    }
    return CheckResult.ok('$v');
  }
}
