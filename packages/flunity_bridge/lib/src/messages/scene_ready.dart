import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:meta/meta.dart';

@immutable
final class SceneReady extends FlunityMessage {
  const SceneReady();

  static const String typeName = 'scene_ready';

  static void register() {
    FlunityMessage.registerType(typeName, (_) => const SceneReady());
  }

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is SceneReady;

  @override
  int get hashCode => 'scene_ready'.hashCode;
}
