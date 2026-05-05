# Project Structure

Flunity scaffolds a project with three top-level concerns:

```
hello_unity/
├── flunity.yaml          # project manifest (read by every flunity command)
├── flutter_app/          # the Flutter side
└── unity_project/        # the Unity side (open this in Unity)
```

## `flunity.yaml`

The manifest is the single source of truth for project metadata and paths. Every CLI command except `flunity create` walks up from `cwd` looking for it.

```yaml
name: hello_unity
version: 0.1.0
target: webgl

paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_build: unity_project/Builds/WebGL
  flutter_assets: flutter_app/assets/unity_webgl

webgl:
  dev_server:
    host: 127.0.0.1
    port: 8080
    cross_origin_isolation: true
    hot_reload: false
  android_emulator_host: 10.0.2.2

bridge:
  enabled: true
  messages: []
```

Edit any path, port, or host as needed. The CLI honors the manifest values; flags like `--port` override per-invocation.

## `flutter_app/`

A normal Flutter app, with two opinions baked in:

- It depends on `flunity_bridge` and imports it in `main.dart`.
- `lib/unity/` contains the WebView screen, a typed wrapper, and the dev/bundled config switch.

```
flutter_app/
├── pubspec.yaml          # declares assets/unity_webgl/ and flunity_bridge dep
├── lib/
│   ├── main.dart         # registerBuiltInMessages() + runApp(...)
│   └── unity/
│       ├── unity_webgl_screen.dart
│       ├── unity_webgl_bridge.dart
│       └── unity_webgl_config.dart
├── android/              # cleartext exception scoped to 10.0.2.2 + 127.0.0.1
├── ios/                  # ATS exception scoped to 127.0.0.1 + localhost
└── assets/
    └── unity_webgl/      # populated by `flunity webgl copy`
```

## `unity_project/`

A regular Unity 2022.3+ project. Flunity ships these:

```
unity_project/
└── Assets/
    ├── Scripts/
    │   ├── FlunityBridge.cs        # static API for game code
    │   └── FlunityBridgeDemo.cs    # listens for load_scene, replies with scene_ready
    └── Plugins/WebGL/
        ├── flunity_bridge.jslib    # extern "C" hook into the JS shim
        └── flunity_bridge.js       # included in the WebGL build
```

After Unity builds the WebGL target into `unity_project/Builds/WebGL/`, the build is served by `flunity webgl serve` (dev) or copied into `flutter_app/assets/unity_webgl/` by `flunity webgl copy` (production).

## Scripts

`scripts/serve_unity_webgl.sh` and `scripts/copy_unity_webgl_to_flutter_assets.sh` are 3-line wrappers around `flunity webgl serve` and `flunity webgl copy`. They exist for muscle memory and IDE task runners.

## What Flunity does NOT generate

- A `pubspec.lock` for `flutter_app/` — you run `flutter pub get` after `flunity create`.
- The Unity `Library/`, `Temp/`, `obj/` artifacts — Unity creates them on first open.
- Native Android Gradle wrapper and Xcode project — `flutter create` produces those, and `flunity create` runs it for you behind the scenes.
