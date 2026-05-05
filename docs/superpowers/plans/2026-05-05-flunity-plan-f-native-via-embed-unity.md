# Plan F — Native Unity-as-a-Library via `flutter_embed_unity`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Add a `target: native` mode to Flunity that wraps the existing [`flutter_embed_unity`](https://pub.dev/packages/flutter_embed_unity) package. WebGL stays the default and unchanged. Flunity's value-add is the tooling layer: scaffolding, manifest, doctor checks, an abstract bridge controller, and scene-per-route helpers — not the platform integration itself, which `flutter_embed_unity` already solves.

**Architecture:**

- `flutter_embed_unity` does the heavy native integration: Unity Library export, Android Gradle module, iOS XCFramework, the platform view widget, the `unityToFlutter` / `flutterToUnity` channels.
- Flunity provides:
  - **Manifest:** `target: native_android | native_ios | native` (alongside existing `webgl`).
  - **`FlunityNativeView`:** thin wrapper around `flutter_embed_unity`'s `EmbedUnity` widget that exposes the same `FlunityWebGLController` API surface (renamed to `FlunityController`).
  - **Bridge contract preserved:** the same `FlunityMessage` types (Ping / Pong / LoadScene / SceneReady / RawMessage) round-trip through both transports. User code switching from WebGL to native = swap one widget.
  - **Templates:** `flutter_native_bridge` peer to `flutter_webgl_bridge`. Generated app shows native-mode wiring out of the box.
  - **CLI:**
    - `flunity create --target native` (or `--target native_android` / `native_ios` / `webgl`).
    - `flunity native prepare` — invokes Unity batch export to produce the Library / Framework artifact in the location `flutter_embed_unity` expects.
    - `flunity native export` — assembles + bundles into the Flutter app's android/ or ios/ tree.
    - Existing WebGL commands unchanged.
  - **Doctor:** new checks for Unity Hub modules (Android Build Support, iOS Build Support), Android NDK / iOS toolchain, `flutter_embed_unity` dependency, target-appropriate manifest fields.
  - **Scene routing helper:** `UnitySceneRoute` widget that auto-sends `load_scene` on push, restores the prior scene on pop. One Unity instance per app (Unity-as-library limitation), multiple Flutter routes can host different scenes within it.

**Tech Stack:** Existing Flunity stack + `flutter_embed_unity ^x.y.z` (latest at planning time). `flutter_embed_unity_android` / `flutter_embed_unity_ios` are the platform implementations consumed transitively.

**Spec reference:** Promotes the design spec's §12 (Native roadmap) from "future work" to v0.2 deliverable. Keeps the v1 WebGL contract intact.

---

## Prerequisites

- Branch `feat/plan-f-native-via-embed` cut off `main` after Plan D merged.
- The user's `my_hybrid_app` continues to work in WebGL mode through this whole plan — no breaking changes to v1.
- A real Unity 2022.3 LTS install with **Android Build Support** AND **iOS Build Support** modules enabled (for testing native side).

---

## File Structure

```
flunity/
├── packages/flunity_bridge/
│   ├── lib/src/
│   │   ├── flunity_controller.dart                # NEW — abstract controller
│   │   ├── flunity_webgl_controller.dart          # MODIFY — implements FlunityController
│   │   ├── flunity_native_controller.dart         # NEW — wraps flutter_embed_unity
│   │   ├── flunity_native_view.dart               # NEW — peer to FlunityWebGLView
│   │   ├── flunity_view.dart                      # NEW — target-aware composite (Webgl OR Native)
│   │   ├── routing/
│   │   │   └── unity_scene_route.dart             # NEW — load_scene per Flutter route
│   │   └── transport/
│   │       └── embed_unity_transport.dart         # NEW — MessageTransport over flutter_embed_unity
│   ├── pubspec.yaml                               # MODIFY — add flutter_embed_unity dep
│   └── test/...                                   # NEW tests for native controller + scene_route
├── packages/flunity_cli/
│   ├── lib/src/
│   │   ├── manifest/manifest_schema.dart          # MODIFY — accept native_* targets
│   │   ├── commands/
│   │   │   ├── create_command.dart                # MODIFY — branch on target
│   │   │   ├── native_command.dart                # NEW — prepare/export subcommands
│   │   │   └── doctor_command.dart                # MODIFY — call into native checks
│   │   ├── doctor/checks/
│   │   │   ├── unity_modules_check.dart           # NEW
│   │   │   ├── android_ndk_check.dart             # NEW
│   │   │   ├── ios_toolchain_check.dart           # NEW
│   │   │   └── flutter_embed_unity_dep_check.dart # NEW
│   │   └── native/
│   │       ├── unity_batch_runner.dart            # NEW — invokes Unity headless
│   │       └── platform_artifact_resolver.dart    # NEW — locate Gradle module / XCFramework
│   ├── templates/
│   │   ├── flutter_native_basic/                  # NEW
│   │   └── flutter_native_bridge/                 # NEW
│   └── test/...
└── docs/
    ├── native-setup.md                            # REPLACES native-roadmap.md
    ├── target-comparison.md                       # NEW
    └── scene-routing.md                           # NEW
```

