import 'dart:async';
import 'dart:collection';

import 'package:flunity_bridge/src/transport/message_transport.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// [MessageTransport] backed by an [InAppWebViewController]. Routes outbound
/// JSON via `window.flunity.post(...)` (defined by the JS shim) and surfaces
/// inbound JSON via the `flunity` JS handler.
class InAppWebViewMessageTransport implements MessageTransport {
  InAppWebViewMessageTransport();

  InAppWebViewController? _webViewController;
  final Completer<void> _ready = Completer<void>();
  final StreamController<String> _incoming = StreamController<String>.broadcast();
  final Queue<String> _pending = Queue<String>();
  bool _disposed = false;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Future<void> send(String json) async {
    if (_disposed) throw StateError('InAppWebViewMessageTransport disposed');
    if (_webViewController == null || !_ready.isCompleted) {
      _pending.add(json);
      return;
    }
    await _evaluate(json);
  }

  @override
  Future<void> reload() async {
    await _webViewController?.reload();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    await _incoming.close();
    _webViewController = null;
  }

  /// Hooked by [FlunityWebGLView] when the platform controller is available.
  void attach(InAppWebViewController controller) {
    _webViewController = controller;
    controller.addJavaScriptHandler(
      handlerName: 'flunity',
      callback: (args) {
        if (_disposed) return null;
        if (args.isNotEmpty && args.first is String) {
          _incoming.add(args.first as String);
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'flunity_ready',
      callback: (_) {
        markReady();
        return null;
      },
    );
  }

  /// Hooked by [FlunityWebGLView] once `window.flunity.ready()` fires.
  Future<void> markReady() async {
    if (_disposed || _ready.isCompleted) return;
    _ready.complete();
    while (_pending.isNotEmpty) {
      final next = _pending.removeFirst();
      await _evaluate(next);
    }
  }

  Future<void> _evaluate(String json) async {
    final controller = _webViewController;
    if (controller == null) return;
    final escaped = _jsString(json);
    await controller.evaluateJavascript(source: 'window.flunity.post($escaped);');
  }

  static String _jsString(String value) {
    final buf = StringBuffer('"');
    for (final r in value.runes) {
      final ch = String.fromCharCode(r);
      switch (ch) {
        case '\\':
          buf.write(r'\\');
        case '"':
          buf.write(r'\"');
        case '\n':
          buf.write(r'\n');
        case '\r':
          buf.write(r'\r');
        case '\t':
          buf.write(r'\t');
        default:
          if (r < 0x20) {
            buf.write('\\u${r.toRadixString(16).padLeft(4, '0')}');
          } else {
            buf.write(ch);
          }
      }
    }
    buf.write('"');
    return buf.toString();
  }
}
