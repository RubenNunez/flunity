import 'dart:convert';

import 'package:flunity_bridge/flunity_bridge.dart';

/// Helper for talking to Unity over the native (iOS / Android) bridge.
///
/// The wire format matches the WebGL bridge — same JSON envelope
/// `{"type": ..., "payload": ...}` parsed by `FlunityBridge.cs` on the
/// Unity side. The transport differs:
/// - WebGL: goes through `FlunityWebGLController` + the JS shim.
/// - Native: goes through `sendToUnity('[FlunityBridge]',
///   'ReceiveFromFlutter', json)` and Unity's native messaging.
///
/// `[FlunityBridge]` is the GameObject name your scene must contain (see
/// `FlunityBridgeBehaviour`). The method name `ReceiveFromFlutter` is
/// hardcoded on the Unity-side script.
class UnityNativeBridge {
  /// Send a typed [FlunityMessage] to Unity.
  static Future<void> send(FlunityMessage message) async {
    await sendToUnity(
      '[FlunityBridge]',
      'ReceiveFromFlutter',
      jsonEncode(message.toJson()),
    );
  }

  /// Convenience: send a `LoadScene` message.
  static Future<void> loadScene(String sceneName) =>
      send(LoadScene(scene: sceneName));

  /// Convenience: send a `Ping`. Returns the nonce so the caller can match
  /// the `Pong` response in their `onMessageFromUnity` callback.
  static Future<String> ping() async {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    await send(Ping(nonce: nonce));
    return nonce;
  }

  /// Parse a raw string from Unity (delivered via
  /// `FlunityNativeView.onMessageFromUnity`) as a typed [FlunityMessage].
  /// Returns null if the payload is not a valid envelope.
  static FlunityMessage? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, Object?>) {
        return FlunityMessage.fromJson(json);
      }
    } catch (_) {}
    return null;
  }
}
