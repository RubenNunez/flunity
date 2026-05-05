# Plan D — Real-world fixes from the first dry-run

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Take Flunity from "compiles and tests pass" to "I can actually use it end-to-end without hand-patching files." Discovered by walking a real user through `flunity create` → Unity build → `flunity webgl serve` → `flutter run` and finding ten things broken or missing.

**Architecture:** Same as before. Plan D fixes integration gaps:

1. The Unity-side filename rule (D1) — Unity Add Component requires `filename == classname` for MonoBehaviours.
2. `flunity create` doesn't generate platform dirs (D2) — needs to invoke `flutter create` in the rendered output.
3. `flunity_bridge` not on pub.dev (D3) — generate `pubspec_overrides.yaml` automatically.
4. The Unity index.html patcher is incomplete (D4/D8) — needs to (a) copy the JS shim, (b) wrap `createUnityInstance().then(...)` to call `window.flunity.ready(instance)`.
5. Unity rebuilds clobber the patched index.html (D5) — auto-run prepare on every `webgl serve` / `webgl copy`.
6. `flunity create` doesn't run `flutter pub get` (D6) — should, in `flutter_app/`.
7. `Content-Encoding` not set for direct `.gz` requests (D7) — already fixed; commit on this branch.
8. (folded into D4)
9. The shipped `Info.plist` and `AndroidManifest.xml` are stubs that interfere with `flutter create` (D9, D10) — drop them, generate via `flutter create`, then patch via merge logic.

After all of this lands the user-facing flow is:

```bash
flunity create my_app
# (open Unity, build WebGL — once)
flunity webgl serve
# (in another terminal)
cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev
```

No manual edits anywhere.

**Tech Stack:** Same as Plans A–C. New external dep: invoking the user's `flutter` binary via `Process.run`.

**Spec reference:** Plans A, B, C and the design spec. This plan is the integration-fix layer.

---

## Prerequisites

- Branch `feat/plan-d-fixes` is already cut and contains the D7 commit (`fix: Content-Encoding for direct .gz/.br requests`).
- `melos run test` and `melos run analyze` pass.

---

## File Structure

```
flunity/
├── packages/flunity_cli/
│   ├── lib/src/
│   │   ├── platform/                                  # NEW
│   │   │   ├── ios_ats_patcher.dart
│   │   │   └── android_cleartext_patcher.dart
│   │   ├── webgl/
│   │   │   └── prepare_webgl.dart                     # NEW (replaces standalone patcher)
│   │   ├── bridge/index_html_patcher.dart             # REWRITE — adds createUnityInstance wrap
│   │   ├── commands/
│   │   │   ├── create_command.dart                    # MODIFY — runs flutter create + patches + pub get
│   │   │   └── webgl_command.dart                     # MODIFY — adds prepare subcommand, auto-runs prepare in serve/copy
│   │   └── doctor/checks/unity_build_check.dart       # MODIFY — also checks index.html is prepared
│   ├── templates/
│   │   ├── flutter_webgl_bridge/
│   │   │   ├── flutter_app/ios/                       # DELETE entirely (flutter create generates)
│   │   │   ├── flutter_app/android/app/src/main/AndroidManifest.xml  # DELETE (flutter create generates)
│   │   │   └── flutter_app/android/app/src/main/res/xml/network_security_config.xml  # KEEP — copied verbatim by patcher
│   │   ├── unity_bridge_basic/.../Scripts/
│   │   │   ├── FlunityBridge.cs                       # SHRINK — keep static class only
│   │   │   └── FlunityBridgeBehaviour.cs              # NEW — the MonoBehaviour
│   │   └── flutter_webgl_bridge/.../Scripts/
│   │       ├── FlunityBridge.cs                       # SHRINK
│   │       └── FlunityBridgeBehaviour.cs              # NEW
│   └── test/
│       ├── platform/{ios_ats_patcher,android_cleartext_patcher}_test.dart  # NEW
│       ├── webgl/prepare_webgl_test.dart                # NEW
│       └── bridge/index_html_patcher_test.dart          # MODIFY — covers wrap behavior
└── (no changes to flunity_bridge or other parts of the workspace)
```

---

## Phase 1 — Split `FlunityBridge.cs` (D1)

Unity rule: a `MonoBehaviour` subclass must live in a file whose name matches the class. `FlunityBridge.cs` currently contains both `FlunityBridge` (static) and `FlunityBridgeBehaviour` (MonoBehaviour); the second isn't visible in Unity's Add Component dialog.

### Task 1: Split in `unity_bridge_basic`

Two files at `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Scripts/`:

**`FlunityBridgeBehaviour.cs`** (new):

