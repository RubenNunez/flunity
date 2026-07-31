import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flunity_bridge/src/outlets/flunity_invoker.dart';
import 'package:flutter/foundation.dart';
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

  test(
    'invoke routes an outlet_call through the transport and resolves on reply',
    () async {
      final invoker = FlunityInvoker.forTest();
      final fake = FakeMessageTransport();
      invoker.attachWebTransport(fake);

      final future = invoker.invoke<String>(
        'Greeter.Greet',
        args: {'name': 'Ruben'},
      );
      await _settle();

      expect(fake.sentMessages, hasLength(1));
      final envelope =
          jsonDecode(fake.sentMessages.single) as Map<String, Object?>;
      expect(envelope['type'], 'outlet_call');
      final payload = _payloadOf(fake.sentMessages.single);
      expect(payload['name'], 'Greeter.Greet');
      expect(payload['args'], {'name': 'Ruben'});
      final nonce = payload['nonce'] as String;

      fake.pushFromUnity(
        jsonEncode({
          'type': 'outlet_reply',
          'payload': {'nonce': nonce, 'ok': true, 'value': 'Hello, Ruben!'},
        }),
      );

      expect(await future, 'Hello, Ruben!');
    },
  );

  test('an ok:false reply rejects with FlunityOutletException', () async {
    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);

    final future = invoker.invoke<void>('Greeter.Boom');
    await _settle();
    final nonce = _payloadOf(fake.sentMessages.single)['nonce'] as String;

    fake.pushFromUnity(
      jsonEncode({
        'type': 'outlet_reply',
        'payload': {
          'nonce': nonce,
          'ok': false,
          'value': null,
          'error': 'kaboom',
        },
      }),
    );

    await expectLater(
      future,
      throwsA(
        isA<FlunityOutletException>().having(
          (e) => e.unityMessage,
          'unityMessage',
          'kaboom',
        ),
      ),
    );
  });

  test('no reply times out with FlunityOutletTimeoutException', () async {
    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);

    final future = invoker.invoke<void>(
      'Greeter.Hang',
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(future, throwsA(isA<FlunityOutletTimeoutException>()));
  });

  test('find routes outlet_find and maps the reply into handles', () async {
    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);

    final future = invoker.find('Pet');
    await _settle();

    final envelope =
        jsonDecode(fake.sentMessages.single) as Map<String, Object?>;
    expect(envelope['type'], 'outlet_find');
    final payload = _payloadOf(fake.sentMessages.single);
    expect(payload['component'], 'Pet');
    final nonce = payload['nonce'] as String;

    fake.pushFromUnity(
      jsonEncode({
        'type': 'outlet_find_reply',
        'payload': {
          'nonce': nonce,
          'components': [
            {'id': 'bunny', 'name': 'Pet', 'path': 'Forest/Trees/Pet'},
            {'id': 'foxxy', 'name': 'Pet', 'path': 'Forest/Den/Pet'},
          ],
        },
      }),
    );

    final handles = await future;
    expect(handles, hasLength(2));
    expect(handles.first.id, 'bunny');
    expect(handles.first.path, 'Forest/Trees/Pet');
    expect(handles.last.id, 'foxxy');
  });

  test(
    'invoke without an attached transport on a non-native platform throws',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final invoker = FlunityInvoker.forTest();
      await expectLater(
        invoker.invoke<void>('Greeter.Greet'),
        throwsA(isA<FlunityNotAttachedException>()),
      );
    },
  );

  test('detachWebTransport stops routing to that transport', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);
    invoker.detachWebTransport(fake);

    await expectLater(
      invoker.invoke<void>('Greeter.Greet'),
      throwsA(isA<FlunityNotAttachedException>()),
    );
  });

  test(
    'attaching a second transport stops routing replies through the first',
    () async {
      final invoker = FlunityInvoker.forTest();
      final first = FakeMessageTransport();
      final second = FakeMessageTransport();
      invoker.attachWebTransport(first);
      invoker.attachWebTransport(second); // replaces & tears down `first`

      final future = invoker.invoke<int>('Counter.Get');
      await _settle();

      // Outbound went to the active (second) transport, not the first.
      expect(second.sentMessages, hasLength(1));
      expect(first.sentMessages, isEmpty);
      final nonce = _payloadOf(second.sentMessages.single)['nonce'] as String;

      // A reply on the now-detached `first` must NOT resolve the pending call.
      first.pushFromUnity(
        jsonEncode({
          'type': 'outlet_reply',
          'payload': {'nonce': nonce, 'ok': true, 'value': 1},
        }),
      );
      await _settle();

      // The reply on the active `second` transport resolves it.
      second.pushFromUnity(
        jsonEncode({
          'type': 'outlet_reply',
          'payload': {'nonce': nonce, 'ok': true, 'value': 2},
        }),
      );
      expect(await future, 2);
    },
  );

  test('attaching the same transport twice does not double-subscribe', () async {
    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);
    invoker.attachWebTransport(fake); // idempotent — must not double-subscribe

    final future = invoker.invoke<int>('Counter.Get');
    await _settle();
    final nonce = _payloadOf(fake.sentMessages.single)['nonce'] as String;

    fake.pushFromUnity(
      jsonEncode({
        'type': 'outlet_reply',
        'payload': {'nonce': nonce, 'ok': true, 'value': 42},
      }),
    );

    // Resolves exactly once with the right value; a double-subscribe would
    // process the reply twice (second lookup finds no pending — harmless here,
    // but this guards the idempotency contract).
    expect(await future, 42);
  });

  group('a reply that cannot be parsed', () {
    // Unity answered, so the call must not sit out its whole timeout and then
    // claim the outlet "did not reply" — that sends you looking in the wrong
    // place entirely.
    test('fails its call immediately when the nonce is readable', () async {
      final invoker = FlunityInvoker.forTest();
      final fake = FakeMessageTransport();
      invoker.attachWebTransport(fake);

      final future = invoker.invoke<int>(
        'Creature.Health',
        timeout: const Duration(seconds: 30),
      );
      await _settle();
      final nonce = _payloadOf(fake.sentMessages.single)['nonce'] as String;

      // `ok` must be a bool; OutletReply.register rejects this payload.
      fake.pushFromUnity(
        jsonEncode({
          'type': 'outlet_reply',
          'payload': {'nonce': nonce, 'ok': 'yes', 'value': 1},
        }),
      );

      await expectLater(
        future,
        throwsA(
          isA<FlunityOutletException>().having(
            (e) => e.unityMessage,
            'unityMessage',
            allOf(contains('Creature.Health'), contains('malformed')),
          ),
        ),
      );
    });

    test('does not disturb other in-flight calls', () async {
      final invoker = FlunityInvoker.forTest();
      final fake = FakeMessageTransport();
      invoker.attachWebTransport(fake);

      final bad = invoker.invoke<int>('Creature.Health');
      final good = invoker.invoke<int>('Creature.Age');
      await _settle();

      final nonces = fake.sentMessages
          .map((m) => _payloadOf(m)['nonce'] as String)
          .toList();

      fake.pushFromUnity(
        jsonEncode({
          'type': 'outlet_reply',
          'payload': {'nonce': nonces[0], 'ok': 'yes'},
        }),
      );
      await expectLater(bad, throwsA(isA<FlunityOutletException>()));

      fake.pushFromUnity(
        jsonEncode({
          'type': 'outlet_reply',
          'payload': {'nonce': nonces[1], 'ok': true, 'value': 3},
        }),
      );
      expect(await good, 3);
    });

    test('undecodable JSON leaves the stream usable', () async {
      final invoker = FlunityInvoker.forTest();
      final fake = FakeMessageTransport();
      invoker.attachWebTransport(fake);

      fake.pushFromUnity('this is not json {');
      await _settle();

      final future = invoker.invoke<int>('Counter.Get');
      await _settle();
      final nonce = _payloadOf(fake.sentMessages.single)['nonce'] as String;
      fake.pushFromUnity(
        jsonEncode({
          'type': 'outlet_reply',
          'payload': {'nonce': nonce, 'ok': true, 'value': 9},
        }),
      );

      expect(await future, 9);
    });
  });

  group('the timeout budget covers the reply, not the boot', () {
    // Unity WebGL takes seconds to tens of seconds to come up, and the
    // transport parks sends until its JS shim is ready. Starting the clock at
    // call time meant every early invoke expired before it was ever delivered,
    // then reported "did not reply" once the real reply arrived late.
    test('a call parked before ready is not charged for the wait', () {
      FakeAsync().run((async) {
        final invoker = FlunityInvoker.forTest();
        final fake = FakeMessageTransport(startReady: false);
        invoker.attachWebTransport(fake);

        Object? error;
        String? value;
        invoker
            .invoke<String>(
              'Greeter.Greet',
              timeout: const Duration(seconds: 5),
            )
            .then<void>(
              (v) {
                value = v;
              },
              onError: (Object e) {
                error = e;
              },
            );

        async.elapse(const Duration(seconds: 30));
        expect(fake.sentMessages, isEmpty, reason: 'still parked on the gate');
        expect(error, isNull, reason: 'nothing was delivered to time out');

        fake.markReady();
        async.flushMicrotasks();
        expect(fake.sentMessages, hasLength(1));

        final nonce = _payloadOf(fake.sentMessages.single)['nonce'] as String;
        fake.pushFromUnity(
          jsonEncode({
            'type': 'outlet_reply',
            'payload': {'nonce': nonce, 'ok': true, 'value': 'Hello!'},
          }),
        );
        async.flushMicrotasks();

        expect(error, isNull);
        expect(value, 'Hello!');
      });
    });

    test('the clock still runs once the call has been delivered', () {
      FakeAsync().run((async) {
        final invoker = FlunityInvoker.forTest();
        final fake = FakeMessageTransport(startReady: false);
        invoker.attachWebTransport(fake);

        Object? error;
        invoker
            .invoke<String>(
              'Greeter.Greet',
              timeout: const Duration(seconds: 5),
            )
            .then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );

        async.elapse(const Duration(seconds: 30));
        fake.markReady();
        async.flushMicrotasks();
        expect(error, isNull);

        // Delivered, and Unity never answers.
        async.elapse(const Duration(seconds: 5));
        expect(error, isA<FlunityOutletTimeoutException>());
      });
    });
  });
}
