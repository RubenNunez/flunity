# Flunity v1 — Design Spec

**Date:** 2026-05-04
**Status:** Approved (brainstorming complete; awaiting implementation plan)
**Repo:** `git@github.com:RubenNunez/flunity.git`
**License:** MIT

## 1. What Flunity is

Flunity is a Flutter-first toolkit and CLI for embedding Unity inside Flutter apps. The first supported workflow is lightweight Unity WebGL scenes loaded inside Flutter through a WebView. Native Unity Android/iOS is explicitly future work.

Flutter is the root app. Unity is treated as an optional embedded experience.

Flunity is a long-lived **development companion**, not a one-shot scaffold generator. Every command except `create` works inside an existing project, codegen never clobbers user edits, and the surface area is shaped to grow with the project (more targets, more codegen, more orchestration).

## 2. Scope

### In scope for v1

- A single `flunity` Dart CLI executable
- A Flutter package `flunity_bridge` providing the WebView, controller, message types, and config
- Three v1 templates: `flutter_webgl_basic`, `flutter_webgl_bridge`, `unity_bridge_basic`
- Five v1 commands: `create`, `doctor`, `webgl serve`, `webgl copy`, `bridge init` (plus `webgl clean` as a trivial helper)
- A `flunity.yaml` project manifest read by every command
- A working bridge with `Ping`/`Pong` round-trip out of the box
- Generated Android cleartext + iOS ATS configuration scoped to loopback / emulator host
- Documentation: getting started, project structure, WebGL workflow, bridge API, production build, Android emulator notes, native roadmap

### Out of scope for v1 (named so we don't drift)

- `bridge generate` codegen (typed message generation from manifest)
- Native Unity targets (`native_android`, `native_ios`) — only the abstraction seams
- `add native-*`, `native prepare`, `native export` commands
- Hot module reload of Unity itself, multi-scene preloading, GPU surface sharing
- Flutter Web as a target (Flutter Web embedding Unity WebGL has its own COOP/COEP issues — second wave)

## 3. Repo layout (Melos monorepo)

```
flunity/
├── README.md
├── LICENSE                          # MIT
├── CHANGELOG.md
├── melos.yaml
├── pubspec.yaml                     # workspace root
├── packages/
│   ├── flunity_cli/                 # pure Dart CLI, publishes the `flunity` exe
│   │   ├── bin/flunity.dart
│   │   ├── lib/src/
│   │   │   ├── commands/
│   │   │   ├── manifest/            # flunity.yaml schema + loader
│   │   │   ├── templates/           # rendering engine
│   │   │   ├── webgl/               # shelf server, copy logic
│   │   │   ├── bridge/              # bridge init logic
│   │   │   ├── doctor/              # checks
│   │   │   └── utils/
│   │   └── test/
│   └── flunity_bridge/              # Flutter package consumed by generated apps
│       ├── lib/flunity_bridge.dart
│       ├── lib/src/
│       │   ├── flunity_webgl_view.dart
│       │   ├── flunity_webgl_controller.dart
│       │   ├── flunity_webgl_config.dart
│       │   ├── flunity_message.dart            # sealed class hierarchy
│       │   ├── messages/                       # built-in messages
│       │   └── platform/                       # Android cleartext / iOS ATS helpers
│       └── test/
├── templates/
│   ├── flutter_webgl_basic/
│   ├── flutter_webgl_bridge/
│   └── unity_bridge_basic/
├── examples/
│   ├── webgl_simple_scene/
│   └── webgl_product_viewer/
├── docs/
│   ├── getting-started.md
│   ├── project-structure.md
│   ├── webgl-workflow.md
│   ├── bridge-api.md
│   ├── production-build.md
│   ├── android-emulator.md
│   └── native-roadmap.md
└── scripts/                         # repo-level dev/release scripts
```

`templates/` and `examples/` are checked-in source of truth. CI smoke-tests `flunity create` against each template into a tmp dir and runs `flutter analyze` + `flutter test`.

