import 'dart:async';
import 'dart:convert';

import 'package:flunity_bridge/src/native/unity_message_listeners.dart';
import 'package:flutter/foundation.dart';

/// Severity bucket. `info` covers `Debug.Log` and Flutter `print` /
/// `debugPrint`; `warn` covers `Debug.LogWarning`; `error` covers
/// `Debug.LogError`, `Debug.LogException`, and `Debug.LogAssert`.
enum FlunityLogLevel { info, warn, error }

/// Where the log line came from. The bottom-sheet UI in jellx (and other
/// consumers) renders these as filter chips so devs can scope to one
/// source while debugging.
enum FlunityLogSource { unity, flutter }

@immutable
class FlunityLogEntry {
  const FlunityLogEntry({
    required this.timestamp,
    required this.source,
    required this.level,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final FlunityLogSource source;
  final FlunityLogLevel level;
  final String message;
  final String? stackTrace;

  @override
  String toString() {
    final ts =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    final sourceTag = source == FlunityLogSource.unity ? 'U' : 'F';
    final levelTag = switch (level) {
      FlunityLogLevel.info => '·',
      FlunityLogLevel.warn => '!',
      FlunityLogLevel.error => '✗',
    };
    return '$ts $sourceTag$levelTag $message';
  }
}

/// In-memory ring buffer of [FlunityLogEntry]s. Singleton, exposed via
/// [flunityLogs]. Subscribes to Unity's `flunity_log` messages on
/// construction and intercepts Flutter's `debugPrint` so both streams
/// land in the same buffer.
class FlunityLogStream {
  FlunityLogStream._() {
    _attachUnityListener();
    _attachFlutterListener();
  }

  static final FlunityLogStream _instance = FlunityLogStream._();
  static FlunityLogStream get instance => _instance;

  static const int defaultMaxEntries = 500;

  /// Maximum entries to retain. Older entries are dropped FIFO when the
  /// buffer overflows. Tune via [setMaxEntries] before/while logging.
  int _maxEntries = defaultMaxEntries;
  int get maxEntries => _maxEntries;
  void setMaxEntries(int value) {
    _maxEntries = value;
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    _changes.add(null);
  }

  final List<FlunityLogEntry> _entries = <FlunityLogEntry>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Snapshot of all retained entries, oldest first.
  List<FlunityLogEntry> get entries =>
      List<FlunityLogEntry>.unmodifiable(_entries);

  /// Fires (with no payload) any time [entries] changes — UI listeners
  /// rebuild from the snapshot. The void payload is intentional: the UI
  /// shouldn't need to track individual additions, just "something
  /// changed, re-read entries."
  Stream<void> get changes => _changes.stream;

  /// Manually push a Flutter-side entry. The default `debugPrint` hook
  /// captures most cases automatically, but call this if you want to log
  /// something that shouldn't go through `debugPrint`.
  void log(String message, {FlunityLogLevel level = FlunityLogLevel.info}) {
    _add(
      FlunityLogEntry(
        timestamp: DateTime.now(),
        source: FlunityLogSource.flutter,
        level: level,
        message: message,
      ),
    );
  }

  /// Drops every retained entry. UI consumers see [changes] fire with
  /// the cleared state.
  void clear() {
    _entries.clear();
    _changes.add(null);
  }

  // ---------- internal ----------

  void _add(FlunityLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  void _attachUnityListener() {
    UnityMessageListeners.instance.addAlwaysListener(_onUnityMessage);
  }

  void _onUnityMessage(String raw) {
    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) json = decoded.cast<String, Object?>();
    } catch (_) {
      return;
    }
    if (json == null) return;
    if (json['type'] != 'flunity_log') return;
    final payload = json['payload'];
    if (payload is! Map) return;
    final p = payload.cast<String, Object?>();
    final levelStr = p['level'] as String? ?? 'info';
    final message = p['message'] as String? ?? '';
    final stackTrace = p['stackTrace'] as String?;
    _add(
      FlunityLogEntry(
        timestamp: DateTime.now(),
        source: FlunityLogSource.unity,
        level: switch (levelStr) {
          'warn' => FlunityLogLevel.warn,
          'error' => FlunityLogLevel.error,
          _ => FlunityLogLevel.info,
        },
        message: message,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Wraps Flutter's `debugPrint` so app + framework log lines also land
  /// in the buffer. Idempotent — a second install no-ops via the
  /// `_originalDebugPrint` guard.
  void _attachFlutterListener() {
    if (_originalDebugPrint != null) return;
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        _add(
          FlunityLogEntry(
            timestamp: DateTime.now(),
            source: FlunityLogSource.flutter,
            level: FlunityLogLevel.info,
            message: message,
          ),
        );
      }
      _originalDebugPrint!(message, wrapWidth: wrapWidth);
    };
  }

  DebugPrintCallback? _originalDebugPrint;
}

/// Process-wide singleton. Lazily initialized on first access — that's
/// when the Unity bridge listener and `debugPrint` hook are wired.
final FlunityLogStream flunityLogs = FlunityLogStream.instance;
