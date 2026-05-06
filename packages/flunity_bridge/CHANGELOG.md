# Changelog

## [Unreleased]

### Added
- Initial release: abstract `FlunityMessage` hierarchy, `FlunityWebGLConfig`, `FlunityWebGLController`, `FlunityWebGLView`.
- Native (iOS / Android) transport vendored from `flutter_embed_unity` v2.0.0 (MIT, learntoflutter): `FlunityNativeView`, `sendToUnity` / `pauseUnity` / `resumeUnity` top-level helpers, `FlunityNativePreferences`, `UnityMessageListener`. iOS plugin class `FlunityBridgeIosPlugin`, Android `FlunityBridgeAndroidPlugin` (package `com.flunity.bridge`).
- `UnitySceneRoute` widget — route-scoped helper for "one Unity, many Flutter routes". `UnitySceneRoute.native` factory pre-wires `sendToUnity('[FlunityBridge]', 'ReceiveFromFlutter', json)` for the canonical native template setup.
- iOS `@_cdecl("FlunityBridge_sendToFlutter")` C symbol so Unity's `[DllImport("__Internal")]` resolves at runtime.
- Android `com.flunity.bridge.messaging.SendToFlutter` static class so Unity's `AndroidJavaClass` reflection resolves outbound messages.
- iOS Pod gains `OTHER_LDFLAGS = -undefined dynamic_lookup` so UnityFramework class symbols (`_OBJC_CLASS_$_UnityFramework` etc.) resolve at runtime against the real framework loaded by the consuming app's Embed phase. Without this, every native iOS build failed at link time.
- WebGL-only mode opt-out via `FLUNITY_WEBGL_ONLY=1` env var in the Podfile — skips UnityFramework linking + view factory registration for Flutter apps that ship Unity through the WebView path only.

### Plan K — Outlets

- New built-in message types: `outlet_call`, `outlet_reply`, `outlet_find`, `outlet_find_reply`. Registered automatically by `registerBuiltInMessages()`.
- New `FlunityInvoker` singleton (`flunity`) with `invoke<T>(name, {target, args, timeout})` and `find(componentName)`. Returns `Future<T>` / `Future<List<FlunityComponentHandle>>`.
- `FlunityComponentHandle.invoke(method, args:)` sugar threads target id automatically.
- `FlunityOutletException`, `FlunityOutletTimeoutException`, `FlunityNotAttachedException` for the three failure modes. 5s default timeout, configurable per call.
- `UnityMessageListeners` gains `addAlwaysListener` / `removeAlwaysListener` — bypasses the per-widget preferences gate so the invoker correlates replies regardless of which `FlunityNativeView` (if any) is mounted.
- iOS / Android only in v1; WebGL invoker support is Plan L (calls raise `FlunityNotAttachedException` until then).
