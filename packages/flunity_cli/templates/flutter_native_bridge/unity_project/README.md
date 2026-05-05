# __app_name__ — Unity project

Open this folder in Unity 6 (6000.x) with **iOS** and/or **Android** Build Support modules installed.

To build:

- **iOS**: Use the **Flunity → Build → iOS** menu (or run `flunity build ios` from the project root). Output goes to `Builds/ios/`, ready to be embedded in the Flutter app as `UnityFramework.xcframework`.
- **Android**: Use the **Flunity → Build → Android** menu (or `flunity build android`). Output goes to `Builds/android/` as a Gradle module, ready for inclusion as a library project.

The bridge GameObject (`[FlunityBridge]`) and its `FlunityBridgeBehaviour` component must exist in your active scene for Flutter ↔ Unity messaging to work.
