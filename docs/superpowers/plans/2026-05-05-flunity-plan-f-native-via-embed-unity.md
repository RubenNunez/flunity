# Plan F — Multi-target builds (`webgl` / `ios` / `android`) with vendored embed-unity

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Make Flunity a real multi-target tool. One Unity project produces three artifacts under `Builds/{webgl,ios,android}/`. The Flutter app picks the right one at compile time. The bridge contract — same `FlunityMessage` types — flows over WebView (webgl), iOS UnityFramework (ios), or Android UnityPlayer (android) transparently. Code is **vendored** from `flutter_embed_unity` v2.0.0 (MIT, github.com/learntoflutter/flutter_embed_unity) into `flunity_bridge` so Flunity has no external embed-unity dependency.

**Architecture:**

- **Targets** are just three short names: `webgl`, `ios`, `android`. No `native_` prefix.
- **Build outputs** live at `<unity_project>/Builds/<target>/`. Unity-side editor scripts (shipped in the `unity_bridge_basic` template) provide:
  - `Flunity > Build > WebGL`
  - `Flunity > Build > iOS`
  - `Flunity > Build > Android`
  - `Flunity > Build > All`
  - Plus batch-mode entry points (`Flunity.Build.BuildWebGL`, etc.) so `flunity build <target>` can invoke them headlessly.
- **One Unity project, multiple Flutter consumers.** The Unity project lives wherever the user wants. The Flutter app lives wherever the user wants. `flunity.yaml` (next to the Flutter app) glues them via absolute or relative paths.
- **Vendored embed-unity.** Take essentials from:
  - `flutter_embed_unity` (top-level Dart wrapper)
  - `flutter_embed_unity_2022_3_ios` (iOS UnityFramework integration — Unity 2022.3 LTS)
  - `flutter_embed_unity_6000_0_android` (Android UnityPlayer integration — Unity 6+; check whether it works for 2022.3 too, otherwise vendor a 2022.3 sibling)
  - License: MIT, attribution preserved in headers.
  - We rebrand the public API to live under `flunity_bridge` namespace so users only see `package:flunity_bridge` imports.
- **Unchanged for v0.1:** The webgl flow stays exactly as it is. `flunity_bridge`'s sealed `FlunityMessage` hierarchy stays. The `[FlunityBridge]` GameObject + `ReceiveFromFlutter` method stay. Only the *transport* under the controller changes per target.
- **Future-flagged:** reflection-based dynamic GameObject access — Plan H.

**Tech Stack:** Existing Flunity stack. New Android side: Kotlin/Java + Gradle module. New iOS side: Swift/Objective-C + XCFramework. No new pub deps in `flunity_bridge` — code is vendored.

---

## Prerequisites

- Branch `feat/plan-f-native-via-embed` cut off `main`.
- Unity 2022.3 LTS with **Android Build Support** AND **iOS Build Support** modules installed.
- Xcode + iOS toolchain on macOS for iOS testing. Android Studio + NDK for Android testing.
- The user's existing webgl flow keeps working through every phase.

---

## File Structure