```csharp
using UnityEngine;

namespace Flunity {
    /// <summary>
    /// Bridge between Flutter (host) and Unity (guest). Place a single GameObject
    /// named "[FlunityBridge]" in your scene and attach this MonoBehaviour to it.
    /// Unity's SendMessage will dispatch inbound JSON to ReceiveFromFlutter.
    /// </summary>
    [DisallowMultipleComponent]
    public class FlunityBridgeBehaviour : MonoBehaviour {
        public static FlunityBridgeBehaviour Instance { get; private set; }

        void Awake() {
            if (Instance != null && Instance != this) {
                Destroy(this);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        // Called by the JS shim via unityInstance.SendMessage("[FlunityBridge]", "ReceiveFromFlutter", json)
        public void ReceiveFromFlutter(string json) {
            FlunityBridge.DispatchInbound(json);
        }
    }
}
```

**`FlunityBridge.cs`** (replace existing content with just the static class):

```csharp
using System;
using UnityEngine;

#if UNITY_WEBGL && !UNITY_EDITOR
using System.Runtime.InteropServices;
#endif

namespace Flunity {
    /// <summary>
    /// Static API for game code. Subscribe to <see cref="OnMessage"/> for inbound
    /// messages, call <see cref="Send{T}"/> or <see cref="SendRaw"/> to talk back
    /// to Flutter. WebGL-only — no-ops in the editor and on other platforms.
    /// </summary>
    public static class FlunityBridge {
        public static event Action<string, string> OnMessage;

#if UNITY_WEBGL && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void FlunityPostMessage(string json);
#endif

        public static void Send<T>(string type, T payload) {
            string payloadJson = JsonUtility.ToJson(payload ?? default(T));
            SendRaw(type, payloadJson);
        }

        public static void SendRaw(string type, string payloadJson) {
            string envelope = "{\"type\":\"" + EscapeJson(type) + "\",\"payload\":" +
                              (string.IsNullOrEmpty(payloadJson) ? "{}" : payloadJson) + "}";
#if UNITY_WEBGL && !UNITY_EDITOR
            FlunityPostMessage(envelope);
#else
            Debug.Log("[FlunityBridge] (no-op outside WebGL) " + envelope);
#endif
        }

        internal static void DispatchInbound(string json) {
            string type = ExtractStringField(json, "type");
            string payload = ExtractObjectField(json, "payload") ?? "{}";

            if (type == "ping") {
                string nonce = ExtractStringField(payload, "nonce") ?? "";
                SendRaw("pong", "{\"nonce\":\"" + EscapeJson(nonce) + "\"}");
            }

            OnMessage?.Invoke(type, payload);
        }

        // ---- Mini JSON helpers ----

        static string ExtractStringField(string json, string field) {
            string key = "\"" + field + "\"";
            int idx = json.IndexOf(key, StringComparison.Ordinal);
            if (idx < 0) return null;
            int colon = json.IndexOf(':', idx + key.Length);
            if (colon < 0) return null;
            int quote = json.IndexOf('"', colon + 1);
            if (quote < 0) return null;
            int end = quote + 1;
            var sb = new System.Text.StringBuilder();
            while (end < json.Length) {
                char c = json[end];
                if (c == '\\' && end + 1 < json.Length) { sb.Append(json[end + 1]); end += 2; continue; }
                if (c == '"') break;
                sb.Append(c);
                end += 1;
            }
            return sb.ToString();
        }

        static string ExtractObjectField(string json, string field) {
            string key = "\"" + field + "\"";
            int idx = json.IndexOf(key, StringComparison.Ordinal);
            if (idx < 0) return null;
            int colon = json.IndexOf(':', idx + key.Length);
            if (colon < 0) return null;
            int braceStart = json.IndexOf('{', colon);
            if (braceStart < 0) return null;
            int depth = 0;
            for (int i = braceStart; i < json.Length; i++) {
                char c = json[i];
                if (c == '{') depth++;
                else if (c == '}') { depth--; if (depth == 0) return json.Substring(braceStart, i - braceStart + 1); }
            }
            return null;
        }

        static string EscapeJson(string s) {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new System.Text.StringBuilder(s.Length + 8);
            foreach (char c in s) {
                switch (c) {
                    case '\\': sb.Append("\\\\"); break;
                    case '"':  sb.Append("\\\""); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20) sb.AppendFormat("\\u{0:x4}", (int)c);
                        else sb.Append(c);
                        break;
                }
            }
            return sb.ToString();
        }
    }
}
```

### Task 2: Mirror in `flutter_webgl_bridge`

Same two files at `packages/flunity_cli/templates/flutter_webgl_bridge/unity_project/Assets/Scripts/`. Just copy.

