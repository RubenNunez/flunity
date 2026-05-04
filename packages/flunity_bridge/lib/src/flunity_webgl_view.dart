import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/flunity_webgl_config.dart';
import 'package:flunity_bridge/src/flunity_webgl_controller.dart';
import 'package:flunity_bridge/src/transport/inapp_webview_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Drop-in widget that loads a Unity WebGL build inside an [InAppWebView] and
/// exposes a typed [FlunityWebGLController] via [onReady].
///
/// Bundled mode uses an [InAppLocalhostServer] because Unity WebGL refuses to
/// load via `file://` (uses ranged requests + workers). The server is started
/// lazily on first mount and reused process-wide.
class FlunityWebGLView extends StatefulWidget {
  const FlunityWebGLView({
    required this.config,
    this.onReady,
    this.onMessage,
    this.loadingBuilder,
    this.errorBuilder,
    super.key,
  });

  final FlunityWebGLConfig config;
  final ValueChanged<FlunityWebGLController>? onReady;
  final ValueChanged<FlunityMessage>? onMessage;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext, Object error)? errorBuilder;

  @override
  State<FlunityWebGLView> createState() => _FlunityWebGLViewState();
}

class _FlunityWebGLViewState extends State<FlunityWebGLView> {
  static final InAppLocalhostServer _bundledServer =
      InAppLocalhostServer(documentRoot: 'assets');

  late final InAppWebViewMessageTransport _transport;
  FlunityWebGLController? _controller;
  Object? _error;
  bool _bundledServerStarted = false;

  @override
  void initState() {
    super.initState();
    _transport = InAppWebViewMessageTransport();
    _controller = FlunityWebGLController(transport: _transport);
    if (widget.onReady != null) {
      // Fire onReady immediately; consumers can call send() — it'll queue.
      widget.onReady!(_controller!);
    }
    _controller!.messages.listen((m) => widget.onMessage?.call(m));
    _ensureBundledServerIfNeeded();
  }

  Future<void> _ensureBundledServerIfNeeded() async {
    if (widget.config.mode != FlunityWebGLMode.bundled) return;
    if (_bundledServer.isRunning()) {
      _bundledServerStarted = true;
      if (mounted) setState(() {});
      return;
    }
    try {
      await _bundledServer.start();
      _bundledServerStarted = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  WebUri _initialUri() {
    if (widget.config.mode == FlunityWebGLMode.dev) {
      final base = widget.config.resolveBaseUrl(platform: defaultTargetPlatform);
      return WebUri('${base}index.html');
    }
    // Bundled: InAppLocalhostServer's documentRoot is 'assets', so URLs are
    // relative to the Flutter assets root. Strip the leading 'assets/' from
    // the project-relative assetPath when building the URL.
    final urlPath = widget.config.assetPath.startsWith('assets/')
        ? widget.config.assetPath.substring('assets/'.length)
        : widget.config.assetPath;
    return WebUri('http://localhost:8080/${urlPath}index.html');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final builder = widget.errorBuilder;
      return builder != null
          ? builder(context, _error!)
          : Center(child: Text('Flunity error: $_error'));
    }
    if (widget.config.mode == FlunityWebGLMode.bundled && !_bundledServerStarted) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: _initialUri()),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        useShouldInterceptAjaxRequest: false,
        transparentBackground: true,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (controller) {
        _transport.attach(controller);
      },
      onLoadStop: (controller, url) async {
        // Wait for window.flunity.ready() to be called by the JS shim.
        await controller.evaluateJavascript(source: '''
          if (window.flunity && window.flunity._isReady) {
            window.flutter_inappwebview.callHandler('flunity_ready');
          } else {
            (window.flunity ||= {})._notifyReady = function() {
              window.flutter_inappwebview.callHandler('flunity_ready');
            };
          }
        ''');
      },
    );
  }
}