```
flunity/
├── packages/flunity_bridge/
│   ├── android/                                   # NEW — vendored, becomes the package's Android plugin
│   │   ├── build.gradle
│   │   └── src/main/kotlin/com/flunity/bridge/
│   │       ├── FlunityBridgePlugin.kt
│   │       ├── UnityHostActivity.kt
│   │       └── UnityPlatformView.kt
│   ├── ios/                                       # NEW — vendored
│   │   ├── flunity_bridge.podspec
│   │   └── Classes/
│   │       ├── FlunityBridgePlugin.swift
│   │       ├── UnityFrameworkLoader.swift
│   │       └── UnityPlatformView.swift
│   ├── lib/src/
│   │   ├── flunity_controller.dart                # NEW — abstract interface
│   │   ├── flunity_webgl_controller.dart          # MODIFY — implements FlunityController
│   │   ├── flunity_native_controller.dart         # NEW — uses NativeMessageTransport
│   │   ├── flunity_native_view.dart               # NEW — wraps the native UnityPlatformView
│   │   ├── flunity_view.dart                      # NEW — target-aware composite
│   │   ├── target.dart                            # NEW — FlunityRuntimeTarget detection
│   │   ├── routing/
│   │   │   └── unity_scene_route.dart             # NEW
│   │   └── transport/
│   │       └── native_message_transport.dart      # NEW — over MethodChannel
│   ├── pubspec.yaml                               # MODIFY — declare android/ + ios/ plugin sections
│   └── test/...
├── packages/flunity_cli/
│   ├── lib/src/
│   │   ├── manifest/manifest_schema.dart          # MODIFY — accept ios/android targets, add unity_builds parent path
│   │   ├── commands/
│   │   │   ├── create_command.dart                # MODIFY — branch on target
│   │   │   ├── build_command.dart                 # NEW — `flunity build <target>` (Unity batch invocation)
│   │   │   ├── bundle_command.dart                # NEW — `flunity bundle <target>` (integrate artifact)
│   │   │   ├── webgl_command.dart                 # MODIFY — keep `webgl serve`, retire `webgl copy` (folded into bundle)
│   │   │   └── doctor_command.dart                # MODIFY — target-conditional checks
│   │   ├── doctor/checks/
│   │   │   ├── unity_modules_check.dart           # NEW
│   │   │   ├── android_ndk_check.dart             # NEW
│   │   │   └── ios_toolchain_check.dart           # NEW
│   │   ├── native/
│   │   │   ├── unity_batch_runner.dart            # NEW — invokes Unity headless
│   │   │   ├── ios_artifact_integrator.dart       # NEW — embeds XCFramework into Flutter ios/
│   │   │   └── android_artifact_integrator.dart   # NEW — embeds Gradle module into Flutter android/
│   │   └── ...
│   ├── templates/
│   │   ├── flutter_webgl_basic/                   # unchanged
│   │   ├── flutter_webgl_bridge/                  # unchanged
│   │   ├── flutter_native_basic/                  # NEW
│   │   ├── flutter_native_bridge/                 # NEW
│   │   └── unity_bridge_basic/
│   │       └── unity_project/Assets/
│   │           ├── Editor/Flunity/
│   │           │   ├── FlunityBuilder.cs          # NEW — menu items + batch-mode build entries
│   │           │   ├── FlunityBuildSettings.cs    # NEW — per-target player settings
│   │           │   └── FlunityMenu.cs             # NEW — top-level menu wiring
│   │           ├── Scripts/                        # unchanged (FlunityBridge.cs etc.)
│   │           └── Plugins/WebGL/                  # unchanged (jslib + js shim)
│   └── test/...
└── docs/
    ├── multi-target.md                            # NEW — one Unity, three builds
    ├── target-comparison.md                       # NEW — when to pick what
    ├── native-setup.md                            # REPLACES native-roadmap.md
    └── scene-routing.md                           # NEW
```

---

## Phase 0 — Vendoring prep

### Task 1: Inventory the upstream code

**Files:**
- Create: `packages/flunity_bridge/THIRDPARTY.md` — attribution for vendored code.
- Create: `packages/flunity_bridge/VENDOR-INVENTORY.md` — checklist of files we copy and their upstream locations.

**Subagent task:**
- Clone or browse `github.com/learntoflutter/flutter_embed_unity` at the v2.0.0 tag.
- Identify the essential files in:
  - `flutter_embed_unity/lib/` — the Dart-level public API.
  - `flutter_embed_unity_platform_interface/` (if present) — the federated interface contract.
  - `flutter_embed_unity_2022_3_ios/ios/` — the Swift / ObjC sources, podspec, and any header-bridging files.
  - `flutter_embed_unity_6000_0_android/android/` — Kotlin / Java sources, gradle file, manifest entries.
  - Any Unity Editor scripts the package ships (for embedding Unity into Flutter — should be there).
- Record each file's upstream path in `VENDOR-INVENTORY.md` like:
  ```
  - lib/embed_unity.dart                       → packages/flunity_bridge/lib/src/native/embed_unity.dart
  - ios/Classes/FlutterEmbedUnityPlugin.swift  → packages/flunity_bridge/ios/Classes/FlunityBridgePlugin.swift
  ...
  ```
- Note license header in each file. We'll preserve those headers when we copy.

This phase produces the **plan-of-record** for what gets copied. No code yet.

### Task 2: Commit the inventory

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/VENDOR-INVENTORY.md packages/flunity_bridge/THIRDPARTY.md
git -C /Volumes/Transcend/Projects/flunity commit -m "docs(flunity_bridge): vendor inventory for Plan F native targets"
```

---

## Phase 1 — Manifest accepts `webgl` / `ios` / `android`

### Task 3: Update `FlunityTarget` enum + parser

**Files:**
- Modify: `packages/flunity_cli/lib/src/manifest/flunity_project.dart`
- Modify: `packages/flunity_cli/lib/src/manifest/manifest_schema.dart`
- Modify: `packages/flunity_cli/test/manifest/flunity_project_test.dart`

```dart
enum FlunityTarget { webgl, ios, android }
```

YAML accepted values: `webgl`, `ios`, `android`. Anything else → `ManifestException`.

### Task 4: Replace `unity_build` with `unity_builds` (parent dir)

**The path change:**

```yaml
# old
paths:
  unity_build: unity_project/Builds/WebGL