### Task 3: Commit Phase 1

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Scripts packages/flunity_cli/templates/flutter_webgl_bridge/unity_project/Assets/Scripts
git -C /Volumes/Transcend/Projects/flunity commit -m "fix(flunity_cli): split FlunityBridge.cs so Unity Add Component finds the MonoBehaviour"
```

---

## Phase 2 — Drop incomplete platform stubs (D9, D10 prep)

The shipped `Info.plist` and `AndroidManifest.xml` are minimal and break `flutter create`'s ability to generate proper iOS/Android projects.

### Task 4: Delete

```bash
rm -rf /Volumes/Transcend/Projects/flunity/packages/flunity_cli/templates/flutter_webgl_bridge/flutter_app/ios
rm /Volumes/Transcend/Projects/flunity/packages/flunity_cli/templates/flutter_webgl_bridge/flutter_app/android/app/src/main/AndroidManifest.xml
```

KEEP `flutter_app/android/app/src/main/res/xml/network_security_config.xml` — `flutter create` doesn't touch this path, so the file lives happily next to whatever `flutter create` generates.

### Task 5: Commit

```bash
git -C /Volumes/Transcend/Projects/flunity add -u packages/flunity_cli/templates/flutter_webgl_bridge
git -C /Volumes/Transcend/Projects/flunity commit -m "fix(flunity_cli): drop incomplete iOS/Android stubs from template (will be flutter-create'd then patched)"
```

---

## Phase 3 — iOS ATS + Android cleartext patchers (D9, D10)

Two new files that idempotently merge our customizations into `flutter create`'s output.

### Task 6: `lib/src/platform/ios_ats_patcher.dart`

```dart
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
      throw FormatException('Info.plist missing top-level </dict>: $infoPlistPath');
    }
    final patched = content.substring(0, closer) + _atsBlock + content.substring(closer);
    file.writeAsStringSync(patched);
    return true;
  }
}
```

### Task 7: `lib/src/platform/android_cleartext_patcher.dart`

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// Patches an Android `AndroidManifest.xml` to add a `networkSecurityConfig`
/// reference, and copies a network_security_config.xml into res/xml/.
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
    final manifestPath = p.join(androidAppDir, 'src', 'main', 'AndroidManifest.xml');
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
      throw FormatException(
        'AndroidManifest.xml missing <application> tag: $manifestPath',
      );
    }
    final injectionPoint = match.end;
    final patched = '${manifestContent.substring(0, injectionPoint)}'
        'android:networkSecurityConfig="@xml/network_security_config"\n        '
        '${manifestContent.substring(injectionPoint)}';
    manifest.writeAsStringSync(patched);
    return true;
  }
}
```

### Task 8: Tests

**`test/platform/ios_ats_patcher_test.dart`:**

```dart
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
```

**`test/platform/android_cleartext_patcher_test.dart`:**

```dart
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
    File(p.join(androidAppDir, 'src', 'main', 'AndroidManifest.xml'))
        .writeAsStringSync('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="my_app"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
''');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('adds networkSecurityConfig attribute and writes the xml file', () {
    final modified = AndroidCleartextPatcher.patch(androidAppDir: androidAppDir);
    expect(modified, isTrue);

    final manifest = File(
      p.join(androidAppDir, 'src', 'main', 'AndroidManifest.xml'),
    ).readAsStringSync();
    expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));

    final xml = File(
      p.join(androidAppDir, 'src', 'main', 'res', 'xml', 'network_security_config.xml'),
    );
    expect(xml.existsSync(), isTrue);
    expect(xml.readAsStringSync(), contains('127.0.0.1'));
    expect(xml.readAsStringSync(), contains('10.0.2.2'));
  });

  test('idempotent on second run', () {
    AndroidCleartextPatcher.patch(androidAppDir: androidAppDir);
    final modified2 = AndroidCleartextPatcher.patch(androidAppDir: androidAppDir);
    expect(modified2, isFalse);
  });
}
```

### Task 9: Commit Phase 3

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/platform packages/flunity_cli/test/platform
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): iOS ATS and Android cleartext patchers (idempotent merges)"
```

---

## Phase 4 — `flunity create` runs `flutter create` + patchers + override + pub get (D2, D3, D6)

### Task 10: Add a `process_runner` helper

`lib/src/utils/process_runner.dart`:

```dart
import 'dart:io';

