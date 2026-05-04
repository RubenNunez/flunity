import 'dart:async';

import 'package:flunity_bridge/src/transport/message_transport.dart';

/// Test double for [MessageTransport]. Tests drive `incoming` via [pushFromUnity]
/// and assert what was sent via [sentMessages].
class FakeMessageTransport implements MessageTransport {
  FakeMessageTransport({bool startReady = true}) {
    if (startReady) markReady();
  }

  final List<String> sentMessages = <String>[];
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();
  final Completer<void> _ready = Completer<void>();
  bool _disposed = false;
  int reloadCount = 0;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Future<void> send(String json) async {
    if (_disposed) throw StateError('FakeMessageTransport disposed');
    await ready;
    sentMessages.add(json);
  }

  @override
  Future<void> reload() async {
    reloadCount += 1;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _incoming.close();
  }

  // Test helpers ---

  void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void pushFromUnity(String json) {
    _incoming.add(json);
  }
}