# new
paths:
  unity_builds: unity_project/Builds       # the parent of webgl/, ios/, android/
```

The per-target build dir is computed: `unity_builds/<target>` where `<target>` is the manifest's target.

**Backward-compat:** if the manifest still has `unity_build:` (old field), accept it for `target: webgl` and emit a deprecation warning. Drop in the next major.

### Task 5: Convenience getters on `FlunityProject`

```dart
class FlunityProject {
  final FlunityTarget target;

  bool get isWebGL  => target == FlunityTarget.webgl;
  bool get isIos    => target == FlunityTarget.ios;
  bool get isAndroid => target == FlunityTarget.android;
  bool get isNative => isIos || isAndroid;

  /// The directory of the build artifact for the current target.
  String get buildDir => p.join(paths.unityBuilds, target.name);
}
```

`paths.unityBuilds` is the new field on `FlunityPaths`.

### Task 6: Tests + commit

Update existing `flunity_project_test.dart`:
- Replace the test that asserted `native_android` is rejected — now expects it to be rejected (plain `android` accepted instead).
- New tests for each of webgl / ios / android parsing.
- New test for `buildDir` getter returning the right per-target subdir.

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/manifest packages/flunity_cli/test/manifest
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): manifest accepts webgl|ios|android targets + unity_builds path"
```

---

## Phase 2 — Unity-side: `Flunity.Build` editor scripts

### Task 7: `Editor/Flunity/FlunityBuilder.cs`

Lives in the `unity_bridge_basic` template (and consequently in `flutter_native_bridge`'s shared assets).

```csharp
using UnityEditor;
using UnityEngine;
using System.IO;

namespace Flunity.Editor {
    public static class FlunityBuilder {

        // ---- Menu items (interactive) ----

        [MenuItem("Flunity/Build/WebGL")]
        public static void BuildWebGLMenu() => BuildWebGL();

        [MenuItem("Flunity/Build/iOS")]
        public static void BuildIOSMenu() => BuildIOS();

        [MenuItem("Flunity/Build/Android")]
        public static void BuildAndroidMenu() => BuildAndroid();

        [MenuItem("Flunity/Build/All")]
        public static void BuildAllMenu() => BuildAll();

        // ---- Batch-mode entry points ----
        // Invoked by `flunity build <target>` via `unity -batchmode -executeMethod ...`

        public static void BuildWebGL() {
            EditorUserBuildSettings.SwitchActiveBuildTarget(
                BuildTargetGroup.WebGL, BuildTarget.WebGL);
            FlunityBuildSettings.ApplyWebGL();
            BuildPipeline.BuildPlayer(
                FlunityBuildSettings.Scenes,
                BuildPath("webgl"),
                BuildTarget.WebGL,
                BuildOptions.None);
        }

        public static void BuildIOS() {
            EditorUserBuildSettings.SwitchActiveBuildTarget(
                BuildTargetGroup.iOS, BuildTarget.iOS);
            FlunityBuildSettings.ApplyIOS();
            // Library-style export — we want UnityFramework, not a standalone player.
            BuildPipeline.BuildPlayer(
                FlunityBuildSettings.Scenes,
                BuildPath("ios"),
                BuildTarget.iOS,
                BuildOptions.AcceptExternalModificationsToPlayer);
            // Post-build hook in FlunityBuildSettings or a separate IPostprocessBuildWithReport
            // converts the Xcode project into an XCFramework via xcodebuild — see Phase 5.
        }

        public static void BuildAndroid() {
            EditorUserBuildSettings.SwitchActiveBuildTarget(
                BuildTargetGroup.Android, BuildTarget.Android);
            EditorUserBuildSettings.exportAsGoogleAndroidProject = true; // gradle module
            FlunityBuildSettings.ApplyAndroid();
            BuildPipeline.BuildPlayer(
                FlunityBuildSettings.Scenes,
                BuildPath("android"),
                BuildTarget.Android,
                BuildOptions.None);
        }

        public static void BuildAll() {
            BuildWebGL();
            BuildIOS();
            BuildAndroid();
        }

        // ---- Helpers ----

        private static string BuildPath(string target) {
            // Default: <project>/Builds/<target>. Overridable via -buildPath CLI arg.
            string fromArg = GetCliArg("-buildPath");
            if (!string.IsNullOrEmpty(fromArg)) {
                return Path.Combine(fromArg, target);
            }
            return Path.Combine(Application.dataPath, "..", "Builds", target);
        }

        private static string GetCliArg(string name) {
            string[] args = System.Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length - 1; i++) {
                if (args[i] == name) return args[i + 1];
            }
            return null;
        }
    }
}
```

### Task 8: `Editor/Flunity/FlunityBuildSettings.cs`

Per-target Player settings + scene list.

```csharp
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;

namespace Flunity.Editor {
    public static class FlunityBuildSettings {
        public static string[] Scenes {
            get {
                var scenes = EditorBuildSettings.scenes;
                var paths = new System.Collections.Generic.List<string>();
                foreach (var s in scenes) if (s.enabled) paths.Add(s.path);
                return paths.ToArray();
            }
        }

        public static void ApplyWebGL() {
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Brotli;
            PlayerSettings.SetIl2CppCodeGeneration(NamedBuildTarget.WebGL, Il2CppCodeGeneration.OptimizeSpeed);
            PlayerSettings.SetIl2CppCompilerConfiguration(NamedBuildTarget.WebGL, Il2CppCompilerConfiguration.Master);
            PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.WebGL, ManagedStrippingLevel.High);
        }

        public static void ApplyIOS() {
            PlayerSettings.iOS.targetOSVersionString = "12.0";
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.iOS, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetArchitecture(NamedBuildTarget.iOS, 1); // ARM64
        }

        public static void ApplyAndroid() {
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.Android, ManagedStrippingLevel.High);
        }
    }
}
```

### Task 9: Commit Phase 2

The Editor scripts ship as part of `unity_bridge_basic` template, so they land in any project produced by `flunity create` (or applied via `flunity bridge init`).

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Editor
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): Unity-side editor scripts for multi-target builds"
```

---

## Phase 3 — Vendor `flutter_embed_unity` into `flunity_bridge`

### Task 10: Pre-vendor — extract the existing controller into an interface

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_controller.dart`
- Modify: `packages/flunity_bridge/lib/src/flunity_webgl_controller.dart`
- Modify the public exports.

