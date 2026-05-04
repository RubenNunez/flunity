import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class Pong extends FlunityMessage {
  const Pong({required this.nonce});

  static const String typeName = 'pong';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic n = payload['nonce'];
      if (n is! String) {
        throw const FormatException('Pong payload requires string "nonce"');
      }
      return Pong(nonce: n);
    });
  }

  final String nonce;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'nonce': nonce};

  @override
  bool operator ==(Object other) => other is Pong && other.nonce == nonce;

  @override
  int get hashCode => Object.hash('pong', nonce);
}
