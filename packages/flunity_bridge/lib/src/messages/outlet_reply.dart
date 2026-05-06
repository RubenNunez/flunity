import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

/// Unity → Flutter: reply to an [OutletCall], correlated by [nonce].
///
/// On success, [ok] is true and [value] holds the C# return value (already
/// JSON-deserialized; `void` returns produce `null`). On failure, [ok] is
/// false and [error] holds the C# exception message — the Dart side rejects
/// the awaiting [Future] with a `FlunityOutletException`.
@immutable
final class OutletReply extends FlunityMessage {
  const OutletReply({
    required this.nonce,
    required this.ok,
    this.value,
    this.error,
  });

  static const String typeName = 'outlet_reply';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic nonce = payload['nonce'];
      final dynamic ok = payload['ok'];
      if (nonce is! String) {
        throw const FormatException(
          'OutletReply payload requires string "nonce"',
        );
      }
      if (ok is! bool) {
        throw const FormatException('OutletReply payload requires bool "ok"');
      }
      final dynamic err = payload['error'];
      return OutletReply(
        nonce: nonce,
        ok: ok,
        value: payload['value'],
        error: err is String ? err : null,
      );
    });
  }

  final String nonce;
  final bool ok;
  final Object? value;
  final String? error;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'nonce': nonce,
    'ok': ok,
    'value': value,
    if (error != null) 'error': error,
  };

  @override
  bool operator ==(Object other) =>
      other is OutletReply &&
      other.nonce == nonce &&
      other.ok == ok &&
      other.error == error;

  @override
  int get hashCode => Object.hash('outlet_reply', nonce, ok, error);
}