```dart
abstract interface class FlunityController {
  bool get isReady;
  Stream<FlunityMessage> get messages;
  Future<void> send(FlunityMessage message);
  Future<void> reload();
  Future<void> dispose();
}
```

`FlunityWebGLController` becomes `class FlunityWebGLController implements FlunityController { ... }`. No behavior change. Tests still pass.

### Task 11: Copy iOS code (Swift + podspec)

**Subagent task** (referencing `VENDOR-INVENTORY.md` from Phase 0):
- Copy iOS sources from `flutter_embed_unity_2022_3_ios/ios/` into `packages/flunity_bridge/ios/`.
- Rename Swift class prefixes from `FlutterEmbedUnity*` to `FlunityBridge*` (or similar — consistent within the package).
- Update the podspec to declare `flunity_bridge` as the pod name.
- Preserve MIT license headers; add a note above each ported file:
  ```
  // Adapted from flutter_embed_unity_2022_3_ios v2.0.0 (MIT, learntoflutter).
  // See packages/flunity_bridge/THIRDPARTY.md for full attribution.
  ```

The package's iOS code typically does:
- Loads `UnityFramework` (the framework Unity exports for iOS) via `Bundle.main`.
- Spins up a `UIView` that hosts Unity's view.
- Bridges Flutter `MethodChannel` calls into `UnityFramework.sendMessageToGOWithName(...)`.
- Receives Unity messages via `NativeCallProxy` (Unity provides this for native callbacks).

### Task 12: Copy Android code (Kotlin + Gradle)

**Subagent task:**
- Copy Android sources from `flutter_embed_unity_6000_0_android/android/` into `packages/flunity_bridge/android/`.
- Rename Kotlin class prefixes from `FlutterEmbedUnity*` to `FlunityBridge*`.
- Update `build.gradle` `group`, `version`, namespace.
- Preserve MIT headers + attribution.

The package's Android code typically does:
- Wraps a `UnityPlayer` instance from the embedded Gradle module.
- Hosts it in a Flutter `PlatformView` via `AndroidView`.
- Bridges `MethodChannel` calls into `UnityPlayer.UnitySendMessage(...)`.
- Calls back via `IUnityMessageManager` or similar.

