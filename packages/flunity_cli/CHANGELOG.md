# Changelog

## [Unreleased]

### Added
- Initial release: `create`, `doctor`, `webgl serve`, `webgl copy`, `webgl clean`, and `bridge init` commands.
- `flunity.yaml` project manifest model and loader.
- Template rendering engine (`__var__` substitution).
- `flunity` executable (canonical entry point for the CLI).
- `flutter_webgl_bridge` template (default for `flunity create`) with full bridge wiring.
- `unity_bridge_basic` template applied by `flunity bridge init`.
- E2E smoke test against a stub WebGL build.

### Changed
- `flunity create` now defaults to `flutter_webgl_bridge`. Pass `--no-bridge` for the basic scaffold.
- `flunity bridge init` now reads from templates instead of inlined string constants.
- **Breaking:** `flunity create` now runs `flutter create`, patches iOS ATS + Android cleartext, writes `pubspec_overrides.yaml`, and runs `flutter pub get`. Requires `flutter` on PATH.
- `flunity webgl serve` and `flunity webgl copy` auto-prepare the Unity WebGL build (no more manual `bridge init` after each Unity rebuild).

### Added
- New `flunity webgl prepare` subcommand.
- New `--bridge-path` option on `flunity create`.

### Fixed
- Dev server sets `Content-Encoding: gzip` / `br` for direct `.gz` / `.br` requests.
- Split `FlunityBridge.cs` so Unity's Add Component finds the MonoBehaviour.