---

## Phase 1 — Manifest accepts native targets

### Task 1: Extend `FlunityTarget` enum + parser

**Files:**
- Modify: `packages/flunity_cli/lib/src/manifest/flunity_project.dart`
- Modify: `packages/flunity_cli/lib/src/manifest/manifest_schema.dart`
- Modify: `packages/flunity_cli/test/manifest/flunity_project_test.dart`

Add two new enum values (don't add `native` as combined yet — use explicit per-platform):

```dart
enum FlunityTarget { webgl, nativeAndroid, nativeIos }
```

Parser accepts `webgl`, `native_android`, `native_ios` (snake_case in YAML to match existing convention). Reject anything else with a friendly error.

The previously rejected `native_android` test now passes. Add new tests for both native values + a `native` value that's still rejected (we'll consider multi-target later).

### Task 2: Add a `targets` future-friendly model

The manifest's single `target:` field stays. To support multi-target later, expose:

```dart
class FlunityProject {
  final FlunityTarget target;
  bool get isWebGL => target == FlunityTarget.webgl;
  bool get isNative =>
      target == FlunityTarget.nativeAndroid || target == FlunityTarget.nativeIos;
}
```

Two commits: parser change, then the convenience getters.

---

## Phase 2 — Bridge package: abstract controller + native controller

### Task 3: Extract `FlunityController` interface

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_controller.dart`
- Modify: `packages/flunity_bridge/lib/src/flunity_webgl_controller.dart`
- Modify: `packages/flunity_bridge/test/flunity_webgl_controller_test.dart`

```dart
abstract interface class FlunityController {
  bool get isReady;
  Stream<FlunityMessage> get messages;
  Future<void> send(FlunityMessage message);
  Future<void> reload();
  Future<void> dispose();
}
```

`FlunityWebGLController` becomes `class FlunityWebGLController implements FlunityController { ... }` — no behavior change.

Tests update to `FlunityController controller = FlunityWebGLController(...)` style assertions where useful.

### Task 4: Add `flutter_embed_unity` to `flunity_bridge`

**Files:**
- Modify: `packages/flunity_bridge/pubspec.yaml`

Add (alphabetical):
```yaml
dependencies:
  flutter_embed_unity: ^x.y.z   # pin at planning time; current latest as of branch cut
```

`melos bootstrap` to fetch.

### Task 5: `EmbedUnityMessageTransport` — the native transport

**Files:**
- Create: `packages/flunity_bridge/lib/src/transport/embed_unity_transport.dart`

`flutter_embed_unity` exposes (paraphrased):
- `sendToUnity(String gameObjectName, String methodName, String payload)`
- A callback for messages received FROM Unity, typically registered via `UnityWidget(onUnityMessage: ...)`

Wrap this in a `MessageTransport` (the same interface `flunity_bridge` already uses for WebGL):

```dart
class EmbedUnityMessageTransport implements MessageTransport {
  final Completer<void> _ready = Completer<void>();
  final StreamController<String> _incoming = StreamController.broadcast();
  // ... ready completes when the EmbedUnity widget reports unity-ready
  // ... send -> sendToUnity('[FlunityBridge]', 'ReceiveFromFlutter', json)
  // ... onUnityMessage -> _incoming.add(json)
}
```

Same JSON envelope as WebGL. Same `[FlunityBridge]` GameObject + `ReceiveFromFlutter` method. The `FlunityBridge.cs` we already ship works unchanged — it just gets called via Unity's native messaging instead of the JS shim.

### Task 6: `FlunityNativeController`

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_native_controller.dart`

A thin class implementing `FlunityController` over `EmbedUnityMessageTransport`. Most of the logic (queueing, JSON parse) is identical to `FlunityWebGLController` — extract a common `FlunityControllerBase` if it makes sense, or duplicate the small body.

Tests: same six behaviors as the WebGL controller (queue-before-ready, typed stream, error path, isReady, reload, dispose). Use a fake `MessageTransport`.