**Important**: the upstream package is named `_6000_0_android` because it targets Unity 6. For Unity 2022.3 LTS support, two options:
- (a) The 6000_0 code might just work for 2022.3 builds; test it.
- (b) If not, vendor an older sibling from the package's git history (perhaps a 1.x release that targeted 2022.3).

Phase 0's inventory should resolve this.

### Task 13: `pubspec.yaml` plugin declaration

**Files:**
- Modify: `packages/flunity_bridge/pubspec.yaml`

Add the platform plugin sections:

```yaml
flutter:
  plugin:
    platforms:
      ios:
        pluginClass: FlunityBridgePlugin
      android:
        package: com.flunity.bridge
        pluginClass: FlunityBridgePlugin
```

Now `flunity_bridge` ships as a Flutter platform plugin. `flutter pub get` in a consuming app will pick up the platform code.

### Task 14: `NativeMessageTransport`

**Files:**
- Create: `packages/flunity_bridge/lib/src/transport/native_message_transport.dart`

Implements `MessageTransport` over a `MethodChannel`. Same shape as the WebGL `InAppWebViewMessageTransport`:

```dart
class NativeMessageTransport implements MessageTransport {
  static const _channel = MethodChannel('flunity_bridge/messages');
  final Completer<void> _ready = Completer<void>();
  final StreamController<String> _incoming = StreamController.broadcast();

  NativeMessageTransport() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'unity.ready':
          if (!_ready.isCompleted) _ready.complete();
          break;
        case 'unity.message':
          _incoming.add(call.arguments as String);
          break;
      }
    });
  }

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Future<void> send(String json) async {
    await ready;
    await _channel.invokeMethod('flutter.message', json);
  }

  @override
  Future<void> reload() => _channel.invokeMethod('unity.reload');

  @override
  Future<void> dispose() async {
    await _incoming.close();
  }
}
```

The native code (Phases 11/12) routes:
- `flutter.message` → `UnityFramework.sendMessageToGOWithName('[FlunityBridge]', 'ReceiveFromFlutter', json)` (iOS)
  or `UnityPlayer.UnitySendMessage('[FlunityBridge]', 'ReceiveFromFlutter', json)` (Android).
- Unity messages back → `MethodChannel.invokeMethod('unity.message', json)`.

### Task 15: `FlunityNativeController`

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_native_controller.dart`

Same pattern as `FlunityWebGLController`. Wraps a `NativeMessageTransport`. JSON encode/decode. Implements `FlunityController`. Six tests (queue-before-ready, typed stream, error path, isReady, reload, dispose) — directly mirrors the WebGL controller.

### Task 16: `FlunityNativeView`

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_native_view.dart`

```dart
class FlunityNativeView extends StatefulWidget {
  const FlunityNativeView({
    this.onReady,
    this.onMessage,
    this.loadingBuilder,
    super.key,
  });

  final ValueChanged<FlunityController>? onReady;
  final ValueChanged<FlunityMessage>? onMessage;
  final WidgetBuilder? loadingBuilder;
  @override
  State<FlunityNativeView> createState() => _FlunityNativeViewState();
}
```

State implementation hosts a `UiKitView` (iOS) / `AndroidView` (Android) pointing at the registered `flunity_bridge/UnityPlatformView` factory in the native code. Wires the `NativeMessageTransport` and `FlunityNativeController`. Same `addPostFrameCallback` deferral for `onReady` we learned from Plan D.

### Task 17: `FlunityView` — target-aware composite

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_view.dart`

Picks `FlunityWebGLView` or `FlunityNativeView` based on:
1. `--dart-define=FLUNITY_TARGET=webgl|ios|android` if present.
2. Otherwise, `defaultTargetPlatform` (iOS/Android → native; web → webgl).
3. For desktop: prefer webgl (via the dev server) since native UnityFramework on desktop isn't a v0.2 concern.

```dart
class FlunityView extends StatelessWidget {
  const FlunityView({
    this.onReady,
    this.onMessage,
    this.webglConfig,
    super.key,
  });

  final ValueChanged<FlunityController>? onReady;
  final ValueChanged<FlunityMessage>? onMessage;
  final FlunityWebGLConfig? webglConfig;

