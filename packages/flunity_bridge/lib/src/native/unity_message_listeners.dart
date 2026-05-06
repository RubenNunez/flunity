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

  /// Always-fanout listeners. Bypass [FlunityNativePreferences] — every
  /// callback in this list receives every inbound message, no matter which
  /// widget is mounted. Used by the outlet invoker so `outlet_reply` /
  /// `outlet_find_reply` always reach the awaiting [Future], regardless of
  /// which `FlunityNativeView` (if any) is currently on screen.
  final List<void Function(String)> _alwaysListeners =
      <void Function(String)>[];

  void addListener(UnityMessageListener listener) {
    _listeners.add(listener);
  }

  void removeListener(UnityMessageListener listener) {
    _listeners.remove(listener);
  }

  void addAlwaysListener(void Function(String) callback) {
    _alwaysListeners.add(callback);
  }

  void removeAlwaysListener(void Function(String) callback) {
    _alwaysListeners.remove(callback);
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
    // Always-fanout listeners run regardless of preferences — invoker depends
    // on this to correlate replies even when no widget is currently mounted.
    for (final cb in _alwaysListeners) {
      cb(data);
    }
    return null;
  }
}
