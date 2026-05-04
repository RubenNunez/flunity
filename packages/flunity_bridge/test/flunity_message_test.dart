import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawMessage', () {
    test('serializes to {type, payload} envelope', () {
      const msg = RawMessage(type: 'custom', payload: {'a': 1});
      expect(msg.toJson(), {'type': 'custom', 'payload': {'a': 1}});
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
}