`scripts/` at the **repo root** is for repo development. `scripts/` inside a generated user project is different — those are thin wrappers over the CLI.

## 4. Tech stack

- Dart `^3.5.0`, Flutter `^3.24.0`
- CLI: `args` (CommandRunner), `mason_logger`, `path`, `yaml`, `pub_semver`, `shelf`, `shelf_static`, `http_multi_server`
- Bridge: `flutter_inappwebview` `^6.x`
- Monorepo: Melos (path overrides during dev, normal pub deps once published)
- License: MIT

### Why these choices

- **`flutter_inappwebview`** over `webview_flutter`: built-in `InAppLocalhostServer` (needed for production bundled mode — Unity WebGL won't load via `file://`), better JS handler ergonomics, can intercept requests and inject COOP/COEP headers Unity WebGL sometimes needs.
- **Dart-native dev server** (shelf-based) over shell scripts: single source of truth, no Python/Node assumption, full control over Unity-specific MIME types and headers.
- **Plain file templates with `__var__` substitution** over Mustache: legible, editable, no logic in templates — anything conditional is a separate template directory.
- **Melos**: standard for Dart workspaces; required so CLI changes are visible in the example app immediately during development.

## 5. CLI

### Entry point

Single `flunity` executable built on `CommandRunner`. Every command except `create` locates `flunity.yaml` by walking up from cwd, so commands work from anywhere inside a project. A typed `FlunityProject` model loads and validates the manifest — no command does its own path math.

### v1 commands

```
flunity create <name> [--target webgl] [--org com.example] [--no-bridge]
flunity doctor
flunity webgl serve    [--port 8080] [--host 127.0.0.1] [--open]
flunity webgl copy     [--clean]
flunity webgl clean
flunity bridge init    [--force]
```

#### `create`

Renders a template tree into `<name>/`. Default template is `flutter_webgl_bridge` unless `--no-bridge` is passed (then `flutter_webgl_basic`). `--target webgl` is the only accepted target in v1; other values error with a "future work" message that links to `docs/native-roadmap.md`. After rendering, runs `flutter pub get` in `flutter_app/` and prints next-steps onboarding (open Unity, build WebGL to `unity_project/Builds/WebGL/`, then `flunity webgl serve`).

#### `doctor`

Environment + project checks. Each row is `✓` / `⚠` / `✗` with an actionable hint. Exits non-zero on any `✗`.

Checks:
- Flutter SDK present and `>=3.24.0`
- Dart SDK present and `>=3.5.0`
- Cwd is inside a Flunity project (locates `flunity.yaml`)
- `flunity.yaml` parses and validates against schema
- `unity_project/` exists
- `unity_project/Builds/WebGL/index.html` exists (warn if missing — user might not have built yet)
- `flutter_app/pubspec.yaml` declares `assets/unity_webgl/` and depends on `flunity_bridge`
- Configured dev server port is free
- (Best-effort) physical device + `127.0.0.1` dev host detection — warn

#### `webgl serve`

`shelf_static` server rooted at `paths.unity_build` (default `unity_project/Builds/WebGL/`). Binds via `http_multi_server` so both IPv4 and IPv6 loopback work. Serves with:

- Cross-origin isolation headers: `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`
- Unity-correct MIME for `.wasm`, `.data`, `.symbols.json`, `.framework.js`
- Brotli (`.br`) and gzip (`.gz`) precompressed asset support (sets `Content-Encoding`, strips suffix from URL)
- `Cache-Control: no-store` in dev

If `webgl.dev_server.hot_reload: true` in the manifest, watches the build dir and broadcasts SSE pings on `/__flunity/reload` that the bridge listens for to auto-refresh the WebView. Off by default.

`--open` opens the served URL in the system browser (handy for debugging the WebGL build outside Flutter).

#### `webgl copy`

Copies `paths.unity_build` → `paths.flutter_assets` (default `flutter_app/assets/unity_webgl/`), normalizes paths inside `index.html` (any absolute references → relative), and writes `flunity_webgl_manifest.json` containing the build hash and timestamp so Flutter can cache-bust.

`--clean` removes the destination first.

#### `webgl clean`

Removes `paths.flutter_assets` (preserving `.gitkeep`) and stops any running `flunity webgl serve`.

#### `bridge init`

- Adds `flunity_bridge` to `flutter_app/pubspec.yaml` if missing
- Creates `lib/unity/{unity_webgl_screen,unity_webgl_bridge,unity_webgl_config}.dart` from `templates/flutter_webgl_bridge/flutter_app/lib/unity/`
- Copies `FlunityBridge.cs` (and `FlunityBridgeDemo.cs`) into `unity_project/Assets/Scripts/`
- Patches `unity_project/Builds/WebGL/index.html` to inject the JS shim if the file exists (idempotent — guarded by a marker comment)
- Refuses to overwrite existing files unless `--force`

### `flunity.yaml`

```yaml
name: my_app
version: 0.1.0
target: webgl                                # webgl | native_android | native_ios (future)

paths:
  flutter_app: flutter_app
  unity_project: unity_project
  unity_build: unity_project/Builds/WebGL    # source of webgl serve / copy
  flutter_assets: flutter_app/assets/unity_webgl   # destination of webgl copy

webgl:
  dev_server:
    host: 127.0.0.1
    port: 8080
    cross_origin_isolation: true
    hot_reload: false                        # opt-in SSE ping
  android_emulator_host: 10.0.2.2

bridge:
  enabled: true
  messages: []                               # reserved for future `bridge generate`
```

### Future commands (informing the design but not in v1)

`bridge generate`, `add native-android`, `add native-ios`, `native prepare`, `native export`, `webgl analyze`, `upgrade`. The CLI surface accommodates them: `target` in the manifest is a first-class string, not a boolean.

## 6. The bridge

Three coordinated pieces.

### 6a. Dart side — `flunity_bridge`

#### Sealed message hierarchy

```dart
sealed class FlunityMessage {
  String get type;
  Map<String, dynamic> toJson();
  static FlunityMessage fromJson(Map<String, dynamic> json);
}

final class LoadScene  extends FlunityMessage { final String scene; }
final class SceneReady extends FlunityMessage {}
final class Ping       extends FlunityMessage { final String nonce; }
final class Pong       extends FlunityMessage { final String nonce; }
final class RawMessage extends FlunityMessage {                       // escape hatch
  final String type;
  final Map<String, dynamic> payload;
}
```

JSON wire format: `{"type": "...", "payload": {...}}`. No version field in v1 (YAGNI); we'll add `"v": 1` if we ever break compat. `Ping`/`Pong` ship in v1 because the example app uses them as the smoke test.

`fromJson` uses a registry keyed by `type`; unknown types fall back to `RawMessage` rather than throwing — forward-compatibility for new Unity-side message types.

#### Controller

```dart
class FlunityWebGLController {
  Stream<FlunityMessage> get messages;       // hot stream of inbound msgs
  Future<void> send(FlunityMessage msg);
  Future<void> reload();
  Future<void> dispose();
  bool get isReady;
}
```

Messages sent before the underlying `unityInstance` is ready are queued (small bounded queue) and flushed on ready, so consumer code doesn't need to await readiness.

#### View

```dart
FlunityWebGLView(
  config: FlunityWebGLConfig.fromManifest(...),  // or .dev() / .bundled()
  onReady: (controller) { ... },
  onMessage: (msg) { ... },                      // sugar over controller.messages
  loadingBuilder: (ctx) => const ProgressRing(),
  errorBuilder:   (ctx, err) => ErrorView(err),
)
```

Owns the `InAppWebView`, configures it for Unity (allow JS, allow inline media, register the `flunity` JS handler), wires custom request headers for COOP/COEP when the build needs them, and exposes the controller via `onReady`.

#### Config — the dev/bundled switch

```dart
class FlunityWebGLConfig {
  factory FlunityWebGLConfig.dev({
    String host = '127.0.0.1',
    int port = 8080,
    String androidEmulatorHost = '10.0.2.2',
  });
  factory FlunityWebGLConfig.bundled({
    String assetPath = 'assets/unity_webgl/',
  });
}
```

Resolution rules baked into the controller:
- On Android with `host == '127.0.0.1'`, substitute `androidEmulatorHost` (default `10.0.2.2`).
- iOS simulator and any other host: keep as-is.
- Bundled mode: lift assets via `flutter_inappwebview`'s `InAppLocalhostServer` bound to `127.0.0.1:<random>` — needed because Unity WebGL refuses `file://`. The user never sees this; the view manages the loopback server lifecycle.

Generated `unity_webgl_config.dart` reads three `--dart-define`s (`FLUNITY_MODE`, `FLUNITY_DEV_HOST`, `FLUNITY_DEV_PORT`) so a single build can be steered at runtime. Default `FLUNITY_MODE=bundled`.

### 6b. Unity side — `FlunityBridge.cs`

A `MonoBehaviour` placed on a single `[FlunityBridge]` GameObject in the user's scene. WebGL-only, guarded with `#if UNITY_WEBGL && !UNITY_EDITOR` so it no-ops in the editor and stays compileable when native targets land.

Public surface:

```csharp
public static class FlunityBridge {
  public static event Action<string, string> OnMessage; // (type, jsonPayload)
  public static void Send<T>(string type, T payload);   // serializes via JsonUtility
  public static void SendRaw(string type, string jsonPayload);
}
```

`Send` calls a JS extern (`extern "C" void FlunityPostMessage(const char* json)`) declared in a `.jslib`. Inbound: the JS shim calls `unityInstance.SendMessage("[FlunityBridge]", "ReceiveFromFlutter", json)` which dispatches to `OnMessage`.

`FlunityBridge.cs` itself auto-handles `Ping` and replies with matching-nonce `Pong` — the round-trip smoke test works on a freshly generated project before the user writes a line of game code. `FlunityBridgeDemo.cs` listens for `LoadScene` and emits `SceneReady` for the second smoke test.

### 6c. JS shim — `flunity_bridge.js`

~80 lines. Provides:

- `window.flunity.post(json)` — called by Dart via `evaluateJavascript`; routes into `unityInstance.SendMessage("[FlunityBridge]", "ReceiveFromFlutter", json)`.
- `window.flunity._fromUnity(json)` — called by the Unity-side `.jslib` extern; forwards via `window.flutter_inappwebview.callHandler('flunity', json)`.
- `window.flunity.ready()` — emitted once `unityInstance` is available so Flutter knows when it's safe to send (also flushes the Dart-side queue).
- A small bounded queue so Dart→Unity messages sent before `ready` aren't dropped.

`bridge init` patches the WebGL `index.html` to (a) `<script src="flunity_bridge.js"></script>` and (b) wrap `createUnityInstance(...).then(...)` so we can capture `unityInstance`. The patch is guarded by a marker comment (`<!-- flunity:patch v1 -->`) so re-running `bridge init` is idempotent.

## 7. Templates and generated app

### Template format

Plain file trees under `templates/<name>/` with `__var__` substitution. Variables resolved at render time: `__app_name__`, `__app_name_pascal__`, `__org__`, `__bundle_id__`, `__flutter_version__`, `__bridge_version__`. No Mustache, no logic — anything conditional is a separate template directory.

### Three v1 templates

1. **`flutter_webgl_basic/`** — Flutter app + empty `unity_project/` placeholder. WebView shell, no bridge wiring. For users who'll wire their own messaging.
2. **`flutter_webgl_bridge/`** (default) — Same as above plus full bridge: `flunity_bridge` dep, `unity_webgl_screen.dart` with `FlunityWebGLView`, `unity_webgl_bridge.dart` with `Ping`/`Pong` round-trip demo, `unity_webgl_config.dart` with `--dart-define` switch.
3. **`unity_bridge_basic/`** — Standalone Unity-side template applied by `bridge init` into `unity_project/Assets/Scripts/`: `FlunityBridge.cs` + `FlunityBridgeDemo.cs`.

### Generated app structure

```
my_app/
├── flunity.yaml
├── README.md                        # generated quickstart
├── .gitignore
├── flutter_app/
│   ├── pubspec.yaml                 # incl. flunity_bridge dep + assets entry
│   ├── analysis_options.yaml        # extends flutter_lints
│   ├── lib/
│   │   ├── main.dart                # routes / to UnityWebGLScreen
│   │   └── unity/
│   │       ├── unity_webgl_screen.dart
│   │       ├── unity_webgl_bridge.dart
│   │       └── unity_webgl_config.dart
│   ├── android/                     # cleartext exception scoped to 10.0.2.2 + 127.0.0.1
│   ├── ios/                         # ATS exception scoped to 127.0.0.1
│   ├── assets/
│   │   └── unity_webgl/
│   │       └── .gitkeep             # populated by `flunity webgl copy`
│   └── test/
│       └── unity_webgl_bridge_test.dart   # message (de)ser round-trip
├── unity_project/
│   ├── README.md                    # "open this folder in Unity 2022.3 LTS+"
│   ├── Assets/
│   │   └── Scripts/
│   │       ├── FlunityBridge.cs
│   │       └── FlunityBridgeDemo.cs
│   └── .gitignore                   # Unity-standard ignores
└── scripts/
    ├── serve_unity_webgl.sh         # exec flunity webgl serve "$@"
    └── copy_unity_webgl_to_flutter_assets.sh   # exec flunity webgl copy "$@"
```

### Key generated files

- `lib/unity/unity_webgl_screen.dart` — `Scaffold` with `FlunityWebGLView`, an overlay status row showing connection / last message, a debug button that fires `Ping`. Suitable to ship and to learn from.
- `lib/unity/unity_webgl_bridge.dart` — typed wrapper over the controller for app-specific messages; v1 demonstrates `loadScene(name)` and listens for `SceneReady`.
- `lib/unity/unity_webgl_config.dart` — reads `--dart-define=FLUNITY_MODE` (default `bundled`), `FLUNITY_DEV_HOST`, `FLUNITY_DEV_PORT`; chooses `.dev(...)` or `.bundled(...)`.
- `pubspec.yaml` — declares `assets/unity_webgl/` and depends on `flunity_bridge` (path dep in this monorepo, pub dep once published).
- `unity_project/.gitignore` — canonical Unity ignores (`Library/`, `Temp/`, `Builds/`, `Logs/`, `obj/`, `MemoryCaptures/`, `*.csproj`, `*.sln`, `*.unityproj`, `UserSettings/`).
- `scripts/*.sh` — three-line wrappers (`cd "$(git rev-parse --show-toplevel)" && exec flunity <subcommand> "$@"`).
- `flutter_app/test/unity_webgl_bridge_test.dart` — asserts the `Ping`/`Pong` JSON round-trip and the `FlunityWebGLConfig` mode switch. Keeps generated apps green in CI without a real WebView.

## 8. Workflows

### Local dev

1. `flunity create my_app`
2. Open `my_app/unity_project/` in Unity (2022.3 LTS or newer)
3. Build the scene as **WebGL** to `unity_project/Builds/WebGL/`
4. `flunity webgl serve` (project root)
5. `cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev`
6. Iterate: rebuild Unity → reload Flutter (or enable `webgl.dev_server.hot_reload`)

### Production

1. Build Unity WebGL release-flavored (Brotli, no profiler)
2. `flunity webgl copy`
3. `flutter build <ios|apk|appbundle>` — default `FLUNITY_MODE=bundled` so no extra flags
4. `FlunityWebGLView` serves the bundled WebGL via `flutter_inappwebview`'s `InAppLocalhostServer` (because Unity WebGL refuses `file://`)

## 9. Environment notes

### Android

- Emulator: `127.0.0.1` from inside the emulator points to the emulator. Use `10.0.2.2` for the host. `FlunityWebGLConfig.dev()` does the swap automatically.
- Cleartext: dev hits `http://`, prod loopback also `http://127.0.0.1`. Generated `AndroidManifest.xml` includes `android:networkSecurityConfig` with `<domain-config cleartextTrafficPermitted="true">` scoped to `10.0.2.2` and `127.0.0.1`.

### iOS

- Simulator: `127.0.0.1` works directly. Loopback prod server fine.
- ATS exception scoped to `127.0.0.1` only — no global `NSAllowsArbitraryLoads`.

### Physical devices in dev

Must use the host's LAN IP. Override via `--dart-define=FLUNITY_DEV_HOST=<lan-ip>`. `flunity doctor` warns when it detects a physical device + `127.0.0.1` dev host.

## 10. Performance (`docs/production-build.md`)

Unity WebGL settings the docs prescribe:
- Brotli or gzip compression
- Code stripping High, IL2CPP Master mode
- Disable Development Build / Profiler / Exceptions=None
- Texture compression ASTC
- Strip unused engine subsystems
- Tune `WebGLMemorySize` to scene needs (don't keep the default)

Mobile WebView guidance:
- Lazy-init Unity by mounting `FlunityWebGLView` on a route push, not at app start
- Call `controller.dispose()` on pop
- Prefer texture streaming, avoid `Camera.allowMSAA`, mobile-realistic poly counts
- Size budget: <10 MB total compressed for UX-acceptable cold start on mid-range Android

## 11. Testing strategy

- **CLI unit tests:** template renderer, manifest loader, doctor checks (each check independently testable), WebGL copy normalization, bridge init patcher.
- **CLI integration tests:** render each template into a tmp dir; assert `flutter analyze` and `flutter test` pass.
- **Bridge unit tests:** message (de)serialization round-trip, config resolution rules (Android emulator host swap, dart-define parsing), queue behavior before ready.
- **Bridge widget tests:** `FlunityWebGLView` mount/unmount with a fake controller (no real WebView).
- **Example app smoke test:** `examples/webgl_simple_scene` boots in CI with a stub WebGL build (a single `index.html` that pretends to be Unity) and exercises `Ping`/`Pong`.

No live Unity required in CI.

## 12. Native roadmap (future, not v1)

Native Unity-as-a-library is a separate, larger integration. The CLI already accommodates it: `--target native_android|native_ios`, `add native-android`, `add native-ios`, `native prepare`, `native export`.

Integration approach when we tackle it:
- Unity exports as Gradle module (Android) / Xcode framework (iOS)
- Flutter consumes via a platform channel
- `flunity_bridge` grows a `FlunityNativeView` peer to `FlunityWebGLView` sharing the same `FlunityMessage` types — switching from WebGL to native is a widget swap

Why not now:
- Unity-as-a-library has heavier developer setup (Unity Hub modules, signing, two build pipelines)
- Fragile across Unity versions
- Adds a hard Unity install dependency to the generated project's CI
- WebGL is a vastly cleaner first target

## 13. Definition of done for v1

- [ ] `flunity create my_app` produces a project where `flutter run --dart-define=FLUNITY_MODE=dev` boots, the WebView mounts, and the placeholder WebGL build (or stub) returns `Pong` to a `Ping`.
- [ ] All five v1 commands work and have unit tests.
- [ ] `flunity doctor` correctly diagnoses a fresh project, a project with a missing Unity build, and a project with a busy port.
- [ ] `flunity webgl copy` produces an `assets/unity_webgl/` that, after `flutter build apk`, runs in the bundled mode without flags.
- [ ] Generated Android cleartext + iOS ATS rules are scoped, not global.
- [ ] `examples/webgl_simple_scene` runs in CI and demonstrates `Ping`/`Pong`.
- [ ] All seven docs in `docs/` exist and cover their topics.
- [ ] License is MIT, README pitches Flunity as Flutter+Unity tooling (not WebGL-only).
