import 'dart:io';

import 'package:flunity_cli/src/platform/ios_ats_patcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String plistPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_ats_');
    plistPath = p.join(tmp.path, 'Info.plist');
    File(plistPath).writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleIdentifier</key>
\t<string>com.example</string>
</dict>
</plist>
''');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('adds NSAppTransportSecurity block on first run', () {
    final modified = IosAtsPatcher.patch(plistPath);
    expect(modified, isTrue);
    final result = File(plistPath).readAsStringSync();
    expect(result, contains('NSAppTransportSecurity'));
    expect(result, contains('127.0.0.1'));
    expect(result, contains('localhost'));
    expect(result, contains('NSExceptionAllowsInsecureHTTPLoads'));
  });

  test('idempotent on second run', () {
    IosAtsPatcher.patch(plistPath);
    final modified2 = IosAtsPatcher.patch(plistPath);
    expect(modified2, isFalse);
  });

  test('returns false when file is missing', () {
    final modified = IosAtsPatcher.patch('/nonexistent/Info.plist');
    expect(modified, isFalse);
  });
}
