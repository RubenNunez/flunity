# flunity_cli

The `flunity` command — a development companion for Flutter + Unity-as-a-library projects.

## Install

```bash
dart pub global activate flunity_cli
```

This installs the `flunity` executable. Make sure `$HOME/.pub-cache/bin` is on your PATH.

## Commands

```
flunity --version
flunity create <name> [--target ios|android] [--org com.example] [--no-bridge]
flunity doctor
flunity build <target> [--simulator] [--batch]
flunity bundle <target>
```

## How to use Flunity

The full step-by-step walkthrough lives in the [main repo README](https://github.com/RubenNunez/flunity#how-to). Quick version:

1. `flunity create my_app && cd my_app`
2. `flunity doctor`
3. Open `my_app/unity_project/` in Unity 6 with the target's Build Support installed
4. `flunity build <target> && flunity bundle <target>`
5. `cd flutter_app && flutter run -d <device>`

## License

MIT.
