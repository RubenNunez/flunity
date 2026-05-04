import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(LoadScene.register);

  test('serializes to {type: "load_scene", payload: {scene}}', () {
    expect(const LoadScene(scene: 'ProductViewer').toJson(), {
      'type': 'load_scene',
      'payload': {'scene': 'ProductViewer'},
    });
  });

  test('round-trips via fromJson', () {
    final restored = FlunityMessage.fromJson(
      const LoadScene(scene: 'X').toJson(),
    );
    expect((restored as LoadScene).scene, 'X');
  });

  test('equality', () {
    expect(const LoadScene(scene: 'a'), const LoadScene(scene: 'a'));
    expect(const LoadScene(scene: 'a'), isNot(const LoadScene(scene: 'b')));
  });

  test('throws on missing scene', () {
    expect(
      () => FlunityMessage.fromJson({'type': 'load_scene', 'payload': {}}),
      throwsA(isA<FormatException>()),
    );
  });
}
