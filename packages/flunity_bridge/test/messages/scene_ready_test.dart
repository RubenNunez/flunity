import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/scene_ready.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(SceneReady.register);

  test('serializes to {type: "scene_ready", payload: {}}', () {
    expect(const SceneReady().toJson(), {
      'type': 'scene_ready',
      'payload': <String, Object?>{},
    });
  });

  test('round-trips via fromJson', () {
    final restored = FlunityMessage.fromJson(const SceneReady().toJson());
    expect(restored, isA<SceneReady>());
  });

  test('all SceneReady instances are equal', () {
    expect(const SceneReady(), const SceneReady());
    expect(const SceneReady().hashCode, const SceneReady().hashCode);
  });
}
