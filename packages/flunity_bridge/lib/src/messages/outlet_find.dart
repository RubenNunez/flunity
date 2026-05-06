import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

/// Flutter → Unity: list every loaded MonoBehaviour whose class name matches
/// [component] and which has at least one `[FlunityOutlet]` method. Reply
/// is an [OutletFindReply] correlated by [nonce].
@immutable
final class OutletFind extends FlunityMessage {
  const OutletFind({required this.nonce, required this.component});

  static const String typeName = 'outlet_find';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic nonce = payload['nonce'];
      final dynamic component = payload['component'];
      if (nonce is! String) {
        throw const FormatException(
          'OutletFind payload requires string "nonce"',
        );
      }
      if (component is! String) {
        throw const FormatException(
          'OutletFind payload requires string "component"',
        );
      }
      return OutletFind(nonce: nonce, component: component);
    });
  }

  final String nonce;
  final String component;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'nonce': nonce,
    'component': component,
  };

  @override
  bool operator ==(Object other) =>
      other is OutletFind &&
      other.nonce == nonce &&
      other.component == component;

  @override
  int get hashCode => Object.hash('outlet_find', nonce, component);
}