### Task 7: `FlunityNativeView` widget

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
  // ...
}
```

State implementation mounts `flutter_embed_unity`'s `EmbedUnity` widget and wires the `EmbedUnityMessageTransport`. Same `onReady` deferral via `addPostFrameCallback` we learned from Plan D.

No `config:` parameter — native mode has no dev/bundled distinction. The Unity Library is bundled into the app binary.

### Task 8: `FlunityView` — target-aware composite (optional but useful)

**Files:**
- Create: `packages/flunity_bridge/lib/src/flunity_view.dart`

```dart
class FlunityView extends StatelessWidget {
  // Reads the target from a configuration (passed in or read from manifest at
  // app build time via --dart-define). Renders FlunityWebGLView OR
  // FlunityNativeView accordingly.
}
```

This lets generated apps switch transports via `--dart-define=FLUNITY_TARGET=native` without code change. Useful for projects that ship both — e.g., dev on native, demo on the web.

### Task 9: Public exports update

**Files:**
- Modify: `packages/flunity_bridge/lib/flunity_bridge.dart`

Export the new public types: `FlunityController`, `FlunityNativeController`, `FlunityNativeView`, `FlunityView`. Keep backward-compatible exports of the WebGL types.

---

## Phase 3 — Templates for native

### Task 10: `flutter_native_bridge` template

**Files:**
- Create: `packages/flunity_cli/templates/flutter_native_bridge/...`

Largely a copy of `flutter_webgl_bridge` with:

- `flutter_app/lib/unity/unity_view.dart` mounts `FlunityNativeView` instead of `FlunityWebGLView`.
- `flutter_app/lib/unity/unity_config.dart` is a no-op (or absent) — native has no dev/bundled.
- `flutter_app/pubspec.yaml` declares `flunity_bridge` AND `flutter_embed_unity` as deps.
- The Unity-side scripts (`FlunityBridge.cs`, etc.) are SHARED with the WebGL template — same code, same behavior.
- `flunity.yaml` defaults `target: native_ios` (or `native_android` based on `--target` flag).
- README in the template explains the manual one-time Unity setup: enable `flutter_embed_unity`'s build target, run `flunity native prepare`.

### Task 11: `flutter_native_basic` template

Stripped-down version for `--no-bridge`. Same as WebGL basic but for native target.

---

## Phase 4 — `flunity create` branches on target

### Task 12: Update `create_command.dart`

**Files:**
- Modify: `packages/flunity_cli/lib/src/commands/create_command.dart`
- Modify: `packages/flunity_cli/test/commands/create_command_test.dart`

The current command accepts `--target webgl` only and rejects others. Now:

```dart
final target = argResults!['target'] as String;
final allowedTargets = {'webgl', 'native_android', 'native_ios'};
if (!allowedTargets.contains(target)) { ... }

final templateName = (argResults!['no-bridge'] == true)
    ? (target == 'webgl' ? 'flutter_webgl_basic' : 'flutter_native_basic')
    : (target == 'webgl' ? 'flutter_webgl_bridge' : 'flutter_native_bridge');
