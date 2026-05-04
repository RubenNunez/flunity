/// Abstract transport for the Flutter <-> Unity bridge. Implementations:
///   - InAppWebViewMessageTransport: real WebView (lib/src/transport/inapp_webview_transport.dart)
///   - FakeMessageTransport: in-memory test impl (test/transport/fake_transport.dart)
abstract interface class MessageTransport {
  /// A future that completes when the underlying runtime is ready to accept messages.
  Future<void> get ready;

  /// Stream of raw JSON strings sent from Unity to Flutter.
  Stream<String> get incoming;

  /// Send a JSON string from Flutter to Unity. Implementations queue if not yet ready.
  Future<void> send(String json);

  /// Reload the underlying runtime (e.g. WebView reload). Optional for fakes.
  Future<void> reload();

  /// Tear down resources. Idempotent.
  Future<void> dispose();
}
