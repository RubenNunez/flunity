import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/outlet_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(OutletReply.register);

  test('serializes a successful reply', () {
    const reply = OutletReply(nonce: 'n1', ok: true, value: 42);
    expect(reply.toJson(), {
      'type': 'outlet_reply',
      'payload': {'nonce': 'n1', 'ok': true, 'value': 42},
    });
  });

  test('serializes an error reply with both value:null and error', () {
    const reply = OutletReply(nonce: 'n2', ok: false, error: 'boom');
    expect(reply.toJson(), {
      'type': 'outlet_reply',
      'payload': {'nonce': 'n2', 'ok': false, 'value': null, 'error': 'boom'},
    });
  });

  test('round-trips with complex value', () {
    final restored =
        FlunityMessage.fromJson(
              const OutletReply(
                nonce: 'n3',
                ok: true,
                value: {'hp': 100, 'name': 'Bunny'},
              ).toJson(),
            )
            as OutletReply;
    expect(restored.ok, isTrue);
    expect(restored.value, {'hp': 100, 'name': 'Bunny'});
  });

  test('throws on missing required fields', () {
    expect(
      () => FlunityMessage.fromJson({
        'type': 'outlet_reply',
        'payload': {'ok': true},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => FlunityMessage.fromJson({
        'type': 'outlet_reply',
        'payload': {'nonce': 'x'},
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
