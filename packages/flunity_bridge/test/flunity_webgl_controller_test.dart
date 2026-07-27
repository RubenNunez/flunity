import 'dart:convert';

import 'package:flunity_bridge/src/flunity_message.dart';
import 'package:flunity_bridge/src/flunity_webgl_controller.dart';
import 'package:flunity_bridge/src/messages/built_in.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flunity_bridge/src/outlets/flunity_invoker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transport/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(registerBuiltInMessages);

  test('send() before ready queues, then flushes once ready', () async {
    final transport = FakeMessageTransport(startReady: false);
    final controller = FlunityWebGLController(
      transport: transport,
      invoker: FlunityInvoker.forTest(),
    );

    final pending = controller.send(const Ping(nonce: 'q'));
    expect(transport.sentMessages, isEmpty);

    transport.markReady();
    await pending;

    expect(transport.sentMessages, hasLength(1));
    final decoded =
        jsonDecode(transport.sentMessages.first) as Map<String, Object?>;
    expect(decoded['type'], 'ping');
    expect(decoded['payload'], {'nonce': 'q'});
  });

  test('messages stream emits typed FlunityMessage values', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(
      transport: transport,
      invoker: FlunityInvoker.forTest(),
    );

    final received = <FlunityMessage>[];
    final sub = controller.messages.listen(received.add);

    transport.pushFromUnity(jsonEncode(const Pong(nonce: 'r').toJson()));
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received.single, isA<Pong>());
    expect((received.single as Pong).nonce, 'r');

    await sub.cancel();
    await controller.dispose();
  });

  test('messages stream surfaces malformed JSON via onError handler', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(
      transport: transport,
      invoker: FlunityInvoker.forTest(),
    );

    final errors = <Object>[];
    final sub = controller.messages.listen((_) {}, onError: errors.add);

    transport.pushFromUnity('{not valid json');
    await Future<void>.delayed(Duration.zero);

    expect(errors, hasLength(1));
    await sub.cancel();
    await controller.dispose();
  });

  test('isReady reflects underlying transport readiness', () async {
    final transport = FakeMessageTransport(startReady: false);
    final controller = FlunityWebGLController(
      transport: transport,
      invoker: FlunityInvoker.forTest(),
    );

    expect(controller.isReady, isFalse);
    transport.markReady();
    await transport.ready;
    expect(controller.isReady, isTrue);
  });

  test('reload delegates to transport', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(
      transport: transport,
      invoker: FlunityInvoker.forTest(),
    );
    await controller.reload();
    expect(transport.reloadCount, 1);
  });

  test('dispose closes the messages stream', () async {
    final transport = FakeMessageTransport();
    final controller = FlunityWebGLController(
      transport: transport,
      invoker: FlunityInvoker.forTest(),
    );

    final done = controller.messages.toList();
    await controller.dispose();
    expect(await done, isEmpty);
  });

  group('outlet auto-registration', () {
    test(
      'constructing the controller attaches its transport to the invoker',
      () async {
        final invoker = FlunityInvoker.forTest();
        final fake = FakeMessageTransport();
        FlunityWebGLController(transport: fake, invoker: invoker);

        final future = invoker.invoke<int>('Counter.Get');
        await Future<void>.delayed(Duration.zero);

        final payload =
            ((jsonDecode(fake.sentMessages.single)
                        as Map<String, Object?>)['payload']
                    as Map)
                .cast<String, Object?>();
        fake.pushFromUnity(
          jsonEncode({
            'type': 'outlet_reply',
            'payload': {'nonce': payload['nonce'], 'ok': true, 'value': 7},
          }),
        );

        expect(await future, 7);
      },
    );

    test(
      'disposing the controller detaches its transport from the invoker',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final invoker = FlunityInvoker.forTest();
        final fake = FakeMessageTransport();
        final controller = FlunityWebGLController(
          transport: fake,
          invoker: invoker,
        );
        await controller.dispose();

        await expectLater(
          invoker.invoke<void>('Counter.Get'),
          throwsA(isA<FlunityNotAttachedException>()),
        );
      },
    );
  });
}
