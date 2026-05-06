# Changelog

## [Unreleased]

### Initial

- `FlunityMessage` hierarchy + built-in types (Ping/Pong, LoadScene/SceneReady).
- WebGL transport: `FlunityWebGLConfig`, `FlunityWebGLController`, `FlunityWebGLView`.

### Plan F — native transport

- iOS + Android plugins vendored from `flutter_embed_unity` v2.0.0 (MIT). See `THIRDPARTY.md`.
- `FlunityNativeView`, `sendToUnity` / `pauseUnity` / `resumeUnity`, `FlunityNativePreferences`, `UnityMessageListener`.
- `UnitySceneRoute` widget — route-scoped scene swap helper.

### Plan K — outlets

- `OutletCall` / `OutletReply` / `OutletFind` / `OutletFindReply` message types.
- `FlunityInvoker` singleton (`flunity`): `invoke<T>(name, {target, args, timeout})`, `find(componentName)`, `FlunityComponentHandle.invoke(method, args:)`.
- `FlunityOutletException`, `FlunityOutletTimeoutException`, `FlunityNotAttachedException`.
- iOS / Android only; WebGL outlet support is Plan L.

### Logs + scene inspection

- `FlunityLogStream` (`flunityLogs`): collects Unity `Debug.Log` + Flutter `debugPrint` into a 500-entry ring buffer. Outlet calls auto-recorded as `← outlet_call` / `→ outlet_reply`.
- `UnityMessageListeners` always-fanout listener hook (used by the invoker + log stream so they receive replies regardless of which native widget is mounted).
