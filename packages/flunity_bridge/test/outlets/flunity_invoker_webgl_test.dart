import 'dart:convert';

import 'package:flunity_bridge/src/outlets/flunity_invoker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../transport/fake_transport.dart';

/// Pumps the microtask queue so `invoke`'s `await _sendEnvelope(...)` runs and
/// the outbound JSON lands in the fake before we assert / reply.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

Map<String, Object?> _payloadOf(String sentJson) {
  final envelope = jsonDecode(sentJson) as Map<String, Object?>;
  return (envelope['payload'] as Map).cast<String, Object?>();
}

void main() {
  // The invoker logs via `flunityLogs`, which lazily constructs
  // UnityMessageListeners and calls MethodChannel.setMethodCallHandler — that
  // asserts an initialized binding. Plain `test()` (unlike `testWidgets`) does
  // not auto-initialize one, so do it here.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invoke routes an outlet_call through the transport and resolves on reply',
      () async {
    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);

    final future = invoker.invoke<String>('Greeter.Greet', args: {'name': 'Ruben'});
    await _settle();

    expect(fake.sentMessages, hasLength(1));
    final envelope = jsonDecode(fake.sentMessages.single) as Map<String, Object?>;
    expect(envelope['type'], 'outlet_call');
    final payload = _payloadOf(fake.sentMessages.single);
    expect(payload['name'], 'Greeter.Greet');
    expect(payload['args'], {'name': 'Ruben'});
    final nonce = payload['nonce'] as String;

    fake.pushFromUnity(jsonEncode({
      'type': 'outlet_reply',
      'payload': {'nonce': nonce, 'ok': true, 'value': 'Hello, Ruben!'},
    }));

    expect(await future, 'Hello, Ruben!');
  });
}
