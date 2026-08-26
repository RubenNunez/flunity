# WebGL Workflow

Flunity supports two modes for loading the Unity WebGL build into Flutter:

| Mode | When | URL |
| --- | --- | --- |
| **dev** | Local iteration | `http://127.0.0.1:<port>/index.html` (or `10.0.2.2` on Android emulator) |
| **bundled** | Release builds | `http://localhost:<server>/<assetPath>/index.html` (process-local loopback over Flutter assets) |

Switch between them via `--dart-define=FLUNITY_MODE=dev` (default: `bundled`). The generated `unity_webgl_config.dart` reads this define and resolves the right `FlunityWebGLConfig`.

Outlets (`flunity.invoke` / `flunity.find`) work inside WebGL views too — mounting the view registers the bridge automatically.

## Dev loop (rapid iteration)

```bash
# Terminal 1
flunity webgl serve

# Terminal 2
cd flutter_app
flutter run --dart-define=FLUNITY_MODE=dev
```

Iterate by:

1. Editing your Unity scene.
2. Building Unity WebGL again to `unity_project/Builds/WebGL/`.
3. Hot-reloading the Flutter app (or pulling-to-refresh in the WebView).

`flunity webgl serve` runs an in-process Dart `shelf` server with:

- COOP/COEP headers (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`) so SharedArrayBuffer is available.
- Unity-correct MIME types for `.wasm`, `.data`, `.symbols.json`, and `.framework.js`.
- Brotli (`.br`) and gzip (`.gz`) precompressed asset support.
- `Cache-Control: no-store` so you always see the latest build.

## Building while the Editor is open

`flunity build webgl` (and `ios` / `android`) used to require quitting Unity first — batchmode refuses to start a second instance against a project another Editor already has open:

```
Aborting batchmode due to fatal error:
It looks like another Unity instance is running with this project open.
```

If the standalone `unity` CLI is installed — Unity Hub installs it at `~/.unity/bin/unity`; see the [Unity CLI reference](https://docs.unity.com/en-us/unity-cli/unity-cli-reference) — `flunity build` detects the open Editor and drives it directly instead of spawning batchmode:

1. **Lock detection.** `<unity_project>/Temp/UnityLockfile` exists exactly while an Editor holds the project open. No lockfile → nothing changes; `flunity build` uses batchmode exactly as before.
2. **Connected build.** With the project locked and the `unity` CLI available, `flunity build` invokes the same `Flunity/Build/...` menu item you'd click by hand in the Editor — `WebGL (Dev)` / `WebGL (Release)` for webgl, `iOS (Device)` / `iOS (Simulator)` for ios — over the CLI's pipeline connection (`unity cmd menu --path ...`). Output lands in the usual `unity_project/Builds/<target>/`, and `flunity build` only reports success once that artifact actually appears on disk.
3. **Android** has no dedicated menu route yet, so the connected-Editor path falls back to the generic `unity cmd build` + status polling, which skips Flunity's Android-specific export setup (Gradle "Export Project" mode, ARM64-only architecture, JDK root). Quit the Editor for a guaranteed-correct Android build until that lands.

Two things worth knowing:

- **The Editor's active build target must already match.** iOS's and Android's export menu items pop a *blocking* dialog in the Editor if its active build target isn't already the one you're building, which would otherwise hang the connected-Editor path indefinitely. `flunity build` checks first (`unity cmd get_build_settings`) and fails fast with instructions instead — switch platforms in the Editor (`File → Build Profiles`) and re-run. WebGL is unaffected; its own menu handler switches targets itself with no dialog.
- **`--batch`** forces the old batchmode path unconditionally, and `--timeout <minutes>` (default `30`) controls how long a connected-Editor build may run before `flunity build` gives up waiting.

If the project is locked and the `unity` CLI isn't installed, `flunity build` says so directly — update Unity Hub to get it, or quit the Editor and re-run.

## Production loop (asset-bundled)

```bash
flunity webgl copy
cd flutter_app
flutter build apk           # or appbundle, ios, etc.
```

`flunity webgl copy` packages the Unity build into `flutter_app/assets/unity_webgl/` and writes a `flunity_webgl_manifest.json` with a sha256 build hash. Bundled mode is the default for `flutter run` / `flutter build` (no `--dart-define` needed).

At runtime, `FlunityWebGLView` starts an `InAppLocalhostServer` (via `flutter_inappwebview`) bound to `127.0.0.1:<random>` to serve the bundled WebGL — Unity WebGL refuses `file://` URLs.

## Running WebGL on the iOS simulator (no Unity export)

WebGL is also the fastest way to iterate on a **native-target** project: you get
the Unity scene inside the simulator without building `UnityFramework` at all.
Two things are in the way by default.

**1. The iOS pod links UnityFramework unconditionally.** Without a simulator
Unity export the app dies at launch:

```
dyld: symbol not found in flat namespace '_OBJC_CLASS_$_UnityFramework'
```

Set `FLUNITY_WEBGL_ONLY=1` — the podspec then compiles only the messaging
sources and skips the vendored framework:

```bash
cd flutter_app/ios && FLUNITY_WEBGL_ONLY=1 pod install && cd ..
FLUNITY_WEBGL_ONLY=1 flutter run -d <simulator-id> --dart-define=FLUNITY_FORCE_WEBGL=true
```

Keep the variable on `flutter run` too — Flutter re-runs `pod install` itself and
would otherwise restore the full pod.

**2. The host app still embeds the framework.** In the Runner target add

```
EXCLUDED_SOURCE_FILE_NAMES[sdk=iphonesimulator*] = UnityFramework.framework
```

so device builds keep embedding it and simulator builds skip it. On Flutter 3.47+
also pin the project to CocoaPods (`flutter: config: enable-swift-package-manager: false`
in `pubspec.yaml`) — the automatic SPM migration rewrites the Xcode project and
breaks the Unity sub-project wiring.

### When the WebGL build itself fails

```
Exception: FROZEN_CACHE is set, but cache file is missing: "sysroot_install.stamp"
```

Unity's Web Build Support module lost its prebuilt Emscripten cache. Unity Hub
refuses to repair it ("already installed"), so restore the directory by hand:
take `downloadUrl` for the `webgl` entry in `<editor>/modules.json`, then

```bash
curl -L -o webgl.pkg "<downloadUrl>"
pkgutil --expand-full webgl.pkg webgl-expanded
rsync -a webgl-expanded/**/BuildTools/Emscripten/emscripten/cache/ \
  "<editor>/PlaybackEngines/WebGLSupport/BuildTools/Emscripten/emscripten/cache/"
```

### Blurring the scene behind Flutter UI

Flutter's `BackdropFilter` cannot sample a platform view, so it never blurs the
Unity WebView. `FlunityWebGLController.captureFrame()` returns a PNG snapshot of
the canvas — draw that image blurred beneath your overlay, or blur the Flutter
layers above the view and accept a sharp scene behind them.

## Iterating against a real Android device on the same network

```bash
flutter run --dart-define=FLUNITY_MODE=dev --dart-define=FLUNITY_DEV_HOST=192.168.1.42
```

Use your machine's LAN IP. `flunity doctor` will warn if it detects a physical device with `127.0.0.1` as the dev host.
