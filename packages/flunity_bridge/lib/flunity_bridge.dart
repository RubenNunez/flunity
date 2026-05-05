/// Flunity bridge: embed Unity inside Flutter with a typed message bridge.
///
/// Three transports, one bridge contract:
/// - **WebGL** — [FlunityWebGLView] hosts the Unity build inside an
///   `InAppWebView`. See `FlunityWebGLConfig` for dev/bundled mode.
/// - **iOS / Android (native)** — [FlunityNativeView] hosts a native Unity
///   instance via the bundled platform plugin. Top-level helpers
///   [sendToUnity], [pauseUnity], [resumeUnity] target the active instance.
///
/// Consumers must call [registerBuiltInMessages] once at app startup
/// (typically in `main()`) before any [FlunityMessage.fromJson] calls. Plan
/// C's templates do this for generated apps.
library flunity_bridge;

// Bridge contract (transport-independent).
export 'package:flunity_bridge/src/flunity_message.dart';
export 'package:flunity_bridge/src/messages/built_in.dart'
    show registerBuiltInMessages;
export 'package:flunity_bridge/src/messages/load_scene.dart';
export 'package:flunity_bridge/src/messages/ping.dart';
export 'package:flunity_bridge/src/messages/pong.dart';
export 'package:flunity_bridge/src/messages/scene_ready.dart';
export 'package:flunity_bridge/src/routing/unity_scene_route.dart'
    show UnitySceneRoute;
export 'package:flunity_bridge/src/transport/message_transport.dart';

// WebGL transport.
export 'package:flunity_bridge/src/flunity_webgl_config.dart';
export 'package:flunity_bridge/src/flunity_webgl_controller.dart';
export 'package:flunity_bridge/src/flunity_webgl_view.dart';

// Native (iOS / Android) transport. Vendored from flutter_embed_unity v2.0.0
// (MIT). See THIRDPARTY.md.
export 'package:flunity_bridge/src/native/flunity_native_view.dart'
    show FlunityNativeView;
export 'package:flunity_bridge/src/native/native_api.dart'
    show sendToUnity, pauseUnity, resumeUnity;
export 'package:flunity_bridge/src/native/native_preferences.dart'
    show FlunityNativePreferences, MessageFromUnityListeningBehaviour;
export 'package:flunity_bridge/src/native/unity_message_listener.dart'
    show UnityMessageListener;
