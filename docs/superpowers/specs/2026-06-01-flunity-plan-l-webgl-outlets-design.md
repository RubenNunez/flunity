# Flunity Plan L — WebGL Outlets

**Date:** 2026-06-01
**Status:** Approved (brainstorming complete; awaiting implementation plan)
**Repo:** `git@github.com:RubenNunez/flunity.git`
**Builds on:** Plan K (outlets — native iOS/Android), Plan F (multi-target)

## 1. Goal

Make `flunity.invoke<T>()` and `flunity.find()` work on **WebGL**, reaching full
parity with the native iOS/Android outlet support shipped in Plan K. After this
plan, outlets are a first-class feature on all three targets with **identical
app-facing API** — no per-target branching in user code.

## 2. Why this is small

The outlet system was designed transport-agnostic. Everything except the
Dart-side transport binding is already WebGL-ready:

- **C# is done.** `FlunityOutletRegistry` auto-spawns on the `[FlunityBridge]`
  GameObject on every platform (`Awake`-based). `FlunityBridge.SendRaw` already
  has a `#if UNITY_WEBGL` branch (`FlunityPostMessage(envelope)` →
  `window.flunity._fromUnity`) — the same outbound path Pong replies travel
  today. No C# changes.
- **Wire format is identical** across all targets: `{type, payload}` envelopes
  with `outlet_call` / `outlet_reply` / `outlet_find` / `outlet_find_reply`.
- **The WebGL JS bridge is proven** by the existing Ping/Pong round-trip:
  Flutter ↔ `InAppWebView` ↔ `flunity_bridge.js` ↔ `unityInstance.SendMessage`.

The entire blocker is on the Dart side. `FlunityInvoker`
(`packages/flunity_bridge/lib/src/outlets/flunity_invoker.dart`) is hardwired to
the native MethodChannel:

- outbound via `_sendEnvelope` → `native.sendToUnity()` (line 293-299)
- inbound via `UnityMessageListeners.instance.addAlwaysListener(_onMessage)`
  (line 94)
- explicit gate `_ensureNativeAvailable()` throws `FlunityNotAttachedException`
  on web (line 301-307)

## 3. Approach — additive WebGL branch (native path untouched)

The invoker keeps its native path exactly as-is and gains an **optional WebGL
transport binding**. We deliberately do *not* refactor the working native path
into a shared abstraction — that would add risk for no functional gain.

```
flunity (global FlunityInvoker)
 ├── native path  (iOS/Android)  — UNCHANGED
 │     outbound: native.sendToUnity(...)
 │     inbound:  UnityMessageListeners always-listener → _onMessage
 └── _webTransport: MessageTransport?   (WebGL — NEW)
        outbound: _webTransport.send(jsonEncode(envelope))
        inbound:  _webTransport.incoming.listen(_onMessage)   ← same handler, reused
```

`MessageTransport`
(`packages/flunity_bridge/lib/src/transport/message_transport.dart`) is exactly
the abstraction needed: `Future<void> send(String json)` plus a **broadcast**
`Stream<String> get incoming` of raw JSON. Because `incoming` is broadcast (see
`InAppWebViewMessageTransport`, `StreamController<String>.broadcast()`), the
invoker can subscribe alongside `FlunityWebGLController`, which already listens
to the same stream.

`_onMessage` already filters for `OutletReply.typeName` /
`OutletFindReply.typeName` and ignores everything else, so feeding it the WebGL
stream (which also carries Ping/Pong and log messages) is safe and requires **no
change to that method**.

## 4. The four seams

### Seam 1 — Invoker transport registration (NEW)
Add to `FlunityInvoker`:

- field `MessageTransport? _webTransport;` and
  `StreamSubscription<String>? _webSub;`
- `void attachWebTransport(MessageTransport t)` — sets `_webTransport = t` and
  subscribes `_webSub = t.incoming.listen(_onMessage)`. If a different transport
  is already attached, detach it first (single active WebGL transport — the same
  one-Unity-instance assumption the native side already makes).
- `void detachWebTransport(MessageTransport t)` — only acts if
  `identical(_webTransport, t)`: cancels `_webSub`, nulls both. Idempotent and
  safe to call for a transport that isn't the current one (no-op).

### Seam 2 — Outbound routing
`_sendEnvelope(FlunityMessage)`:

```dart
Future<void> _sendEnvelope(FlunityMessage message) {
  final json = jsonEncode(message.toJson());
  if (kIsWeb) {
    return _webTransport!.send(json); // _webTransport guaranteed by _ensureAvailable
  }
  return native.sendToUnity(_bridgeGameObject, _bridgeMethod, json);
}
```

### Seam 3 — Platform gate
Rename `_ensureNativeAvailable()` → `_ensureAvailable()`:

```dart
void _ensureAvailable() {
  if (kIsWeb) {
    if (_webTransport == null) throw FlunityNotAttachedException();
    return;
  }
  final p = defaultTargetPlatform;
  if (p != TargetPlatform.iOS && p != TargetPlatform.android) {
    throw FlunityNotAttachedException();
  }
}
```

