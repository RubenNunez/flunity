# Plan L — WebGL Outlets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `flunity.invoke<T>()` and `flunity.find()` work over the WebGL `MessageTransport`, reaching full parity with native iOS/Android outlets, with identical app-facing API.

**Architecture:** Additive. The native path in `FlunityInvoker` is untouched. The invoker gains an optional `MessageTransport? _webTransport`; when present, outbound `_sendEnvelope` routes through it and the invoker subscribes to its broadcast `incoming` stream with the *existing* `_onMessage` handler. `FlunityWebGLController` auto-registers/deregisters its transport with the global `flunity` invoker, so mounting a WebGL view makes outlets live with zero extra setup. Routing keys off transport presence (not `kIsWeb`), which keeps the new seam unit-testable on the Dart VM.

**Tech Stack:** Dart / Flutter, `flunity_bridge` package, `flutter_test`, existing `FakeMessageTransport`.

**Spec:** `docs/superpowers/specs/2026-06-01-flunity-plan-l-webgl-outlets-design.md`

---

## File Structure

- **Modify** `packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart` — add transport fields, `attachWebTransport`/`detachWebTransport`, route `_sendEnvelope` by transport presence, rename `_ensureNativeAvailable` → `_ensureAvailable`, add `FlunityInvoker.forTest()`, rewrite `FlunityNotAttachedException` message.
- **Modify** `packages/flunity_bridge/lib/src/flunity_webgl_controller.dart` — auto-register transport with an injectable invoker (defaults to global `flunity`), detach on `dispose`.
- **Create** `packages/flunity_bridge/test/outlets/flunity_invoker_webgl_test.dart` — invoke/find/error/timeout/not-attached/detach over a `FakeMessageTransport`.
- **Modify** `packages/flunity_bridge/test/flunity_webgl_controller_test.dart` — auto-register + dispose-detach tests.
- **Modify** docs: `docs/outlets.md`, `README.md`, `CHANGELOG.md`, `packages/flunity_bridge/CHANGELOG.md`, `docs/scene-routing.md`, `docs/webgl-workflow.md`.

All test commands run from `packages/flunity_bridge/`.

---

### Task 1: Route the invoker over an injectable transport

**Files:**
- Modify: `packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart`
- Test: `packages/flunity_bridge/test/outlets/flunity_invoker_webgl_test.dart`

- [ ] **Step 1: Write the failing test**

Create `packages/flunity_bridge/test/outlets/flunity_invoker_webgl_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/outlets/flunity_invoker_webgl_test.dart`
Expected: COMPILE FAILURE — `FlunityInvoker.forTest` and `attachWebTransport` are not defined.

- [ ] **Step 3: Implement the invoker changes**

In `packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart`:

Add the transport import near the other `src` imports (after the `outlet_reply` import line):

```dart
import 'package:flunity_bridge/src/transport/message_transport.dart';
```

Replace the constructor (currently `FlunityInvoker._() { ... }`, lines ~86-95) with a parameterized version plus a test factory:

```dart
  FlunityInvoker._({bool attachNativeListener = true}) {
    // Register the typed reply factories the invoker depends on. Doing this
    // here (rather than relying on the consumer's main() to call
    // registerBuiltInMessages) means `flunity.invoke(...)` works out of the
    // box — without it, FlunityMessage.fromJson silently downgrades replies
    // to RawMessage and every call times out. Idempotent.
    OutletReply.register();
    OutletFindReply.register();
    if (attachNativeListener) {
      UnityMessageListeners.instance.addAlwaysListener(_onMessage);
    }
  }

  /// Builds an invoker with the native MethodChannel listener detached, so
  /// tests can drive it purely through an attached [MessageTransport] without
  /// touching platform channels.
  @visibleForTesting
  factory FlunityInvoker.forTest() =>
      FlunityInvoker._(attachNativeListener: false);
```

Add the transport fields next to `_pending` / `_nonceCounter` (around line 108):

```dart
  MessageTransport? _webTransport;
  StreamSubscription<String>? _webSub;
```

Add the attach/detach methods (place them just above `invoke`, after the field declarations):

```dart
  /// Bind a WebGL [MessageTransport] so `invoke`/`find` route over it.
  ///
  /// Called automatically by [FlunityWebGLController]; you rarely call this
  /// directly. A single transport is active at a time (matching the
  /// one-Unity-instance assumption of the native path) — attaching a new one
  /// replaces and tears down the previous binding.
  void attachWebTransport(MessageTransport transport) {
    if (identical(_webTransport, transport)) return;
    _webSub?.cancel();
    _webTransport = transport;
    _webSub = transport.incoming.listen(_onMessage);
  }

  /// Unbind [transport] if it is the currently-attached one; otherwise a no-op.
  /// Called automatically by [FlunityWebGLController.dispose].
  void detachWebTransport(MessageTransport transport) {
    if (!identical(_webTransport, transport)) return;
    _webSub?.cancel();
    _webSub = null;
    _webTransport = null;
  }
```

