# Getting Started

Welcome to Flunity. This guide takes you from zero to a Flutter app rendering a Unity scene in under ten minutes.

## Prerequisites

- **Flutter** 3.44 or newer (`flutter --version`).
- **Dart** 3.12 or newer (ships with Flutter).
- **Unity** 6.0 (6000.x) with the right Build Support module for your target:
  - `ios` → iOS Build Support
  - `android` → Android Build Support + NDK 27
- **Xcode** 15+ for iOS targets; **Android Studio** with NDK 27+ for Android targets.

## 1. Install the CLI

```bash
dart pub global activate flunity_cli
```

Verify (`$HOME/.pub-cache/bin` must be on your PATH):

```bash
flunity --version
# flunity 0.1.0
```

## 2. Pick a target and scaffold

Flunity embeds Unity natively (Unity-as-a-library). Pick a target — you can switch later by editing `flunity.yaml`.

```bash
flunity create hello_unity --target ios      # default if --target is omitted
# or
flunity create hello_unity --target android

cd hello_unity
```

You'll get `flunity.yaml`, a `flutter_app/` and a `unity_project/`. See [project-structure.md](project-structure.md).

## 3. Verify your environment

```bash
flunity doctor
```

The doctor branches per target — for `ios` it checks Xcode + Unity binary; for `android` it checks ANDROID_HOME + NDK. Each row is `✓` / `⚠` / `✗` with a hint.

## 4. Build the Unity scene

```bash
flunity build <target>      # ios | android
flunity bundle <target>     # copies the build into the Flutter app
```

`flunity build` runs Unity headless via batchmode against vendored Editor scripts; `flunity bundle` copies the output into the right place in `flutter_app/`. For iOS specifically, the first time you'll also need to drag `app/ios/UnityExport/unityLibrary/Unity-iPhone.xcodeproj` into your `Runner.xcworkspace` and embed `UnityFramework.framework` — see [native-setup.md](native-setup.md).

iOS also has in-Editor menu items — **Flunity → Build → iOS (Device)** and **iOS (Simulator)**.

Editor already open? `flunity build` detects that (via the standalone `unity` CLI) and drives it directly instead of failing with "another Unity instance is running".

## 5. Run

```bash
cd flutter_app
flutter run -d <device-id>      # `flutter devices` lists them
```

## 6. Talk to Unity

Two patterns:

- **Outlets** — typed Flutter→Unity invocation (recommended for new code). Decorate a C# method with `[FlunityOutlet]`, call it from Dart with `await flunity.invoke<T>('Class.Method', args:)`. The same typed API on both targets. See [outlets.md](outlets.md).
- **Manual messages** — `FlunityBridge.OnMessage` event + `FlunityBridge.SendRaw` for stream-style or multi-receiver use. Works on every transport. See [bridge-api.md](bridge-api.md).

## 7. What's next?

- [outlets.md](outlets.md) — declarative `[FlunityOutlet]` API.
- [bridge-api.md](bridge-api.md) — raw message / `OnMessage` patterns.
- [native-setup.md](native-setup.md) — iOS / Android end-to-end + Xcode wiring.
- [multi-target.md](multi-target.md) — one Unity project, two artifacts.
- [scene-routing.md](scene-routing.md) — `UnitySceneRoute` for one-Unity-many-Flutter-routes.
