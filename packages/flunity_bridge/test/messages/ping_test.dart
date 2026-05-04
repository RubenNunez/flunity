import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(Ping.register);

  test('Ping serializes to {type: "ping", payload: {nonce}}', () {
    const msg = Ping(nonce: 'abc');
    expect(msg.toJson(), {
      'type': 'ping',
      'payload': {'nonce': 'abc'},
    });
  });

  test('Ping round-trips via FlunityMessage.fromJson', () {
    final restored = FlunityMessage.fromJson(const Ping(nonce: 'abc').toJson());
    expect(restored, isA<Ping>());
    expect((restored as Ping).nonce, 'abc');
  });

  test('Ping equality + hashCode', () {
    expect(const Ping(nonce: 'x'), const Ping(nonce: 'x'));
    expect(const Ping(nonce: 'x').hashCode, const Ping(nonce: 'x').hashCode);
    expect(const Ping(nonce: 'x'), isNot(const Ping(nonce: 'y')));
  });

  test('Ping.fromJson throws on missing nonce', () {
    expect(
      () => FlunityMessage.fromJson({'type': 'ping', 'payload': {}}),
      throwsA(isA<FormatException>()),
    );
  });
}
