import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

/// Flutter → Unity: invoke a `[FlunityOutlet]` method on the Unity side.
///
/// [name] is `<ClassName>.<MethodName>` (or the explicit name passed to the
/// `[FlunityOutlet("custom.name")]` attribute). [target] is optional — when
/// set, the registry routes to the MonoBehaviour with the matching
/// `[FlunityIdentity]` (or Unity `InstanceID` fallback). [nonce] correlates
/// the [OutletReply] back to the awaiting [Future] on the Dart side.
@immutable
final class OutletCall extends FlunityMessage {
  const OutletCall({
    required this.name,
    required this.nonce,
    this.target,
    this.args,
  });

  static const String typeName = 'outlet_call';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic name = payload['name'];
      final dynamic nonce = payload['nonce'];
      if (name is! String) {
        throw const FormatException(
          'OutletCall payload requires string "name"',
        );
      }
      if (nonce is! String) {
        throw const FormatException(
          'OutletCall payload requires string "nonce"',
        );
      }
      final dynamic target = payload['target'];
      final dynamic args = payload['args'];
      return OutletCall(
        name: name,
        nonce: nonce,
        target: target is String ? target : null,
        args: args is Map ? args.cast<String, Object?>() : null,
      );
    });
  }

  final String name;
  final String nonce;
  final String? target;
  final Map<String, Object?>? args;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'name': name,
    'nonce': nonce,
    if (target != null) 'target': target,
    if (args != null) 'args': args,
  };

  @override
  bool operator ==(Object other) =>
      other is OutletCall &&
      other.name == name &&
      other.nonce == nonce &&
      other.target == target;

  @override
  int get hashCode => Object.hash('outlet_call', name, nonce, target);
}
