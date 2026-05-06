import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/messages/outlet_find.dart';
import 'package:flunity_bridge/src/messages/outlet_find_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    OutletFind.register();
    OutletFindReply.register();
  });

  test('OutletFind serializes', () {
    expect(const OutletFind(nonce: 'n1', component: 'Pet').toJson(), {
      'type': 'outlet_find',
      'payload': {'nonce': 'n1', 'component': 'Pet'},
    });
  });

  test('OutletFindReply serializes empty list', () {
    expect(const OutletFindReply(nonce: 'n1', components: []).toJson(), {
      'type': 'outlet_find_reply',
      'payload': {'nonce': 'n1', 'components': <dynamic>[]},
    });
  });

  test('OutletFindReply round-trips two components', () {
    final reply = OutletFindReply(
      nonce: 'n1',
      components: [
        const FlunityComponentRef(
          id: 'bunny',
          name: 'Pet',
          path: 'Forest/Trees/Pet',
        ),
        const FlunityComponentRef(
          id: '12345',
          name: 'Pet',
          path: 'Forest/Trees/Pet (1)',
        ),
      ],
    );
    final restored = FlunityMessage.fromJson(reply.toJson()) as OutletFindReply;
    expect(restored.components.length, 2);
    expect(restored.components[0].id, 'bunny');
    expect(restored.components[0].name, 'Pet');
    expect(restored.components[0].path, 'Forest/Trees/Pet');
    expect(restored.components[1].id, '12345');
  });

  test('FlunityComponentRef.fromJson rejects missing fields', () {
    expect(
      () => FlunityComponentRef.fromJson({'id': 'x', 'name': 'Pet'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('OutletFind throws on missing component', () {
    expect(
      () => FlunityMessage.fromJson({
        'type': 'outlet_find',
        'payload': {'nonce': 'x'},
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
