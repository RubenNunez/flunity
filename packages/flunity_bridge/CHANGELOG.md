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

### Plan L — WebGL outlets

- Outlet invoker now routes over an attachable `MessageTransport` (`attachWebTransport` / `detachWebTransport`) instead of being native-only.
- `FlunityWebGLController` auto-registers its transport with the global `flunity` invoker on start and deregisters it on dispose, so `flunity.invoke` / `flunity.find` work on WebGL with no extra setup.
- `FlunityNotAttachedException` message updated to the new "mount a view" guidance.

### Logs + scene inspection

- `FlunityLogStream` (`flunityLogs`): collects Unity `Debug.Log` + Flutter `debugPrint` into a 500-entry ring buffer. Outlet calls auto-recorded as `← outlet_call` / `→ outlet_reply`.
- `UnityMessageListeners` always-fanout listener hook (used by the invoker + log stream so they receive replies regardless of which native widget is mounted).