```

Native scaffolding does NOT call `flutter pub get` immediately if `flutter_embed_unity` requires platform-specific setup steps. Those run via `flunity native prepare` afterward.

The post-render flow:
1. Render template.
2. Run `flutter create` (still needed — generates iOS / Android shells).
3. Patches: iOS ATS (still useful for telemetry / API calls), Android cleartext (less needed but harmless).
4. Write `pubspec_overrides.yaml` for `flunity_bridge` (until pub.dev publish).
5. For native targets: print "Now run `flunity native prepare` from this directory to invoke the Unity export."
6. For webgl: existing flow.

Tests gain native-target variants.

---

## Phase 5 — `flunity native prepare` / `flunity native export`

This phase is the most uncertain because it depends on `flutter_embed_unity`'s actual API shape. The plan describes intent; details may shift on first contact with the package's docs.

### Task 13: `flunity native` parent command

**Files:**
- Create: `packages/flunity_cli/lib/src/commands/native_command.dart`

Two subcommands: `prepare`, `export`.

### Task 14: `flunity native prepare`

**Behavior:**
- Locate the user's Unity install (via `unity` on PATH, `UNITY_PATH` env, or `flunity.yaml` config).
- Invoke Unity in batchmode against the manifest's `unity_project` directory:
  ```
  unity -batchmode -nographics -projectPath <unity_project> \
    -executeMethod FlutterEmbedUnity.Editor.Build.BuildAndroid \
    -quit
  ```
  (or `BuildIOS`, depending on `flunity.yaml` target)

  Note: `flutter_embed_unity` provides the editor scripts that implement `BuildAndroid` / `BuildIOS`. Flunity's job is just to invoke them with the right arguments and stream output.

- On success: artifact lands at the path `flutter_embed_unity` expects (typically `unity_project/AndroidExport/` or `unity_project/iOSExport/`).

### Task 15: `flunity native export`

**Behavior:**
- Copy the prepared artifact into the Flutter app's `android/` or `ios/` tree at the location `flutter_embed_unity` documents.
- Patch `flutter_app/android/app/build.gradle` (or `flutter_app/ios/Podfile`) with the dependency on the embedded Unity module.
- Idempotent (markers).

If `flutter_embed_unity` ships a CLI helper that does these steps, Flunity's command becomes a thin wrapper. Investigate at implementation time.

### Task 16: Tests

The Unity batch invocation is hard to test in CI (needs a Unity license). Cover:
- Argument construction (`unity_batch_runner.dart` → list of args).
- Artifact path resolution (`platform_artifact_resolver.dart`).
- Idempotent gradle / Podfile patching.

End-to-end native verification stays manual + a private CI runner.

---

## Phase 6 — Doctor checks for native

### Task 17: New checks

**Files:**
- Create: `packages/flunity_cli/lib/src/doctor/checks/unity_modules_check.dart`
  - Reads Unity Hub config or `Unity.app/Contents/PlaybackEngines/`. Verifies `Android Build Support` and/or `iOS Build Support` modules exist.
- Create: `packages/flunity_cli/lib/src/doctor/checks/android_ndk_check.dart`
  - Runs `sdkmanager --list_installed | grep ndk` or reads `local.properties`.
- Create: `packages/flunity_cli/lib/src/doctor/checks/ios_toolchain_check.dart`
  - `xcrun --find xcodebuild` exists. `xcodebuild -version` >= a known minimum.
- Create: `packages/flunity_cli/lib/src/doctor/checks/flutter_embed_unity_dep_check.dart`
  - Reads `flutter_app/pubspec.yaml` — confirms `flutter_embed_unity` is declared (only when target is native).

### Task 18: Doctor command wires native checks conditionally

**Modify:** `packages/flunity_cli/lib/src/commands/doctor_command.dart`

```dart
if (project.isNative) {
  checks.addAll([
    UnityModulesCheck(...),
    AndroidNdkCheck(...),
    IosToolchainCheck(...),
    FlutterEmbedUnityDepCheck(...),
  ]);
}
```

WebGL checks (port available, etc.) only run when `project.isWebGL`.

---

## Phase 7 — Scene routing: one Unity, many Flutter routes

### Task 19: `UnitySceneRoute` helper widget

**Files:**
- Create: `packages/flunity_bridge/lib/src/routing/unity_scene_route.dart`

Premise: Unity-as-library hosts a SINGLE Unity instance per process. Flutter has many routes. Pattern:

- Mount `FlunityNativeView` once at the app root (above the Navigator).
- Each route declares which Unity scene it wants.
- A controller-aware widget intercepts route push/pop and sends `LoadScene` messages.

```dart
class UnitySceneRoute extends StatefulWidget {
  const UnitySceneRoute({
    required this.scene,
    required this.controller,
    required this.child,
    super.key,
  });

  final String scene;
  final FlunityController controller;
  final Widget child;

