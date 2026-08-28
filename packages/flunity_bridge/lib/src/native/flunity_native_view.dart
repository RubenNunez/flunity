// Adapted from flutter_embed_unity/lib/src/embed_unity.dart in
// flutter_embed_unity v2.0.0 (MIT, learntoflutter). Class renamed from
// EmbedUnity → FlunityNativeView; viewType uses NativeConstants.channelName.
// See packages/flunity_bridge/THIRDPARTY.md for full attribution.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

import 'native_constants.dart';
import 'unity_message_listener.dart';
import 'unity_message_listeners.dart';

/// Embeds a native (iOS / Android) Unity instance into a Flutter app.
///
/// One Unity instance per process is a hard constraint of Unity-as-a-library;
/// mounting multiple [FlunityNativeView] widgets shares the single instance.
/// Use Flunity's `UnitySceneRoute` (or send `LoadScene` messages directly)
/// to swap what the shared instance shows per Flutter route.
///
/// Native targets only — throws [UnsupportedError] on web / desktop. Use
/// `FlunityWebGLView` for the web target instead, or the target-aware
/// `FlunityView` composite.
class FlunityNativeView extends StatefulWidget {
  /// Called whenever Unity emits a message via `SendToFlutter.cs`.
  /// The string is the raw payload passed through Unity's bridge — by
  /// convention a JSON envelope `{"type": ..., "payload": ...}` matching the
  /// rest of Flunity, but the widget itself is payload-agnostic.
  final ValueChanged<String>? onMessageFromUnity;

  const FlunityNativeView({this.onMessageFromUnity, super.key});

  @override
  State<FlunityNativeView> createState() => _FlunityNativeViewState();
}

class _FlunityNativeViewState extends State<FlunityNativeView>
    implements UnityMessageListener {
  @override
  void initState() {
    UnityMessageListeners.instance.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    UnityMessageListeners.instance.removeListener(this);
    super.dispose();
  }

  @override
  void onMessageFromUnity(String data) {
    widget.onMessageFromUnity?.call(data);
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Hybrid Composition, not a plain AndroidView: Unity draws into a
        // SurfaceView, and for that AndroidView falls back to Virtual Display
        // mode — Unity renders off-screen, gets copied into a texture and
        // composited late (measured ~26 fps on a Nothing Phone (1) while Unity
        // itself ran at 60). With initExpensiveAndroidView the SurfaceView
        // reaches the screen directly and Flutter composites on top.
        return PlatformViewLink(
          viewType: NativeConstants.channelName,
          surfaceFactory: (context, controller) => AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          ),
          onCreatePlatformView: (params) =>
              PlatformViewsService.initExpensiveAndroidView(
                  id: params.id,
                  viewType: NativeConstants.channelName,
                  layoutDirection: TextDirection.ltr,
                  creationParamsCodec: const StandardMessageCodec(),
                  onFocus: () => params.onFocusChanged(true),
                )
                ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
                ..create(),
        );
      case TargetPlatform.iOS:
        return const UiKitView(viewType: NativeConstants.channelName);
      default:
        throw UnsupportedError(
          'FlunityNativeView is only supported on Android and iOS '
          '(got: $defaultTargetPlatform). Use FlunityWebGLView for web, '
          'or wrap them with FlunityView for target-aware mounting.',
        );
    }
  }
}
