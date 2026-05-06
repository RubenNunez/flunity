# Changelog

## [Unreleased]

### Initial

- `flunity` executable. Commands: `create`, `doctor`, `bridge init`, `webgl serve|copy|clean|prepare`.
- `flunity.yaml` manifest model + template renderer.
- Templates: `flutter_webgl_basic`, `flutter_webgl_bridge`, `unity_bridge_basic`.

### Plan F — native targets

- `flunity create --target webgl|ios|android`. New templates: `flutter_native_basic`, `flutter_native_bridge`.
- `flunity build [<target>]` — Unity batchmode against vendored Editor scripts (`FlunityWebGLBuilder`, `FlunityBatchmode.ExportProjectIos`, `FlunityBatchmode.ExportProjectAndroid`). Locates Unity via `--unity` / `UNITY_PATH` / Hub auto-detect.
- `flunity build ios --simulator` — flips Unity Player Settings to Simulator SDK for that build only.
- `flunity bundle [<target>]` — copies the Unity export into the Flutter app. Android additionally patches Gradle (Groovy + Kotlin DSL).
- Manifest: `target: webgl|ios|android`, per-target build dir `<paths.unity_builds>/<target>/`.
- Doctor branches per target (Unity binary + Xcode for iOS, NDK for Android, port + assets for WebGL).
- Editor menu: `Flunity → Build → iOS (Device|Simulator) | Android | WebGL`. No folder picker; canonical Flunity path resolved from project root.

### Plan K — outlets (templates only — Dart-side in flunity_bridge)

- C# attributes `[FlunityOutlet]` / `[FlunityIdentity]`.
- `FlunityOutletRegistry` MonoBehaviour — assembly scan + dispatch on Awake. Sync, async (`Task` / `Task<T>`).
- `FlunitySceneInspector` MonoBehaviour — `Flunity.Scene.Tree()` + `Flunity.Scene.Inspect({id})` system outlets.
- `FlunityLogStreamer` MonoBehaviour — forwards Unity `Debug.Log` to Flutter as `flunity_log` messages.
- All four auto-attached on `[FlunityBridge]` by `FlunityBridgeBehaviour`.
- Framework scripts grouped under `Assets/Scripts/Flunity/` in every template.