/// Runs an external process. Throws [ProcessException] on non-zero exit.
/// Streams stdout/stderr to the parent process so the user sees progress
/// (especially for `flutter create` and `flutter pub get`, which are slow).
Future<void> runOrThrow(
  String executable,
  List<String> args, {
  required String workingDirectory,
  Map<String, String>? environment,
}) async {
  final result = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: true, // helps when flutter is a shell wrapper
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await result.exitCode;
  if (code != 0) {
    throw ProcessException(executable, args, '$executable exited with $code', code);
  }
}
```

### Task 11: Modify `create_command.dart`

Add the post-render flow. The full updated `run()` body:

```dart
@override
Future<int> run() async {
  // ... existing arg validation unchanged ...

  // ... existing render call unchanged through `progress.complete('Rendered $appName/')` ...

  // NEW: post-render flow.
  final flutterAppDir = p.join(outputPath, 'flutter_app');

  // Step 1: flutter create (generates ios/, android/, macos/, etc.)
  _logger.info('');
  final flutterCreate = _logger.progress('Generating platform projects via flutter create');
  try {
    await runOrThrow(
      'flutter',
      [
        'create',
        '--org', argResults!['org'] as String,
        '--project-name', appName,
        '--platforms', 'ios,android,macos',
        '.',
      ],
      workingDirectory: flutterAppDir,
    );
    flutterCreate.complete('Platform projects ready');
  } catch (e) {
    flutterCreate.fail();
    _logger.err('flutter create failed: $e');
    return 70;
  }

  // Step 2: iOS ATS + Android cleartext patchers.
  IosAtsPatcher.patch(p.join(flutterAppDir, 'ios', 'Runner', 'Info.plist'));
  AndroidCleartextPatcher.patch(
    androidAppDir: p.join(flutterAppDir, 'android', 'app'),
  );

  // Step 3: pubspec_overrides.yaml — point at the local flunity_bridge so
  // `flutter pub get` doesn't fail until flunity_bridge is on pub.dev.
  final bridgePath = (argResults!['bridge-path'] as String?) ??
      _detectFlunityBridgePath();
  if (bridgePath != null) {
    final overridesFile = File(p.join(flutterAppDir, 'pubspec_overrides.yaml'));
    overridesFile.writeAsStringSync('''
dependency_overrides:
  flunity_bridge:
    path: $bridgePath
''');
  } else {
    _logger.warn(
      'flunity_bridge path not detected; flutter pub get may fail. '
      'Re-run with --bridge-path /absolute/path/to/flunity_bridge.',
    );
  }

  // Step 4: flutter pub get.
  final pubGet = _logger.progress('flutter pub get');
  try {
    await runOrThrow('flutter', ['pub', 'get'], workingDirectory: flutterAppDir);
    pubGet.complete('Dependencies resolved');
  } catch (e) {
    pubGet.fail();
    _logger.err('flutter pub get failed: $e');
    return 70;
  }

  // ... existing "Created $appName/. Next steps:" message unchanged ...
  return 0;
}

