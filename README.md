# Flunity

> Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.

**Status: pre-alpha.** Under active development. Public API may change without notice until `0.1.0`.

Flunity is a development companion for Flutter + Unity projects. The first supported workflow is lightweight Unity WebGL scenes loaded inside Flutter through a WebView. Native Unity Android/iOS targets are on the roadmap but not yet implemented.

## Packages

| Package | Description |
| --- | --- |
| [`flunity_cli`](packages/flunity_cli) | The `flunity` executable (and `fl` / `fu` aliases): scaffolding, dev server, asset bundling, bridge init. |
| [`flunity_bridge`](packages/flunity_bridge) | Flutter package: `FlunityWebGLView`, controller, message types, dev/bundled config. |

## How to

### 1. Install

```bash
dart pub global activate flunity_cli
```

This installs three commands. They all do the same thing — pick whichever is easiest to type:

| Command | Purpose |
| --- | --- |
| `flunity` | canonical name (use in scripts, CI, docs) |
| `fl` | short alias |
| `fu` | short alias |

Make sure `$HOME/.pub-cache/bin` is on your PATH. Verify with `fl --version`.

### 2. Scaffold a project

```bash
fl create my_app
cd my_app
```

This creates:

```
my_app/
├── flunity.yaml          # project manifest
├── flutter_app/          # Flutter side
└── unity_project/        # Unity side (open this in Unity)
```

### 3. Verify your environment

```bash
fl doctor
```

This checks Flutter SDK, Dart SDK, the manifest, your Unity project layout, and that the dev server port is free. Each row has ✓/⚠/✗ and a hint.

### 4. Build the Unity scene

Open `my_app/unity_project/` in Unity 2022.3 LTS (or newer). Build the WebGL target into `unity_project/Builds/WebGL/`.

### 5. Run the dev loop

In one terminal:

```bash
fl webgl serve
# Serving http://127.0.0.1:8080/
```

In a second terminal:

```bash
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

The Flutter app boots, loads `http://127.0.0.1:8080/index.html` in a WebView, and the Unity scene renders inside Flutter. Iterate by rebuilding Unity → reloading the Flutter app.

> **Android emulator:** `127.0.0.1` from inside the emulator points to the emulator, not your host. Flunity automatically swaps it for `10.0.2.2`. No action needed.

### 6. Build for production

```bash
fl webgl copy
cd flutter_app
flutter build apk     # or appbundle, ipa, etc.
```

`fl webgl copy` packages the Unity build into `flutter_app/assets/unity_webgl/`. Bundled mode is the Flutter default; the production app loads Unity from inside the asset bundle via a process-local HTTP loopback (Unity WebGL refuses to load via `file://`).

## Documentation

See [`docs/`](docs/) — getting started, project structure, WebGL workflow, bridge API, production build, Android emulator notes, and the native roadmap.

## License

MIT. See [LICENSE](LICENSE).
