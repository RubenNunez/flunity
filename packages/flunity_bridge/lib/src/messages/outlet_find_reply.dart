import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

/// One row of an [OutletFindReply]: a Unity scene-graph reference to a
/// MonoBehaviour instance that exposes `[FlunityOutlet]` methods.
///
/// [id] is the `[FlunityIdentity]` value if set, otherwise Unity's
/// `InstanceID` formatted as a string. Either form is a valid `target` for
/// `flunity.invoke(..., target: id)`.
@immutable
class FlunityComponentRef {
  const FlunityComponentRef({
    required this.id,
    required this.name,
    required this.path,
  });

  factory FlunityComponentRef.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final path = json['path'];
    if (id is! String || name is! String || path is! String) {
      throw const FormatException(
        'FlunityComponentRef requires string id, name, path',
      );
    }
    return FlunityComponentRef(id: id, name: name, path: path);
  }

  final String id;
  final String name;
  final String path;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      other is FlunityComponentRef &&
      other.id == id &&
      other.name == name &&
      other.path == path;

  @override
  int get hashCode => Object.hash('flunity_component_ref', id, name, path);

  @override
  String toString() => 'FlunityComponentRef(id: $id, name: $name, path: $path)';
}

/// Unity → Flutter: response to an [OutletFind]. [components] is the
/// (possibly empty) list of matching MonoBehaviour instances.
@immutable
final class OutletFindReply extends FlunityMessage {
  const OutletFindReply({required this.nonce, required this.components});

  static const String typeName = 'outlet_find_reply';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic nonce = payload['nonce'];
      final dynamic raw = payload['components'];
      if (nonce is! String) {
        throw const FormatException(
          'OutletFindReply payload requires string "nonce"',
        );
      }
      if (raw is! List) {
        throw const FormatException(
          'OutletFindReply payload requires array "components"',
        );
      }
      final list = raw
          .whereType<Map<Object?, Object?>>()
          .map((e) => FlunityComponentRef.fromJson(e.cast<String, Object?>()))
          .toList(growable: false);
      return OutletFindReply(nonce: nonce, components: list);
    });
  }

  final String nonce;
  final List<FlunityComponentRef> components;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'nonce': nonce,
    'components': components.map((c) => c.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is OutletFindReply &&
      other.nonce == nonce &&
      _listEq(other.components, components);

  @override
  int get hashCode => Object.hash('outlet_find_reply', nonce, components);

  static bool _listEq(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
