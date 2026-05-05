import 'dart:io';

import 'package:path/path.dart' as p;

/// Patches an Android `AndroidManifest.xml` to add a `networkSecurityConfig`
/// reference, and copies `network_security_config.xml` into res/xml/.
///
/// Idempotent: re-running over an already-patched manifest is a no-op.
class AndroidCleartextPatcher {
  static const String _networkConfig = '''<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
''';

  /// Returns true iff anything was modified.
  static bool patch({
    required String androidAppDir, // e.g. flutter_app/android/app
  }) {
    final manifestPath = p.join(
      androidAppDir,
      'src',
      'main',
      'AndroidManifest.xml',
    );
    final manifest = File(manifestPath);
    if (!manifest.existsSync()) return false;

    var modified = false;

    // 1. Write res/xml/network_security_config.xml (idempotent).
    final xmlDir = Directory(p.join(androidAppDir, 'src', 'main', 'res', 'xml'))
      ..createSync(recursive: true);
    final xmlFile = File(p.join(xmlDir.path, 'network_security_config.xml'));
    if (!xmlFile.existsSync() || xmlFile.readAsStringSync() != _networkConfig) {
      xmlFile.writeAsStringSync(_networkConfig);
      modified = true;
    }

    // 2. Add the networkSecurityConfig attribute to the <application> tag if missing.
    final manifestContent = manifest.readAsStringSync();
    if (manifestContent.contains('android:networkSecurityConfig')) {
      return modified; // already wired
    }

    // Find the <application ...> opening tag and insert the attribute.
    final appTagRegex = RegExp(r'<application\s');
    final match = appTagRegex.firstMatch(manifestContent);
    if (match == null) {
      throw const FormatException(
        'AndroidManifest.xml missing <application> tag',
      );
    }
    final injectionPoint = match.end;
    final patched =
        '${manifestContent.substring(0, injectionPoint)}'
        'android:networkSecurityConfig="@xml/network_security_config"\n        '
        '${manifestContent.substring(injectionPoint)}';
    manifest.writeAsStringSync(patched);
    return true;
  }
}