Called at the top of both `invoke` and `find` (replacing the existing
`_ensureNativeAvailable()` calls).

### Seam 4 — Controller auto-register
`FlunityWebGLController` (`flunity_webgl_controller.dart`):

- constructor body: `flunity.attachWebTransport(_transport);`
- `dispose()`: `flunity.detachWebTransport(_transport);` (before/with existing
  teardown).

This is the **auto-register** model: creating a `FlunityWebGLView` /
`UnitySceneRoute` (which owns a controller) makes `flunity.invoke()` /
`flunity.find()` live with zero extra setup. Disposing the view detaches it.

## 5. Error handling

`FlunityNotAttachedException.toString()` is rewritten to be WebGL-aware. Current
text tells users to "use FlunityWebGLController directly for now" — that advice
is now wrong. New message, roughly:

> `FlunityNotAttachedException: no Unity bridge is attached. On WebGL, mount a
> FlunityWebGLView (or UnitySceneRoute) before calling outlets; on desktop/web
> without Unity, outlets are unavailable.`

All other failure modes (`FlunityOutletException`, `FlunityOutletTimeoutException`,
type-mismatch) are transport-agnostic and unchanged.

## 6. Testing

The risk introduced by this plan lives entirely in the Dart routing seam, and
that seam is fully unit-testable **without a browser or a WebGL build** (the test
project, jellx, has no WebGL build at time of writing).

### Unit tests (the real verification)
Using the existing `FakeMessageTransport`
(`test/transport/fake_transport.dart`):

1. `attachWebTransport(fake)`, call `flunity.invoke<T>('Class.Method', args:...)`,
   assert the JSON written to the fake's outbound sink is a well-formed
   `outlet_call` with the right name/args/nonce.
2. Push a matching `outlet_reply` (same nonce, `ok:true`, a value) into the
   fake's `incoming`; assert the future completes with the deserialized value
   (cover `void`/null, primitive, and `Map` return shapes).
3. Error reply (`ok:false`, `error:"boom"`) → future completes with
   `FlunityOutletException` carrying `boom`.
4. No reply → `FlunityOutletTimeoutException` after the timeout.
5. `find('Pet')` → outbound `outlet_find`; push `outlet_find_reply` with two
   components; assert two `FlunityComponentHandle`s with correct id/name/path.
6. `invoke` with no transport attached on web → `FlunityNotAttachedException`.
7. `detachWebTransport` cancels the subscription (a later `incoming` event does
   not resolve a stale pending call).

Tests must run under the web platform configuration (or with `kIsWeb` exercised
via the web test target) so the `_sendEnvelope` web branch is taken. If driving
`kIsWeb` in unit tests proves impractical, the implementation plan will inject
the transport directly and assert routing through the fake regardless of
`kIsWeb`, plus a separate `defaultTargetPlatform`-gated test for the native
branch — the plan will settle the exact mechanism.

### Deferred (explicitly flagged, not silently skipped)
True end-to-end on a real WebGL build in a browser is **not** done in this plan
because no WebGL build exists in the test project. It is recorded as a manual
follow-up: build a WebGL scene with a `[FlunityOutlet]`, run the app, call
`flunity.invoke` from the in-app Inspector, confirm the round-trip. The C# and
JS legs are already exercised by Ping/Pong, so this is a confirmation step, not
a source of expected risk.

## 7. Documentation

- `docs/outlets.md` — remove the "Status: native iOS / Android only" line and the
  Plan-L pointer; remove the "WebGL / desktop / web → FlunityNotAttachedException"
  row from the error table (or rewrite it to mean "no Unity view mounted");
  update the `FlunityNotAttachedException` wording reference.
- `README.md` — outlets section currently says "iOS / Android only in v1; WebGL
  outlet support tracked as Plan L." Update to: outlets work on all three
  targets.
- `CHANGELOG.md` — add a Plan L entry under "Plans landed".
- `docs/scene-routing.md` / `docs/webgl-workflow.md` — one line noting outlets
  (`invoke`/`find`) now work inside WebGL views.
- `packages/flunity_bridge/CHANGELOG.md` — package-level entry.

## 8. Out of scope

- No refactor of the native transport into a shared abstraction.
- No support for multiple simultaneous WebGL Unity instances (single active
  transport, matching the native assumption).
- No new outlet capabilities — strictly transport parity for the existing
  `invoke` / `find` surface.
- Flutter Web (the browser app itself embedding Unity WebGL) remains a separate
  future concern with its own COOP/COEP issues.

## 9. Definition of done

- [ ] `flunity.invoke<T>()` and `flunity.find()` route over a `MessageTransport`
      on web; native path unchanged and still green.
- [ ] `FlunityWebGLController` auto-registers/deregisters its transport.
- [ ] `FlunityNotAttachedException` message no longer recommends the removed
      workaround.
- [ ] Unit tests cover invoke/find success, error, timeout, not-attached, and
      detach cleanup — all passing.
- [ ] Docs (outlets, README, CHANGELOGs, scene-routing/webgl-workflow) updated.
- [ ] Real-browser e2e recorded as a manual follow-up.
