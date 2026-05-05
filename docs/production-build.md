# Production Build

Production = asset-bundled Unity inside a Flutter release artifact (APK, AAB, IPA, …).

## 1. Build Unity for production

In Unity's WebGL Player settings:

- **Compression Format**: Brotli (preferred) or gzip.
- **Code stripping**: High.
- **Strip Engine Code**: ON.
- **IL2CPP Code Generation**: Faster runtime (IL2CPP Master).
- **Exceptions**: None.
- **Development Build**: OFF.
- **Profiler**: OFF.
- **Texture Compression**: ASTC (covers Android + iOS).
- **WebGL Memory Size**: tune to your scene; default 256 MB is usually too high. Most Flunity apps land at 64–128 MB.
- Strip subsystems you don't use (Audio, Vehicles, etc.) under the Module Manager.

Build into `unity_project/Builds/WebGL/`.

## 2. Copy into Flutter assets

```bash
flunity webgl copy
```

This:
1. Removes anything previously in `flutter_app/assets/unity_webgl/` (except `.gitkeep` if present and `--clean` is set).
2. Copies the build dir verbatim.
3. Writes `flutter_app/assets/unity_webgl/flunity_webgl_manifest.json` with a sha256 build hash, file count, total bytes, and timestamp. Use it for cache-busting.

## 3. Build the Flutter app

```bash
cd flutter_app
flutter build apk           # or appbundle, ios, ipa
```

`FLUNITY_MODE=bundled` is the default — no flags needed.

## Mobile WebView guidance

Unity WebGL inside a WebView on a phone is real, but it's not free. Recommendations:

- **Lazy-mount the view.** Mount `FlunityWebGLView` on a route push, not at app start. Tear it down on pop with `controller.dispose()`.
- **One scene at a time.** Multi-scene preloading inside the WebView is rarely worth the memory.
- **Texture streaming**, low MSAA (`Camera.allowMSAA = false`), mobile-realistic poly counts.
- **Audio off** unless you need it — saves both bandwidth and battery.
- **Size budget**: target < 10 MB total compressed for an acceptable cold start on a mid-range Android.

## Why a loopback server in production?

Unity WebGL refuses `file://` URLs (it uses ranged requests, web workers, and sometimes service workers). `flutter_inappwebview` ships an `InAppLocalhostServer` that serves Flutter assets over a process-local HTTP loopback bound to `127.0.0.1`. Flunity manages it for you — your code only sees `FlunityWebGLConfig.bundled()`.

## Cache invalidation

When the Unity build changes, the assets bundle changes, so the Flutter binary changes — that's already enough for app stores to deliver fresh code on the next install. Within a running session, `flunity_webgl_manifest.json` exposes a build hash that you can show in dev menus or use to invalidate any in-app caches you maintain.
