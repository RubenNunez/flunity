// Adapted from flutter_embed_unity/lib/flutter_embed_unity.dart in
// flutter_embed_unity v2.0.0 (MIT, learntoflutter). Federation collapsed —
// the abstract platform interface is replaced with direct MethodChannel calls.
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

import 'package:flutter/services.dart';

import 'native_constants.dart';

const MethodChannel _channel = MethodChannel(NativeConstants.channelName);

/// Send [data] to a public MonoBehaviour method named [methodName] attached
/// to a Unity GameObject named [gameObjectName] in the active scene.
///
/// The Unity method must be public and accept a single [String] parameter.
/// Native (iOS / Android) only — no-op on other platforms.
Future<void> sendToUnity(
  String gameObjectName,
  String methodName,
  String data,
) async {
  await _channel.invokeMethod(NativeConstants.methodSendToUnity, [
    gameObjectName,
    methodName,
    data,
  ]);
}

/// Pause time in Unity.
///
/// Unity remains loaded in memory and will still receive messages.
Future<void> pauseUnity() async {
  await _channel.invokeMethod(NativeConstants.methodPauseUnity);
}

/// Resume time in Unity.
Future<void> resumeUnity() async {
  await _channel.invokeMethod(NativeConstants.methodResumeUnity);
}
