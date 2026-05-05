# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial design spec (`docs/superpowers/specs/2026-05-04-flunity-v1-design.md`).
- Melos workspace bootstrap.
- `flunity_bridge` package with abstract `FlunityMessage` hierarchy, `FlunityWebGLConfig`, `FlunityWebGLController`, `FlunityWebGLView`.
- `flunity_cli` package with `flunity` executable and six commands (`create`, `doctor`, `webgl serve`, `webgl copy`, `webgl clean`, `bridge init`).
- `flutter_webgl_bridge` and `unity_bridge_basic` templates with full bridge wiring (Unity-side `FlunityBridge.cs`, `flunity_bridge.jslib`, `flunity_bridge.js` shim).
- `flunity create` defaults to the bridge-wired template; `--no-bridge` opts out.
- `flunity bridge init` reads from the `unity_bridge_basic` template instead of inlined strings.
- E2E smoke test against a stub WebGL build.
- Documentation: getting-started, project-structure, webgl-workflow, bridge-api, production-build, android-emulator, native-roadmap.

### Changed
- Dropped the short `fl` / `fu` aliases; only `flunity` is shipped.
