/// Flunity bridge: embed Unity inside Flutter with a typed message bridge.
///
/// Three transports, one bridge contract:
/// - **WebGL** — [FlunityWebGLView] hosts the Unity build inside an
///   `InAppWebView`. See `FlunityWebGLConfig` for dev/bundled mode.
/// - **iOS / Android (native)** — [FlunityNativeView] hosts a native Unity
///   instance via the bundled platform plugin. Top-level helpers
///   [sendToUnity], [pauseUnity], [resumeUnity] target the active instance.
///
/// `flunity.invoke` and the log stream work out of the box — no setup call
/// required. If you parse raw envelopes via [FlunityMessage.fromJson] for
/// the other built-ins (Ping/Pong/LoadScene/SceneReady), call
/// [registerBuiltInMessages] once at app startup so those types resolve
/// to their typed factories instead of a [RawMessage].
library flunity_bridge;

// ignore_for_file: directives_ordering
//
// Exports are intentionally grouped by concern (bridge contract / WebGL /
// native transport / outlets / routing) for readability. The directives
// inside each group ARE alphabetically sorted; the overall file just isn't.

// Bridge contract (transport-independent).
export 'package:flunity_bridge/src/flunity_message.dart';
export 'package:flunity_bridge/src/messages/built_in.dart'
    show registerBuiltInMessages;
export 'package:flunity_bridge/src/messages/load_scene.dart';
export 'package:flunity_bridge/src/messages/outlet_call.dart';
export 'package:flunity_bridge/src/messages/outlet_find.dart';
export 'package:flunity_bridge/src/messages/outlet_find_reply.dart'
    show FlunityComponentRef, OutletFindReply;
export 'package:flunity_bridge/src/messages/outlet_reply.dart';
export 'package:flunity_bridge/src/messages/ping.dart';
export 'package:flunity_bridge/src/messages/pong.dart';
export 'package:flunity_bridge/src/messages/scene_ready.dart';
export 'package:flunity_bridge/src/logging/flunity_log_stream.dart'
    show
        FlunityLogEntry,
        FlunityLogLevel,
        FlunityLogSource,
        FlunityLogStream,
        flunityLogs;
export 'package:flunity_bridge/src/outlets/flunity_invoker.dart'
    show
        FlunityComponentHandle,
        FlunityInvoker,
        FlunityNotAttachedException,
        FlunityOutletException,
        FlunityOutletTimeoutException,
        flunity;
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
