# flunity_cli

The `flunity` command — a development companion for Flutter + Unity WebGL projects.

## Install

```bash
dart pub global activate flunity_cli
```

This installs the `flunity` executable. Make sure `$HOME/.pub-cache/bin` is on your PATH.

## Commands

```
flunity --version
flunity create <name> [--target webgl] [--org com.example] [--no-bridge]
flunity doctor
flunity webgl serve [--host <h>] [--port <p>] [--open]
flunity webgl copy [--clean]
flunity webgl clean
flunity bridge init [--force]
```

## How to use Flunity

The full step-by-step walkthrough lives in the [main repo README](https://github.com/RubenNunez/flunity#how-to). Quick version:

1. `flunity create my_app && cd my_app`
2. `flunity doctor`
3. Open `my_app/unity_project/` in Unity, build WebGL → `unity_project/Builds/WebGL/`
4. `flunity webgl serve` (one terminal)
5. `cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev` (another terminal)
6. For production: `flunity webgl copy` then `flutter build <ios|apk|appbundle>`

## License

MIT.
