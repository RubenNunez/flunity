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
target: ios

paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_builds: unity_project/Builds

bridge:
  enabled: true
  messages: []
```

Edit any path as needed. The CLI honors the manifest values.

## `flutter_app/`

A normal Flutter app, with two opinions baked in:

- It depends on `flunity_bridge` and imports it in `main.dart`.
- `lib/unity/` contains the Unity screen and a typed wrapper.

```
flutter_app/
├── pubspec.yaml          # declares the flunity_bridge dep
├── lib/
│   ├── main.dart         # registerBuiltInMessages() + runApp(...)
│   └── unity/            # native Unity screen + typed bridge wrapper
├── android/              # unityLibrary module included after `flunity bundle android`
└── ios/                  # Unity-iPhone sub-project wired after `flunity bundle ios`
```

## `unity_project/`

A regular Unity 2022.3+ project. Flunity ships these:

```
unity_project/
└── Assets/
    ├── Scripts/
    │   ├── FlunityBridge.cs        # static API for game code
    │   └── FlunityBridgeDemo.cs    # listens for load_scene, replies with scene_ready
    └── Editor/Flunity/             # vendored export scripts (FlunityBatchmode, FlunityMenu)
```

After Unity exports a target into `unity_project/Builds/<target>/`, `flunity bundle <target>` copies it into the Flutter app.

## What Flunity does NOT generate

- A `pubspec.lock` for `flutter_app/` — you run `flutter pub get` after `flunity create`.
- The Unity `Library/`, `Temp/`, `obj/` artifacts — Unity creates them on first open.
- Native Android Gradle wrapper and Xcode project — `flutter create` produces those, and `flunity create` runs it for you behind the scenes.
