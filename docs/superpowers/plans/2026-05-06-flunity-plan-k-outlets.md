# Plan K — Outlets: typed Flutter→Unity invocation + scene discovery

**Status:** in progress (branch `feat/plan-k-outlets`)
**Driver:** jellx integration ergonomics — manual switch-statement dispatch on `FlunityBridge.OnMessage` is too noisy.
**Date:** 2026-05-06

## Goal

Replace the `OnMessage` event + `if (type == "X")` boilerplate on the Unity side with a declarative attribute-based pattern. Add a Flutter-side `flunity.invoke<T>(name, args:)` API that returns a `Future<T>`, plus a `flunity.find('Pet')` query that lists scene instances of a component.

## Non-goals (v1)

- Reverse direction (`Unity invokes Flutter`) — same shape, separate plan (Plan L).
- Cross-scene synchronization, hot-reload of the registry on script edits.
- Generic-typed C# outlets, `params` / positional args, `IEnumerator` coroutine returns.
- Multi-instance addressing beyond `[FlunityIdentity]` + auto-fallback to `InstanceID`.

## API surface

### C# (Unity-side)

```csharp
using Flunity;

public class PetController : MonoBehaviour {
    [FlunityIdentity] public string petId;     // optional; auto-fallback to InstanceID

    [FlunityOutlet]                            // exposed as "PetController.Feed"
    public void Feed(FeedArgs args) { ... }

    [FlunityOutlet("pet.snapshot")]            // explicit name override
    public PetSnapshot Snapshot() { ... }

    [FlunityOutlet]                            // async — Future stays pending until Task completes
    public async Task<bool> WarmUp(WarmUpArgs args) { await Task.Delay(500); return true; }
}

public static class GameApi {
    [FlunityOutlet]                            // static methods work too — no instance ambiguity
    public static void Pause() { Time.timeScale = 0; }
}

[Serializable] public class FeedArgs { public int amount; }
```

A `FlunityOutletRegistry` MonoBehaviour spawns alongside `FlunityBridgeBehaviour` on the `[FlunityBridge]` GameObject. On Awake / scene load, it scans all loaded MonoBehaviours via reflection and indexes `[FlunityOutlet]` methods by name. Static methods are discovered via `Assembly.GetTypes()`.

Dispatch: registry subscribes to `FlunityBridge.OnMessage` for `outlet_call` and `outlet_find`. Args are deserialized via `JsonUtility.FromJson<T>`.

### Dart (Flutter-side)

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

// Singleton accessor — backed by the active FlunityNativeView's MethodChannel.
// Calls fail with FlunityNotAttachedException if no native view is mounted.

await flunity.invoke('PetController.Feed', args: {'amount': 10});
final status = await flunity.invoke<String>('PetController.Snapshot');
final ok     = await flunity.invoke<bool>('PetController.WarmUp', args: {'reason': 'init'});

await flunity.invoke('GameApi.Pause');

// Discovery — returns List<FlunityComponentRef>.
final pets = await flunity.find('Pet');
print(pets[0].id);                          // "bunny" or "12345" (Unity InstanceID fallback)
print(pets[0].path);                        // "Forest/Trees/Pet"
await pets[0].invoke('Feed', args: {'amount': 10});
```

`FlunityComponentRef.invoke(...)` is sugar for `flunity.invoke('<class>.<method>', target: ref.id, args: ...)`.

Errors thrown on the Unity side become `FlunityOutletException` on the Dart side, with the original C# message preserved.

## Wire format

Built-in message types added to `flunity_bridge`:

```json
{ "type": "outlet_call",
  "payload": {"name": "PetController.Feed", "target": "bunny",
              "nonce": "abc", "args": {"amount": 10}} }

{ "type": "outlet_reply",
  "payload": {"nonce": "abc", "ok": true,  "value": null} }

{ "type": "outlet_reply",
  "payload": {"nonce": "abc", "ok": false, "error": "no such outlet 'PetController.Feed'"} }

{ "type": "outlet_find",
  "payload": {"nonce": "abc", "component": "Pet"} }

{ "type": "outlet_find_reply",
  "payload": {"nonce": "abc", "components": [
    {"id": "bunny", "name": "Pet", "path": "Forest/Trees/Pet"},
    {"id": "12345", "name": "Pet", "path": "Forest/Trees/Pet (1)"}
  ]} }
```

## Resolution order on the Unity side

For an `outlet_call` with name `<X>.<Y>` and optional `target`:

1. **Static method match** — `<X>` is a static class, `<Y>` is a `[FlunityOutlet]` static method. Invoke directly.
2. **Targeted instance match** — `target` is set; find the MonoBehaviour with matching `[FlunityIdentity]` value (or matching `InstanceID` as string). Class name must match `<X>`.
3. **Singleton instance match** — `target` is null; find the unique MonoBehaviour of class `<X>` with the `[FlunityOutlet]` method `<Y>`. If multiple instances exist and no target was specified, return `outlet_reply` with `ok=false, error="<X>.<Y> is ambiguous: N instances; pass a target"`.
4. **Miss** — return `outlet_reply` with `ok=false, error="no such outlet '<X>.<Y>'"`.

## Defaults locked

- `flunity.find` re-queries Unity every call (no cache, simplicity).
- Discovery + invoke responses route through the existing `FlunityNativeView.onMessageFromUnity` callback / WebGL transport — no new MethodChannel.
- `flunity` is a singleton accessor; calls fail with `FlunityNotAttachedException` if no native view is mounted.

## Implementation plan

1. Branch `feat/plan-k-outlets`. Plan doc (this file).
2. Dart message types: `OutletCall`, `OutletReply`, `OutletFind`, `OutletFindReply`. Register in `built_in.dart`.
3. C# `[FlunityOutlet]`, `[FlunityIdentity]` attributes + `FlunityOutletRegistry` MonoBehaviour. Mirror into all 4 templates AND copy into `jellx/Assets/Scripts/Flunity/`.
4. Dart `FlunityInvoker` + singleton `flunity` accessor. Exposes `invoke<T>` and `find`.
5. Tests: round-trip with a `FakeMessageTransport`. Unit-tests for nonce correlation, timeout, error mapping.
6. Doc `docs/outlets.md` with worked examples (the four variants).
7. jellx demo wiring — `PetController` with `[FlunityOutlet]` Feed/Play/Sleep/Cuddle, buttons in `unity_webgl_screen.dart` call them.
8. CHANGELOGs.
9. PR.

## Out of scope (Plan L territory)

- `[FlunityOutlet]` in Dart for the reverse direction (Unity → Flutter typed RPC).
- `FlunityComponentRef` mutation (e.g. `ref.dispose()`, `ref.setActive(false)`) — these would let Flutter manipulate Unity scene graph beyond invoking outlets. Worth a separate pass.
- Hot-reload of the outlet registry when scripts change in the Editor. Easy win but not load-bearing.
