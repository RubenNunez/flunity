import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/outlet_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(OutletCall.register);

  test('serializes with required fields only', () {
    final call = const OutletCall(name: 'PetController.Feed', nonce: 'n1');
    expect(call.toJson(), {
      'type': 'outlet_call',
      'payload': {'name': 'PetController.Feed', 'nonce': 'n1'},
    });
  });

  test('serializes with optional target + args', () {
    final call = const OutletCall(
      name: 'Pet.Feed',
      nonce: 'n2',
      target: 'bunny',
      args: {'amount': 10},
    );
    expect(call.toJson(), {
      'type': 'outlet_call',
      'payload': {
        'name': 'Pet.Feed',
        'nonce': 'n2',
        'target': 'bunny',
        'args': {'amount': 10},
      },
    });
  });

  test('round-trips via fromJson', () {
    final restored =
        FlunityMessage.fromJson(
              const OutletCall(
                name: 'X',
                nonce: 'y',
                target: 'z',
                args: {'k': 'v'},
              ).toJson(),
            )
            as OutletCall;
    expect(restored.name, 'X');
    expect(restored.nonce, 'y');
    expect(restored.target, 'z');
    expect(restored.args, {'k': 'v'});
  });

  test('equality', () {
    expect(
      const OutletCall(name: 'a', nonce: 'b'),
      const OutletCall(name: 'a', nonce: 'b'),
    );
    expect(
      const OutletCall(name: 'a', nonce: 'b'),
      isNot(const OutletCall(name: 'a', nonce: 'c')),
    );
  });

  test('throws on missing name or nonce', () {
    expect(
      () => FlunityMessage.fromJson({
        'type': 'outlet_call',
        'payload': {'nonce': 'x'},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => FlunityMessage.fromJson({
        'type': 'outlet_call',
        'payload': {'name': 'X'},
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