  @override
  Widget build(BuildContext context) {
    final target = FlunityRuntimeTarget.detect();
    return switch (target) {
      FlunityRuntimeTarget.webgl => FlunityWebGLView(
          config: webglConfig ?? FlunityWebGLConfig.bundled(),
          onReady: onReady,
          onMessage: onMessage,
        ),
      _ => FlunityNativeView(
          onReady: onReady,
          onMessage: onMessage,
        ),
    };
  }
}
```

### Task 18: Public exports

`packages/flunity_bridge/lib/flunity_bridge.dart` adds:

```dart
export 'src/flunity_controller.dart';
export 'src/flunity_native_controller.dart';
export 'src/flunity_native_view.dart';
export 'src/flunity_view.dart';
export 'src/target.dart';
```

WebGL types stay exported. Existing user code keeps compiling.

### Task 19: Commit Phase 3

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): vendor iOS+Android UnityPlayer integration from flutter_embed_unity v2.0.0 (MIT)"
```

---

## Phase 4 — Templates: `flutter_native_bridge`

### Task 20: Build the template

**Files:** all of `packages/flunity_cli/templates/flutter_native_bridge/`.

Largely a copy of `flutter_webgl_bridge`, with these differences:

- `flutter_app/lib/main.dart` — same; it imports `flunity_bridge` and `unity/unity_screen.dart`.
- `flutter_app/lib/unity/unity_screen.dart` — uses `FlunityNativeView` instead of `FlunityWebGLView`.
- `flutter_app/pubspec.yaml` — declares `flunity_bridge: ^0.1.0`. No `flutter_embed_unity` dep (we vendored it). The override-yaml dance still applies until pub.dev publish.
- The Unity-side scripts AND editor scripts are SHARED with the WebGL template (already shipped in `unity_bridge_basic`).
- `flunity.yaml` defaults to `target: ios` (for `--target ios`) or `android`.

### Task 21: `flutter_native_basic` template

Stripped-down. `--no-bridge` opt-out for native users.

### Task 22: Commit

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/templates/flutter_native_bridge packages/flunity_cli/templates/flutter_native_basic
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): flutter_native_bridge + flutter_native_basic templates"
```

---

## Phase 5 — CLI: `flunity create --target` + `flunity build` + `flunity bundle`

### Task 23: `create_command.dart` accepts ios/android

Allowed targets: `webgl`, `ios`, `android`. Default still `webgl`. Template selection branches on target × `--no-bridge`:

```dart
final templateName = switch ((target, argResults!['no-bridge'] == true)) {
  ('webgl', false) => 'flutter_webgl_bridge',
  ('webgl', true)  => 'flutter_webgl_basic',
  ('ios' || 'android', false) => 'flutter_native_bridge',
  ('ios' || 'android', true)  => 'flutter_native_basic',
  _ => throw StateError('unreachable'),
};
```

The post-render flow (Plan D's flutter create + patchers + override + pub get) runs unchanged. For native targets, `flutter create` generates the iOS/Android shells we need.

Tests gain target variants.

### Task 24: `flunity build <target>`

**Files:**
- Create: `packages/flunity_cli/lib/src/commands/build_command.dart`
- Create: `packages/flunity_cli/lib/src/native/unity_batch_runner.dart`

```
flunity build webgl
flunity build ios
flunity build android
flunity build all
```

Behavior:
1. Locate Unity (`UNITY_PATH` env, Unity Hub, or `unity` on PATH).
2. Resolve build path: `<unity_project>/Builds/<target>/`.
3. Run:
   ```
   <unity> -batchmode -nographics -quit \
     -projectPath <unity_project> \
     -executeMethod Flunity.Editor.FlunityBuilder.Build<Target> \
     -buildPath <unity_builds_root> \
     -logFile -
   ```
4. Stream output. Exit non-zero on failure.
5. For `ios`: post-step that runs `xcodebuild -create-xcframework ...` to package the exported Xcode project as a `UnityFramework.xcframework` (the format Flutter iOS plugins consume cleanly). Lives in `lib/src/native/ios_artifact_integrator.dart`.

### Task 25: `flunity bundle <target>`

**Files:**
- Create: `packages/flunity_cli/lib/src/commands/bundle_command.dart`
- Create: `packages/flunity_cli/lib/src/native/ios_artifact_integrator.dart`
- Create: `packages/flunity_cli/lib/src/native/android_artifact_integrator.dart`

What it does per target:

- **webgl:** copy `<unity_builds>/webgl/` → `flutter_app/assets/unity_webgl/`. Same as today's `webgl copy`. Idempotent.
- **ios:** copy/integrate `<unity_builds>/ios/UnityFramework.xcframework` into the Flutter app's `ios/Frameworks/` directory and patch `Podfile` if needed. Idempotent (markers).
- **android:** copy `<unity_builds>/android/unityLibrary/` (the Gradle module) into `flutter_app/android/unityLibrary/` and patch the app's `settings.gradle` + `app/build.gradle` with the `:unityLibrary` dep. Idempotent.

Old `flunity webgl copy` becomes a thin alias for `flunity bundle webgl` with a deprecation note.

### Task 26: Commits + tests

Two commits — `flunity build` and `flunity bundle` ship together. Tests for argument parsing, artifact path resolution, and the (mockable) shell-command construction.

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/commands packages/flunity_cli/lib/src/native packages/flunity_cli/test
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): flunity build|bundle target commands"
```