Replace `_sendEnvelope` (lines ~293-299) with transport-aware routing:

```dart
  Future<void> _sendEnvelope(FlunityMessage message) {
    final json = jsonEncode(message.toJson());
    final web = _webTransport;
    if (web != null) {
      return web.send(json);
    }
    return native.sendToUnity(_bridgeGameObject, _bridgeMethod, json);
  }
```

Rename `_ensureNativeAvailable` (lines ~301-307) to `_ensureAvailable` and let an attached transport satisfy it:

```dart
  void _ensureAvailable() {
    if (_webTransport != null) return;
    if (kIsWeb) throw FlunityNotAttachedException();
    final p = defaultTargetPlatform;
    if (p != TargetPlatform.iOS && p != TargetPlatform.android) {
      throw FlunityNotAttachedException();
    }
  }
```

Update the two call sites: in `invoke` (line ~127) and `find` (line ~193), change `_ensureNativeAvailable();` to `_ensureAvailable();`.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/outlets/flunity_invoker_webgl_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Verify nothing else broke**

Run: `dart analyze lib test && dart test`
Expected: No analyzer issues; full suite green.

- [ ] **Step 6: Commit**

```bash
git add packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart packages/flunity_bridge/test/outlets/flunity_invoker_webgl_test.dart
git commit -m "feat(flunity_bridge): route outlet invoker over an attachable transport"
```

---

### Task 2: Parity coverage — error, timeout, find, not-attached, detach

**Files:**
- Modify: `packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart` (exception message only)
- Test: `packages/flunity_bridge/test/outlets/flunity_invoker_webgl_test.dart`

These exercise the existing reply/timeout/find machinery over the new transport. The error/timeout/find tests should pass immediately against Task 1's implementation — they are parity guards. Only the `FlunityNotAttachedException` message is new code.

- [ ] **Step 1: Add the parity tests**

Append inside `main()` in `test/outlets/flunity_invoker_webgl_test.dart` (add `import 'package:flutter/foundation.dart';` at the top of the file for `debugDefaultTargetPlatformOverride` / `TargetPlatform`):

```dart
  test('an ok:false reply rejects with FlunityOutletException', () async {
    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);

    final future = invoker.invoke('Greeter.Boom');
    await _settle();
    final nonce = _payloadOf(fake.sentMessages.single)['nonce'] as String;

    fake.pushFromUnity(jsonEncode({
      'type': 'outlet_reply',
      'payload': {'nonce': nonce, 'ok': false, 'value': null, 'error': 'kaboom'},
    }));

    await expectLater(
      future,
      throwsA(isA<FlunityOutletException>()
          .having((e) => e.unityMessage, 'unityMessage', 'kaboom')),
    );
  });

  test('no reply times out with FlunityOutletTimeoutException', () async {
    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);

    final future = invoker.invoke(
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

    final envelope = jsonDecode(fake.sentMessages.single) as Map<String, Object?>;
    expect(envelope['type'], 'outlet_find');
    final payload = _payloadOf(fake.sentMessages.single);
    expect(payload['component'], 'Pet');
    final nonce = payload['nonce'] as String;

    fake.pushFromUnity(jsonEncode({
      'type': 'outlet_find_reply',
      'payload': {
        'nonce': nonce,
        'components': [
          {'id': 'bunny', 'name': 'Pet', 'path': 'Forest/Trees/Pet'},
          {'id': 'foxxy', 'name': 'Pet', 'path': 'Forest/Den/Pet'},
        ],
      },
    }));

    final handles = await future;
    expect(handles, hasLength(2));
    expect(handles.first.id, 'bunny');
    expect(handles.first.path, 'Forest/Trees/Pet');
    expect(handles.last.id, 'foxxy');
  });

  test('invoke without an attached transport on a non-native platform throws',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final invoker = FlunityInvoker.forTest();
    await expectLater(
      invoker.invoke('Greeter.Greet'),
      throwsA(isA<FlunityNotAttachedException>()),
    );
  });

  test('detachWebTransport stops routing to that transport', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final invoker = FlunityInvoker.forTest();
    final fake = FakeMessageTransport();
    invoker.attachWebTransport(fake);
    invoker.detachWebTransport(fake);

    await expectLater(
      invoker.invoke('Greeter.Greet'),
      throwsA(isA<FlunityNotAttachedException>()),
    );
  });
```