/// Tries to find the local `flunity_bridge` package — useful when running
/// from a path-source-activated CLI. Walks up from Platform.script looking
/// for `packages/flunity_bridge/pubspec.yaml`.
String? _detectFlunityBridgePath() {
  Directory? dir = Directory(p.dirname(Platform.script.toFilePath()));
  for (var i = 0; i < 8 && dir != null; i++) {
    final candidate = p.join(dir.path, 'packages', 'flunity_bridge');
    if (Directory(candidate).existsSync() &&
        File(p.join(candidate, 'pubspec.yaml')).existsSync()) {
      return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
```

Also add an `--bridge-path` option to the constructor's argParser:

```dart
..addOption(
  'bridge-path',
  help: 'Absolute path to a local flunity_bridge package. '
      'When omitted, Flunity tries to auto-detect from the activated CLI location. '
      'Once flunity_bridge is on pub.dev, this option will go away.',
);
```

Add imports at the top of the file:

```dart
import 'package:flunity_cli/src/platform/ios_ats_patcher.dart';
import 'package:flunity_cli/src/platform/android_cleartext_patcher.dart';
import 'package:flunity_cli/src/utils/process_runner.dart';
```

### Task 12: Drop the bridge-template's `lib/main.dart` use of `unity/unity_webgl_screen.dart`?

No — `lib/main.dart` already imports `unity/unity_webgl_screen.dart` from the rendered template. Nothing to change here.

### Task 13: Update `create_command_test.dart`

The existing tests use a fake template + a `templateRootOverride`. They DON'T invoke `flutter create` (because they don't have a real Flutter SDK in the test environment). So we need a way to skip the post-render flow in tests.

Add a constructor parameter `bool skipFlutterCreate = false` (only for tests). Tests pass `true`.

```dart
CreateCommand({
  required Logger logger,
  String? templateRootOverride,
  bool skipFlutterCreate = false,
})  : _logger = logger,
      _templateRootOverride = templateRootOverride,
      _skipFlutterCreate = skipFlutterCreate {
  // ... existing argParser ...
}

final bool _skipFlutterCreate;
```

Inside `run()`, gate the post-render flow on `!_skipFlutterCreate`:

```dart
if (!_skipFlutterCreate) {
  // Step 1: flutter create
  // Step 2: patchers
  // Step 3: pubspec_overrides.yaml
  // Step 4: flutter pub get
}
```

Update each test to pass `skipFlutterCreate: true`. The existing tests still verify rendering correctness. Add ONE NEW test that exercises only the patchers + pubspec_overrides on a hand-built fake `ios/Runner/Info.plist` and `android/app/...`. Leave the actual `flutter create` invocation untested in unit tests; rely on manual verification + the e2e smoke test.

Concretely, add this test:

```dart
test('post-render: writes pubspec_overrides.yaml when bridge-path provided', () async {
  // ... build fake template with bridge dir ...
  final fakeBridge = Directory(p.join(tmp.path, 'fake_flunity_bridge'))..createSync();
  File(p.join(fakeBridge.path, 'pubspec.yaml')).writeAsStringSync('name: flunity_bridge');

  final runner = CommandRunner<int>('flunity', 'test')
    ..addCommand(CreateCommand(
      logger: Logger(level: Level.error),
      templateRootOverride: fakeTemplateRoot.path,
      skipFlutterCreate: true,
    ));

  final originalCwd = Directory.current;
  Directory.current = tmp;
  try {
    final code = await runner.run([
      'create', '--bridge-path', fakeBridge.path, 'my_app'
    ]);
    expect(code, 0);
    // Bridge-path was provided — but flutter create was skipped, so
    // there's no flutter_app/ to write the override into. Skip this part
    // unless skipFlutterCreate also still runs the override step.
    // For Plan D, the override step runs regardless of skipFlutterCreate
    // (it doesn't depend on flutter create's output). Adjust the gate.
  } finally {
    Directory.current = originalCwd;
  }
});
```

Actually given the complexity, simpler: have `skipFlutterCreate` skip the entire post-render flow as a unit. Don't mix concerns. The unit test only exercises the renderer; the patchers and override generation get unit-tested in their own modules (Tasks 6-9 covered patchers; the override file write is too trivial for a dedicated test).

So just gate everything post-render on `!_skipFlutterCreate`. Tests pass that flag. No new test in `create_command_test.dart`.

### Task 14: Commit Phase 4

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/utils/process_runner.dart packages/flunity_cli/lib/src/commands/create_command.dart packages/flunity_cli/test/commands/create_command_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli)!: create runs flutter create + patches platforms + writes overrides + pub get"
```

---

## Phase 5 — `prepareWebGLBuild` + auto-prepare in serve/copy/prepare (D4, D5, D8)

The Unity WebGL build's `index.html` needs three things to make the bridge work:

1. The `flunity_bridge.js` shim file must be next to `index.html`.
2. `<script src="flunity_bridge.js"></script>` must be in `<head>`.
3. The body's `createUnityInstance(...).then((unityInstance) => {...})` must call `window.flunity.ready(unityInstance)` inside that `.then`.

Today's `index_html_patcher.dart` only does (2). Plan D fixes (1) and (3) and runs the whole thing automatically on every `flunity webgl serve` and `flunity webgl copy`.

### Task 15: Replace `index_html_patcher.dart` (or rename to `webgl_index_patcher.dart`)

Keep the file at `packages/flunity_cli/lib/src/bridge/index_html_patcher.dart`. Replace its content with a richer version:

```dart
const String _marker = '<!-- flunity:patch v1 -->';
const String _scriptInjection = '$_marker\n<script src="flunity_bridge.js"></script>';

/// Patches a Unity WebGL `index.html` to load the Flunity bridge JS shim and
/// call `window.flunity.ready(unityInstance)` once Unity has booted.
///
/// Idempotent: skipping if the marker is already present.
String patchUnityIndexHtml(String html) {
  if (html.contains(_marker)) return html;

  // 1. Insert the script tag right before </head>.
  final headIdx = html.indexOf('</head>');
  if (headIdx >= 0) {
    html = '${html.substring(0, headIdx)}$_scriptInjection\n  ${html.substring(headIdx)}';
  } else {
    // Fall back to before </body>; if neither exists, append.
    final bodyIdx = html.indexOf('</body>');
    if (bodyIdx >= 0) {
      html = '${html.substring(0, bodyIdx)}$_scriptInjection\n  ${html.substring(bodyIdx)}';
    } else {
      html = '$html\n$_scriptInjection\n';
    }
  }

  // 2. Insert window.flunity.ready(unityInstance) inside Unity's
  //    createUnityInstance(...).then((unityInstance) => { ... })
  //
  // Unity 2022 LTS template uses the pattern:
  //
  //   .then((unityInstance) => {
  //     document.querySelector("#unity-loading-bar").style.display = "none";
  //     ...
  //   })
  //
  // We append the ready() call as the LAST statement of that block.
  final thenPattern = RegExp(
    r'\.then\(\(unityInstance\)\s*=>\s*\{',
    multiLine: true,
  );
  final match = thenPattern.firstMatch(html);
  if (match == null) {
    // Couldn't find the createUnityInstance.then — leave it; the user can
    // wire ready() manually if they have a non-standard template.
    return html;
  }

  // Find the matching closing brace of the .then block.
  final openBrace = match.end - 1; // points at '{'
  var depth = 1;
  var i = openBrace + 1;
  while (i < html.length && depth > 0) {
    final c = html[i];
    if (c == '{') depth++;
    else if (c == '}') depth--;
    if (depth == 0) break;
    i++;
  }
  if (i >= html.length) return html; // unmatched, give up

  // Insert before the closing brace.
  const readyCall = '''

                if (window.flunity && typeof window.flunity.ready === 'function') {
                  window.flunity.ready(unityInstance);
                }
              ''';
  return '${html.substring(0, i)}$readyCall${html.substring(i)}';
}
```

### Task 16: New `lib/src/webgl/prepare_webgl.dart`

```dart
import 'dart:io';

import 'package:flunity_cli/src/bridge/index_html_patcher.dart';
import 'package:path/path.dart' as p;

class PrepareSummary {
  PrepareSummary({
    required this.shimCopied,
    required this.indexHtmlPatched,
  });
  final bool shimCopied;
  final bool indexHtmlPatched;
}

/// Prepares a Unity WebGL build directory for the Flunity bridge by:
///
///   1. Copying `flunity_bridge.js` from the project's
///      `unity_project/Assets/Plugins/WebGL/` into the build dir next to
///      `index.html`.
///   2. Patching `index.html` to load the shim AND call
///      `window.flunity.ready(unityInstance)`.
///
/// Idempotent and safe to run on every serve/copy.
Future<PrepareSummary> prepareWebGLBuild({
  required String buildDir,
  required String shimSourcePath,
}) async {
  var shimCopied = false;
  var patched = false;

  final shimSrc = File(shimSourcePath);
  final shimDst = File(p.join(buildDir, 'flunity_bridge.js'));
  if (shimSrc.existsSync()) {
    if (!shimDst.existsSync() ||
        shimDst.readAsStringSync() != shimSrc.readAsStringSync()) {
      shimDst.writeAsStringSync(shimSrc.readAsStringSync());
      shimCopied = true;
    }
  }

  final indexHtml = File(p.join(buildDir, 'index.html'));
  if (indexHtml.existsSync()) {
    final original = indexHtml.readAsStringSync();
    final updated = patchUnityIndexHtml(original);
    if (updated != original) {
      indexHtml.writeAsStringSync(updated);
      patched = true;
    }
  }

  return PrepareSummary(shimCopied: shimCopied, indexHtmlPatched: patched);
}
```

### Task 17: Tests for `prepareWebGLBuild` + revised `index_html_patcher_test.dart`

**`test/webgl/prepare_webgl_test.dart`:**

```dart
import 'dart:io';

import 'package:flunity_cli/src/webgl/prepare_webgl.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('flunity_prepare_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('copies shim and patches index.html on first run', () async {
    final shim = File(p.join(tmp.path, 'flunity_bridge.js'))
      ..writeAsStringSync('// shim');
    final buildDir = Directory(p.join(tmp.path, 'WebGL'))..createSync();
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync(
      '<html><head></head><body><script>'
      'createUnityInstance(canvas, config).then((unityInstance) => { x(); });'
      '</script></body></html>',
    );

    final result = await prepareWebGLBuild(
      buildDir: buildDir.path,
      shimSourcePath: shim.path,
    );

    expect(result.shimCopied, isTrue);
    expect(result.indexHtmlPatched, isTrue);
    expect(File(p.join(buildDir.path, 'flunity_bridge.js')).existsSync(), isTrue);
    final patched =
        File(p.join(buildDir.path, 'index.html')).readAsStringSync();
    expect(patched, contains('flunity:patch v1'));
    expect(patched, contains('flunity_bridge.js'));
    expect(patched, contains('window.flunity.ready(unityInstance)'));
  });

  test('idempotent on second run', () async {
    final shim = File(p.join(tmp.path, 'flunity_bridge.js'))
      ..writeAsStringSync('// shim');
    final buildDir = Directory(p.join(tmp.path, 'WebGL'))..createSync();
    File(p.join(buildDir.path, 'index.html')).writeAsStringSync(
      '<html><head></head><body><script>'
      'createUnityInstance(canvas, config).then((unityInstance) => { x(); });'
      '</script></body></html>',
    );

    await prepareWebGLBuild(buildDir: buildDir.path, shimSourcePath: shim.path);
    final r2 = await prepareWebGLBuild(
        buildDir: buildDir.path, shimSourcePath: shim.path);
    expect(r2.shimCopied, isFalse);
    expect(r2.indexHtmlPatched, isFalse);
  });
}
```

**Update `test/bridge/index_html_patcher_test.dart`** with two new tests:

```dart
test('inserts window.flunity.ready inside createUnityInstance.then', () {
  const original = '''<!doctype html>
<html><head></head><body>
<script>
  createUnityInstance(canvas, config).then((unityInstance) => {
    document.querySelector("#bar").style.display = "none";
  });
</script>
</body></html>
''';
  final patched = patchUnityIndexHtml(original);
  expect(patched, contains('window.flunity.ready(unityInstance)'));
});

test('handles missing createUnityInstance gracefully', () {
  const original = '<html><head></head><body></body></html>';
  final patched = patchUnityIndexHtml(original);
  expect(patched, contains('flunity:patch v1'));
  expect(patched, isNot(contains('window.flunity.ready')));
});
```

Plus the existing two tests stay.

### Task 18: Hook `prepareWebGLBuild` into `WebGLCommand`

Modify `lib/src/commands/webgl_command.dart`:

- Add a new `_PrepareSubcommand` (so `flunity webgl prepare` works standalone).
- In `_ServeSubcommand.run()`, call `prepareWebGLBuild(...)` BEFORE starting the dev server.
- In `_CopySubcommand.run()`, call `prepareWebGLBuild(...)` BEFORE copying.

The shim source lives at `<unity_project>/Assets/Plugins/WebGL/flunity_bridge.js`. Resolved from `project.paths.unityProject`.

Add to `WebGLCommand`'s constructor:

```dart
addSubcommand(_PrepareSubcommand(logger: _logger));
```

Add `_PrepareSubcommand`:

```dart
class _PrepareSubcommand extends Command<int> {
  _PrepareSubcommand({required Logger logger}) : _logger = logger;
  final Logger _logger;

  @override
  String get name => 'prepare';
  @override
  String get description =>
      'Patch the Unity WebGL build (index.html + JS shim) for the Flunity bridge.';

  @override
  Future<int> run() async {
    final project = _loadProjectOrDie(_logger);
    if (project == null) return 64;
    final summary = await prepareWebGLBuild(
      buildDir: project.paths.unityBuild,
      shimSourcePath: p.join(
        project.paths.unityProject,
        'Assets', 'Plugins', 'WebGL', 'flunity_bridge.js',
      ),
    );
    if (summary.shimCopied) {
      _logger.info('Copied flunity_bridge.js into build dir');
    }
    if (summary.indexHtmlPatched) {
      _logger.info('Patched index.html with bridge wiring');
    }
    if (!summary.shimCopied && !summary.indexHtmlPatched) {
      _logger.info('Build already prepared.');
    }
    return 0;
  }
}
```

In `_ServeSubcommand.run()`, immediately after the `indexHtml.existsSync()` check, before `UnityDevServer.start(...)`:

```dart
final shimSourcePath = p.join(
  project.paths.unityProject,
  'Assets', 'Plugins', 'WebGL', 'flunity_bridge.js',
);
await prepareWebGLBuild(
  buildDir: project.paths.unityBuild,
  shimSourcePath: shimSourcePath,
);
```

Same for `_CopySubcommand.run()`.

Imports to add at the top of `webgl_command.dart`:

```dart
import 'package:flunity_cli/src/webgl/prepare_webgl.dart';
```

### Task 19: Update doctor's `unity_build_check.dart`

When the build exists but the marker isn't present, give a hint to run `flunity webgl prepare` (although serve/copy auto-prepare, an explicit hint helps debugging).

```dart
@override
Future<CheckResult> run() async {
  final indexHtml = File(p.join(project.paths.unityBuild, 'index.html'));
  if (!indexHtml.existsSync()) {
    return CheckResult.warn(
      'No build at ${project.paths.unityBuild}/index.html',
      hint: 'Build WebGL from Unity into ${project.paths.unityBuild}/.',
    );
  }
  final content = indexHtml.readAsStringSync();
  if (!content.contains('flunity:patch')) {
    return CheckResult.ok(
      'Found at ${indexHtml.path} (will auto-prepare on `flunity webgl serve`)',
    );
  }
  return CheckResult.ok('Found at ${indexHtml.path} (prepared)');
}
```

### Task 20: Commit Phase 5

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/bridge/index_html_patcher.dart packages/flunity_cli/lib/src/webgl/prepare_webgl.dart packages/flunity_cli/lib/src/commands/webgl_command.dart packages/flunity_cli/lib/src/doctor/checks/unity_build_check.dart packages/flunity_cli/test/webgl/prepare_webgl_test.dart packages/flunity_cli/test/bridge/index_html_patcher_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): prepareWebGLBuild auto-runs on serve/copy/prepare"
```

---

## Phase 6 — Polish, push, PR

### Task 21: Update CHANGELOGs

Append under `## [Unreleased]` in repo `CHANGELOG.md`:

```markdown
- `flunity create` now invokes `flutter create`, patches iOS ATS / Android cleartext, writes `pubspec_overrides.yaml`, and runs `flutter pub get` so the generated project is ready to `flutter run` immediately.
- `flunity webgl serve` and `flunity webgl copy` auto-prepare the Unity WebGL build (copy `flunity_bridge.js`, patch `index.html` to call `window.flunity.ready(unityInstance)`).
- New `flunity webgl prepare` subcommand for explicit invocation.
- `Content-Encoding: gzip` / `br` is now set for direct `.gz` / `.br` requests in the dev server (Unity's compressed-build URL convention).
- Split `FlunityBridge.cs` into `FlunityBridge.cs` + `FlunityBridgeBehaviour.cs` so Unity's Add Component dialog finds the MonoBehaviour.
- Dropped the incomplete custom `Info.plist` and `AndroidManifest.xml` from templates — `flutter create` now generates the standard versions and Flunity merges its customizations on top.
```

Append to `packages/flunity_cli/CHANGELOG.md`:

```markdown
- `create` now runs `flutter create`, patches platforms, writes overrides, runs pub get.
- `webgl serve|copy` auto-prepare the Unity build.
- New `webgl prepare` subcommand.
- New `--bridge-path` flag on `create` for path-based flunity_bridge installs.
```

### Task 22: Run all checks

```bash
cd /Volumes/Transcend/Projects/flunity
melos run analyze
melos run format-check
melos run test
```

If `format-check` fails, run `melos run format` and commit `style: apply dart format` separately before the CHANGELOG commit.

### Task 23: Commit + push

```bash
git -C /Volumes/Transcend/Projects/flunity add CHANGELOG.md packages/flunity_cli/CHANGELOG.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: Plan D CHANGELOG entries"
git -C /Volumes/Transcend/Projects/flunity push -u origin feat/plan-d-fixes
```

### Task 24: Open PR

```bash
gh pr create --base main --head feat/plan-d-fixes \
  --title "Plan D: real-world fixes (flutter create, auto-prepare, ATS/cleartext patchers, FlunityBridge split)" \
  --body "$(cat <<'EOF'
## Summary

Discovered by walking a real user through the full flow on macOS + iOS simulator. Ten things needed fixing.

- **D1**: split FlunityBridge.cs so Unity's Add Component dialog finds the MonoBehaviour.
- **D2**: \`flunity create\` invokes \`flutter create\` to generate iOS / Android / macOS platform projects.
- **D3**: \`flunity create\` writes a \`pubspec_overrides.yaml\` pointing at the local flunity_bridge (auto-detect or \`--bridge-path\`).
- **D4 / D8**: \`index_html_patcher\` now copies the JS shim into the build dir AND wraps \`createUnityInstance().then(...)\` to call \`window.flunity.ready(unityInstance)\`.
- **D5**: \`flunity webgl serve\` and \`flunity webgl copy\` auto-prepare the Unity build (every Unity rebuild is automatically re-patched).
- **D6**: \`flunity create\` runs \`flutter pub get\` so the project is immediately runnable.
- **D7**: dev server sets \`Content-Encoding: gzip\` / \`br\` on direct \`.gz\` / \`.br\` requests.
- **D9 / D10**: dropped the incomplete custom \`Info.plist\` and \`AndroidManifest.xml\` from templates; \`flutter create\` generates standard versions and Flunity \`IosAtsPatcher\` / \`AndroidCleartextPatcher\` merge customizations on top.
- New \`flunity webgl prepare\` subcommand for explicit invocation.

## Test plan

- [ ] \`melos run analyze\` clean.
- [ ] \`melos run format-check\` clean.
- [ ] \`melos run test\` passes.
- [ ] After path-source activate: \`flunity create my_test_app\` produces a project where \`cd flutter_app && flutter run\` works on the iOS simulator with no manual edits.
- [ ] Tap the Ping icon → see \`Pong: <nonce>\` in the overlay.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Definition of done for Plan D

- [ ] All ten fixes (D1-D10) landed.
- [ ] No manual file editing required for `flunity create my_app && cd my_app/flutter_app && flutter run` to work.
- [ ] Tests pass; analyze + format-check clean.
- [ ] PR opened, ready for the user to retest end-to-end.