---

## Phase 6 — Doctor: target-conditional checks

### Task 27: New checks

**Files:**
- Create: `packages/flunity_cli/lib/src/doctor/checks/unity_modules_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/android_ndk_check.dart`
- Create: `packages/flunity_cli/lib/src/doctor/checks/ios_toolchain_check.dart`

`UnityModulesCheck` reads `Unity Hub`'s installed-modules list (either via `~/Library/Application Support/UnityHub/secondaryInstallPath.json` or by inspecting Unity install dir's `Editor/Data/PlaybackEngines/`). Verifies the modules required for the project's target are installed.

`AndroidNdkCheck` runs `sdkmanager --list_installed | grep ndk` (or reads `local.properties`). Reports the NDK version found and whether it satisfies Unity's minimum.

`IosToolchainCheck` runs `xcrun --find xcodebuild` and `xcodebuild -version`. Verifies Xcode is installed and at least the version Unity 2022.3 LTS requires.

### Task 28: Doctor command wires checks per target

```dart
if (project.isWebGL) {
  checks.add(PortAvailableCheck(...));
}
if (project.isIos) {
  checks.add(IosToolchainCheck(...));
  checks.add(UnityModulesCheck(target: FlunityTarget.ios));
}
if (project.isAndroid) {
  checks.add(AndroidNdkCheck(...));
  checks.add(UnityModulesCheck(target: FlunityTarget.android));
}
```

UnityWebGL build check stays target-agnostic (it just checks `<unity_builds>/<target>/index.html` for webgl, or `unityLibrary/build.gradle` for android, etc.). Refactor to a polymorphic check.

### Task 29: Commit Phase 6

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_cli/lib/src/doctor packages/flunity_cli/lib/src/commands/doctor_command.dart packages/flunity_cli/test/doctor
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_cli): target-conditional doctor checks (NDK, Xcode, Unity modules)"
```

---

## Phase 7 — Scene routing helper

### Task 30: `UnitySceneRoute` widget

**Files:**
- Create: `packages/flunity_bridge/lib/src/routing/unity_scene_route.dart`

```dart
class UnitySceneRoute extends StatefulWidget {
  const UnitySceneRoute({
    required this.scene,
    required this.controller,
    required this.child,
    this.previousScene,
    super.key,
  });

