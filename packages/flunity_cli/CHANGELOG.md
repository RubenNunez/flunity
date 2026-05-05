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
