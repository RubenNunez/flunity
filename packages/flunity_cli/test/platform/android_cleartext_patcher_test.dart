import 'dart:io';

import 'package:flunity_cli/src/platform/android_cleartext_patcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String androidAppDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_cleartext_');
    androidAppDir = p.join(tmp.path, 'android', 'app');
    Directory(p.join(androidAppDir, 'src', 'main')).createSync(recursive: true);
    File(
      p.join(androidAppDir, 'src', 'main', 'AndroidManifest.xml'),
    ).writeAsStringSync(
      '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="my_app"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
''',
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('adds networkSecurityConfig attribute and writes the xml file', () {
    final modified = AndroidCleartextPatcher.patch(
      androidAppDir: androidAppDir,
    );
    expect(modified, isTrue);

    final manifest = File(
      p.join(androidAppDir, 'src', 'main', 'AndroidManifest.xml'),
    ).readAsStringSync();
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );

    final xml = File(
      p.join(
        androidAppDir,
        'src',
        'main',
        'res',
        'xml',
        'network_security_config.xml',
      ),
    );
    expect(xml.existsSync(), isTrue);
    expect(xml.readAsStringSync(), contains('127.0.0.1'));
    expect(xml.readAsStringSync(), contains('10.0.2.2'));
  });

  test('idempotent on second run', () {
    AndroidCleartextPatcher.patch(androidAppDir: androidAppDir);
    final modified2 = AndroidCleartextPatcher.patch(
      androidAppDir: androidAppDir,
    );
    expect(modified2, isFalse);
  });
}
