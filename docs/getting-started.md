# Getting Started

Welcome to Flunity. This guide takes you from zero to a Flutter app rendering a Unity scene in under ten minutes.

## Prerequisites

- **Flutter** 3.38 or newer (`flutter --version`).
- **Dart** 3.10 or newer (ships with Flutter).
- **Unity** 6.0 (6000.x) with the right Build Support module for your target:
  - `webgl` → WebGL Build Support
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

Flunity supports three Unity build targets. Pick one — you can switch later by editing `flunity.yaml`. See [target-comparison.md](target-comparison.md) for the honest tradeoff guide.

```bash
flunity create hello_unity --target webgl    # default if --target is omitted
# or
flunity create hello_unity --target ios
flunity create hello_unity --target android

cd hello_unity
```

You'll get `flunity.yaml`, a `flutter_app/` and a `unity_project/`. See [project-structure.md](project-structure.md).

## 3. Verify your environment

```bash
flunity doctor
```

The doctor branches per target — for `webgl` it checks port availability + asset declarations; for `ios` it checks Xcode + Unity binary; for `android` it checks ANDROID_HOME + NDK. Each row is `✓` / `⚠` / `✗` with a hint.

## 4. Build the Unity scene

```bash
flunity build <target>      # webgl | ios | android
flunity bundle <target>     # copies the build into the Flutter app
```

`flunity build` runs Unity headless via batchmode against vendored Editor scripts; `flunity bundle` copies the output into the right place in `flutter_app/`. For iOS specifically, the first time you'll also need to drag `app/ios/UnityExport/unityLibrary/Unity-iPhone.xcodeproj` into your `Runner.xcworkspace` and embed `UnityFramework.framework` — see [native-setup.md](native-setup.md).

For WebGL you can also use the in-Editor menu: open `unity_project/` in Unity → **Flunity → Build → WebGL**. iOS gets two menu items — **Flunity → Build → iOS (Device)** and **iOS (Simulator)**.

## 5. Run

WebGL dev loop:

```bash
# terminal 1
flunity webgl serve

# terminal 2
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

iOS / Android:

```bash
cd flutter_app
flutter run -d <device-id>      # `flutter devices` lists them
```

## 6. Talk to Unity

Two patterns:

- **Outlets** — typed Flutter→Unity invocation (recommended for new code). Decorate a C# method with `[FlunityOutlet]`, call it from Dart with `await flunity.invoke<T>('Class.Method', args:)`. Currently iOS / Android only — WebGL outlet support is on the roadmap. See [outlets.md](outlets.md).
- **Manual messages** — `FlunityBridge.OnMessage` event + `FlunityBridge.SendRaw` for stream-style or multi-receiver use. Works on every transport. See [bridge-api.md](bridge-api.md).

## 7. What's next?

- [target-comparison.md](target-comparison.md) — webgl vs ios vs android, when to pick what.
- [outlets.md](outlets.md) — declarative `[FlunityOutlet]` API.
- [bridge-api.md](bridge-api.md) — raw message / `OnMessage` patterns.
- [webgl-workflow.md](webgl-workflow.md) — WebGL dev/production loop in detail.
- [native-setup.md](native-setup.md) — iOS / Android end-to-end + Xcode wiring.
- [multi-target.md](multi-target.md) — one Unity project, three artifacts.
- [scene-routing.md](scene-routing.md) — `UnitySceneRoute` for one-Unity-many-Flutter-routes.
- [production-build.md](production-build.md) — release builds.
- [android-emulator.md](android-emulator.md) — `10.0.2.2` and cleartext.