  @override
  State<UnitySceneRoute> createState() => _UnitySceneRouteState();
}
```

On `initState`, sends `LoadScene(scene)` via the controller. Maintains a stack of "previous scenes" so on dispose it can restore the parent route's scene.

Plus an unobtrusive `FlunityRootView` widget that hosts `FlunityNativeView` at the app root and exposes the controller via `Provider` or `InheritedWidget`.

### Task 20: Scene routing tests + docs

A widget test that exercises push/pop and asserts the correct sequence of `LoadScene` messages went to a fake controller.

Plus `docs/scene-routing.md` with example app skeleton.

---

## Phase 8 — Docs

### Task 21: Replace `docs/native-roadmap.md` with `docs/native-setup.md`

Real setup walkthrough (now that this is shipping, not aspirational):
- Prerequisites (Unity Hub modules, NDK, Xcode).
- `flunity create my_app --target native_ios` walkthrough.
- `flunity native prepare` step.
- `flunity native export` step.
- First `flutter run`.
- Bridge messages work identically to WebGL.
- Migration from WebGL: change `target:` in flunity.yaml + swap widget; everything else unchanged.

### Task 22: New `docs/target-comparison.md`

Honest comparison: when to pick WebGL vs native_android vs native_ios. Build times, runtime perf, bundle size, multi-platform strategy.

### Task 23: New `docs/scene-routing.md`

The `UnitySceneRoute` pattern. One Unity, many Flutter routes. Code samples.

---

## Phase 9 — Polish + push + PR

### Task 24: CHANGELOGs

Repo `CHANGELOG.md`:
- New `target: native_android` / `native_ios` mode via `flutter_embed_unity` integration.
- New widgets `FlunityNativeView`, `FlunityView`, `UnitySceneRoute`.
- New commands `flunity native prepare` / `flunity native export`.
- New doctor checks for Unity modules, NDK, Xcode.
- Existing WebGL flow unchanged — fully backward-compatible.

`flunity_bridge/CHANGELOG.md`:
- Extracted `FlunityController` abstract interface.
- Added `FlunityNativeController`, `FlunityNativeView`, `FlunityView`.
- New `flutter_embed_unity` dependency.

`flunity_cli/CHANGELOG.md`:
- `--target native_android` / `--target native_ios` accepted.
- New `flunity native prepare` + `export` subcommands.
- Two new templates.

### Task 25: melos analyze / format-check / test all green

53 prior tests + new tests from Phases 2, 3, 4, 5, 6, 7. Estimated total: 70-90 tests.

### Task 26: Push + PR

```bash
git push -u origin feat/plan-f-native-via-embed
gh pr create --base main --head feat/plan-f-native-via-embed \
  --title "Plan F: native target via flutter_embed_unity" --body ...
```

---

## Definition of done for Plan F

- [ ] `flunity.yaml` accepts `target: native_android` / `native_ios`.
- [ ] `flunity create my_app --target native_ios` produces a project that scaffolds correctly.
- [ ] `flunity native prepare` invokes Unity batch export and the artifact lands.
- [ ] `flunity native export` integrates the artifact into the Flutter app.
- [ ] After `flutter run --release`, the native Unity runs in the Flutter app, Ping/Pong round-trips through `FlunityNativeView`.
- [ ] `UnitySceneRoute` swaps Unity scenes when Flutter routes push/pop.
- [ ] WebGL flow remains untouched — `flunity create my_app` (default target) still produces a working WebGL project.
- [ ] Doctor distinguishes WebGL and native projects, runs target-appropriate checks.
- [ ] `melos run analyze + test + format-check` all green.

---

## Open questions (resolve at implementation time)

1. **`flutter_embed_unity` version pinning.** What's the latest stable as of branch cut? Does it support Flutter 3.24+?
2. **Editor script authorship.** Does `flutter_embed_unity` provide `BuildAndroid` / `BuildIOS` editor scripts, or do users write them? Affects Phase 5 scope.
3. **Unity license for CI.** Native build pipelines need a license. Likely defer real native CI to a private runner; keep public CI as analyze + test only.
4. **`FlunityView` target detection.** Should it read `--dart-define=FLUNITY_TARGET`, or call into a generated `unity_config.dart` like the WebGL template does?
5. **Multi-target single project.** Can one project ship BOTH webgl + native? Manifest `target:` is a single value. Future `targets: [webgl, native_ios]` could use composite scaffolding. Out of scope for Plan F; flag as Plan G.

---

## Effort estimate (refined)

| Phase | Time |
| --- | --- |
| 1 — Manifest accepts native | 2-4 hours |
| 2 — Bridge: abstract controller + native controller | 1-2 days |
| 3 — Native templates | 1 day |
| 4 — `flunity create` branches | 4-6 hours |
| 5 — Native prepare / export | 2-3 days (uncertain — depends on `flutter_embed_unity`) |
| 6 — Doctor native checks | 4-6 hours |
| 7 — Scene routing | 1-2 days |
| 8 — Docs | 4-6 hours |
| 9 — Polish + PR | 4 hours |
| **Total** | **~1.5-2 weeks of focused work** |

vs. building native from scratch (~6-8 weeks).

---

## Out of scope for Plan F (named so we don't drift)

- Multi-target projects (`targets: [webgl, native_ios]`) — Plan G.
- Custom Unity versions / non-LTS support — Plan G.
- Hot-reload / live link for native — Plan H (may share infrastructure with Plan E).
- Replacing `flutter_embed_unity` with our own platform integration — only if `flutter_embed_unity` becomes unmaintained.
- Web target (Flutter web embedding Unity WebGL inside a webview-in-canvas) — second-wave.
