import 'dart:async';

import 'package:flunity_bridge/src/transport/message_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// [MessageTransport] backed by an [InAppWebViewController]. Routes outbound
/// JSON via `window.flunity.post(...)` (defined by the JS shim) and surfaces
/// inbound JSON via the `flunity` JS handler.
class InAppWebViewMessageTransport implements MessageTransport {
  InAppWebViewMessageTransport();

  InAppWebViewController? _webViewController;
  Completer<void> _ready = Completer<void>();
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();
  bool _disposed = false;

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<String> get incoming => _incoming.stream;

  /// Resolves once the message has been handed to the WebView.
  ///
  /// Messages sent before the JS shim signals ready wait here rather than
  /// resolving early: callers time their own operations off this future, so
  /// resolving at enqueue time would charge them for Unity's boot. Waiters
  /// resume in the order they arrived, which is what keeps a `load_scene`
  /// ahead of the `outlet_call` that depends on it.
  @override
  Future<void> send(String json) async {
    if (_disposed) throw StateError('InAppWebViewMessageTransport disposed');
    if (!_ready.isCompleted) await _ready.future;
    if (_disposed) throw StateError('InAppWebViewMessageTransport disposed');
    await evaluate(json);
  }

  @override
  Future<void> reload() async {
    // The new document has not run the JS shim yet, so re-arm the gate:
    // `window.flunity` is undefined until `flunity_ready` fires again.
    if (_ready.isCompleted) _ready = Completer<void>();
    await _webViewController?.reload();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Wake anything parked on the gate so it fails fast instead of hanging.
    if (!_ready.isCompleted) _ready.complete();
    await _incoming.close();
    _webViewController = null;
  }

  /// Snapshot of the current web content (PNG bytes), or null before the
  /// controller is attached. Lets hosts draw a blurred still of the Unity
  /// canvas behind their own overlays — Flutter's BackdropFilter cannot
  /// sample a platform view.
  Future<Uint8List?> takeScreenshot() =>
      _webViewController?.takeScreenshot() ?? Future.value(null);

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
  }

  /// Hands one JSON envelope to the page. Overridden in tests to exercise the
  /// gate and ordering without a live WebView.
  @protected
  @visibleForOverriding
  Future<void> evaluate(String json) async {
    final controller = _webViewController;
    if (controller == null) return;
    final escaped = _jsString(json);
    await controller.evaluateJavascript(
      source: 'window.flunity.post($escaped);',
    );
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
