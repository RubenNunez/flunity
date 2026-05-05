# Vendor Inventory — flutter_embed_unity v2.0.0

> Plan-of-record for Plan F Phases 11-13 (the actual copy + adapt work).
>
> Upstream: <https://github.com/learntoflutter/flutter_embed_unity> @ commit `32d6b2d` (tag `v2.0.0`).
> License: MIT (see [`THIRDPARTY-LICENSES/flutter_embed_unity-LICENSE.txt`](THIRDPARTY-LICENSES/flutter_embed_unity-LICENSE.txt)).
>
> The implementer of Phase 3 should clone the upstream repo locally
> (`/tmp/flutter_embed_unity_upstream` is reused), check out the tag,
> and copy each file below in order, applying the rename rules in this
> document and the conventions in [`THIRDPARTY.md`](THIRDPARTY.md).

## Path conventions

- All upstream paths are relative to the upstream repo root.
- All target paths are relative to `packages/flunity_bridge/` unless noted.
- Editor scripts land in the `unity_bridge_basic` template, under
  `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Editor/Flunity/`.
- Add a header comment to every vendored file:
  ```
  // Adapted from <upstream/path> in flutter_embed_unity v2.0.0 (MIT, learntoflutter).
  // See packages/flunity_bridge/THIRDPARTY.md for full attribution.
  ```

## Symbol renames (apply globally during copy)

| Upstream | Our name |
| --- | --- |
| `EmbedUnity` (widget) | `FlunityNativeView` |
| `MessageFromUnityListeningBehaviour` | `MessageFromUnityListeningBehaviour` (keep — descriptive, no brand) |
| `EmbedUnityPreferences` | `FlunityNativePreferences` |
| `sendToUnity()` (top-level) | `sendToUnity()` (keep — verb is fine; the Dart import is `package:flunity_bridge/flunity_bridge.dart`) |
| `pauseUnity()` / `resumeUnity()` | unchanged |
| `FlutterEmbedUnityIosPlugin` (Swift) | `FlunityBridgeIosPlugin` |
| `FlutterEmbedUnityAndroidPlugin` (Kotlin) | `FlunityBridgeAndroidPlugin` |
| `com.learntoflutter.flutter_embed_unity_ios` (iOS pod) | `com.flunity.bridge.ios` (or just `flunity_bridge`) |
| `com.learntoflutter.flutter_embed_unity_android` (Android pkg) | `com.flunity.bridge` |
| Method channel names `flutter_embed_unity` | `flunity_bridge` |

## flutter_embed_unity (Dart wrapper)

| Upstream | Target | Notes |
| --- | --- | --- |
| `flutter_embed_unity/lib/flutter_embed_unity.dart` | `lib/src/native/flunity_native_api.dart` | Public re-exports → become internal exports of flunity_bridge. The lib's `flunity_bridge.dart` adds these to its export list. |
| `flutter_embed_unity/lib/src/embed_unity.dart` | `lib/src/native/flunity_native_view.dart` | Class `EmbedUnity` → `FlunityNativeView`. |
| `flutter_embed_unity/lib/src/embed_unity_preferences.dart` | `lib/src/native/flunity_native_preferences.dart` | `EmbedUnityPreferences` → `FlunityNativePreferences`. |
| `flutter_embed_unity/lib/src/unity_message_listener.dart` | `lib/src/native/unity_message_listener.dart` | Keep symbol names. |
| `flutter_embed_unity/lib/src/unity_message_listeners.dart` | `lib/src/native/unity_message_listeners.dart` | Keep symbol names. |

## flutter_embed_unity_platform_interface

| Upstream | Target | Notes |
| --- | --- | --- |
| `flutter_embed_unity_platform_interface/lib/flutter_embed_unity_platform_interface.dart` | `lib/src/native/platform_interface.dart` | The interface class — collapses into a regular abstract class within flunity_bridge (no federation). |
| `flutter_embed_unity_platform_interface/lib/method_channel_flutter_embed_unity.dart` | `lib/src/native/method_channel_native.dart` | The MethodChannel-backed default impl. Rename channel to `flunity_bridge`. |
| `flutter_embed_unity_platform_interface/lib/flutter_embed_constants.dart` | `lib/src/native/native_constants.dart` | Channel/handler name constants. Update to `flunity_bridge`. |

