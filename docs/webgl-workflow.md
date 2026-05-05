# WebGL Workflow

Flunity supports two modes for loading the Unity WebGL build into Flutter:

| Mode | When | URL |
| --- | --- | --- |
| **dev** | Local iteration | `http://127.0.0.1:<port>/index.html` (or `10.0.2.2` on Android emulator) |
| **bundled** | Release builds | `http://localhost:<server>/<assetPath>/index.html` (process-local loopback over Flutter assets) |

Switch between them via `--dart-define=FLUNITY_MODE=dev` (default: `bundled`). The generated `unity_webgl_config.dart` reads this define and resolves the right `FlunityWebGLConfig`.

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

## Production loop (asset-bundled)

```bash
flunity webgl copy
cd flutter_app
flutter build apk           # or appbundle, ios, etc.
```

`flunity webgl copy` packages the Unity build into `flutter_app/assets/unity_webgl/` and writes a `flunity_webgl_manifest.json` with a sha256 build hash. Bundled mode is the default for `flutter run` / `flutter build` (no `--dart-define` needed).

At runtime, `FlunityWebGLView` starts an `InAppLocalhostServer` (via `flutter_inappwebview`) bound to `127.0.0.1:<random>` to serve the bundled WebGL — Unity WebGL refuses `file://` URLs.

## Iterating against a real Android device on the same network

```bash
flutter run --dart-define=FLUNITY_MODE=dev --dart-define=FLUNITY_DEV_HOST=192.168.1.42
```

Use your machine's LAN IP. `flunity doctor` will warn if it detects a physical device with `127.0.0.1` as the dev host.
