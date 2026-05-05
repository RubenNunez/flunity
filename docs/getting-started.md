# Getting Started

Welcome to Flunity. This guide takes you from zero to a Flutter app rendering a Unity WebGL scene in under ten minutes.

## Prerequisites

- **Flutter** 3.24 or newer (`flutter --version`).
- **Dart** 3.5 or newer (ships with Flutter).
- **Unity** 2022.3 LTS or newer with the **WebGL Build Support** module installed.
- A working Flutter target (Android emulator, iOS simulator, macOS, Windows, or Linux desktop).

## 1. Install the CLI

```bash
dart pub global activate flunity_cli
```

This installs the `flunity` executable. `$HOME/.pub-cache/bin` must be on your PATH.

Verify the install:

```bash
flunity --version
# flunity 0.1.0
```

## 2. Scaffold a project

```bash
flunity create hello_unity
cd hello_unity
```

You'll get a directory tree with `flunity.yaml`, a `flutter_app/` and a `unity_project/`. See [Project Structure](project-structure.md).

## 3. Verify your environment

```bash
flunity doctor
```

Doctor runs a series of checks — Flutter SDK version, Dart SDK version, port availability, manifest validity, and so on. Each row is `✓` / `⚠` / `✗` with a hint.

## 4. Build the Unity scene

Open `hello_unity/unity_project/` in Unity. Build the WebGL target into `unity_project/Builds/WebGL/` (any scene works; the template includes a placeholder).

## 5. Run the dev loop

In one terminal:

```bash
flunity webgl serve
```

In another:

```bash
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

The Flutter app launches, mounts a `FlunityWebGLView`, and loads the served Unity build via WebView.

## 6. What's next?

- [WebGL Workflow](webgl-workflow.md) — the dev/production loop in detail.
- [Bridge API](bridge-api.md) — sending typed messages between Flutter and Unity.
- [Production Build](production-build.md) — bundling Unity into your release APK / IPA.
- [Android Emulator Notes](android-emulator.md) — `10.0.2.2` and cleartext.
