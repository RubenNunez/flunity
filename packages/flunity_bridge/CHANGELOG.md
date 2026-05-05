# Changelog

## [Unreleased]

### Added
- Initial release: abstract `FlunityMessage` hierarchy, `FlunityWebGLConfig`, `FlunityWebGLController`, `FlunityWebGLView`.
- Native (iOS / Android) transport vendored from `flutter_embed_unity` v2.0.0 (MIT, learntoflutter): `FlunityNativeView`, `sendToUnity` / `pauseUnity` / `resumeUnity` top-level helpers, `FlunityNativePreferences`, `UnityMessageListener`. iOS plugin class `FlunityBridgeIosPlugin`, Android `FlunityBridgeAndroidPlugin` (package `com.flunity.bridge`).
- `UnitySceneRoute` widget — route-scoped helper for "one Unity, many Flutter routes". `UnitySceneRoute.native` factory pre-wires `sendToUnity('[FlunityBridge]', 'ReceiveFromFlutter', json)` for the canonical native template setup.
- iOS `@_cdecl("FlunityBridge_sendToFlutter")` C symbol so Unity's `[DllImport("__Internal")]` resolves at runtime.
- Android `com.flunity.bridge.messaging.SendToFlutter` static class so Unity's `AndroidJavaClass` reflection resolves outbound messages.
