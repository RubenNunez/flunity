import 'dart:async';
import 'dart:convert';

import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/logging/flunity_log_stream.dart';
import 'package:flunity_bridge/src/messages/outlet_call.dart';
import 'package:flunity_bridge/src/messages/outlet_find.dart';
import 'package:flunity_bridge/src/messages/outlet_find_reply.dart';
import 'package:flunity_bridge/src/messages/outlet_reply.dart';
import 'package:flunity_bridge/src/native/native_api.dart' as native;
import 'package:flunity_bridge/src/native/unity_message_listeners.dart';
import 'package:flunity_bridge/src/transport/message_transport.dart';
import 'package:flutter/foundation.dart';

/// Thrown when an outlet call fails on the Unity side. [unityMessage] is the
/// C# exception or registry error verbatim.
class FlunityOutletException implements Exception {
  FlunityOutletException(this.unityMessage);
  final String unityMessage;
  @override
  String toString() => 'FlunityOutletException: $unityMessage';
}

/// Thrown when an outlet call times out before Unity replies. Default
/// timeout is 5s; override per-call via `flunity.invoke(..., timeout:)`.
class FlunityOutletTimeoutException implements Exception {
  FlunityOutletTimeoutException(this.name, this.timeout);
  final String name;
  final Duration timeout;
  @override
  String toString() =>
      'FlunityOutletTimeoutException: $name did not reply within $timeout';
}

/// Thrown when [FlunityInvoker] is used with no Unity transport available:
/// on WebGL before a [FlunityWebGLController] (view) is mounted, or on an
/// unsupported platform (desktop / web without Unity).
class FlunityNotAttachedException implements Exception {
  @override
  String toString() =>
      'FlunityNotAttachedException: no Unity bridge is attached. On WebGL, '
      'mount a FlunityWebGLView (or UnitySceneRoute) before calling outlets; '
      'on iOS / Android the native bridge attaches automatically. Outlets are '
      'unavailable on desktop / web targets without a Unity view.';
}

/// Reference to a Unity MonoBehaviour instance returned by [FlunityInvoker.find].
///
/// `ref.invoke(...)` is sugar for `flunity.invoke('<class>.<method>',
/// target: ref.id, args: ...)`. The [id] is the `[FlunityIdentity]` value if
/// one was set, otherwise Unity's `InstanceID` formatted as a string.
class FlunityComponentHandle {
  FlunityComponentHandle._({
    required this.id,
    required this.name,
    required this.path,
    required FlunityInvoker invoker,
  }) : _invoker = invoker;

  final String id;
  final String name;
  final String path;
  final FlunityInvoker _invoker;

  Future<T?> invoke<T>(
    String method, {
    Map<String, Object?>? args,
    Duration timeout = FlunityInvoker.defaultTimeout,
  }) {
    return _invoker.invoke<T>(
      '$name.$method',
      target: id,
      args: args,
      timeout: timeout,
    );
  }

  @override
  String toString() =>
      'FlunityComponentHandle(id: $id, name: $name, path: $path)';
}

/// Singleton entry point for outlet invocation + scene discovery.
///
/// Use the package-level [flunity] global rather than constructing
/// [FlunityInvoker] yourself — outbound transport state and the inbound
/// reply listener are wired once at construction time.
class FlunityInvoker {
  FlunityInvoker._({bool attachNativeListener = true}) {
    // Register the typed reply factories the invoker depends on. Doing this
    // here (rather than relying on the consumer's main() to call
    // registerBuiltInMessages) means `flunity.invoke(...)` works out of the
    // box — without it, FlunityMessage.fromJson silently downgrades replies
    // to RawMessage and every call times out. Idempotent.
    OutletReply.register();
    OutletFindReply.register();
    if (attachNativeListener) {
      UnityMessageListeners.instance.addAlwaysListener(_onMessage);
    }
  }

  /// Builds an invoker with the native MethodChannel listener detached, so
  /// tests can drive it purely through an attached [MessageTransport] without
  /// touching platform channels.
  @visibleForTesting
  factory FlunityInvoker.forTest() =>
      FlunityInvoker._(attachNativeListener: false);

  /// 5 seconds. Override per call via the `timeout` parameter on [invoke] /
  /// [find] when you expect long-running Unity work.
  static const Duration defaultTimeout = Duration(seconds: 5);

  /// Conventional GameObject name the Unity-side `FlunityBridgeBehaviour`
  /// listens on. Mirrors the constant baked into the templates' Unity
  /// scripts; if you renamed it on the Unity side, you'll need to keep
  /// these aligned.
  static const String _bridgeGameObject = '[FlunityBridge]';
  static const String _bridgeMethod = 'ReceiveFromFlutter';

