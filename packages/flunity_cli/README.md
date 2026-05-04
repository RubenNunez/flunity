# flunity_cli

The `flunity` command — a development companion for Flutter + Unity WebGL projects.

## Install

```bash
dart pub global activate flunity_cli
```

This installs three executable names that all run the same binary:

| Command | Purpose |
| --- | --- |
| `flunity` | canonical |
| `fl` | short alias |
| `fu` | short alias |

Make sure `$HOME/.pub-cache/bin` is on your PATH.

## Commands

```
fl --version
fl create <name> [--target webgl] [--org com.example] [--no-bridge]
fl doctor
fl webgl serve [--host <h>] [--port <p>] [--open]
fl webgl copy [--clean]
fl webgl clean
fl bridge init [--force]
```

## How to use Flunity

The full step-by-step walkthrough lives in the [main repo README](https://github.com/RubenNunez/flunity#how-to). Quick version:

1. `fl create my_app && cd my_app`
2. `fl doctor`
3. Open `my_app/unity_project/` in Unity, build WebGL → `unity_project/Builds/WebGL/`
4. `fl webgl serve` (one terminal)
5. `cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev` (another terminal)
6. For production: `fl webgl copy` then `flutter build <ios|apk|appbundle>`

## License

MIT.
