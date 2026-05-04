# flunity_cli

The `flunity` command — a development companion for Flutter + Unity WebGL projects.

## Install

```bash
dart pub global activate flunity_cli
```

This installs three command names that all run the same binary:

| Command | Purpose |
| --- | --- |
| `flunity` | canonical name — use in scripts and CI |
| `fl` | short alias for everyday typing |
| `fu` | short alias for everyday typing |

Make sure `$HOME/.pub-cache/bin` is on your PATH.

## How to use Flunity (end-to-end)

The full how-to lives in the [main repo README](../../README.md#how-to). The short version:

```bash
fl create my_app                # scaffold
fl doctor                       # verify environment
# (open my_app/unity_project in Unity; build WebGL to unity_project/Builds/WebGL/)
fl webgl serve                  # local dev server
cd flutter_app && flutter run --dart-define=FLUNITY_MODE=dev
# for production:
fl webgl copy
flutter build apk
```

## License

MIT.
