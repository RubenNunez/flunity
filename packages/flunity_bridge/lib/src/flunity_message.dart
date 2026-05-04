import 'package:meta/meta.dart';

/// Wire-format envelope used by every Flunity message: `{"type": ..., "payload": ...}`.
@immutable
abstract class FlunityMessage {
  const FlunityMessage();

  String get type;
  Map<String, Object?> get payload;

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'payload': payload,
      };

  /// Parses a JSON map into a typed [FlunityMessage]. Unknown `type`s fall back
  /// to [RawMessage] so future Unity-side message types don't break consumers.
  static FlunityMessage fromJson(Map<String, Object?> json) {
    final dynamic rawType = json['type'];
    if (rawType is! String) {
      throw const FormatException('FlunityMessage requires a string "type" field');
    }
    final Map<String, Object?> payload = switch (json['payload']) {
      final Map<String, Object?> map => map,
      final Map<dynamic, dynamic> map => map.cast<String, Object?>(),
      null => const <String, Object?>{},
      _ => throw const FormatException('FlunityMessage "payload" must be a JSON object'),
    };
    final factory = _registry[rawType];
    if (factory != null) {
      return factory(payload);
    }
    return RawMessage(type: rawType, payload: payload);
  }

  static final Map<String, FlunityMessage Function(Map<String, Object?>)> _registry =
      <String, FlunityMessage Function(Map<String, Object?>)>{};

  /// Registers a factory for a typed message subclass. Used by built-in message
  /// classes; callers can register their own types too (overrides allowed).
  static void registerType(
    String type,
    FlunityMessage Function(Map<String, Object?> payload) factory,
  ) {
    _registry[type] = factory;
  }
}

/// Escape hatch for messages whose dart type isn't known to this package.
final class RawMessage extends FlunityMessage {
  const RawMessage({required this.type, required this.payload});

  @override
  final String type;

  @override
  final Map<String, Object?> payload;

  @override
  bool operator ==(Object other) =>
      other is RawMessage &&
      other.type == type &&
      _mapEquals(other.payload, payload);

  @override
  int get hashCode => Object.hash(type, _mapHash(payload));
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash(Map<String, Object?> map) =>
    Object.hashAllUnordered(map.entries.map((e) => Object.hash(e.key, e.value)));
