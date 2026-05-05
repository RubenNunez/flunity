# Multi-target builds

A single Unity project can produce three independent build artifacts: a WebGL bundle, an iOS Xcode export, and an Android Gradle module. Flunity treats each as a first-class **target** with its own manifest entry, build dir, and Flutter integration path.

## Targets

| Target | Manifest | Build dir | Flutter integration |
| --- | --- | --- | --- |
| `webgl` | `target: webgl` | `unity_project/Builds/webgl/` | Asset bundle (`flutter_app/assets/unity_webgl/`) loaded by `FlunityWebGLView`. |
| `ios` | `target: ios` | `unity_project/Builds/ios/` | `flutter_app/ios/UnityExport/` Xcode sub-project + `UnityFramework.xcframework` embedded into Runner. |
| `android` | `target: android` | `unity_project/Builds/android/` | `flutter_app/android/unityLibrary/` Gradle module included from `settings.gradle`. |

The build dir is derived as `<paths.unity_builds>/<target>` — by default `unity_project/Builds/<target>`. Override it per-project with `paths.unity_build` if your CI splits artifacts somewhere unusual.

## Switching targets in an existing project

The CLI scaffolds for one target at a time. To target the others, edit `flunity.yaml`:

```yaml
target: ios   # was webgl
```

…then re-run `flunity doctor` to see what's missing for the new target. If you scaffolded `--target webgl` originally, your `flutter_app/ios/Info.plist` won't have an embedded UnityFramework — run `flunity bundle ios` after the first `flunity build ios` to copy the artifact in.

> Plan G ("multi-target single project") will let one manifest declare `targets: [webgl, ios]` and pick the active target via a CLI flag. Until then, switching means re-editing the manifest.

## Sharing assets across targets

Inside `unity_project/`:

- `Assets/` — shared by all targets.
- `Assets/Plugins/WebGL/` — only included in WebGL builds (Unity excludes by platform).
- `Assets/Plugins/iOS/` and `Assets/Plugins/Android/` — only included in their respective native builds.

The vendored `Assets/Editor/Flunity/` build scripts produce different outputs per target but read the **same scenes** from `EditorBuildSettings.scenes`. Maintain one set of scenes; the per-target exporter handles platform differences.

## Per-target Player Settings

Unity's Player Settings are stored per-platform inside `unity_project/ProjectSettings/ProjectSettings.asset`. Setting splash screen, bundle ID, scripting backend, etc. for one target doesn't affect the others. Open Unity → File → Build Settings → Player Settings → expand the target tab.

For settings you want to drive from `flunity.yaml` (org, bundle ID, version), the CLI's `flunity create --org com.example` populates the Flutter scaffold's bundle ID. Unity's bundle ID is independent — you can keep them aligned manually or leave them divergent and let your store listings own the canonical value.

## CI tips

`flunity build <target>` is intended to be CI-friendly. Required env:

- `UNITY_PATH` — full path to the Unity binary.
- `UNITY_LICENSE` (or a manual activation step before invoking) — Unity refuses to build without a license, even for free Personal seats in CI.
- `ANDROID_HOME` + NDK 27 (Android only).
- `xcode-select -p` returning a valid developer dir (iOS only).

Run `flunity doctor` as the first CI step; it surfaces missing toolchain pieces before the 5-minute Unity build wastes runner time.

## Limitations to know about

- **Only one target's artifacts can be "bundled" into a given Flutter scaffold at a time.** `flunity bundle ios` copies into `flutter_app/ios/UnityExport/`; it doesn't conflict with `flunity bundle android`'s `flutter_app/android/unityLibrary/`, but the **Flutter pubspec assets** for WebGL (`assets/unity_webgl/`) and the iOS/Android native modules can coexist if you really want a triple-target Flutter app — Plan G will make that ergonomic.
- **macOS desktop is not a Flunity target.** It's tracked as Plan J. For now, run the WebGL build inside Flutter desktop's WebView if you need a Mac/Linux/Windows desktop story.
