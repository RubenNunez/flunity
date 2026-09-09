# Flunity

> Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.

**Status: pre-alpha.** Under active development. Public API may change without notice until `0.1.0`.

Flunity is a development companion for Flutter + Unity projects. It embeds Unity natively — **iOS** (a UnityFramework.framework embedded into the Flutter Runner) and **Android** (`unityLibrary` Gradle module included from the Flutter Android scaffold). Pick a target with `flunity create --target ios|android`. (WebGL-in-a-WebView support existed through 2026-09-07 and was removed — git history has it.)

## Packages

| Package | Description |
| --- | --- |
| [`flunity_cli`](packages/flunity_cli) | The `flunity` executable: scaffolding, dev server, asset bundling, bridge init. |
| [`flunity_bridge`](packages/flunity_bridge) | Flutter package: `FlunityNativeView`, message types, the outlet invoker, `UnitySceneRoute` helper. |

## How to

### 1. Install

```bash
git clone https://github.com/RubenNunez/flunity.git
dart pub global activate --source path flunity/packages/flunity_cli
```

Neither `flunity_cli` nor `flunity_bridge` is on pub.dev yet, so install from a
clone. A path activation runs the code in that directory, so `git pull` is how you
update — no need to re-activate. Once the packages are published,
`dart pub global activate flunity_cli` will work instead.

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

Run `flunity build ios` (or `flunity build android`). If the project is open in the Editor, Flunity drives *that* Editor through the Unity CLI (much faster warm); otherwise it runs Unity in batch mode with the bundled exporter. Never quit the Editor for a build.

No Unity Android export at hand? The Flutter app still builds UI-only when the `:unityLibrary` Gradle include is conditional on the directory existing — the Android plugin detects the missing Unity library at runtime and answers Unity calls with `unity_unavailable` instead of crashing plugin registration.

### 5. Run the dev loop

Bundle the build into the Flutter app, then run:

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

The Future stays pending until Unity finishes the work — easy round-trip UX (disable buttons while busy, show progress, etc). See [docs/outlets.md](docs/outlets.md) for the full API. Outlets work on iOS and Android — the same typed API on both targets.

For Unity → Flutter (or stream-style messaging), see [docs/bridge-api.md](docs/bridge-api.md). Built-in tools: a Logs sheet streams both sides into one buffer, and an Inspector tab lets you query the Unity scene (`tree`, `find`, `call`) from a typed terminal — see [docs/debugging.md](docs/debugging.md).

### 7. Build for production

```bash
flunity build <target>
flunity bundle <target>
cd flutter_app
flutter build ipa     # or appbundle
```

`flunity bundle` copies the Unity export into the right place (`flutter_app/ios/UnityExport/` or `flutter_app/android/unityLibrary/`) and patches the Gradle wiring on Android. iOS still needs a one-time manual Xcode link — see [docs/native-setup.md](docs/native-setup.md).

## Documentation

See [`docs/`](docs/) — [getting-started](docs/getting-started.md), [project-structure](docs/project-structure.md), [multi-target builds](docs/multi-target.md), [native setup](docs/native-setup.md), [scene routing](docs/scene-routing.md), [bridge API](docs/bridge-api.md).

## License

MIT. See [LICENSE](LICENSE).