- [ ] **Step 2: Run the tests**

Run: `dart test test/outlets/flunity_invoker_webgl_test.dart`
Expected: All pass except possibly the wording of `FlunityNotAttachedException` — the *type* assertions pass since Task 1 already throws the right type. (If all pass, Step 3 is a doc-only polish; still apply it.)

- [ ] **Step 3: Rewrite the FlunityNotAttachedException message**

The current message (lines ~37-42) tells users to "use FlunityWebGLController directly for now" — now wrong. Replace the class body's `toString`:

```dart
class FlunityNotAttachedException implements Exception {
  @override
  String toString() =>
      'FlunityNotAttachedException: no Unity bridge is attached. On WebGL, '
      'mount a FlunityWebGLView (or UnitySceneRoute) before calling outlets; '
      'on iOS / Android the native bridge attaches automatically. Outlets are '
      'unavailable on desktop / web targets without a Unity view.';
}
```

Also update the doc comment above the class (lines ~34-36) to drop the "Plan L" tracking note, e.g.:

```dart
/// Thrown when [FlunityInvoker] is used with no Unity transport available:
/// on WebGL before a [FlunityWebGLController] (view) is mounted, or on an
/// unsupported platform (desktop / web without Unity).
```

- [ ] **Step 4: Run analyzer + full suite**

Run: `dart analyze lib test && dart test`
Expected: No issues; all green.

- [ ] **Step 5: Commit**

```bash
git add packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart packages/flunity_bridge/test/outlets/flunity_invoker_webgl_test.dart
git commit -m "test(flunity_bridge): cover outlet parity over transport; fix not-attached message"
```

---

### Task 3: Auto-register the transport from the WebGL controller