  final Map<String, _PendingCall> _pending = <String, _PendingCall>{};
  int _nonceCounter = 0;

  MessageTransport? _webTransport;
  StreamSubscription<String>? _webSub;

  /// Bind a WebGL [MessageTransport] so `invoke`/`find` route over it.
  ///
  /// Called automatically by [FlunityWebGLController]; you rarely call this
  /// directly. A single transport is active at a time (matching the
  /// one-Unity-instance assumption of the native path) — attaching a new one
  /// replaces and tears down the previous binding.
  void attachWebTransport(MessageTransport transport) {
    if (identical(_webTransport, transport)) return;
    _webSub?.cancel();
    _webTransport = transport;
    _webSub = transport.incoming.listen(_onMessage);
  }

  /// Unbind [transport] if it is the currently-attached one; otherwise a no-op.
  /// Called automatically by [FlunityWebGLController.dispose].
  void detachWebTransport(MessageTransport transport) {
    if (!identical(_webTransport, transport)) return;
    _webSub?.cancel();
    _webSub = null;
    _webTransport = null;
  }

  /// Send an outlet invocation to Unity and await its reply.
  ///
  /// [name] is `<ClassName>.<MethodName>` (or the explicit name passed to
  /// `[FlunityOutlet("custom.name")]`). [target] disambiguates between
  /// multiple instances exposing the same outlet (matched against the
  /// `[FlunityIdentity]` value or the `InstanceID` fallback).
  ///
  /// Returns the Unity-side return value, JSON-deserialized. `void` C#
  /// methods produce `null`. Complex types come back as `Map<String,
  /// dynamic>` — map them to your own model in the call site.
  Future<T?> invoke<T>(
    String name, {
    String? target,
    Map<String, Object?>? args,
    Duration timeout = defaultTimeout,
  }) async {
    _ensureAvailable();
    final nonce = _nextNonce();
    final completer = Completer<Object?>();
    _pending[nonce] = _PendingCall(completer: completer);

    final call = OutletCall(
      name: name,
      nonce: nonce,
      target: target,
      args: args,
    );
    flunityLogs.log(_formatOutletCall(call), level: FlunityLogLevel.info);
    try {
      await _sendEnvelope(call);
    } catch (e) {
      _pending.remove(nonce)?.cancelTimer();
      flunityLogs.log(
        '← outlet_call $name (nonce $nonce) send failed: $e',
        level: FlunityLogLevel.error,
      );
      rethrow;
    }
    _armTimeout(nonce, name, timeout);

    try {
      final result = await completer.future;
      flunityLogs.log(
        '→ outlet_reply $name (nonce $nonce) ok value=${_truncate(result)}',
        level: FlunityLogLevel.info,
      );
      return result as T?;
    } on FlunityOutletException catch (e) {
      flunityLogs.log(
        '→ outlet_reply $name (nonce $nonce) error: ${e.unityMessage}',
        level: FlunityLogLevel.error,
      );
      rethrow;
    } on FlunityOutletTimeoutException {
      flunityLogs.log(
        '→ outlet_reply $name (nonce $nonce) TIMEOUT after $timeout',
        level: FlunityLogLevel.warn,
      );
      rethrow;
    } on TypeError catch (e) {
      throw FlunityOutletException(
        'outlet "$name" returned a value that does not match expected type '
        '$T: $e',
      );
    }
  }

  /// Starts the reply clock for [nonce].
  ///
  /// Deliberately called only after the transport reports the envelope
  /// delivered. The WebGL transport parks sends until Unity's JS shim is
  /// ready, so arming at call time charged the caller's budget for Unity's
  /// boot — a call issued on the first frame always expired, and the genuine
  /// reply then arrived with no pending entry to match.
  ///
  /// A no-op if the call has already been answered.
  void _armTimeout(String nonce, String label, Duration timeout) {
    final pending = _pending[nonce];
    if (pending == null) return;
    pending.timer = Timer(timeout, () {
      final entry = _pending.remove(nonce);
      if (entry != null && !entry.completer.isCompleted) {
        entry.completer.completeError(
          FlunityOutletTimeoutException(label, timeout),
        );
      }
    });
  }

  static String _formatOutletCall(OutletCall c) {
    final argSummary = c.args == null || c.args!.isEmpty ? '' : ' ${c.args}';
    final tgt = c.target == null ? '' : ' target=${c.target}';
    return '← outlet_call ${c.name}$tgt (nonce ${c.nonce})$argSummary';
  }

