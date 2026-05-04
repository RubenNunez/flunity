import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(Pong.register);

  test('Pong serializes to {type: "pong", payload: {nonce}}', () {
    expect(const Pong(nonce: 'abc').toJson(), {
      'type': 'pong',
      'payload': {'nonce': 'abc'},
    });
  });

  test('Pong round-trips via fromJson', () {
    final restored = FlunityMessage.fromJson(const Pong(nonce: 'abc').toJson());
    expect((restored as Pong).nonce, 'abc');
  });

  test('Pong equality', () {
    expect(const Pong(nonce: 'x'), const Pong(nonce: 'x'));
    expect(const Pong(nonce: 'x'), isNot(const Pong(nonce: 'y')));
  });

  test('Pong.fromJson throws on missing nonce', () {
    expect(
      () => FlunityMessage.fromJson({'type': 'pong', 'payload': {}}),
      throwsA(isA<FormatException>()),
    );
  });
}
