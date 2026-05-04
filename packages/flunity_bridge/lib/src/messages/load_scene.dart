import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class LoadScene extends FlunityMessage {
  const LoadScene({required this.scene});

  static const String typeName = 'load_scene';

  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final dynamic s = payload['scene'];
      if (s is! String) {
        throw const FormatException('LoadScene payload requires string "scene"');
      }
      return LoadScene(scene: s);
    });
  }

  final String scene;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'scene': scene};

  @override
  bool operator ==(Object other) => other is LoadScene && other.scene == scene;

  @override
  int get hashCode => Object.hash('load_scene', scene);
}
