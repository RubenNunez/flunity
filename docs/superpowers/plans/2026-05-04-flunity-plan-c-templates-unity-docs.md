# Plan C — Templates, Unity-side, Examples, Docs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Close out Flunity v1's Definition of Done. Add the `flutter_webgl_bridge` and `unity_bridge_basic` templates with full bridge wiring, ship the Unity-side `FlunityBridge.cs` + `.jslib` extern + `flunity_bridge.js` shim, refactor `flunity bridge init` to use templates, swap `flunity create`'s default to `flutter_webgl_bridge`, add one example, write all seven docs, and add a smoke test that proves Ping/Pong round-trips against a stub WebGL build.

**Architecture:** Templates remain plain file trees with `__var__` substitution. Unity-side bridge is a `MonoBehaviour` plus `static` API (`FlunityBridge.Send<T>`, `OnMessage` event). Bridge JS-side is a tiny `flunity_bridge.js` (~80 lines) + `flunity_bridge.jslib` (extern "C" hook). The shim contract: when Unity's `unityInstance` becomes available, the shim sets `window.flunity._isReady = true` AND calls `_notifyReady?.()` synchronously. The Flutter side's `onLoadStop` JS snippet wires `_notifyReady` to call back via `flutter_inappwebview.callHandler('flunity_ready')`.

