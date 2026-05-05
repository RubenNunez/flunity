# Changelog

## [Unreleased]

### Added
- Initial release: `create`, `doctor`, `webgl serve`, `webgl copy`, `webgl clean`, and `bridge init` commands.
- `flunity.yaml` project manifest model and loader.
- Template rendering engine (`__var__` substitution).
- `flunity` executable (canonical entry point for the CLI).
- `flutter_webgl_bridge` template (default for `flunity create`) with full bridge wiring.
- `unity_bridge_basic` template applied by `flunity bridge init`.
- E2E smoke test against a stub WebGL build.

### Changed
- `flunity create` now defaults to `flutter_webgl_bridge`. Pass `--no-bridge` for the basic scaffold.
- `flunity bridge init` now reads from templates instead of inlined string constants.
- **Breaking:** `flunity create` now runs `flutter create`, patches iOS ATS + Android cleartext, writes `pubspec_overrides.yaml`, and runs `flutter pub get`. Requires `flutter` on PATH.
- `flunity webgl serve` and `flunity webgl copy` auto-prepare the Unity WebGL build (no more manual `bridge init` after each Unity rebuild).

### Added
- New `flunity webgl prepare` subcommand.
- New `--bridge-path` option on `flunity create`.

### Fixed
- Dev server sets `Content-Encoding: gzip` / `br` for direct `.gz` / `.br` requests.
- Split `FlunityBridge.cs` so Unity's Add Component finds the MonoBehaviour.

### Added (Plan F: native targets)
- `flunity create --target webgl|ios|android`. Native targets pick the new `flutter_native_basic` / `flutter_native_bridge` templates.
- `flunity build [<target>]` — runs Unity in batchmode against the bundled Editor scripts (`FlunityWebGLBuilder`, `FlunityBatchmode.ExportProjectIos`, `FlunityBatchmode.ExportProjectAndroid`). Locates Unity via `--unity`, `UNITY_PATH`, or Unity Hub auto-detect; prefers Unity 6 (6000.x).
- `flunity bundle [<target>]` — copies the build artifact into the Flutter app. WebGL → `assets/unity_webgl/`. iOS → `flutter_app/ios/UnityExport/` (prints Xcode wiring checklist). Android → `flutter_app/android/unityLibrary/` plus idempotent `settings.gradle` and `app/build.gradle` patches (Groovy and Kotlin DSL supported).
- Manifest: `target:` accepts `webgl | ios | android`; per-target build dir derived as `<paths.unity_builds>/<target>/`. Legacy `paths.unity_build` still honored as an override.
- Doctor: target-conditional checks. Native targets add `unity_binary_check` + `xcode_check` (iOS) / `android_sdk_check` (Android); the existing `flutter_assets_declared_check` and `port_available_check` only run for `target: webgl`.
- Unity Editor scripts vendored from `flutter_embed_unity` v2.0.0 (MIT) — `ProjectExporterIos` / `ProjectExporterAndroid` produce flutter-friendly Xcode and Gradle exports. Plus a new `FlunityWebGLBuilder` for parity.
- New `flutter_native_basic` and `flutter_native_bridge` templates ship the bundled Editor scripts, the `[FlunityBridge]` GameObject prefab (bridge variant), and `build_unity_{ios,android}.sh` muscle-memory wrappers.

### Changed (Plan F)
- iOS / Android cleartext + ATS patchers now only run on `target: webgl` — native templates don't need a 127.0.0.1 exemption.
- Unity build dir convention: `unity_project/Builds/webgl/` (lowercase, was `WebGL/`); per-target subdirs for `ios/` and `android/`.
