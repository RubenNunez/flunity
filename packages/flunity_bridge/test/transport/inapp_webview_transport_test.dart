import 'dart:async';

import 'package:flunity_bridge/src/transport/inapp_webview_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the real transport by overriding only the one method that needs
/// a live WebView. Everything else — the ready gate, ordering, dispose — is
/// the production code path.
class _RecordingTransport extends InAppWebViewMessageTransport {
  final List<String> evaluated = <String>[];
  Object? failWith;

  @override
  Future<void> evaluate(String json) async {
    if (failWith != null) throw failWith!;
    evaluated.add(json);
  }
}

void main() {
  group('send before ready', () {
    test('does not reach the WebView', () async {
      final transport = _RecordingTransport();

      unawaited(transport.send('{"a":1}'));
      await pumpEventQueue();

      expect(transport.evaluated, isEmpty);
    });

    // The timeout on an outlet call starts when send() resolves. If send()
    // resolves at enqueue time rather than delivery time, every call issued
    // before Unity boots burns its whole budget sitting in the queue.
    test('leaves the returned future pending until delivery', () async {
      final transport = _RecordingTransport();
      var completed = false;

      unawaited(transport.send('{"a":1}').then((_) => completed = true));
      await pumpEventQueue();
      expect(completed, isFalse, reason: 'not delivered yet');

      await transport.markReady();
      await pumpEventQueue();

      expect(completed, isTrue);
      expect(transport.evaluated, <String>['{"a":1}']);
    });

    test('delivers queued messages in the order they were sent', () async {
      final transport = _RecordingTransport();

      unawaited(transport.send('first'));
      unawaited(transport.send('second'));
      unawaited(transport.send('third'));
      await transport.markReady();
      await pumpEventQueue();

      expect(transport.evaluated, <String>['first', 'second', 'third']);
    });
  });

  group('send after ready', () {
    test('delivers immediately', () async {
      final transport = _RecordingTransport();
      await transport.markReady();

      await transport.send('{"a":1}');

      expect(transport.evaluated, <String>['{"a":1}']);
    });

    // A failed evaluateJavascript used to be swallowed mid-drain, stranding
    // every message behind it with no diagnostic.
    test('surfaces an evaluate failure to the caller', () async {
      final transport = _RecordingTransport()..failWith = StateError('boom');
      await transport.markReady();

      await expectLater(transport.send('{"a":1}'), throwsStateError);
    });
  });

  group('reload', () {
    test('re-arms the ready gate so sends wait for the new document', () async {
      final transport = _RecordingTransport();
      await transport.markReady();
      await transport.send('before');

      await transport.reload();
      var completed = false;
      unawaited(transport.send('after').then((_) => completed = true));
      await pumpEventQueue();

      expect(completed, isFalse, reason: 'the new page has no JS shim yet');
      expect(transport.evaluated, <String>['before']);

      await transport.markReady();
      await pumpEventQueue();

      expect(transport.evaluated, <String>['before', 'after']);
    });
  });

  group('dispose', () {
    test('rejects further sends', () async {
      final transport = _RecordingTransport();
      await transport.dispose();

      expect(() => transport.send('x'), throwsStateError);
    });

    test('abandons sends still waiting on the ready gate', () async {
      final transport = _RecordingTransport();
      // Attach the matcher before disposing: the send fails the moment the
      // gate opens, and an unlistened failure escapes to the zone.
      final settled = expectLater(transport.send('queued'), throwsStateError);

      await transport.dispose();

      await settled;
      expect(transport.evaluated, isEmpty);
    });
  });
}