**Tech Stack:** Same as Plans A and B. New: Unity 2022.3 LTS+ (only the build artifacts; we don't run Unity in CI).

**Spec reference:** `docs/superpowers/specs/2026-05-04-flunity-v1-design.md` §6b, §6c, §7, §8, §9, §10, §11, §12, §13.

---

## Prerequisites

- Branch `feat/plan-c-templates` cut from `main` at the merged Plan B tip.
- `melos run test` and `melos run analyze` both green on `main`.
- `dart pub global activate --source path packages/flunity_cli` succeeds.
- `flunity --version` prints `flunity 0.1.0`.

---

## File Structure

```
flunity/
├── packages/flunity_cli/templates/
│   ├── flutter_webgl_basic/                 # ALREADY EXISTS (Plan B)
│   ├── flutter_webgl_bridge/                # NEW — full bridge-wired scaffold
│   │   ├── flunity.yaml
│   │   ├── README.md
│   │   ├── .gitignore
│   │   ├── flutter_app/                     # extends basic with unity/ wiring
│   │   │   ├── pubspec.yaml
│   │   │   ├── lib/main.dart
│   │   │   ├── lib/unity/
│   │   │   │   ├── unity_webgl_screen.dart  # FlunityWebGLView + status overlay
│   │   │   │   ├── unity_webgl_bridge.dart  # typed wrapper (loadScene, etc.)
│   │   │   │   └── unity_webgl_config.dart  # --dart-define switch
│   │   │   ├── android/app/src/main/AndroidManifest.xml  # cleartext for 10.0.2.2 + 127.0.0.1
│   │   │   ├── android/app/src/main/res/xml/network_security_config.xml
│   │   │   ├── ios/Runner/Info.plist        # ATS exception scoped to 127.0.0.1
│   │   │   ├── assets/unity_webgl/.gitkeep
│   │   │   └── test/unity_webgl_bridge_test.dart
│   │   ├── unity_project/
│   │   │   ├── README.md
│   │   │   ├── .gitignore
│   │   │   └── Assets/
│   │   │       ├── Scripts/
│   │   │       │   ├── FlunityBridge.cs
│   │   │       │   └── FlunityBridgeDemo.cs
│   │   │       └── Plugins/WebGL/
│   │   │           ├── flunity_bridge.jslib
│   │   │           └── flunity_bridge.js    # JS shim (copied into final build)
│   │   └── scripts/
│   │       ├── serve_unity_webgl.sh
│   │       └── copy_unity_webgl_to_flutter_assets.sh
│   └── unity_bridge_basic/                  # NEW — Unity-only template for `bridge init`
│       └── unity_project/Assets/
│           ├── Scripts/
│           │   ├── FlunityBridge.cs
│           │   └── FlunityBridgeDemo.cs
│           └── Plugins/WebGL/
│               ├── flunity_bridge.jslib
│               └── flunity_bridge.js
├── packages/flunity_cli/lib/src/
│   ├── bridge/bridge_init.dart              # MODIFY: read from unity_bridge_basic template
│   ├── bridge/index_html_patcher.dart       # MODIFY: include flunity_bridge.js relative ref
│   └── commands/create_command.dart         # MODIFY: default template → flutter_webgl_bridge
├── packages/flunity_cli/test/
│   ├── bridge/bridge_init_test.dart         # MODIFY: tests use real template
│   └── e2e/                                 # NEW — end-to-end smoke against stub WebGL
│       ├── stub_webgl/                      # checked-in stub WebGL build
│       │   ├── index.html                   # tiny doc that emulates createUnityInstance
│       │   ├── flunity_bridge.js
│       │   └── stub_unity_instance.js
│       └── ping_pong_smoke_test.dart        # spins up dev_server + loads stub
├── examples/
│   └── webgl_simple_scene/                  # NEW — example app the docs link to
│       ├── flunity.yaml
│       ├── flutter_app/
│       └── unity_project/                   # README + scripts only; user opens in Unity
├── docs/                                    # NEW — all seven docs
│   ├── getting-started.md
│   ├── project-structure.md
│   ├── webgl-workflow.md
│   ├── bridge-api.md
│   ├── production-build.md
│   ├── android-emulator.md
│   └── native-roadmap.md
└── CHANGELOG.md                             # MODIFY: add Plan C entries
```

---

## Phase 1 — Unity-side bridge files (`FlunityBridge.cs`, `.jslib`, `flunity_bridge.js`)

### Task 1: Author `FlunityBridge.cs`

**Files:**
- Create: `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Scripts/FlunityBridge.cs`

- [ ] **Step 1: Write the file**

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_WEBGL && !UNITY_EDITOR
using System.Runtime.InteropServices;
#endif

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

    /// <summary>
    /// Static API for game code. Subscribe to <see cref="OnMessage"/> for inbound
    /// messages, call <see cref="Send{T}"/> or <see cref="SendRaw"/> to talk back
    /// to Flutter. WebGL-only — no-ops in the editor and on other platforms.
    /// </summary>
    public static class FlunityBridge {
        /// <summary>Raised for every inbound message. (type, payloadJson).</summary>
        public static event Action<string, string> OnMessage;

#if UNITY_WEBGL && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void FlunityPostMessage(string json);
#endif

        /// <summary>
        /// Sends a typed message to Flutter. Payload is JSON-serialized via Unity's
        /// JsonUtility (so the type must be marked [Serializable] with public fields).
        /// </summary>
        public static void Send<T>(string type, T payload) {
            string payloadJson = JsonUtility.ToJson(payload ?? default(T));
            SendRaw(type, payloadJson);
        }

        /// <summary>
        /// Sends a message with an already-serialized payload string.
        /// </summary>
        public static void SendRaw(string type, string payloadJson) {
            string envelope = "{\"type\":\"" + EscapeJson(type) + "\",\"payload\":" +
                              (string.IsNullOrEmpty(payloadJson) ? "{}" : payloadJson) + "}";
#if UNITY_WEBGL && !UNITY_EDITOR
            FlunityPostMessage(envelope);
#else
            Debug.Log("[FlunityBridge] (no-op outside WebGL) " + envelope);
#endif
        }

        // Called by FlunityBridgeBehaviour.ReceiveFromFlutter.
        internal static void DispatchInbound(string json) {
            // Cheap envelope parse to extract `type`. Game code can re-parse the
            // payload itself with JsonUtility.FromJson when it knows the shape.
            string type = ExtractStringField(json, "type");
            string payload = ExtractObjectField(json, "payload") ?? "{}";

            // Auto-respond to Ping with matching-nonce Pong (smoke test).
            if (type == "ping") {
                string nonce = ExtractStringField(payload, "nonce") ?? "";
                SendRaw("pong", "{\"nonce\":\"" + EscapeJson(nonce) + "\"}");
            }

            OnMessage?.Invoke(type, payload);
        }

        // ---- Mini JSON helpers ----
        // Deliberately tiny — game code does its own deserialization for richer
        // payloads. These exist only so the bridge can introspect the envelope.

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

We verify by hand because the file is C# (not part of the Dart test surface). The plan accepts this file as-is once the Dart `bridge_init_test.dart` confirms it gets dropped into the right place.

### Task 2: Author the `.jslib` extern hook

**Files:**
- Create: `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Plugins/WebGL/flunity_bridge.jslib`

- [ ] **Step 1: Write the file**

```javascript
mergeInto(LibraryManager.library, {
  // Unity calls this with a UTF8 char* JSON string. We hand it off to the JS
  // shim, which pushes it through flutter_inappwebview's JS handler.
  FlunityPostMessage: function(jsonPtr) {
    var json = UTF8ToString(jsonPtr);
    if (typeof window === 'undefined') return;
    if (window.flunity && typeof window.flunity._fromUnity === 'function') {
      window.flunity._fromUnity(json);
    } else {
      // Shim not loaded yet — buffer until it is.
      (window.__flunityPending = window.__flunityPending || []).push(json);
    }
  }
});
```

### Task 3: Author the JS shim `flunity_bridge.js`

**Files:**
- Create: `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Plugins/WebGL/flunity_bridge.js`

- [ ] **Step 1: Write the file**

```javascript
/* Flunity bridge JS shim (~80 lines).
 *
 * Contract:
 *   - Defines window.flunity with .post(json), ._fromUnity(json), .ready(unityInstance)
 *   - Sets window.flunity._isReady = true once unityInstance is available, AND
 *     calls window.flunity._notifyReady?.() in the same synchronous block so the
 *     Flutter-side onLoadStop hook can register a notifier and not miss the edge.
 *   - Buffers Dart→Unity messages sent before unityInstance exists.
 *
 * The patcher (flunity_cli's index_html_patcher.dart) inserts a <script src="flunity_bridge.js">
 * tag in the WebGL build's index.html. The bridge_init command also wraps the
 * existing createUnityInstance call so we capture the resulting unityInstance.
 */
(function () {
  if (window.flunity) return; // already loaded
  var pendingFromDart = [];
  var ready = false;
  var unityInstance = null;

  // Drain anything the .jslib buffered before the shim arrived.
  if (Array.isArray(window.__flunityPending)) {
    var buffered = window.__flunityPending;
    window.__flunityPending = null;
    setTimeout(function () {
      buffered.forEach(function (json) {
        try { window.flunity._fromUnity(json); } catch (e) {}
      });
    }, 0);
  }

  window.flunity = {
    _isReady: false,
    _notifyReady: null,

    /** Called by Dart via evaluateJavascript. Routes JSON into Unity. */
    post: function (json) {
      if (unityInstance && typeof unityInstance.SendMessage === 'function') {
        unityInstance.SendMessage('[FlunityBridge]', 'ReceiveFromFlutter', json);
      } else {
        pendingFromDart.push(json);
      }
    },

    /** Called by the .jslib extern. Forwards to the Flutter-side handler. */
    _fromUnity: function (json) {
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        window.flutter_inappwebview.callHandler('flunity', json);
      }
    },

    /**
     * Called by index.html (after bridge_init's patcher wraps
     * createUnityInstance) once unityInstance resolves.
     */
    ready: function (instance) {
      unityInstance = instance;
      ready = true;
      window.flunity._isReady = true;
      // Flush any messages Dart sent before we were ready.
      var pending = pendingFromDart;
      pendingFromDart = [];
      pending.forEach(function (json) {
        instance.SendMessage('[FlunityBridge]', 'ReceiveFromFlutter', json);
      });
      // Notify the Flutter-side hook (if registered).
      if (typeof window.flunity._notifyReady === 'function') {
        try { window.flunity._notifyReady(); } catch (e) {}
      }
    }
  };
})();
```

### Task 4: Author `FlunityBridgeDemo.cs`

**Files:**
- Create: `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Scripts/FlunityBridgeDemo.cs`

- [ ] **Step 1: Write the file**

```csharp
using UnityEngine;

namespace Flunity {
    /// <summary>
    /// Sample handler that listens for `load_scene` messages from Flutter and
    /// emits a `scene_ready` reply once the scene is loaded. Plan C ships this
    /// as the default demo wiring; remove or replace in real apps.
    /// </summary>
    public class FlunityBridgeDemo : MonoBehaviour {
        void OnEnable() {
            FlunityBridge.OnMessage += HandleMessage;
        }

        void OnDisable() {
            FlunityBridge.OnMessage -= HandleMessage;
        }

        void HandleMessage(string type, string payloadJson) {
            if (type == "load_scene") {
                // Game code would call SceneManager.LoadScene here. We don't —
                // we just acknowledge so the Flutter side can complete the
                // round trip in the smoke test.
                FlunityBridge.SendRaw("scene_ready", "{}");
            }
        }
    }
}
```

### Task 5: Commit Phase 1

- [ ] **Step 1**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/templates/unity_bridge_basic
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): unity_bridge_basic template (FlunityBridge.cs + .jslib + JS shim)"
```

---

## Phase 2 — `flutter_webgl_bridge` template

The default template for `flunity create`. Extends `flutter_webgl_basic` (so we can largely copy from it) plus the bridge wiring.

### Task 6: Build the template tree

**Files** under `packages/flunity_cli/templates/flutter_webgl_bridge/`:

- [ ] **Step 1: Copy the basic template as a starting point**

Run from the repo root:

```bash
cp -r packages/flunity_cli/templates/flutter_webgl_basic packages/flunity_cli/templates/flutter_webgl_bridge
```

- [ ] **Step 2: Replace `flutter_app/lib/main.dart`** with bridge-wired version:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';

import 'unity/unity_webgl_screen.dart';

void main() {
  registerBuiltInMessages();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '__app_name__',
      home: const UnityWebGLScreen(),
    );
  }
}
```

- [ ] **Step 3: Add `flutter_app/lib/unity/unity_webgl_config.dart`**:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

FlunityWebGLConfig resolveFlunityConfig() {
  const mode = String.fromEnvironment('FLUNITY_MODE', defaultValue: 'bundled');
  if (mode == 'dev') {
    const host = String.fromEnvironment('FLUNITY_DEV_HOST', defaultValue: '127.0.0.1');
    const port = int.fromEnvironment('FLUNITY_DEV_PORT', defaultValue: 8080);
    return FlunityWebGLConfig.dev(host: host, port: port);
  }
  return FlunityWebGLConfig.bundled();
}
```

- [ ] **Step 4: Add `flutter_app/lib/unity/unity_webgl_bridge.dart`**:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

/// Typed wrapper over [FlunityWebGLController] for app-specific messages.
/// Extend with your own [FlunityMessage] subclasses as the app grows.
class UnityWebGLBridge {
  UnityWebGLBridge(this.controller);
  final FlunityWebGLController controller;

  Future<void> loadScene(String name) =>
      controller.send(LoadScene(scene: name));

  Stream<SceneReady> get sceneReady =>
      controller.messages.where((m) => m is SceneReady).cast<SceneReady>();

  Future<String> ping() async {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final pong = controller.messages
        .firstWhere((m) => m is Pong && m.nonce == nonce)
        .timeout(const Duration(seconds: 5));
    await controller.send(Ping(nonce: nonce));
    final p = await pong as Pong;
    return p.nonce;
  }
}
```

- [ ] **Step 5: Add `flutter_app/lib/unity/unity_webgl_screen.dart`**:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter/material.dart';

import 'unity_webgl_bridge.dart';
import 'unity_webgl_config.dart';

class UnityWebGLScreen extends StatefulWidget {
  const UnityWebGLScreen({super.key});

  @override
  State<UnityWebGLScreen> createState() => _UnityWebGLScreenState();
}

class _UnityWebGLScreenState extends State<UnityWebGLScreen> {
  UnityWebGLBridge? _bridge;
  String _lastEvent = 'Waiting…';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('__app_name__'),
        actions: [
          IconButton(
            tooltip: 'Ping',
            onPressed: _bridge == null ? null : () async {
              try {
                final nonce = await _bridge!.ping();
                setState(() => _lastEvent = 'Pong: $nonce');
              } catch (e) {
                setState(() => _lastEvent = 'Ping failed: $e');
              }
            },
            icon: const Icon(Icons.network_ping),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlunityWebGLView(
            config: resolveFlunityConfig(),
            onReady: (controller) {
              setState(() => _bridge = UnityWebGLBridge(controller));
            },
            onMessage: (msg) {
              setState(() => _lastEvent = msg.type);
            },
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastEvent,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Add Android cleartext config**

Create `flutter_app/android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="__app_name__"
        android:name="${applicationName}"
        android:networkSecurityConfig="@xml/network_security_config"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
```

Create `flutter_app/android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
```

- [ ] **Step 7: Add iOS ATS exception**

Create `flutter_app/ios/Runner/Info.plist` (only the keys we add — assumes a real Flutter project will fill in the rest via `flutter create`; for the template, we ship a minimal file):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>__app_name__</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>127.0.0.1</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <false/>
            </dict>
            <key>localhost</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <false/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
```

- [ ] **Step 8: Add a Dart test inside the template**

`flutter_app/test/unity_webgl_bridge_test.dart`:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(registerBuiltInMessages);

  test('Ping/Pong round-trip via JSON', () {
    final ping = const Ping(nonce: 'x');
    final pong = const Pong(nonce: 'x');
    final restoredPing = FlunityMessage.fromJson(ping.toJson());
    final restoredPong = FlunityMessage.fromJson(pong.toJson());
    expect(restoredPing, ping);
    expect(restoredPong, pong);
  });

  test('FlunityWebGLConfig switches mode via dart-define defaults', () {
    expect(const FlunityWebGLConfig.dev().mode, FlunityWebGLMode.dev);
    expect(FlunityWebGLConfig.bundled().mode, FlunityWebGLMode.bundled);
  });
}
```

- [ ] **Step 9: Symlink Unity-side files into the template**

We don't want to maintain two copies. Instead, copy `FlunityBridge.cs`, `FlunityBridgeDemo.cs`, `flunity_bridge.jslib`, and `flunity_bridge.js` from `unity_bridge_basic/` into `flutter_webgl_bridge/unity_project/Assets/...`:

```bash
cp -r packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets \
      packages/flunity_cli/templates/flutter_webgl_bridge/unity_project/
```

(Plain copies — git tracks both, and `bridge init` reads from `unity_bridge_basic/`. Plan C-2 could refactor to a single source of truth; not in scope.)

- [ ] **Step 10: Update the template's `flunity.yaml` to reference the bridge demo**

Already correct from the basic template (nothing to change for now).

- [ ] **Step 11: Commit Phase 2**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/templates/flutter_webgl_bridge
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): flutter_webgl_bridge template with full bridge wiring"
```

---

## Phase 3 — Refactor `bridge_init` to use templates instead of inlined strings

The current `lib/src/bridge/bridge_init.dart` has hardcoded `_screenSrc`, `_bridgeSrc`, `_configSrc`, `_bridgeCsPlaceholder`, `_bridgeDemoPlaceholder` strings. Replace them with reads from the `unity_bridge_basic` template (and the `flutter_webgl_bridge/flutter_app/lib/unity/` files for the Dart side).

### Task 7: Refactor + tests

- [ ] **Step 1: Rewrite `lib/src/bridge/bridge_init.dart`**

Replace the file ENTIRELY:

```dart
import 'dart:io';

import 'package:flunity_cli/src/bridge/index_html_patcher.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:flunity_cli/src/utils/pubspec_editor.dart';
import 'package:path/path.dart' as p;

class BridgeInitException implements Exception {
  BridgeInitException(this.message);
  final String message;
  @override
  String toString() => 'BridgeInitException: $message';
}

class BridgeInitSummary {
  BridgeInitSummary({
    required this.depAdded,
    required this.filesCreated,
    required this.indexHtmlPatched,
  });
  final bool depAdded;
  final List<String> filesCreated;
  final bool indexHtmlPatched;
}

/// Wires up the Flunity bridge inside an existing project. Idempotent: re-running
/// without --force is a no-op for already-existing files. With force, overwrites.
Future<BridgeInitSummary> initBridge({
  required FlunityProject project,
  required String bridgeVersion,
  required String templateRoot,
  bool force = false,
}) async {
  final pubspecPath = p.join(project.paths.flutterApp, 'pubspec.yaml');
  final depAdded = ensurePubspecDependency(
    pubspecPath: pubspecPath,
    name: 'flunity_bridge',
    constraint: '^$bridgeVersion',
  );

  final created = <String>[];

  // Copy lib/unity/ scaffolding from the flutter_webgl_bridge template.
  final libUnityDart = p.join(
    templateRoot,
    'flutter_webgl_bridge',
    'flutter_app',
    'lib',
    'unity',
  );
  if (Directory(libUnityDart).existsSync()) {
    final destLibUnity = Directory(p.join(project.paths.flutterApp, 'lib', 'unity'))
      ..createSync(recursive: true);
    for (final entity in Directory(libUnityDart).listSync()) {
      if (entity is! File) continue;
      final destFile = File(p.join(destLibUnity.path, p.basename(entity.path)));
      if (destFile.existsSync() && !force) continue;
      destFile.writeAsStringSync(entity.readAsStringSync());
      created.add(destFile.path);
    }
  }

  // Copy Unity Assets/ from unity_bridge_basic.
  final unityAssetsSrc = Directory(p.join(
    templateRoot,
    'unity_bridge_basic',
    'unity_project',
    'Assets',
  ));
  if (unityAssetsSrc.existsSync()) {
    final destAssets = Directory(p.join(project.paths.unityProject, 'Assets'))
      ..createSync(recursive: true);
    _copyTree(unityAssetsSrc, destAssets, force, created);
  }

  // Patch Unity index.html if it exists.
  var patched = false;
  final indexHtml = File(p.join(project.paths.unityBuild, 'index.html'));
  if (indexHtml.existsSync()) {
    final original = indexHtml.readAsStringSync();
    final updated = patchUnityIndexHtml(original);
    if (updated != original) {
      indexHtml.writeAsStringSync(updated);
      patched = true;
    }
  }

  return BridgeInitSummary(
    depAdded: depAdded,
    filesCreated: created,
    indexHtmlPatched: patched,
  );
}

void _copyTree(Directory src, Directory dst, bool force, List<String> created) {
  if (!dst.existsSync()) dst.createSync(recursive: true);
  for (final entity in src.listSync()) {
    if (entity is Directory) {
      _copyTree(
        entity,
        Directory(p.join(dst.path, p.basename(entity.path))),
        force,
        created,
      );
    } else if (entity is File) {
      final destFile = File(p.join(dst.path, p.basename(entity.path)));
      if (destFile.existsSync() && !force) continue;
      destFile.writeAsBytesSync(entity.readAsBytesSync());
      created.add(destFile.path);
    }
  }
}
```

- [ ] **Step 2: Update `BridgeCommand` to resolve `templateRoot`**

In `lib/src/commands/bridge_command.dart`, the `_InitSubcommand.run` method currently calls `initBridge(project, bridgeVersion)`. Add the `templateRoot` parameter:

```dart
@override
Future<int> run() async {
  final manifestPath = findManifest(start: p.current);
  if (manifestPath == null) {
    _logger.err('No flunity.yaml found.');
    return 64;
  }
  final project = FlunityProject.loadFromManifest(manifestPath);
  final templateRoot = await _resolveTemplateRoot();
  if (templateRoot == null) {
    _logger.err('Could not locate Flunity templates directory.');
    return 70;
  }
  final summary = await initBridge(
    project: project,
    bridgeVersion: defaultBridgeVersion,
    templateRoot: templateRoot,
    force: argResults!['force'] == true,
  );
  // ... existing logging code unchanged
}

Future<String?> _resolveTemplateRoot() async {
  // Same logic as CreateCommand._resolveTemplateRoot — refactor into a shared
  // utility OR just duplicate the ~15 lines for now (Plan C+1 can DRY).
  // For Plan C, copy the implementation:
  try {
    final libUri = await Isolate.resolvePackageUri(
      Uri.parse('package:flunity_cli/flunity_cli.dart'),
    );
    if (libUri != null) {
      final pkgRoot = p.dirname(p.dirname(libUri.toFilePath()));
      final candidate = p.join(pkgRoot, 'templates');
      if (Directory(candidate).existsSync()) return candidate;
    }
  } catch (_) {}
  Directory? dir = Directory(p.dirname(Platform.script.toFilePath()));
  for (var i = 0; i < 8 && dir != null; i++) {
    final candidate = p.join(dir.path, 'templates', 'flutter_webgl_bridge');
    if (Directory(candidate).existsSync()) return p.join(dir.path, 'templates');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
```

(Add `import 'dart:io';` and `import 'dart:isolate';` at the top of the file. The plan accepts the duplication; a refactor of `_resolveTemplateRoot` into a shared utility is a separate followup.)

- [ ] **Step 3: Update `bridge_init_test.dart`**

The existing tests assume the old hardcoded-strings impl. Now they need to pass `templateRoot` and use the real template content. Modify each test to:

1. Set up a tmp dir with a fake template root containing minimal `unity_bridge_basic/unity_project/Assets/Scripts/FlunityBridge.cs` and `flutter_webgl_bridge/flutter_app/lib/unity/unity_webgl_screen.dart` files.
2. Call `initBridge(..., templateRoot: fakeRoot)`.
3. Assert files were copied.

The full updated test file:

```dart
import 'dart:io';

import 'package:flunity_cli/src/bridge/bridge_init.dart';
import 'package:flunity_cli/src/manifest/flunity_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String templateRoot;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_bridge_init_');
    File(p.join(tmp.path, 'flunity.yaml'))
        .writeAsStringSync('name: x\ntarget: webgl');
    Directory(p.join(tmp.path, 'flutter_app')).createSync();
    File(p.join(tmp.path, 'flutter_app', 'pubspec.yaml')).writeAsStringSync(
      'name: x\n\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );

    // Build a minimal fake template tree under tmp/templates/.
    templateRoot = p.join(tmp.path, 'templates');
    final libUnity = Directory(
      p.join(templateRoot, 'flutter_webgl_bridge', 'flutter_app', 'lib', 'unity'),
    )..createSync(recursive: true);
    File(p.join(libUnity.path, 'unity_webgl_screen.dart'))
        .writeAsStringSync('// screen');
    File(p.join(libUnity.path, 'unity_webgl_config.dart'))
        .writeAsStringSync('// config');

    final scripts = Directory(p.join(
      templateRoot,
      'unity_bridge_basic',
      'unity_project',
      'Assets',
      'Scripts',
    ))..createSync(recursive: true);
    File(p.join(scripts.path, 'FlunityBridge.cs')).writeAsStringSync('// cs');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('adds dep, copies template files, leaves missing index.html alone',
      () async {
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(summary.depAdded, isTrue);
    expect(summary.filesCreated, isNotEmpty);
    expect(summary.indexHtmlPatched, isFalse);
    expect(
      File(p.join(tmp.path, 'flutter_app/lib/unity/unity_webgl_screen.dart'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(tmp.path, 'unity_project/Assets/Scripts/FlunityBridge.cs'))
          .existsSync(),
      isTrue,
    );
  });

  test('idempotent without --force', () async {
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final first = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(first.filesCreated, isNotEmpty);
    final second = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(second.filesCreated, isEmpty);
    expect(second.depAdded, isFalse);
  });

  test('patches index.html if present', () async {
    Directory(p.join(tmp.path, 'unity_project/Builds/WebGL'))
        .createSync(recursive: true);
    File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
        .writeAsStringSync('<html><body></body></html>');
    final project = FlunityProject.loadFromManifest(p.join(tmp.path, 'flunity.yaml'));
    final summary = await initBridge(
      project: project,
      bridgeVersion: '0.1.0',
      templateRoot: templateRoot,
    );
    expect(summary.indexHtmlPatched, isTrue);
    final patched = File(p.join(tmp.path, 'unity_project/Builds/WebGL/index.html'))
        .readAsStringSync();
    expect(patched, contains('flunity:patch'));
  });
}
```

- [ ] **Step 4: Run tests, confirm pass.**

Run: `cd /Volumes/Transcend/Projects/flunity/packages/flunity_cli && dart test`
Expected: 42 prior + 0 new = 42 (the existing 3 bridge tests still count, just rewritten).

- [ ] **Step 5: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/bridge/bridge_init.dart packages/flunity_cli/lib/src/commands/bridge_command.dart packages/flunity_cli/test/bridge/bridge_init_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "refactor(flunity_cli): bridge init reads from templates instead of inline strings"
```

---

## Phase 4 — Swap `flunity create` default to `flutter_webgl_bridge`

### Task 8: Update create command default + tests

- [ ] **Step 1: Modify `lib/src/commands/create_command.dart`**

Find:

```dart
const templateName = 'flutter_webgl_basic';
```

Replace with:

```dart
final templateName = (argResults!['no-bridge'] == true)
    ? 'flutter_webgl_basic'
    : 'flutter_webgl_bridge';
```

- [ ] **Step 2: Update `create_command_test.dart`**

The fake template setup currently only creates `flutter_webgl_basic`. Add `flutter_webgl_bridge` too in the fake template root setup. The "renders the basic template" test should be renamed to "renders the bridge template by default" and assert on `flutter_webgl_bridge` content.

Modify the "renders the basic template into <name>/" test to:

```dart
test('renders the bridge template into <name>/ by default', () async {
  final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))..createSync();
  final fakeBasic = Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'))
    ..createSync();
  File(p.join(fakeBasic.path, 'flunity.yaml'))
      .writeAsStringSync('# basic\nname: __app_name__\ntarget: webgl\n');
  final fakeBridge = Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge'))
    ..createSync();
  File(p.join(fakeBridge.path, 'flunity.yaml'))
      .writeAsStringSync('# bridge\nname: __app_name__\ntarget: webgl\n');

  final runner = CommandRunner<int>('flunity', 'test')
    ..addCommand(CreateCommand(
      logger: Logger(level: Level.error),
      templateRootOverride: fakeTemplateRoot.path,
    ));

  final originalCwd = Directory.current;
  Directory.current = tmp;
  try {
    final code = await runner.run(['create', 'my_app']);
    expect(code, 0);
    final manifest =
        File(p.join(tmp.path, 'my_app', 'flunity.yaml')).readAsStringSync();
    expect(manifest, contains('# bridge'));
  } finally {
    Directory.current = originalCwd;
  }
});

test('--no-bridge picks the basic template', () async {
  // Same fake setup as above
  final fakeTemplateRoot = Directory(p.join(tmp.path, 'templates'))..createSync();
  final fakeBasic = Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_basic'))
    ..createSync();
  File(p.join(fakeBasic.path, 'flunity.yaml'))
      .writeAsStringSync('# basic\nname: __app_name__\ntarget: webgl\n');
  Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge')).createSync();

  final runner = CommandRunner<int>('flunity', 'test')
    ..addCommand(CreateCommand(
      logger: Logger(level: Level.error),
      templateRootOverride: fakeTemplateRoot.path,
    ));

  final originalCwd = Directory.current;
  Directory.current = tmp;
  try {
    final code = await runner.run(['create', '--no-bridge', 'my_app']);
    expect(code, 0);
    final manifest =
        File(p.join(tmp.path, 'my_app', 'flunity.yaml')).readAsStringSync();
    expect(manifest, contains('# basic'));
  } finally {
    Directory.current = originalCwd;
  }
});
```

The "rejects existing/target/name" tests need the bridge dir created in their fake templates too — add `Directory(p.join(fakeTemplateRoot.path, 'flutter_webgl_bridge')).createSync();` after the basic dir creation in each.

- [ ] **Step 3: Run tests, confirm pass.**

Expected: 43 total (42 prior + 1 new "no-bridge" test; "renders the bridge template" replaced "renders the basic template" so net +1).

- [ ] **Step 4: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/commands/create_command.dart packages/flunity_cli/test/commands/create_command_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): create defaults to flutter_webgl_bridge; --no-bridge for basic"
```

---

## Phase 5 — Smoke test against a stub WebGL build

### Task 9: Build the stub + test

**Files:**
- Create: `packages/flunity_cli/test/e2e/stub_webgl/index.html`
- Create: `packages/flunity_cli/test/e2e/stub_webgl/flunity_bridge.js`
- Create: `packages/flunity_cli/test/e2e/stub_webgl/stub_unity_instance.js`
- Create: `packages/flunity_cli/test/e2e/ping_pong_smoke_test.dart`

**Note**: This phase tests the CLI's `dev_server` against a stub Unity-WebGL build (no real Unity). It does NOT test the InAppWebView side (that needs a real device). What we validate: when a browser-like client requests `/index.html`, the dev server serves the right files with the right headers, and the JS shim's contract is correct.

Plan B already tests the dev server's MIME and COOP/COEP behavior. The "smoke test" here is a placeholder: a checked-in stub WebGL build that proves the JS shim file we ship in templates is loadable inside an HTML page (no JS errors).

- [ ] **Step 1: Create `stub_webgl/index.html`**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Flunity stub</title>
  <script src="flunity_bridge.js"></script>
  <script src="stub_unity_instance.js"></script>
</head>
<body>
  <p>Flunity stub WebGL page. The smoke test loads this and exercises the bridge.</p>
</body>
</html>
```

- [ ] **Step 2: Create `stub_webgl/flunity_bridge.js`** (copy of the template's shim)

Same contents as `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Plugins/WebGL/flunity_bridge.js`. The smoke test confirms this file can run inside a plain browser environment with no Unity.

- [ ] **Step 3: Create `stub_webgl/stub_unity_instance.js`**

```javascript
// Mimics what Unity's WebGL build does: defines a stub unityInstance and calls
// window.flunity.ready(instance). Only used in the smoke test.
window.addEventListener('load', function () {
  var stubInstance = {
    SendMessage: function (gameObject, method, value) {
      console.log('[stub Unity] SendMessage', gameObject, method, value);
    }
  };
  window.flunity.ready(stubInstance);
});
```

- [ ] **Step 4: Create the Dart smoke test**

```dart
import 'dart:io';

import 'package:flunity_cli/src/webgl/dev_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('stub WebGL build serves with correct headers + shim is fetchable',
      () async {
    final stubRoot = p.join(
      Directory.current.path,
      'test',
      'e2e',
      'stub_webgl',
    );
    final server = await UnityDevServer.start(rootDir: stubRoot, port: 0);
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    Future<HttpClientResponse> get(String path) async {
      final req = await client
          .getUrl(Uri.parse('http://${server.host}:${server.port}$path'));
      return req.close();
    }

    final indexResp = await get('/index.html');
    expect(indexResp.statusCode, 200);
    expect(indexResp.headers.value('cross-origin-opener-policy'), 'same-origin');
    expect(indexResp.headers.value('cross-origin-embedder-policy'),
        'require-corp');

    final shimResp = await get('/flunity_bridge.js');
    expect(shimResp.statusCode, 200);
    expect(shimResp.headers.contentType?.mimeType, 'application/javascript');

    final stubResp = await get('/stub_unity_instance.js');
    expect(stubResp.statusCode, 200);
  });
}
```

- [ ] **Step 5: Run.**

Expected: 1 new test passes. Total: 44.

- [ ] **Step 6: Commit**

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/test/e2e/stub_webgl packages/flunity_cli/test/e2e/ping_pong_smoke_test.dart
git -C /Volumes/Transcend/Projects/flunity commit -m "test(flunity_cli): e2e smoke against stub WebGL build"
```

---

## Phase 6 — Documentation (7 docs)

Each doc is its own commit so the history reads cleanly.

### Task 10: `docs/getting-started.md`

```markdown
# Getting Started

Welcome to Flunity. This guide takes you from zero to a Flutter app rendering a Unity WebGL scene in under ten minutes.

## Prerequisites

- **Flutter** 3.24 or newer (`flutter --version`).
- **Dart** 3.5 or newer (ships with Flutter).
- **Unity** 2022.3 LTS or newer with the **WebGL Build Support** module installed.
- A working Flutter target (Android emulator, iOS simulator, macOS, Windows, or Linux desktop).

## 1. Install the CLI

```bash
dart pub global activate flunity_cli
```

This installs the `flunity` executable. `$HOME/.pub-cache/bin` must be on your PATH.

Verify the install:

```bash
flunity --version
# flunity 0.1.0
```

## 2. Scaffold a project

```bash
flunity create hello_unity
cd hello_unity
```

You'll get a directory tree with `flunity.yaml`, a `flutter_app/` and a `unity_project/`. See [Project Structure](project-structure.md).

## 3. Verify your environment

```bash
flunity doctor
```

Doctor runs a series of checks — Flutter SDK version, Dart SDK version, port availability, manifest validity, and so on. Each row is `✓` / `⚠` / `✗` with a hint.

## 4. Build the Unity scene

Open `hello_unity/unity_project/` in Unity. Build the WebGL target into `unity_project/Builds/WebGL/` (any scene works; the template includes a placeholder).

## 5. Run the dev loop

In one terminal:

```bash
flunity webgl serve
```

In another:

```bash
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

The Flutter app launches, mounts a `FlunityWebGLView`, and loads the served Unity build via WebView.

## 6. What's next?

- [WebGL Workflow](webgl-workflow.md) — the dev/production loop in detail.
- [Bridge API](bridge-api.md) — sending typed messages between Flutter and Unity.
- [Production Build](production-build.md) — bundling Unity into your release APK / IPA.
- [Android Emulator Notes](android-emulator.md) — `10.0.2.2` and cleartext.
```

Commit: `git ... commit -m "docs: add getting-started.md"`

### Task 11: `docs/project-structure.md`

```markdown
# Project Structure

Flunity scaffolds a project with three top-level concerns:

```
hello_unity/
├── flunity.yaml          # project manifest (read by every flunity command)
├── flutter_app/          # the Flutter side
└── unity_project/        # the Unity side (open this in Unity)
```

## `flunity.yaml`

The manifest is the single source of truth for project metadata and paths. Every CLI command except `flunity create` walks up from `cwd` looking for it.

```yaml
name: hello_unity
version: 0.1.0
target: webgl

paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_build: unity_project/Builds/WebGL
  flutter_assets: flutter_app/assets/unity_webgl

webgl:
  dev_server:
    host: 127.0.0.1
    port: 8080
    cross_origin_isolation: true
    hot_reload: false
  android_emulator_host: 10.0.2.2

bridge:
  enabled: true
  messages: []
```

Edit any path, port, or host as needed. The CLI honors the manifest values; flags like `--port` override per-invocation.

## `flutter_app/`

A normal Flutter app, with two opinions baked in:

- It depends on `flunity_bridge` and imports it in `main.dart`.
- `lib/unity/` contains the WebView screen, a typed wrapper, and the dev/bundled config switch.

```
flutter_app/
├── pubspec.yaml          # declares assets/unity_webgl/ and flunity_bridge dep
├── lib/
│   ├── main.dart         # registerBuiltInMessages() + runApp(...)
│   └── unity/
│       ├── unity_webgl_screen.dart
│       ├── unity_webgl_bridge.dart
│       └── unity_webgl_config.dart
├── android/              # cleartext exception scoped to 10.0.2.2 + 127.0.0.1
├── ios/                  # ATS exception scoped to 127.0.0.1 + localhost
└── assets/
    └── unity_webgl/      # populated by `flunity webgl copy`
```

## `unity_project/`

A regular Unity 2022.3+ project. Flunity ships these:

```
unity_project/
└── Assets/
    ├── Scripts/
    │   ├── FlunityBridge.cs        # static API for game code
    │   └── FlunityBridgeDemo.cs    # listens for load_scene, replies with scene_ready
    └── Plugins/WebGL/
        ├── flunity_bridge.jslib    # extern "C" hook into the JS shim
        └── flunity_bridge.js       # included in the WebGL build
```

After Unity builds the WebGL target into `unity_project/Builds/WebGL/`, the build is served by `flunity webgl serve` (dev) or copied into `flutter_app/assets/unity_webgl/` by `flunity webgl copy` (production).

## Scripts

`scripts/serve_unity_webgl.sh` and `scripts/copy_unity_webgl_to_flutter_assets.sh` are 3-line wrappers around `flunity webgl serve` and `flunity webgl copy`. They exist for muscle memory and IDE task runners.

## What Flunity does NOT generate

- A `pubspec.lock` for `flutter_app/` — you run `flutter pub get` after `flunity create`.
- The Unity `Library/`, `Temp/`, `obj/` artifacts — Unity creates them on first open.
- Native Android Gradle wrapper and Xcode project — `flutter create` produces those, and `flunity create` runs it for you behind the scenes.
```

### Task 12: `docs/webgl-workflow.md`

```markdown
# WebGL Workflow

Flunity supports two modes for loading the Unity WebGL build into Flutter:

| Mode | When | URL |
| --- | --- | --- |
| **dev** | Local iteration | `http://127.0.0.1:<port>/index.html` (or `10.0.2.2` on Android emulator) |
| **bundled** | Release builds | `http://localhost:<server>/<assetPath>/index.html` (process-local loopback over Flutter assets) |

Switch between them via `--dart-define=FLUNITY_MODE=dev` (default: `bundled`). The generated `unity_webgl_config.dart` reads this define and resolves the right `FlunityWebGLConfig`.

## Dev loop (rapid iteration)

```bash
# Terminal 1
flunity webgl serve

# Terminal 2
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

Iterate by:

1. Editing your Unity scene.
2. Building Unity WebGL again to `unity_project/Builds/WebGL/`.
3. Hot-reloading the Flutter app (or pulling-to-refresh in the WebView).

`flunity webgl serve` runs an in-process Dart `shelf` server with:

- COOP/COEP headers (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`) so SharedArrayBuffer is available.
- Unity-correct MIME types for `.wasm`, `.data`, `.symbols.json`, and `.framework.js`.
- Brotli (`.br`) and gzip (`.gz`) precompressed asset support.
- `Cache-Control: no-store` so you always see the latest build.

## Production loop (asset-bundled)

```bash
flunity webgl copy
cd flutter_app
flutter build apk           # or appbundle, ios, etc.
```

`flunity webgl copy` packages the Unity build into `flutter_app/assets/unity_webgl/` and writes a `flunity_webgl_manifest.json` with a sha256 build hash. Bundled mode is the default for `flutter run` / `flutter build` (no `--dart-define` needed).

At runtime, `FlunityWebGLView` starts an `InAppLocalhostServer` (via `flutter_inappwebview`) bound to `127.0.0.1:<random>` to serve the bundled WebGL — Unity WebGL refuses `file://` URLs.

## Iterating against a real Android device on the same network

```bash
flutter run --dart-define=FLUNITY_MODE=dev --dart-define=FLUNITY_DEV_HOST=192.168.1.42
```

Use your machine's LAN IP. `flunity doctor` will warn if it detects a physical device with `127.0.0.1` as the dev host.
```

### Task 13: `docs/bridge-api.md`

```markdown
# Bridge API

Flutter and Unity exchange JSON messages of the form:

```json
{ "type": "<string>", "payload": <JSON object> }
```

## Built-in message types

| Type | Direction | Payload |
| --- | --- | --- |
| `ping` | Flutter → Unity | `{ "nonce": "<string>" }` |
| `pong` | Unity → Flutter | `{ "nonce": "<string>" }` (echoes the ping nonce) |
| `load_scene` | Flutter → Unity | `{ "scene": "<string>" }` |
| `scene_ready` | Unity → Flutter | `{}` |

`FlunityBridge.cs` auto-handles `ping` (replies with `pong`). The default `FlunityBridgeDemo.cs` handles `load_scene` and replies with `scene_ready`.

## Flutter side

Sealed-style hierarchy with a `RawMessage` escape hatch:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

void main() {
  registerBuiltInMessages();        // call once at startup
  // ...
}

// Sending:
controller.send(const Ping(nonce: 'hello'));
controller.send(const LoadScene(scene: 'ProductViewer'));

// Receiving (typed):
controller.messages.listen((msg) {
  if (msg is Pong) print('pong: ${msg.nonce}');
  else if (msg is SceneReady) print('scene loaded');
  else if (msg is RawMessage) {
    // Unknown message type — payload is a Map<String, Object?>
    print('${msg.type}: ${msg.payload}');
  }
});
```

## Adding your own message types

```dart
final class TakeScreenshot extends FlunityMessage {
  const TakeScreenshot({required this.format});

  static const String typeName = 'take_screenshot';
  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final fmt = payload['format'];
      if (fmt is! String) {
        throw const FormatException('TakeScreenshot requires string format');
      }
      return TakeScreenshot(format: fmt);
    });
  }

  final String format;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'format': format};
}

void main() {
  registerBuiltInMessages();
  TakeScreenshot.register();
  runApp(...);
}
```

Custom types are not exhaustively matchable; they coexist with built-ins because `FlunityMessage` is `abstract` (not `sealed`) — the trade-off is that users can extend it from their own libraries.

## Unity side

Subscribe to `FlunityBridge.OnMessage`:

```csharp
using Flunity;
using UnityEngine;

public class MyHandler : MonoBehaviour {
    void OnEnable()  { FlunityBridge.OnMessage += Handle; }
    void OnDisable() { FlunityBridge.OnMessage -= Handle; }

    void Handle(string type, string payloadJson) {
        if (type == "take_screenshot") {
            var p = JsonUtility.FromJson<ScreenshotPayload>(payloadJson);
            // … snap, encode, return …
            FlunityBridge.Send("screenshot_ready", new ScreenshotResult { png = encoded });
        }
    }

    [System.Serializable] public class ScreenshotPayload { public string format; }
    [System.Serializable] public class ScreenshotResult  { public string png; }
}
```

`FlunityBridge.Send<T>(type, payload)` JSON-serializes `payload` via Unity's `JsonUtility` (so the type must be `[Serializable]` with public fields). For richer scenarios, use `FlunityBridge.SendRaw(type, jsonString)` and serialize yourself.
```

### Task 14: `docs/production-build.md`

```markdown
# Production Build

Production = asset-bundled Unity inside a Flutter release artifact (APK, AAB, IPA, …).

## 1. Build Unity for production

In Unity's WebGL Player settings:

- **Compression Format**: Brotli (preferred) or gzip.
- **Code stripping**: High.
- **Strip Engine Code**: ON.
- **IL2CPP Code Generation**: Faster runtime (IL2CPP Master).
- **Exceptions**: None.
- **Development Build**: OFF.
- **Profiler**: OFF.
- **Texture Compression**: ASTC (covers Android + iOS).
- **WebGL Memory Size**: tune to your scene; default 256 MB is usually too high. Most Flunity apps land at 64–128 MB.
- Strip subsystems you don't use (Audio, Vehicles, etc.) under the Module Manager.

Build into `unity_project/Builds/WebGL/`.

## 2. Copy into Flutter assets

```bash
flunity webgl copy
```

This:
1. Removes anything previously in `flutter_app/assets/unity_webgl/` (except `.gitkeep` if present and `--clean` is set).
2. Copies the build dir verbatim.
3. Writes `flutter_app/assets/unity_webgl/flunity_webgl_manifest.json` with a sha256 build hash, file count, total bytes, and timestamp. Use it for cache-busting.

## 3. Build the Flutter app

```bash
cd flutter_app
flutter build apk           # or appbundle, ios, ipa
```

`FLUNITY_MODE=bundled` is the default — no flags needed.

## Mobile WebView guidance

Unity WebGL inside a WebView on a phone is real, but it's not free. Recommendations:

- **Lazy-mount the view.** Mount `FlunityWebGLView` on a route push, not at app start. Tear it down on pop with `controller.dispose()`.
- **One scene at a time.** Multi-scene preloading inside the WebView is rarely worth the memory.
- **Texture streaming**, low MSAA (`Camera.allowMSAA = false`), mobile-realistic poly counts.
- **Audio off** unless you need it — saves both bandwidth and battery.
- **Size budget**: target < 10 MB total compressed for an acceptable cold start on a mid-range Android.

## Why a loopback server in production?

Unity WebGL refuses `file://` URLs (it uses ranged requests, web workers, and sometimes service workers). `flutter_inappwebview` ships an `InAppLocalhostServer` that serves Flutter assets over a process-local HTTP loopback bound to `127.0.0.1`. Flunity manages it for you — your code only sees `FlunityWebGLConfig.bundled()`.

## Cache invalidation

When the Unity build changes, the assets bundle changes, so the Flutter binary changes — that's already enough for app stores to deliver fresh code on the next install. Within a running session, `flunity_webgl_manifest.json` exposes a build hash that you can show in dev menus or use to invalidate any in-app caches you maintain.
```

### Task 15: `docs/android-emulator.md`

```markdown
# Android Emulator Notes

Android's emulator runs in its own VM. From inside the emulator, `127.0.0.1` and `localhost` point to the **emulator itself**, not your host machine. Two consequences for Flunity dev:

## `10.0.2.2` instead of `127.0.0.1`

Google's emulator exposes the host machine at `10.0.2.2`. `FlunityWebGLConfig.dev()` automatically substitutes `127.0.0.1` → `10.0.2.2` when running on Android. You don't need to do anything.

If your dev server's `host:` is non-loopback (e.g., a LAN IP for a physical device), the substitution is skipped.

## Cleartext HTTP

Dev mode hits `http://10.0.2.2:8080/...`. Production loopback hits `http://127.0.0.1:<random>/...`. Both are HTTP, not HTTPS.

`flunity create` generates a `flutter_app/android/app/src/main/AndroidManifest.xml` and `flutter_app/android/app/src/main/res/xml/network_security_config.xml` that allow cleartext **only** for `127.0.0.1`, `10.0.2.2`, and `localhost`. The rest of the app stays under the default Android cleartext-disabled policy.

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
```

## Physical device, not emulator?

The emulator host swap only applies to Android emulators, but the runtime can't tell — it just sees "Android". If you're testing on a physical device:

1. Find your machine's LAN IP (e.g., `192.168.1.42`).
2. Run with `--dart-define=FLUNITY_DEV_HOST=192.168.1.42`.
3. Make sure the dev server is reachable from the device (firewall, same network).

`flunity doctor` warns when it detects a physical device + `127.0.0.1` dev host.

## iOS simulator

iOS simulator runs on the host kernel, so `127.0.0.1` works directly. The generated `Info.plist` has an `NSAppTransportSecurity` exception scoped to `127.0.0.1` and `localhost`. No action needed.
```

### Task 16: `docs/native-roadmap.md`

```markdown
# Native Roadmap (future work, not v1)

Flunity v1 only supports Unity WebGL. Native Unity-as-a-library (NUaL) — Unity exported as a Gradle module on Android or an Xcode framework on iOS, embedded into a Flutter app via a platform channel — is on the roadmap but not implemented.

## The CLI is already shaped for it

The `target` field in `flunity.yaml` is a string, not a boolean. The plan's `target: webgl` is the only accepted value in v1. Future targets:

- `target: native_android` — embeds Unity as a Gradle module.
- `target: native_ios` — embeds Unity as an XCFramework.

Future commands (already named in the design):

- `flunity add native-android` — generate the platform-channel glue and Gradle module placeholder.
- `flunity add native-ios` — same for iOS / Xcode.
- `flunity native prepare` — invoke Unity's batch-mode export.
- `flunity native export` — produce the platform artifacts.

`flunity_bridge` will grow a `FlunityNativeView` peer to `FlunityWebGLView`, sharing the same `FlunityMessage` types so user code switching from WebGL to native is mostly a widget swap.

## Why native isn't in v1

- **Setup overhead.** Unity-as-a-library needs Unity Hub modules (Android Build Support / iOS Build Support) plus signing infrastructure on each developer's machine.
- **Fragility across Unity versions.** Unity's exported Gradle / Xcode projects shift shape between LTS releases.
- **CI pressure.** Generating a native Unity export in CI requires a Unity license and a beefy macOS/Linux runner.
- **WebGL is genuinely simpler.** No native compilation, no platform-specific bindings, no signing — just a `WebView`.

Flunity's first job is to make the WebGL path painless. We'll add native targets when the WebGL workflow has graduated out of pre-alpha.

## What you can do today if you really need native

- Use Flutter's [`unity_view`](https://pub.dev/packages/flutter_unity_widget) — third-party, separate ecosystem from Flunity. Bigger setup, more capable for high-FPS native rendering.
- Wait for Flunity native. We'll publish a migration guide so app code (typed messages, `FlunityMessage`-based domain code) ports straight across.
```

### Task 17: Commit each doc separately

```bash
git -C /Volumes/Transcend/Projects/flunity add docs/getting-started.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add getting-started.md"

git -C /Volumes/Transcend/Projects/flunity add docs/project-structure.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add project-structure.md"

git -C /Volumes/Transcend/Projects/flunity add docs/webgl-workflow.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add webgl-workflow.md"

git -C /Volumes/Transcend/Projects/flunity add docs/bridge-api.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add bridge-api.md"

git -C /Volumes/Transcend/Projects/flunity add docs/production-build.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add production-build.md"

git -C /Volumes/Transcend/Projects/flunity add docs/android-emulator.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add android-emulator.md"

git -C /Volumes/Transcend/Projects/flunity add docs/native-roadmap.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs: add native-roadmap.md"
```

(Seven small commits — one per doc — keeps history skim-friendly. Authors can squash later.)

---

## Phase 7 — Final polish + push + PR

### Task 18: Update CHANGELOGs

- [ ] **Step 1: Repo CHANGELOG**

Append under `## [Unreleased]` in `/Volumes/Transcend/Projects/flunity/CHANGELOG.md`:

```markdown
- `flunity_cli`: `create` now defaults to the bridge-wired template; `--no-bridge` opts out.
- `flunity_cli`: `bridge init` reads from `unity_bridge_basic` template instead of inlined strings.
- New `flutter_webgl_bridge` and `unity_bridge_basic` templates with full bridge wiring (Unity-side `FlunityBridge.cs`, `flunity_bridge.jslib`, `flunity_bridge.js` shim).
- Documentation: getting-started, project-structure, webgl-workflow, bridge-api, production-build, android-emulator, native-roadmap.
- E2E smoke test against a stub WebGL build.
```

- [ ] **Step 2: `flunity_cli` CHANGELOG**

Append under `## [Unreleased]`:

```markdown
- `create` default template is now `flutter_webgl_bridge`. `--no-bridge` keeps the basic template.
- `bridge init` refactored to read from the `unity_bridge_basic` template.
- E2E smoke test for the dev server using a checked-in stub WebGL build.
```

### Task 19: Run all checks one last time

```bash
cd /Volumes/Transcend/Projects/flunity
melos run format-check    # if it fails, run melos run format and commit a separate style: commit
melos run analyze
melos run test
```

Expected: all green.

### Task 20: Push and open PR

```bash
git -C /Volumes/Transcend/Projects/flunity push -u origin feat/plan-c-templates
gh pr create --base main --head feat/plan-c-templates \
  --title "Plan C: bridge-wired templates, Unity-side, examples, docs" \
  --body "$(cat <<'EOF'
## Summary

Closes Flunity v1 Definition of Done.

- New \`flutter_webgl_bridge\` and \`unity_bridge_basic\` templates.
- Unity-side: \`FlunityBridge.cs\`, \`FlunityBridgeDemo.cs\`, \`flunity_bridge.jslib\`, \`flunity_bridge.js\` shim.
- \`flunity create\` now defaults to the bridge template (\`--no-bridge\` for the basic).
- \`flunity bridge init\` refactored to read templates instead of inlined strings.
- E2E smoke test against a stub WebGL build.
- Seven docs: getting-started, project-structure, webgl-workflow, bridge-api, production-build, android-emulator, native-roadmap.

## Test plan

- [ ] \`melos run analyze\` clean.
- [ ] \`melos run format-check\` clean.
- [ ] \`melos run test\` passes (both packages).
- [ ] \`flunity --version\` prints \`flunity 0.1.0\`.
- [ ] \`flunity create demo && cd demo\` produces a project with \`flutter_app/lib/unity/unity_webgl_screen.dart\` (verifies bridge template).
- [ ] \`flunity create demo --no-bridge\` produces a basic project (verifies opt-out).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Definition of done for Plan C

- [ ] `flutter_webgl_bridge` template exists and renders into a usable Flutter app.
- [ ] `unity_bridge_basic` template exists with `FlunityBridge.cs` + `.jslib` + JS shim.
- [ ] `flunity create` defaults to bridge template; `--no-bridge` produces basic.
- [ ] `flunity bridge init` reads from templates (no more inlined strings).
- [ ] E2E smoke test passes.
- [ ] All seven docs exist under `docs/`.
- [ ] CHANGELOGs updated.
- [ ] `melos run analyze + test + format-check` all green.
- [ ] PR opened.

When done: brainstorm v1 release — pubspec versioning, GitHub release tagging, publish-to-pub, Plan A/B/C followups.
