import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class Ping extends FlunityMessage {
  const Ping({required this.nonce});

  static const String typeName = 'ping';

  /// Registers `Ping` with [FlunityMessage]'s parser. Idempotent.
  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic n = payload['nonce'];
      if (n is! String) {
        throw const FormatException('Ping payload requires string "nonce"');
      }
      return Ping(nonce: n);
    });
  }

  final String nonce;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'nonce': nonce};

  @override
  bool operator ==(Object other) => other is Ping && other.nonce == nonce;

  @override
  int get hashCode => Object.hash('ping', nonce);
}
