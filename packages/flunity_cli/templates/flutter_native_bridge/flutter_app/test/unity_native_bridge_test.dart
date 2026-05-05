import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(registerBuiltInMessages);

  test('Ping/Pong round-trip via JSON', () {
    final ping = const Ping(nonce: 'x');
    final pong = const Pong(nonce: 'x');
    final restoredPing = FlunityMessage.fromJson(ping.toJson());
    final restoredPong = FlunityMessage.fromJson(pong.toJson());
    expect(restoredPing, ping);
    expect(restoredPong, pong);
  });

  test('LoadScene round-trip via JSON', () {
    final msg = const LoadScene(scene: 'Main');
    final restored = FlunityMessage.fromJson(msg.toJson());
    expect(restored, msg);
  });
}