  final String scene;
  final FlunityController controller;
  final Widget child;
  final String? previousScene;
}
```

On `initState` → sends `LoadScene(scene)`. On `dispose` → if `previousScene != null`, sends `LoadScene(previousScene)` to restore.

Pattern: mount `FlunityView` once at the app root (via a `FlunityRootView` wrapper). Routes wrap their content in `UnitySceneRoute(scene: 'menu', controller: rootController, child: ...)`.

### Task 31: Tests + docs

Widget test using a fake `FlunityController` — push two routes, verify the `LoadScene` messages went out in the expected order. On pop, restore message lands.

Plus `docs/scene-routing.md` with a concrete example app skeleton.

### Task 32: Commit

```bash
git -C /Volumes/Transcend/Projects/flunity add packages/flunity_bridge/lib/src/routing packages/flunity_bridge/test docs/scene-routing.md
git -C /Volumes/Transcend/Projects/flunity commit -m "feat(flunity_bridge): UnitySceneRoute — one Unity, many Flutter routes"
```

---

## Phase 8 — Docs

### Task 33: Replace `docs/native-roadmap.md` with `docs/native-setup.md`

Honest setup walkthrough: prerequisites, `flunity create my_app --target ios`, `flunity build ios`, `flunity bundle ios`, `flutter run`.

### Task 34: New `docs/multi-target.md`

One Unity project, three targets. The `Builds/<target>/` convention. Switching at compile time. Sharing assets across targets. Per-target settings via `FlunityBuildSettings.cs`.

### Task 35: New `docs/target-comparison.md`

Honest decision guide: when to pick webgl vs ios vs android. Build times (webgl is slow but doesn't need a license; native is faster to iterate per-platform but also slow). Runtime perf. Bundle size. Dev experience.

### Task 36: New `docs/scene-routing.md`

The `UnitySceneRoute` pattern. Code samples.

### Task 37: Commit

Five doc commits (one per file) — keeps history skim-friendly.

---

## Phase 9 — Polish, push, PR

### Task 38: CHANGELOGs

Repo `CHANGELOG.md`:
- Targets are now `webgl` / `ios` / `android` (renamed from `native_android` / `native_ios` — though those were never released, just planned).
- Multi-target Unity project: builds at `<unity_project>/Builds/<target>/`.
- Vendored `flutter_embed_unity` v2.0.0 (MIT) into `flunity_bridge`. No external embed-unity dependency.
- New widgets: `FlunityNativeView`, `FlunityView`, `UnitySceneRoute`.
- New commands: `flunity build <target>`, `flunity bundle <target>`. `flunity webgl copy` aliased to `flunity bundle webgl` with deprecation.
- Doctor gains target-conditional native checks.
- Existing webgl flow unchanged.

`flunity_bridge/CHANGELOG.md`:
- Extracted `FlunityController` interface.
- Added native iOS + Android transport (vendored embed-unity).
- New `FlunityNativeView`, `FlunityView`, `UnitySceneRoute`.

`flunity_cli/CHANGELOG.md`:
- New target values + manifest path `unity_builds`.
- New `build` + `bundle` commands.
- New doctor checks.
- Two new templates.

### Task 39: melos analyze + format-check + test all green

Total tests after Plan F: ~80-100. (53 today + new for native controller, native view smoke, scene route, build/bundle command argument parsing, doctor checks.)

### Task 40: Push + PR

```bash
git push -u origin feat/plan-f-native-via-embed
gh pr create --base main --head feat/plan-f-native-via-embed \
  --title "Plan F: multi-target builds (webgl|ios|android), vendored embed-unity" --body ...
```

---

## Definition of done for Plan F

- [ ] `flunity.yaml`'s `target:` accepts `webgl`, `ios`, `android`.
- [ ] `flunity create my_app --target ios` (or `android` or `webgl`) scaffolds a working project.
- [ ] `flunity build <target>` invokes Unity batch and produces `<unity_builds>/<target>/`.
- [ ] `flunity bundle <target>` integrates the artifact into the Flutter app.
- [ ] `flutter run` on iOS/Android: `FlunityNativeView` mounts, Ping/Pong round-trips, scene messages dispatch.
- [ ] `UnitySceneRoute` swaps Unity scenes on Flutter route push/pop.
- [ ] `flunity_bridge` has zero external-package dependencies for native (vendored, MIT, attributed).
- [ ] WebGL flow unchanged — `my_hybrid_app` from Plan D's dry-run still works.
- [ ] Doctor distinguishes targets and runs target-appropriate checks.
- [ ] `melos run analyze + test + format-check` all green.

---

## Out of scope for Plan F

- Multi-target single Flutter project (one app shipping all three) — Plan G.
- Unity 6 support alongside 2022.3 — Plan G if the vendored Android code's `_6000_0` heritage doesn't cover 2022.3.
- Hot reload / live link for native — Plan H (may share infrastructure with Plan E webgl hot-reload).
- **Reflection-based dynamic GameObject access** — Plan I. The future-vision feature where Flutter code can read/write arbitrary properties on Unity GameObjects via runtime reflection. Big, separate concern.
- Macos / Linux desktop native targets — Plan J.

---

## What to call out for the user up-front

1. **Vendoring is real work.** Phase 0 inventory + Phases 11-12 copy + rename. Estimate: 2-3 days of focused work, a chunk of which is iterating on Swift/Kotlin compilation.
2. **Unity 2022.3 vs Unity 6.** The upstream Android package targets Unity 6. We need to verify it works for 2022.3 LTS or vendor an older 2022.3-targeted sibling.
3. **iOS XCFramework packaging.** Unity's iOS export produces an Xcode project, not directly an XCFramework. The post-build step (`xcodebuild -create-xcframework`) is essential for clean Flutter integration.
4. **Bridge contract preserved.** Same `FlunityMessage` types. Same `[FlunityBridge]` GameObject. Same `ReceiveFromFlutter` method. Only the transport changes per target. This is the v1 win we don't compromise.
5. **License.** MIT vendored code, attribution in `THIRDPARTY.md`. Compliant with both MIT and our own MIT.
