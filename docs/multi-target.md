# Multi-target builds

A single Unity project can produce two independent build artifacts: an iOS Xcode export and an Android Gradle module. Flunity treats each as a first-class **target** with its own manifest entry, build dir, and Flutter integration path.

## Targets

| Target | Manifest | Build dir | Flutter integration |
| --- | --- | --- | --- |
| `ios` | `target: ios` | `unity_project/Builds/ios/` | `flutter_app/ios/UnityExport/` Xcode sub-project; its `UnityFramework.framework` product is embedded into Runner. |
| `android` | `target: android` | `unity_project/Builds/android/` | `flutter_app/android/unityLibrary/` Gradle module included from `settings.gradle`. |

The build dir is derived as `<paths.unity_builds>/<target>` — by default `unity_project/Builds/<target>`. Override it per-project with `paths.unity_build` if your CI splits artifacts somewhere unusual.

## Switching targets in an existing project

The CLI scaffolds for one target at a time. To target the others, edit `flunity.yaml`:

```yaml
target: android   # was ios
```

…then re-run `flunity doctor` to see what's missing for the new target.

> Plan G ("multi-target single project") will let one manifest declare `targets: [ios, android]` and pick the active target via a CLI flag. Until then, switching means re-editing the manifest.

## Sharing assets across targets

Inside `unity_project/`:

- `Assets/` — shared by all targets.
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

- **`flunity bundle ios` and `flunity bundle android` coexist** — one copies into `flutter_app/ios/UnityExport/`, the other into `flutter_app/android/unityLibrary/`.
- **macOS desktop is not a Flunity target.** It's tracked as Plan J.
