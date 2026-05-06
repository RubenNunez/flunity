# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial design spec (`docs/superpowers/specs/2026-05-04-flunity-v1-design.md`).
- Melos workspace bootstrap.
- `flunity_bridge` package with abstract `FlunityMessage` hierarchy, `FlunityWebGLConfig`, `FlunityWebGLController`, `FlunityWebGLView`.
- `flunity_cli` package with `flunity` executable and six commands (`create`, `doctor`, `webgl serve`, `webgl copy`, `webgl clean`, `bridge init`).
- `flutter_webgl_bridge` and `unity_bridge_basic` templates with full bridge wiring (Unity-side `FlunityBridge.cs`, `flunity_bridge.jslib`, `flunity_bridge.js` shim).
- `flunity create` defaults to the bridge-wired template; `--no-bridge` opts out.
- `flunity bridge init` reads from the `unity_bridge_basic` template instead of inlined strings.
- E2E smoke test against a stub WebGL build.
- Documentation: getting-started, project-structure, webgl-workflow, bridge-api, production-build, android-emulator.

### Changed
- Dropped the short `fl` / `fu` aliases; only `flunity` is shipped.
- **Breaking:** `flunity create` now invokes `flutter create`, patches iOS ATS / Android cleartext, writes `pubspec_overrides.yaml`, and runs `flutter pub get` so the generated project is ready to `flutter run` immediately. Requires `flutter` on PATH.
- `flunity webgl serve` and `flunity webgl copy` auto-prepare the Unity WebGL build (copy `flunity_bridge.js`, patch `index.html` to call `window.flunity.ready(unityInstance)`). No more manual `bridge init` after each Unity rebuild.

### Added
- New `flunity webgl prepare` subcommand for explicit invocation.
- New `--bridge-path` flag on `flunity create` for path-based `flunity_bridge` installs (until pub.dev publishing).
- `IosAtsPatcher` and `AndroidCleartextPatcher` — idempotent merge logic that adds Flunity's customizations on top of `flutter create`'s output.

### Fixed
- `flunity_bridge`: `FlunityWebGLView.onReady` now fires via `addPostFrameCallback` so consumers can safely call `setState()` in response (was crashing with "setState() called during build").
- `flunity_cli`: dev server sets `Content-Encoding: gzip` / `br` for direct `.gz` / `.br` requests (Unity's compressed-build URL convention).
- `flunity_cli`: split `FlunityBridge.cs` into `FlunityBridge.cs` + `FlunityBridgeBehaviour.cs` so Unity's Add Component dialog finds the MonoBehaviour.
- Templates no longer ship incomplete custom `Info.plist` and `AndroidManifest.xml` — `flutter create` generates standard versions and Flunity merges customizations on top.

### Plan F — Native targets (iOS / Android)

Adds `target: ios` and `target: android` next to the existing `target: webgl`. A single Unity project can now be built to all three with `flunity build webgl|ios|android`. Highlights:

- New `FlunityNativeView` and `UnitySceneRoute` widgets in `flunity_bridge`.
- New `flunity build` and `flunity bundle` CLI commands.
- New `flutter_native_basic` and `flutter_native_bridge` templates.
- Vendored `flutter_embed_unity` v2.0.0 (MIT, learntoflutter) into `flunity_bridge` (no external dependency); see `packages/flunity_bridge/THIRDPARTY.md` for attribution.
- Tooling baselines: Flutter 3.38, Dart 3.10, Unity 6 (6000.x), iOS 14, Android NDK 27.
- Doctor now branches per target: WebGL retains the asset / port checks; native targets gain `unity_binary_check` + `xcode_check` (iOS) / `android_sdk_check` (Android).
- Build directory layout changed to per-target subdirs: `<unity_project>/Builds/<target>/`. The legacy `paths.unity_build:` field is still honored as an override.
- Four new docs: [native-setup](docs/native-setup.md), [multi-target](docs/multi-target.md), [target-comparison](docs/target-comparison.md), [scene-routing](docs/scene-routing.md).

### Plan F follow-up fixes (post-merge stabilization)

The native iOS / Android path needed a handful of fixes after Plan F merged. Bundled here so they don't get lost:

- `flunity_bridge` Pod opts into native UnityFramework linking by default; `FLUNITY_WEBGL_ONLY=1` env var keeps the WebGL-only mode for apps that don't ship native.
- iOS linker symbol renamed: `_FlutterEmbedUnityIos_sendToFlutter` → `_FlunityBridge_sendToFlutter`. Without this, every iOS build failed with "Undefined symbol" at link time.
- New `flunity build ios --simulator` flag flips Unity's iOS Player Settings to Simulator SDK for the build, then restores. Mirrored in the Editor menu as **Flunity → Build → iOS (Device)** vs **iOS (Simulator)**.
- `flunity_bridge` Pod adds `OTHER_LDFLAGS = -undefined dynamic_lookup` so `_OBJC_CLASS_$_UnityFramework` resolves at runtime against the real framework (the vendored stub xcframework doesn't export the symbol).
- Stale references renamed: `ProjectExporterBatchmode` → `FlunityBatchmode`, `PlayerSettings.GetScriptingBackend(BuildTargetGroup)` → `NamedBuildTarget` overload (Unity 6 deprecated the former).
- `flunity doctor` UnityBuildCheck and `flunity bundle ios` next-steps message both now correctly handle the `unityLibrary/` subfolder nesting that the upstream exporter writes to.
- Editor "Select export directory" dialogs reference the correct Flunity path (`<flunity project>/unity_project/Builds/<target>/unityLibrary`) instead of the misleading upstream `flutter_embed_unity` path.

### Plan K — Outlets

Typed Flutter→Unity invocation + scene discovery, replacing manual `OnMessage` switch-statement dispatch.

- New C# attributes: `[FlunityOutlet]` (any public method, optional name override) and `[FlunityIdentity]` (string field, multi-instance routing). `FlunityOutletRegistry` MonoBehaviour auto-attaches via `FlunityBridgeBehaviour` and scans loaded assemblies via reflection. Supports `void`, `T`, `Task`, `Task<T>` returns; async continuations scheduled on the captured Unity main thread.
- New Dart API: singleton `flunity.invoke<T>('Class.Method', args:, target:, timeout:)` and `flunity.find('ComponentName')` returning `List<FlunityComponentHandle>`. `handle.invoke(method, args:)` sugar threads target id automatically.
- New built-in messages: `outlet_call`, `outlet_reply`, `outlet_find`, `outlet_find_reply`.
- `FlunityOutletException` / `FlunityOutletTimeoutException` / `FlunityNotAttachedException` for the three failure modes. 5s default timeout, configurable per call.
- `UnityMessageListeners` gains an "always-fanout" hook so the invoker receives replies regardless of which native widget is mounted.
- Resolution order: static method → targeted instance → unique singleton instance → "ambiguous" / "not found" with a clear hint.
- Native iOS / Android only in v1; WebGL outlet support is Plan L.
- Framework C# scripts now grouped under `Assets/Scripts/Flunity/` in all templates.
- New doc: [outlets.md](docs/outlets.md).
