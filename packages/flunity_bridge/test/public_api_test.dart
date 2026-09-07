import 'package:flunity_bridge/flunity_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public API: registerBuiltInMessages enables typed parsing', () {
    registerBuiltInMessages();
    final restored = FlunityMessage.fromJson(const Ping(nonce: 'ok').toJson());
    expect(restored, isA<Ping>());
  });

  test('public API: the native view is exported', () {
    expect(FlunityNativeView, isNotNull);
  });
}
