// Adapted from flutter_embed_unity/lib/src/embed_unity_preferences.dart in
// flutter_embed_unity v2.0.0 (MIT, learntoflutter). Class renamed from
// EmbedUnityPreferences → FlunityNativePreferences.
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

/// Routing policy for messages flowing from Unity → multiple
/// [FlunityNativeView] widgets in the same Flutter app.
enum MessageFromUnityListeningBehaviour {
  /// All `FlunityNativeView` widgets currently in the widget tree receive
  /// every message from Unity (multicast).
  allWidgetsReceiveMessages,

  /// Only the most recently created widget — usually the top-most route on
  /// the navigation stack — receives messages from Unity (unicast).
  onlyMostRecentlyCreatedWidgetReceivesMessages,
}

/// Process-wide preferences for native Unity messaging.
///
/// Set this once at app startup, before any [FlunityNativeView] mounts.
class FlunityNativePreferences {
  static MessageFromUnityListeningBehaviour messageFromUnityListeningBehaviour =
      MessageFromUnityListeningBehaviour.allWidgetsReceiveMessages;
}
