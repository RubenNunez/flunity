# Flunity

> Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.

**Status: pre-alpha.** Under active development. Public API may change without notice until `0.1.0`.

Flunity is a development companion for Flutter + Unity projects. The first supported workflow is lightweight Unity WebGL scenes loaded inside Flutter through a WebView. Native Unity Android/iOS targets are on the roadmap but not yet implemented.

## Packages

| Package | Description |
| --- | --- |
| [`flunity_bridge`](packages/flunity_bridge) | Flutter package: `FlunityWebGLView`, controller, message types, dev/bundled config. |
| `flunity_cli` *(coming soon)* | The `flunity` executable: project scaffolding, dev server, asset bundling, bridge init. |

## Documentation

See [`docs/`](docs/) — getting started, project structure, WebGL workflow, bridge API, production build, Android emulator notes, and the native roadmap.

## License

MIT. See [LICENSE](LICENSE).