**Files:**
- Modify: `packages/flunity_bridge/lib/src/flunity_webgl_controller.dart`
- Test: `packages/flunity_bridge/test/flunity_webgl_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `main()` in `packages/flunity_bridge/test/flunity_webgl_controller_test.dart` (ensure these imports exist at the top: `dart:convert`, `package:flutter/foundation.dart`, `package:flunity_bridge/src/outlets/flunity_invoker.dart`, and the fake transport import the file already uses):

```dart
  group('outlet auto-registration', () {
    test('constructing the controller attaches its transport to the invoker',
        () async {
      final invoker = FlunityInvoker.forTest();
      final fake = FakeMessageTransport();
      FlunityWebGLController(transport: fake, invoker: invoker);

      final future = invoker.invoke<int>('Counter.Get');
      await Future<void>.delayed(Duration.zero);

      final payload = ((jsonDecode(fake.sentMessages.single)
              as Map<String, Object?>)['payload'] as Map)
          .cast<String, Object?>();
      fake.pushFromUnity(jsonEncode({
        'type': 'outlet_reply',
        'payload': {'nonce': payload['nonce'], 'ok': true, 'value': 7},
      }));

      expect(await future, 7);
    });

    test('disposing the controller detaches its transport from the invoker',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final invoker = FlunityInvoker.forTest();
      final fake = FakeMessageTransport();
      final controller =
          FlunityWebGLController(transport: fake, invoker: invoker);
      await controller.dispose();

      await expectLater(
        invoker.invoke('Counter.Get'),
        throwsA(isA<FlunityNotAttachedException>()),
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/flunity_webgl_controller_test.dart`
Expected: COMPILE FAILURE — `FlunityWebGLController` has no `invoker` parameter.

- [ ] **Step 3: Implement the controller change**

In `packages/flunity_bridge/lib/src/flunity_webgl_controller.dart`, add the import:

```dart
import 'package:flunity_bridge/src/outlets/flunity_invoker.dart';
```

Replace the constructor and add the `_invoker` field:

```dart
  FlunityWebGLController({
    required MessageTransport transport,
    FlunityInvoker? invoker,
  }) : _transport = transport,
       _invoker = invoker ?? flunity {
    _invoker.attachWebTransport(transport);
    _transport.ready.then((_) {
      _isReady = true;
    });
    _incomingSub = _transport.incoming.listen(
      _handleIncoming,
      onError: _messages.addError,
    );
  }

  final MessageTransport _transport;
  final FlunityInvoker _invoker;
```

In `dispose()`, detach before tearing down the transport (add as the first action inside the `if (_disposed) return;` guard):

```dart
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _invoker.detachWebTransport(_transport);
    await _incomingSub.cancel();
    await _transport.dispose();
    await _messages.close();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/flunity_webgl_controller_test.dart`
Expected: PASS (existing tests + the two new ones).

- [ ] **Step 5: Run analyzer + full suite**

Run: `dart analyze lib test && dart test`
Expected: No issues; all green. (If `test/public_api_test.dart` asserts the exported surface, confirm `attachWebTransport`/`detachWebTransport` don't break its expectations; they live in `src` and need no new public export.)

- [ ] **Step 6: Commit**

```bash
git add packages/flunity_bridge/lib/src/flunity_webgl_controller.dart packages/flunity_bridge/test/flunity_webgl_controller_test.dart
git commit -m "feat(flunity_bridge): WebGL controller auto-registers outlets with the invoker"
```

---

### Task 4: Documentation

**Files:**
- Modify: `docs/outlets.md`, `README.md`, `CHANGELOG.md`, `packages/flunity_bridge/CHANGELOG.md`, `docs/scene-routing.md`, `docs/webgl-workflow.md`

- [ ] **Step 1: Update `docs/outlets.md`**

- Replace the status line (line ~5): `**Status: native iOS / Android only in v1.** WebGL invoker support lands in Plan L.` with:
  `**Status: works on iOS, Android, and WebGL.** Outlets are transport-agnostic — the same `flunity.invoke` / `flunity.find` API runs on all three targets.`
- In the Errors table, replace the row
  `| WebGL / desktop / web | `FlunityNotAttachedException` | v1 is iOS / Android only. |`
  with:
  `| No Unity view mounted | `FlunityNotAttachedException` | On WebGL, mount a `FlunityWebGLView` / `UnitySceneRoute` before calling outlets. On desktop (no Unity), outlets are unavailable. |`

- [ ] **Step 2: Update `README.md`**

In the outlets section, replace `iOS / Android only in v1; WebGL outlet support tracked as Plan L.` with:
`Outlets work on iOS, Android, and WebGL — the same typed API on every target.`

- [ ] **Step 3: Update `CHANGELOG.md`**

Under `## [Unreleased]` → `### Plans landed`, add after the Plan K bullet:

```markdown
- **Plan L** — WebGL outlets. `flunity.invoke<T>` and `flunity.find` now run over the WebGL `MessageTransport`, reaching parity with native. `FlunityWebGLController` auto-registers its transport with the global `flunity` invoker, so mounting a WebGL view makes outlets live with no extra setup. C# and JS were already transport-agnostic — change was Dart-side only.
```

- [ ] **Step 4: Update `packages/flunity_bridge/CHANGELOG.md`**

Add an entry (match the file's existing format) noting: invoker now routes over an attachable `MessageTransport`; `FlunityWebGLController` auto-registers/deregisters it; `FlunityNotAttachedException` message updated.

- [ ] **Step 5: Add a line to `docs/scene-routing.md` and `docs/webgl-workflow.md`**

In each, add a short note where it makes sense, e.g.:
`Outlets (`flunity.invoke` / `flunity.find`) work inside WebGL views too — mounting the view registers the bridge automatically.`

- [ ] **Step 6: Commit**

```bash
git add docs/outlets.md README.md CHANGELOG.md packages/flunity_bridge/CHANGELOG.md docs/scene-routing.md docs/webgl-workflow.md
git commit -m "docs: outlets work on WebGL (Plan L)"
```

---

## Manual follow-up (deferred — not in this plan)

True end-to-end on a real WebGL build in a browser is not part of this plan (no WebGL build exists in the test project, jellx). When one exists: add a `[FlunityOutlet]` to a scene MonoBehaviour, build WebGL, run the Flutter app, and call the outlet from the in-app Inspector (`call Class.Method`) to confirm the round-trip. The C# and JS legs are already exercised by Ping/Pong, so this is a confirmation step.

---

## Self-Review

**Spec coverage:** §3 additive approach → Tasks 1, 3. §4 seam 1 (attach/detach) → Task 1 Step 3. §4 seam 2 (outbound routing) → Task 1 Step 3. §4 seam 3 (platform gate) → Task 1 Step 3. §4 seam 4 (controller auto-register) → Task 3. §5 error handling / exception message → Task 2 Step 3. §6 testing (invoke/find/error/timeout/not-attached/detach) → Tasks 1-3. §6 deferred e2e → Manual follow-up section. §7 docs → Task 4. §9 DoD items all map to tasks. No gaps.

**Placeholder scan:** No TBD/TODO; every code step shows full code; every command shows expected output.

**Type/name consistency:** `attachWebTransport`/`detachWebTransport`, `_webTransport`, `_webSub`, `_ensureAvailable`, `FlunityInvoker.forTest()`, `FlunityWebGLController({transport, invoker})` used identically across Tasks 1-3. Wire shapes (`outlet_call`/`outlet_reply`/`outlet_find`/`outlet_find_reply` payload keys) match the message classes in `packages/flunity_bridge/lib/src/messages/`.