  static String _truncate(Object? value, {int max = 80}) {
    if (value == null) return 'null';
    final s = value.toString();
    return s.length <= max ? s : '${s.substring(0, max)}…';
  }

  /// Query Unity for every loaded MonoBehaviour whose class is named
  /// [componentName] and which has at least one `[FlunityOutlet]` method.
  Future<List<FlunityComponentHandle>> find(
    String componentName, {
    Duration timeout = defaultTimeout,
  }) async {
    _ensureAvailable();
    final nonce = _nextNonce();
    final completer = Completer<Object?>();
    _pending[nonce] = _PendingCall(completer: completer);

    final find = OutletFind(nonce: nonce, component: componentName);
    flunityLogs.log(
      '← outlet_find $componentName (nonce $nonce)',
      level: FlunityLogLevel.info,
    );
    try {
      await _sendEnvelope(find);
    } catch (e) {
      _pending.remove(nonce)?.cancelTimer();
      flunityLogs.log(
        '← outlet_find $componentName (nonce $nonce) send failed: $e',
        level: FlunityLogLevel.error,
      );
      rethrow;
    }
    _armTimeout(nonce, 'find($componentName)', timeout);

    final raw = await completer.future;
    if (raw is List<FlunityComponentRef>) {
      flunityLogs.log(
        '→ outlet_find_reply $componentName (nonce $nonce) → ${raw.length} matches',
        level: FlunityLogLevel.info,
      );
    }
    if (raw is! List<FlunityComponentRef>) {
      throw FlunityOutletException(
        'find($componentName) returned non-list payload: $raw',
      );
    }
    return raw
        .map(
          (ref) => FlunityComponentHandle._(
            id: ref.id,
            name: ref.name,
            path: ref.path,
            invoker: this,
          ),
        )
        .toList(growable: false);
  }

  void _onMessage(String raw) {
    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) json = decoded.cast<String, Object?>();
    } catch (e) {
      flunityLogs.log(
        'outlet_reply rx: jsonDecode failed: $e',
        level: FlunityLogLevel.error,
      );
      return;
    }
    if (json == null) return;

    final type = json['type'];
    if (type != OutletReply.typeName && type != OutletFindReply.typeName) {
      return;
    }

    final FlunityMessage parsed;
    try {
      parsed = FlunityMessage.fromJson(json);
    } catch (e) {
      flunityLogs.log(
        'outlet_reply rx: fromJson failed: $e',
        level: FlunityLogLevel.error,
      );
      return;
    }

    if (parsed is OutletReply) {
      final pending = _pending.remove(parsed.nonce);
      if (pending == null) {
        flunityLogs.log(
          'outlet_reply rx: no pending for nonce=${parsed.nonce}',
          level: FlunityLogLevel.warn,
        );
        return;
      }
      pending.cancelTimer();
      if (parsed.ok) {
        pending.completer.complete(parsed.value);
      } else {
        pending.completer.completeError(
          FlunityOutletException(parsed.error ?? 'outlet failed'),
        );
      }
    } else if (parsed is OutletFindReply) {
      final pending = _pending.remove(parsed.nonce);
      if (pending == null) return;
      pending.cancelTimer();
      pending.completer.complete(parsed.components);
    }
  }

  Future<void> _sendEnvelope(FlunityMessage message) {
    final json = jsonEncode(message.toJson());
    final web = _webTransport;
    if (web != null) {
      return web.send(json);
    }
    return native.sendToUnity(_bridgeGameObject, _bridgeMethod, json);
  }

  void _ensureAvailable() {
    if (_webTransport != null) return;
    if (kIsWeb) throw FlunityNotAttachedException();
    final p = defaultTargetPlatform;
    if (p != TargetPlatform.iOS && p != TargetPlatform.android) {
      throw FlunityNotAttachedException();
    }
  }

  String _nextNonce() {
    _nonceCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_nonceCounter';
  }
}

class _PendingCall {
  _PendingCall({required this.completer});
  final Completer<Object?> completer;

  /// Armed once the transport reports the call delivered — see
  /// [FlunityInvoker.invoke]. Null while the call is still on its way out.
  Timer? timer;

  void cancelTimer() => timer?.cancel();
}

/// Process-wide [FlunityInvoker] singleton. Use this rather than
/// constructing [FlunityInvoker] directly.
final FlunityInvoker flunity = FlunityInvoker._();
