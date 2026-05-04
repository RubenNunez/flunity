import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/built_in.dart';
import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flunity_bridge/src/messages/scene_ready.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawMessage', () {
    test('serializes to {type, payload} envelope', () {
      const msg = RawMessage(type: 'custom', payload: {'a': 1});
      expect(msg.toJson(), {
        'type': 'custom',
        'payload': {'a': 1}
      });
    });

    test('round-trips via fromJson', () {
      const original = RawMessage(type: 'custom', payload: {'a': 1});
      final restored = FlunityMessage.fromJson(original.toJson());
      expect(restored, isA<RawMessage>());
      final raw = restored as RawMessage;
      expect(raw.type, 'custom');
      expect(raw.payload, {'a': 1});
    });

    test('fromJson throws FormatException when type is missing', () {
      expect(
        () => FlunityMessage.fromJson({'payload': {}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson tolerates missing payload as empty map', () {
      final msg = FlunityMessage.fromJson({'type': 'noop'}) as RawMessage;
      expect(msg.payload, <String, Object?>{});
    });
  });

  group('built-in registration', () {
    setUp(registerBuiltInMessages);

    test('Ping/Pong/LoadScene/SceneReady all parse via fromJson', () {
      expect(FlunityMessage.fromJson(const Ping(nonce: 'a').toJson()),
          isA<Ping>());
      expect(FlunityMessage.fromJson(const Pong(nonce: 'a').toJson()),
          isA<Pong>());
      expect(FlunityMessage.fromJson(const LoadScene(scene: 's').toJson()),
          isA<LoadScene>());
      expect(FlunityMessage.fromJson(const SceneReady().toJson()),
          isA<SceneReady>());
    });

    test('unknown type still falls back to RawMessage', () {
      final msg = FlunityMessage.fromJson({'type': 'who_dis', 'payload': {}});
      expect(msg, isA<RawMessage>());
    });
  });
}
