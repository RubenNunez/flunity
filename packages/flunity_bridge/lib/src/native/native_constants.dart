// Adapted from flutter_embed_unity_platform_interface/lib/flutter_embed_constants.dart
// in flutter_embed_unity v2.0.0 (MIT, learntoflutter). Channel name rebranded
// from "com.learntoflutter/flutter_embed_unity" to "flunity_bridge".
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

/// Constants used by the native (iOS / Android) Unity bridge.
///
/// [channelName] must match:
/// - the iOS Swift plugin's registered `FlutterMethodChannel` name,
/// - the Android Kotlin plugin's registered `MethodChannel` name,
/// - the PlatformView factory's view-type identifier on both platforms.
class NativeConstants {
  /// The single method channel used for both Flutter→Unity calls and
  /// Unity→Flutter callbacks. Also doubles as the PlatformView factory id.
  static const String channelName = 'flunity_bridge';

  /// Method name: Flutter calls this on the channel to send a message into
  /// Unity (`(gameObjectName, methodName, payload)` triple).
  static const String methodSendToUnity = 'sendToUnity';

  /// Method name: native code calls this on the channel to deliver a message
  /// from Unity to Flutter (string payload).
  static const String methodSendToFlutter = 'sendToFlutter';

  /// Method name: pause Unity time.
  static const String methodPauseUnity = 'pauseUnity';

  /// Method name: resume Unity time.
  static const String methodResumeUnity = 'resumeUnity';
}
