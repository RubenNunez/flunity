import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';
import 'package:flunity_cli/src/unity/unity_locator.dart';

/// Verifies a Unity Editor binary is locatable. Required for `flunity build`
/// to drive Unity in batch mode for native (iOS/Android) targets.
class UnityBinaryCheck implements Check {
  @override
  String get name => 'Unity Editor binary';

  @override
  Future<CheckResult> run() async {
    final found = UnityLocator.locate();
    if (found == null) {
      return CheckResult.warn(
        'Could not locate a Unity Editor binary.',
        hint:
            'Set UNITY_PATH to your Unity binary, or install Unity 6 (6000.x) '
            'via Unity Hub. `flunity build ios|android` will fail without it.',
      );
    }
    final version = await _detectVersion(found);
    if (version == null) {
      return CheckResult.warn(
        'Found Unity at $found but could not detect version.',
        hint: 'Native builds require Unity 6 (6000.x).',
      );
    }
    if (!version.startsWith('6000.')) {
      return CheckResult.warn(
        'Found Unity $version at $found.',
        hint:
            'Flunity native targets are tested on Unity 6 (6000.x). '
            'Older versions may work but are unsupported.',
      );
    }
    return CheckResult.ok('Found Unity $version at $found');
  }

  /// Best-effort version detection: the canonical Unity Hub install layout
  /// is `<base>/Editor/<version>/...`, so we just look for the segment that
  /// follows `Editor` in the path. Returns null when the path doesn't
  /// match — callers downgrade to a warn.
  Future<String?> _detectVersion(String binaryPath) async {
    final segments = binaryPath.split(Platform.pathSeparator);
    final editorIdx = segments.indexOf('Editor');
    if (editorIdx >= 0 && editorIdx + 1 < segments.length) {
      return segments[editorIdx + 1];
    }
    return null;
  }
}
