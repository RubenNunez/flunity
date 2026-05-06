# Flunity

> Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.

**Status: pre-alpha.** Under active development. Public API may change without notice until `0.1.0`.

Flunity is a development companion for Flutter + Unity projects. It supports three Unity build targets — **WebGL** (loaded inside an in-process WebView), **iOS** (UnityFramework.xcframework embedded into the Flutter Runner), and **Android** (`unityLibrary` Gradle module included from the Flutter Android scaffold). Pick a target with `flunity create --target webgl|ios|android`. See [`docs/target-comparison.md`](docs/target-comparison.md) for an honest tradeoff comparison.

## Packages

| Package | Description |
| --- | --- |
| [`flunity_cli`](packages/flunity_cli) | The `flunity` executable: scaffolding, dev server, asset bundling, bridge init. |
| [`flunity_bridge`](packages/flunity_bridge) | Flutter package: `FlunityWebGLView`, `FlunityNativeView`, message types, dev/bundled config, `UnitySceneRoute` helper. |

## How to

### 1. Install

```bash
dart pub global activate flunity_cli
```

Make sure `$HOME/.pub-cache/bin` is on your PATH. Verify with:

```bash
flunity --version
# flunity 0.1.0
```

### 2. Scaffold a project

```bash
flunity create my_app
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
flunity doctor
```

This checks Flutter SDK, Dart SDK, the manifest, your Unity project layout, and that the dev server port is free. Each row has ✓/⚠/✗ and a hint.

### 4. Build the Unity scene

Open `my_app/unity_project/` in Unity 6 (6000.x).

For WebGL: build the WebGL target into `unity_project/Builds/webgl/` (or use **Flunity → Build → WebGL** from the Unity menu).

For iOS / Android: run `flunity build ios` (or `flunity build android`) — Flunity invokes Unity in batch mode using the bundled exporter.

### 5. Run the dev loop

**WebGL.** In one terminal:

```bash
flunity webgl serve
# Serving http://127.0.0.1:8080/
```

In a second terminal:

```bash
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

The Flutter app boots, loads `http://127.0.0.1:8080/index.html` in a WebView, and the Unity scene renders inside Flutter. Iterate by rebuilding Unity → reloading the Flutter app.

> **Android emulator:** `127.0.0.1` from inside the emulator points to the emulator, not your host. Flunity automatically swaps it for `10.0.2.2`. No action needed.

**iOS / Android.** Bundle the build into the Flutter app, then run:

```bash
flunity build ios && flunity bundle ios
cd flutter_app
flutter run -d ios
```

(Substitute `android` for the Android target.) Iteration cycle: edit Unity scene → `flunity build <target> && flunity bundle <target>` → `flutter run`.

### 6. Talk to Unity

For Flutter → Unity calls, use outlets:

```csharp
// Unity (C#)
public class Pet : MonoBehaviour {
    [FlunityOutlet]
    public Task<bool> Feed(FeedArgs args) { /* animate, return when done */ }
}
```

```dart
// Flutter
final ok = await flunity.invoke<bool>('Pet.Feed', args: {'amount': 10});
```

The Future stays pending until Unity finishes the work — easy round-trip UX (disable buttons while busy, show progress, etc). See [docs/outlets.md](docs/outlets.md) for the full API. iOS / Android only in v1; WebGL outlet support tracked as Plan L.

For Unity → Flutter (or stream-style messaging), see [docs/bridge-api.md](docs/bridge-api.md).

### 7. Build for production

For WebGL:

```bash
flunity webgl copy
cd flutter_app
flutter build apk     # or appbundle, ipa, etc.
```

`flunity webgl copy` packages the Unity build into `flutter_app/assets/unity_webgl/`. Bundled mode is the Flutter default; the production app loads Unity from inside the asset bundle via a process-local HTTP loopback (Unity WebGL refuses to load via `file://`).

For iOS / Android:

```bash
flunity build <target>
flunity bundle <target>
cd flutter_app
flutter build ipa     # or appbundle
```

`flunity bundle` copies the Unity export into the right place (`flutter_app/ios/UnityExport/` or `flutter_app/android/unityLibrary/`) and patches the Gradle wiring on Android. iOS still needs a one-time manual Xcode link — see [docs/native-setup.md](docs/native-setup.md).

## Documentation

See [`docs/`](docs/) — [getting-started](docs/getting-started.md), [project-structure](docs/project-structure.md), [target-comparison](docs/target-comparison.md), [multi-target builds](docs/multi-target.md), [WebGL workflow](docs/webgl-workflow.md), [native setup](docs/native-setup.md), [scene routing](docs/scene-routing.md), [bridge API](docs/bridge-api.md), [production build](docs/production-build.md), [Android emulator notes](docs/android-emulator.md).

## License

MIT. See [LICENSE](LICENSE).
