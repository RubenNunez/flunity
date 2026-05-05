# Native Roadmap (future work, not v1)

Flunity v1 only supports Unity WebGL. Native Unity-as-a-library (NUaL) — Unity exported as a Gradle module on Android or an Xcode framework on iOS, embedded into a Flutter app via a platform channel — is on the roadmap but not implemented.

## The CLI is already shaped for it

The `target` field in `flunity.yaml` is a string, not a boolean. The plan's `target: webgl` is the only accepted value in v1. Future targets:

- `target: native_android` — embeds Unity as a Gradle module.
- `target: native_ios` — embeds Unity as an XCFramework.

Future commands (already named in the design):

- `flunity add native-android` — generate the platform-channel glue and Gradle module placeholder.
- `flunity add native-ios` — same for iOS / Xcode.
- `flunity native prepare` — invoke Unity's batch-mode export.
- `flunity native export` — produce the platform artifacts.

`flunity_bridge` will grow a `FlunityNativeView` peer to `FlunityWebGLView`, sharing the same `FlunityMessage` types so user code switching from WebGL to native is mostly a widget swap.

## Why native isn't in v1

- **Setup overhead.** Unity-as-a-library needs Unity Hub modules (Android Build Support / iOS Build Support) plus signing infrastructure on each developer's machine.
- **Fragility across Unity versions.** Unity's exported Gradle / Xcode projects shift shape between LTS releases.
- **CI pressure.** Generating a native Unity export in CI requires a Unity license and a beefy macOS/Linux runner.
- **WebGL is genuinely simpler.** No native compilation, no platform-specific bindings, no signing — just a `WebView`.

Flunity's first job is to make the WebGL path painless. We'll add native targets when the WebGL workflow has graduated out of pre-alpha.

## What you can do today if you really need native

- Use Flutter's [`unity_view`](https://pub.dev/packages/flutter_unity_widget) — third-party, separate ecosystem from Flunity. Bigger setup, more capable for high-FPS native rendering.
- Wait for Flunity native. We'll publish a migration guide so app code (typed messages, `FlunityMessage`-based domain code) ports straight across.
