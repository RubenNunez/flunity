// Adapted from flutter_embed_unity/lib/src/unity_message_listeners.dart in
// flutter_embed_unity v2.0.0 (MIT, learntoflutter). Channel constant
// reference updated to NativeConstants.
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

import 'package:flutter/services.dart';

import 'native_constants.dart';
import 'native_preferences.dart';
import 'unity_message_listener.dart';

/// Process-wide registry of [FlunityNativeView]s currently listening for
/// messages from Unity. Native code dispatches `sendToFlutter` MethodCalls
/// against the [NativeConstants.channelName] channel; this class fans them
/// out to listeners according to [FlunityNativePreferences].
class UnityMessageListeners {
  UnityMessageListeners._internal() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static final UnityMessageListeners instance =
      UnityMessageListeners._internal();

  final MethodChannel _channel = const MethodChannel(
    NativeConstants.channelName,
  );
  final List<UnityMessageListener> _listeners = <UnityMessageListener>[];

  void addListener(UnityMessageListener listener) {
    _listeners.add(listener);
  }

  void removeListener(UnityMessageListener listener) {
    _listeners.remove(listener);
  }

  Future<dynamic> _methodCallHandler(MethodCall call) async {
    if (call.method != NativeConstants.methodSendToFlutter) return null;
    final String data = call.arguments.toString();
    switch (FlunityNativePreferences.messageFromUnityListeningBehaviour) {
      case MessageFromUnityListeningBehaviour.allWidgetsReceiveMessages:
        for (final listener in _listeners) {
          listener.onMessageFromUnity(data);
        }
      case MessageFromUnityListeningBehaviour
          .onlyMostRecentlyCreatedWidgetReceivesMessages:
        if (_listeners.isNotEmpty) {
          _listeners.last.onMessageFromUnity(data);
        }
    }
    return null;
  }
}
