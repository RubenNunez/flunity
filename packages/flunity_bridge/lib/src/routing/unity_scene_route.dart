import 'dart:async';
import 'dart:convert';

import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flunity_bridge/src/native/native_api.dart' as native;
import 'package:flutter/widgets.dart';

/// Route-scoped helper that loads a Unity scene when its subtree mounts and
/// (optionally) restores a previous scene when it unmounts. Useful for
/// "one Unity instance, many Flutter routes" — mount [FlunityNativeView]
/// or [FlunityWebGLView] once at the app shell, then wrap each route's
/// content in `UnitySceneRoute(scene: 'menu', send: ...)`.
///
/// The widget is transport-agnostic: it only needs a `send(FlunityMessage)`
/// callback. For convenience, [UnitySceneRoute.native] wires that to the
/// top-level [native.sendToUnity] helper and the canonical `[FlunityBridge]`
/// GameObject. If you're on WebGL or a custom transport, pass [send]
/// directly so the route can route through your own controller.
class UnitySceneRoute extends StatefulWidget {
  const UnitySceneRoute({
    required this.scene,
    required this.send,
    required this.child,
    this.previousScene,
    super.key,
  });

  /// Native (iOS/Android) shortcut: dispatch through `sendToUnity` with the
  /// canonical `[FlunityBridge]` GameObject + `ReceiveFromFlutter` method
  /// that ships in our templates.
  factory UnitySceneRoute.native({
    Key? key,
    required String scene,
    required Widget child,
    String? previousScene,
  }) {
    return UnitySceneRoute(
      key: key,
      scene: scene,
      previousScene: previousScene,
      send: _sendNative,
      child: child,
    );
  }

  final String scene;
  final String? previousScene;
  final Future<void> Function(FlunityMessage message) send;
  final Widget child;

  @override
  State<UnitySceneRoute> createState() => _UnitySceneRouteState();
}

class _UnitySceneRouteState extends State<UnitySceneRoute> {
  @override
  void initState() {
    super.initState();
    // Defer the send by a frame so route-transition animations don't block
    // on a Unity scene swap that might trigger asset loads.
    scheduleMicrotask(() {
      if (mounted) widget.send(LoadScene(scene: widget.scene));
    });
  }

  @override
  void didUpdateWidget(covariant UnitySceneRoute old) {
    super.didUpdateWidget(old);
    if (old.scene != widget.scene) {
      widget.send(LoadScene(scene: widget.scene));
    }
  }

  @override
  void dispose() {
    final restore = widget.previousScene;
    if (restore != null) {
      widget.send(LoadScene(scene: restore));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> _sendNative(FlunityMessage message) {
  return native.sendToUnity(
    '[FlunityBridge]',
    'ReceiveFromFlutter',
    jsonEncode(message.toJson()),
  );
}
