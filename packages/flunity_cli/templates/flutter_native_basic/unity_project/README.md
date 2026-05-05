# __app_name__ — Unity project

Open this folder in Unity 6 (6000.x) with **iOS** and/or **Android** Build Support modules installed.

This is the `--no-bridge` variant — no `[FlunityBridge]` GameObject, no Flutter ↔ Unity messaging out of the box. Add your own Unity scenes here and they'll be rendered inside the Flutter app via `FlunityNativeView`.

To build:

- **iOS**: Use the **Flunity → Build → iOS** menu (or run `flunity build ios` from the project root). Output goes to `Builds/ios/`.
- **Android**: Use the **Flunity → Build → Android** menu (or `flunity build android`). Output goes to `Builds/android/`.
