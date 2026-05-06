# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For per-commit detail, see `git log`. For per-package additions, see `packages/flunity_bridge/CHANGELOG.md` and `packages/flunity_cli/CHANGELOG.md`.

## [Unreleased]

### Plans landed

- **Plan A–D** — workspace, CLI, templates, real-world fixes. WebGL flow shipped end-to-end.
- **Plan F** — `target: webgl|ios|android`. One Unity project, three artifacts. Vendored `flutter_embed_unity` v2.0.0 (MIT). `flunity build`, `flunity bundle`, target-conditional doctor. Templates: `flutter_native_basic`, `flutter_native_bridge`. Tooling: Flutter 3.38, Dart 3.10, Unity 6, iOS 14, NDK 27.
- **Plan K** — outlets. `[FlunityOutlet]` / `[FlunityIdentity]` C# attributes; `flunity.invoke<T>` and `flunity.find` on the Dart side. `Flunity.Scene.Tree` / `Flunity.Scene.Inspect` system outlets for live scene introspection.

### Cross-cutting tooling

- `FlunityLogStream` — Unity `Debug.Log` lines + Flutter `debugPrint` consolidated into one in-memory buffer. Outlet calls auto-recorded.
- `UnitySceneRoute` widget — one Unity instance, many Flutter routes.
- Editor menu: `Flunity → Build → iOS (Device|Simulator) | Android | WebGL`. No folder picker — paths are deterministic.

See [`docs/debugging.md`](docs/debugging.md) for the in-app Logs + Inspector tools.
