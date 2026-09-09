# Native setup (iOS / Android)

End-to-end walkthrough for building a Flunity app that embeds Unity natively — a `UnityFramework.framework` on iOS, a `unityLibrary` Gradle module on Android.

## Prerequisites

| Tool | Minimum | Notes |
| --- | --- | --- |
| Unity | 6.0 (6000.x) | Install **iOS Build Support** and/or **Android Build Support** modules via Unity Hub. |
| Flutter | 3.44 | Dart 3.12 sdk. Required for Swift Package Manager support. |
| Xcode | 15+ | macOS only. Required for `flunity build ios` and `flutter build ios`. |
| Android NDK | 27+ | Set `ANDROID_HOME` and either install NDK 27 via Android Studio's SDK Manager or export `ANDROID_NDK_HOME`. |

`flunity doctor` verifies all of the above against your manifest's target. Run it after every step.

## Scaffold

```bash
flunity create my_game --target ios     # or --target android
cd my_game
flunity doctor                           # should show all green for ios/android
```

The scaffold gives you:

```
my_game/
├── flunity.yaml                  target: ios (or android)
├── flutter_app/                  Flutter app with FlunityNativeView pre-wired
└── unity_project/                Unity project with the Flunity Editor scripts
    ├── Assets/Editor/Flunity/    iOS + Android exporters (vendored from flutter_embed_unity)
    └── Assets/Scripts/           FlunityBridge.cs + bridge GameObject prefabs
```

Use `--no-bridge` if you want a stripped-down scaffold without the bridge wiring. You can always add it later by hand.

## Build Unity → Flutter

```bash
flunity build ios          # invokes Unity batchmode → unity_project/Builds/ios/
flunity bundle ios         # copies the export into flutter_app/ios/UnityExport/

# or

flunity build android      # → unity_project/Builds/android/
flunity bundle android     # → flutter_app/android/unityLibrary/
```

`flunity build` finds Unity in this order:

1. `--unity /path/to/Unity` (if passed).
2. `UNITY_PATH` environment variable.
3. Unity Hub auto-detect: `/Applications/Unity/Hub/Editor/<version>/Unity.app/...` on macOS, `~/Unity/Hub/Editor/<version>/Editor/Unity` on Linux, `C:\Program Files\Unity\Hub\Editor\<version>\Editor\Unity.exe` on Windows.

When multiple Editor versions are installed, the highest-numbered 6000.x install wins.

Already have `unity_project/` open in the Editor? If the standalone `unity` CLI is installed, `flunity build` detects the lock and drives that open Editor directly instead of failing with "another Unity instance is running" (`--batch` forces the old behaviour; Android falls back to a less-precise path).

`flunity bundle android` patches `flutter_app/android/settings.gradle` to `include ":unityLibrary"` and `flutter_app/android/app/build.gradle` to add `implementation project(":unityLibrary")`. Both patches are idempotent — safe to re-run.

`flunity bundle ios` does **not** edit `project.pbxproj` automatically (text-editing Xcode project files is fragile). It prints a checklist instead:

1. Open `flutter_app/ios/Runner.xcworkspace` in Xcode.
2. Drag `UnityExport/unityLibrary/Unity-iPhone.xcodeproj` into the Runner project as a sub-project.
3. Under Runner target → Frameworks, Libraries, and Embedded Content, add the sub-project's `UnityFramework.framework` product as **Embed & Sign**.

## Dependency manager (CocoaPods / Swift Package Manager)

Swift Package Manager is the default on Flutter 3.44+, and `flunity_bridge`
supports both managers — `ios/flunity_bridge/Package.swift` for SPM,
`ios/flunity_bridge.podspec` for CocoaPods. You do not have to choose; the two
coexist in one project and Flutter wires each plugin through whichever it
supports.

Since WebGL was removed, `flunity_bridge` has no plugin dependencies of its own —
just `flutter` and `meta` — so nothing a Flunity app pulls in is missing SPM
support. With SPM enabled the plugin resolves entirely through Package
Dependencies and `pod install` has nothing of ours to install. If your own
dependencies are likewise SPM-capable you can retire CocoaPods completely —
Flutter detects this and prints the exact `pod deintegrate` steps, including the
two `Pods-Runner` xcconfig includes to strip from `ios/Flutter/Debug.xcconfig`
and `Release.xcconfig`.

A fully deintegrated `ios`-target app — no `Podfile`, no `Pods/`, no xcconfig
includes — has been verified to build: `flutter build ios` runs no `pod install`
step at all. Nothing in `flunity_cli` ever invokes CocoaPods, and embedding Unity
is pure Xcode (a sub-project plus Embed & Sign), so the native path needs it
nowhere. Note that `pod deintegrate` leaves `Runner.xcworkspace` behind; that's
harmless, and you can open `Runner.xcodeproj` directly instead.

`flunity_bridge.podspec` stays in this repo regardless, for consumers who
deliberately pin CocoaPods — supported until it goes read-only on 2026-12-02.

Dragging Unity's `Unity-iPhone.xcodeproj` in as a sub-project is safe with SPM
enabled. Flutter's migration only ever inserts into `project.pbxproj`, guards every
section against re-application, and never touches `projectReferences`, so the Unity
wiring is not disturbed. Re-running it is a no-op.

To force one manager for a single project, set it in `flutter_app/pubspec.yaml`:

```yaml
flutter:
  config:
    enable-swift-package-manager: true   # or false to stay on CocoaPods
```

**Verified:** debug iOS Simulator builds of an `ios`-target scaffold under both
managers, without a Unity export present.
**Not verified:** release and archive builds (TestFlight, ad-hoc, App Store)
under SPM, and runtime symbol resolution against a real Unity export.
`Package.swift` deliberately forces `type: .dynamic` and defers
`_OBJC_CLASS_$_UnityFramework` to dyld via `-undefined dynamic_lookup`; the
failure mode that machinery guards against — `symbol not found in flat
namespace` — only appears in archive configurations. Treat the first release
build on SPM as unproven, and fall back to
`enable-swift-package-manager: false` if it bites.

## Run

```bash
cd flutter_app
flutter run -d ios          # or -d android
```

The default scaffold mounts `FlunityNativeView` on the home screen with a **Ping** button. Tapping it sends a `Ping` message to Unity; Unity's `[FlunityBridge]` GameObject responds with `Pong` and the status overlay updates.

## Iterate

Native iteration cycle:

1. Edit your Unity scene.
2. `flunity build <target> && flunity bundle <target>`.
3. `flutter run` (the AndroidView / UiKitView picks up the rebuilt Unity automatically).

For Android the Unity build alone is ~2 min; on iOS ~3 min. Add `flunity build` to a watchexec or VS Code task if you're iterating heavily.

## Troubleshooting

- **"Unity binary not found"** — `flunity doctor` will show this. Set `UNITY_PATH` or pass `--unity` to `flunity build`.
- **Android build error mentioning `ndkPath`** — Plan F's vendored exporter strips Unity's hardcoded NDK path. If you still see it, your unity build pre-dates the new exporter; clean `unity_project/Library/` and rebuild.
- **iOS link error about `_FlunityBridge_sendToFlutter`** — your scene is missing the `[FlunityBridge]` GameObject + `FlunityBridgeBehaviour`. The template ships with one in `Assets/Scripts/FlunityBridgeDemo.cs` you can drop into Main.unity.
- **Flutter app boots but Unity is black on Android** — the `UnityPlayer` lifecycle is sensitive to your activity's `configChanges`. Add `orientation|keyboardHidden|screenSize|screenLayout` to the main activity in `android/app/src/main/AndroidManifest.xml`.
