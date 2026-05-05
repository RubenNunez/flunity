// Adapted from flutter_embed_unity/lib/src/unity_message_listener.dart in
// flutter_embed_unity v2.0.0 (MIT, learntoflutter). Unchanged.
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

/// A simple interface for a class listening for messages from Unity.
///
/// [FlunityNativeView] implements this internally and forwards to its
/// `onMessageFromUnity` callback. Game code generally doesn't need this
/// interface — use the widget's callback instead.
abstract class UnityMessageListener {
  void onMessageFromUnity(String data);
}
