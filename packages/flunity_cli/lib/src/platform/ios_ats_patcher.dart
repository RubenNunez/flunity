import 'dart:io';

/// Patches an iOS Runner `Info.plist` to add a scoped NSAppTransportSecurity
/// exception for `127.0.0.1` and `localhost`. Idempotent: re-running over an
/// already-patched plist is a no-op.
///
/// Flutter's create-generated Info.plist has no NSAppTransportSecurity key
/// by default; we add the entire dictionary right before the closing `</dict>`
/// of the top-level dict.
class IosAtsPatcher {
  static const String _atsBlock = '''
\t<key>NSAppTransportSecurity</key>
\t<dict>
\t\t<key>NSExceptionDomains</key>
\t\t<dict>
\t\t\t<key>127.0.0.1</key>
\t\t\t<dict>
\t\t\t\t<key>NSExceptionAllowsInsecureHTTPLoads</key>
\t\t\t\t<true/>
\t\t\t\t<key>NSIncludesSubdomains</key>
\t\t\t\t<false/>
\t\t\t</dict>
\t\t\t<key>localhost</key>
\t\t\t<dict>
\t\t\t\t<key>NSExceptionAllowsInsecureHTTPLoads</key>
\t\t\t\t<true/>
\t\t\t\t<key>NSIncludesSubdomains</key>
\t\t\t\t<false/>
\t\t\t</dict>
\t\t</dict>
\t</dict>
''';

  /// Returns true iff the file was modified.
  static bool patch(String infoPlistPath) {
    final file = File(infoPlistPath);
    if (!file.existsSync()) return false;
    final content = file.readAsStringSync();
    if (content.contains('NSAppTransportSecurity')) return false;

    // Find the LAST `</dict>` (the top-level closer).
    final closer = content.lastIndexOf('</dict>');
    if (closer < 0) {
      throw const FormatException('Info.plist missing top-level </dict>');
    }
    final patched =
        content.substring(0, closer) + _atsBlock + content.substring(closer);
    file.writeAsStringSync(patched);
    return true;
  }
}