## flutter_embed_unity_2022_3_ios → `packages/flunity_bridge/ios/`

(The 2022.3 iOS package supports both Unity 2022.3 and Unity 6 per upstream's
pubspec comment.)

| Upstream | Target | Notes |
| --- | --- | --- |
| `flutter_embed_unity_2022_3_ios/ios/flutter_embed_unity_2022_3_ios.podspec` | `ios/flunity_bridge.podspec` | Rename pod, update homepage/repo URLs to flunity. |
| `flutter_embed_unity_2022_3_ios/ios/flutter_embed_unity_2022_3_ios/Package.swift` | `ios/flunity_bridge/Package.swift` | Update package name. |
| `flutter_embed_unity_2022_3_ios/ios/flutter_embed_unity_2022_3_ios/Sources/.../FlutterEmbedUnityIosPlugin.swift` | `ios/Classes/FlunityBridgeIosPlugin.swift` | Rename plugin class. |
| `flutter_embed_unity_2022_3_ios/ios/.../Constants/FlutterEmbedConstants.swift` | `ios/Classes/Constants/NativeConstants.swift` | Update channel name. |
| `flutter_embed_unity_2022_3_ios/ios/.../Messaging/SendToFlutter.swift` | `ios/Classes/Messaging/SendToFlutter.swift` | Keep filename. Update channel constant. |
| `flutter_embed_unity_2022_3_ios/ios/.../Messaging/SendToUnity.swift` | `ios/Classes/Messaging/SendToUnity.swift` | Keep. |
| `flutter_embed_unity_2022_3_ios/ios/.../Unity/UnityPlayerSingleton.swift` | `ios/Classes/Unity/UnityPlayerSingleton.swift` | Keep — the singleton pattern is upstream's; we don't change semantics. |
| `flutter_embed_unity_2022_3_ios/ios/.../View/UnityPlatformView.swift` | `ios/Classes/View/UnityPlatformView.swift` | Keep. |
| `flutter_embed_unity_2022_3_ios/ios/.../View/UnityView.swift` | `ios/Classes/View/UnityView.swift` | Keep. |
| `flutter_embed_unity_2022_3_ios/ios/.../View/UnityViewController.swift` | `ios/Classes/View/UnityViewController.swift` | Keep. |
| `flutter_embed_unity_2022_3_ios/ios/.../View/UnityViewFactory.swift` | `ios/Classes/View/UnityViewFactory.swift` | Update factory ID to `flunity_bridge/UnityView`. |
| `flutter_embed_unity_2022_3_ios/ios/.../View/UnityViewStack.swift` | `ios/Classes/View/UnityViewStack.swift` | Keep. |
| `flutter_embed_unity_2022_3_ios/ios/.../UnityFrameworkStubs/**` | `ios/UnityFrameworkStubs/**` | The stub xcframework headers — verbatim copy (compile-time stubs; the real UnityFramework.xcframework is provided at app integration time by `flunity bundle ios`). |
| `flutter_embed_unity_2022_3_ios/lib/flutter_embed_unity_2022_3_ios.dart` | (skip — collapsed into flunity_bridge's main lib) | This file just registers the iOS implementation against the platform interface. Our collapsed-no-federation model handles registration internally. |

## flutter_embed_unity_6000_0_android → `packages/flunity_bridge/android/`

(Unity 6 only — confirmed locked in Plan F.)

| Upstream | Target | Notes |
| --- | --- | --- |
| `flutter_embed_unity_6000_0_android/android/build.gradle` | `android/build.gradle` | Rename group to `com.flunity.bridge`, update namespace. |
| `flutter_embed_unity_6000_0_android/android/settings.gradle` | `android/settings.gradle` | Project name → `flunity_bridge`. |
| `flutter_embed_unity_6000_0_android/android/src/main/AndroidManifest.xml` | `android/src/main/AndroidManifest.xml` | Update package attribute → `com.flunity.bridge`. |
| `flutter_embed_unity_6000_0_android/.../FlutterEmbedUnityAndroidPlugin.kt` | `android/src/main/kotlin/com/flunity/bridge/FlunityBridgeAndroidPlugin.kt` | Repackage. Rename class. |
| `flutter_embed_unity_6000_0_android/.../constants/FlutterEmbedConstants.kt` | `android/src/main/kotlin/com/flunity/bridge/constants/NativeConstants.kt` | Update channel name to `flunity_bridge`. |
| `flutter_embed_unity_6000_0_android/.../messaging/SendToUnity.kt` | `android/src/main/kotlin/com/flunity/bridge/messaging/SendToUnity.kt` | Keep filename. |
| `flutter_embed_unity_6000_0_android/.../platformView/CopyMotionEvent.kt` | `android/src/main/kotlin/com/flunity/bridge/platformView/CopyMotionEvent.kt` | Keep. |
| `flutter_embed_unity_6000_0_android/.../platformView/CustomFrameLayout.kt` | `android/src/main/kotlin/com/flunity/bridge/platformView/CustomFrameLayout.kt` | Keep. |
| `flutter_embed_unity_6000_0_android/.../platformView/IUnityViewStackable.kt` | `android/src/main/kotlin/com/flunity/bridge/platformView/IUnityViewStackable.kt` | Keep. |
| `flutter_embed_unity_6000_0_android/.../platformView/UnityView.kt` | `android/src/main/kotlin/com/flunity/bridge/platformView/UnityView.kt` | Keep. |
| `flutter_embed_unity_6000_0_android/.../platformView/UnityViewFactory.kt` | `android/src/main/kotlin/com/flunity/bridge/platformView/UnityViewFactory.kt` | Update view factory ID to `flunity_bridge/UnityView`. |
| `flutter_embed_unity_6000_0_android/.../platformView/UnityViewStack.kt` | `android/src/main/kotlin/com/flunity/bridge/platformView/UnityViewStack.kt` | Keep. |
| `flutter_embed_unity_6000_0_android/.../unity/ResumeUnityOnActivityResume.kt` | `android/src/main/kotlin/com/flunity/bridge/unity/ResumeUnityOnActivityResume.kt` | Keep. |
| `flutter_embed_unity_6000_0_android/.../unity/UnityPlayerSingleton.kt` | `android/src/main/kotlin/com/flunity/bridge/unity/UnityPlayerSingleton.kt` | Keep — singleton pattern is upstream's. |
| `flutter_embed_unity_6000_0_android/lib/flutter_embed_unity_6000_0_android.dart` | (skip — collapsed) | Same rationale as the iOS lib file. |

## Unity Editor scripts → `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Editor/Flunity/`

(From the upstream's `example_unity_6000_0_project`; the 2022.3 example has the
same scripts — we use the 6000.0 variant since Unity 6 is locked.)

| Upstream | Target | Notes |
| --- | --- | --- |
| `example_unity_6000_0_project/Assets/FlutterEmbed/Editor/ProjectExporter.cs` | `Editor/Flunity/FlunityExporter.cs` | Rename class. Wraps build invocations. |
| `example_unity_6000_0_project/Assets/FlutterEmbed/Editor/ProjectExporterAndroid.cs` | `Editor/Flunity/FlunityExporterAndroid.cs` | Rename class. Builds Android library export. |
| `example_unity_6000_0_project/Assets/FlutterEmbed/Editor/ProjectExporterIos.cs` | `Editor/Flunity/FlunityExporterIos.cs` | Rename class. Builds iOS Xcode project + post-processes to XCFramework (or surfaces output for `flunity bundle ios` to do that). |
| `example_unity_6000_0_project/Assets/FlutterEmbed/Editor/ProjectExporterMenuItem.cs` | `Editor/Flunity/FlunityMenu.cs` | Rename to `Flunity > Build > {WebGL, iOS, Android, All}`. |
| `example_unity_6000_0_project/Assets/FlutterEmbed/Editor/ProjectExporterBatchmode.cs` | `Editor/Flunity/FlunityBatchmode.cs` | Rename method names per Plan F's Phase 2 task: `Flunity.Editor.FlunityBuilder.BuildWebGL`, `BuildIOS`, `BuildAndroid`, `BuildAll`. |
| `example_unity_6000_0_project/Assets/FlutterEmbed/Editor/ProjectExportChecker.cs` | `Editor/Flunity/FlunityExportChecker.cs` | Rename class. Pre-flight checks (target platform installed, etc.). |
| `example_unity_6000_0_project/Assets/FlutterEmbed/Editor/ProjectExportHelpers.cs` | `Editor/Flunity/FlunityExportHelpers.cs` | Rename class. Helpers. |

## Runtime Unity-side helper

| Upstream | Target | Notes |
| --- | --- | --- |
| `example_unity_6000_0_project/Assets/FlutterEmbed/SendToFlutter/SendToFlutter.cs` | `packages/flunity_cli/templates/unity_bridge_basic/unity_project/Assets/Scripts/SendToFlutter.cs` | Goes alongside our existing `FlunityBridge.cs`. The two complement each other: `FlunityBridge.cs` is our high-level API; `SendToFlutter.cs` is upstream's transport wrapper that we adopt for native (and reuse the same JSON envelope). |

## Things we DO NOT vendor

- Test files under `*/test/` and `example/` — we have our own templates + tests.
- The full `example_unity_*_project` Unity scenes/AR scripts. Just the `Assets/FlutterEmbed/Editor/` and `Assets/FlutterEmbed/SendToFlutter/` subtrees.
- The two example Flutter apps. They're upstream's demos; ours is `my_hybrid_app` + the templates.
- CI configs (`.github/workflows`).
- `flutter_embed_unity_2022_3_android` — Unity 2022.3 only; superseded by `_6000_0_android` per Plan F's locked Unity 6 requirement.
- The `flutter_embed_unity_2022_3_ios` example's `RunnerTests/` — irrelevant.
- Each sub-package's `analysis_options.yaml` — we use our workspace's.
- Each sub-package's `LICENSE` — we keep one canonical copy under `THIRDPARTY-LICENSES/`.

## Open questions for the implementer (Phase 3)

1. **`UnityFrameworkStubs/`**: the upstream iOS package ships compile-time
   stub headers. Phase 3 should copy these verbatim. Phase 5 (`flunity bundle
   ios`) replaces them with the real `UnityFramework.xcframework` produced by
   `flunity build ios`. Verify this dance works (build with stubs → swap with
   real framework → re-link).
2. **`UnityPlayerSingleton`**: both platforms enforce ONE Unity instance per
   process. This is non-negotiable for Unity-as-library. Document this in
   `docs/multi-target.md` so users understand they can't mount two
   `FlunityNativeView` widgets simultaneously expecting independent Unity
   instances.
3. **Android `MainActivity` requirement**: upstream's example `MainActivity.kt`
   may inherit from a custom base class to support Unity lifecycle. Check
   whether vendored code requires the consumer's `MainActivity` to extend
   anything specific. If so, Phase 5's `flunity bundle android` must patch the
   user's `MainActivity.kt`.
4. **`SendToFlutter.cs` envelope vs FlunityBridge.cs envelope**: upstream's
   helper sends a `(gameObject, method, message)` triple. Ours uses
   `(type, payload)` JSON. Phase 3 needs to either bridge the two or make
   `SendToFlutter.cs` use the JSON envelope. The latter is cleaner; verify
   it's a small change in upstream's code.

## Reproducibility

If a future implementer needs to refresh this inventory:

```bash
rm -rf /tmp/flutter_embed_unity_upstream
git clone https://github.com/learntoflutter/flutter_embed_unity /tmp/flutter_embed_unity_upstream
cd /tmp/flutter_embed_unity_upstream
git checkout v2.0.0
# Re-run the find / inventory commands from this file's git history.
```
