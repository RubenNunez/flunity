import 'dart:async';
import 'dart:convert';

import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/transport/message_transport.dart';

/// High-level Flutter-side controller. Wraps a [MessageTransport] and
/// exposes typed [FlunityMessage] streams + send.
class FlunityWebGLController {
  FlunityWebGLController({required MessageTransport transport})
      : _transport = transport {
    _transport.ready.then((_) {
      _isReady = true;
    });
    _incomingSub = _transport.incoming.listen(
      _handleIncoming,
      onError: _messages.addError,
    );
  }

  final MessageTransport _transport;
  final StreamController<FlunityMessage> _messages =
      StreamController<FlunityMessage>.broadcast();
  late final StreamSubscription<String> _incomingSub;

  bool _isReady = false;
  bool _disposed = false;

  bool get isReady => _isReady;

  Stream<FlunityMessage> get messages => _messages.stream;

  Future<void> send(FlunityMessage message) async {
    if (_disposed) {
      throw StateError('FlunityWebGLController has been disposed');
    }
    final encoded = jsonEncode(message.toJson());
    return _transport.send(encoded);
  }

  Future<void> reload() => _transport.reload();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _incomingSub.cancel();
    await _transport.dispose();
    await _messages.close();
  }

  void _handleIncoming(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) {
        _messages.addError(
          FormatException('Expected JSON object from Unity, got ${decoded.runtimeType}'),
        );
        return;
      }
      _messages.add(FlunityMessage.fromJson(decoded));
    } on FormatException catch (e, st) {
      _messages.addError(e, st);
    }
  }
}
