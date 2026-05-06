# Outlets — typed Flutter → Unity invocation

Outlets replace the manual `FlunityBridge.OnMessage` switch-statement dispatch with a declarative attribute pattern. You decorate a C# method with `[FlunityOutlet]` and call it from Dart with `await flunity.invoke('<Class>.<Method>', args: {...})`.

**Status: native iOS / Android only in v1.** WebGL invoker support lands in Plan L.

## Quick start

**Unity:**

```csharp
using UnityEngine;
using Flunity;

public class Greeter : MonoBehaviour {
    [FlunityOutlet]
    public void Greet(GreetArgs args) {
        Debug.Log($"Hello, {args.name}!");
    }
}

[System.Serializable]
public class GreetArgs {
    public string name;
}
```

Attach `Greeter` to any GameObject in your active scene. The bridge's `FlunityBridgeBehaviour` auto-spawns the `FlunityOutletRegistry` on the `[FlunityBridge]` GameObject — no manual setup.

**Flutter:**

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

await flunity.invoke('Greeter.Greet', args: {'name': 'Ruben'});
```

That's it. Unity logs `Hello, Ruben!`. The Future completes once the C# method returns.

## Return values

```csharp
[FlunityOutlet]
public string Greet(GreetArgs args) => $"Hello, {args.name}!";
```

```dart
final greeting = await flunity.invoke<String>('Greeter.Greet', args: {'name': 'Ruben'});
print(greeting);  // → "Hello, Ruben!"
```

Supported return types: `void`, primitives (`bool`, `int`, `long`, `float`, `double`, `string`), and any `[Serializable]` C# class — Unity's `JsonUtility` handles the wire format. Complex types come back to Dart as `Map<String, dynamic>`.

## Async

```csharp
[FlunityOutlet]
public async Task<bool> Warmup(WarmupArgs args) {
    await Task.Delay(500);   // imagine: load assets, prefetch a scene
    return true;
}
```

```dart
final ok = await flunity.invoke<bool>('Greeter.Warmup', args: {});
```

The Future stays pending until the `Task` completes. Configurable timeout (default 5s):

```dart
await flunity.invoke<bool>('Greeter.Warmup',
  args: {'reason': 'init'},
  timeout: const Duration(seconds: 30),
);
```

## Static methods

For app-level operations that don't logically belong to a specific instance:

```csharp
public static class GameApi {
    [FlunityOutlet]
    public static void Pause() => Time.timeScale = 0;

    [FlunityOutlet]
    public static int CurrentLevel() => UnityEngine.SceneManagement.SceneManager.GetActiveScene().buildIndex;
}
```

```dart
await flunity.invoke('GameApi.Pause');
final level = await flunity.invoke<int>('GameApi.CurrentLevel');
```

No instance, no scene-graph lookup.

## Multiple instances

When several MonoBehaviours of the same type expose the same outlet, calls without a `target:` get a clear error:

```
FlunityOutletException: Pet.Feed is ambiguous: 3 instances of Pet; pass `target:` (FlunityIdentity or InstanceID)
```

Two ways to disambiguate.

### Option A — `[FlunityIdentity]` field

```csharp
public class Pet : MonoBehaviour {
    [FlunityIdentity] public string petId;   // set in Inspector or Awake

    [FlunityOutlet]
    public void Feed(FeedArgs args) { hunger -= args.amount; }
}
```

```dart
await flunity.invoke('Pet.Feed', target: 'bunny',  args: {'amount': 10});
await flunity.invoke('Pet.Feed', target: 'foxxy', args: {'amount': 5});
```

### Option B — discover them via `find`

```dart
final pets = await flunity.find('Pet');
for (final pet in pets) {
  print('${pet.id} at ${pet.path}');
  await pet.invoke('Feed', args: {'amount': 10});
}
```

`find` returns `List<FlunityComponentHandle>`. Each handle has:

- `id` — the `[FlunityIdentity]` value if set, otherwise the Unity `InstanceID` formatted as a string. Either is a valid `target` for follow-up calls.
- `name` — class name (e.g. `Pet`).
- `path` — full scene-graph path (e.g. `Forest/Trees/Pet`).
- `invoke(method, args:)` — sugar for `flunity.invoke('${this.name}.${method}', target: this.id, args: ...)`.

Unity uses `Resources.FindObjectsOfTypeAll<T>()` filtered to scene-loaded objects (skips prefabs in assets, includes inactive GameObjects).

## Errors

| Failure | Dart exception | Cause |
| --- | --- | --- |
| C# method threw | `FlunityOutletException` | `e.unityMessage` is the C# exception message verbatim. Stack trace stays on Unity's console. |
| No matching outlet | `FlunityOutletException("no such outlet 'Foo.Bar'")` | Typo or method missing the attribute. |
| Multiple matches without `target:` | `FlunityOutletException("X.Y is ambiguous: N instances; pass target:")` | Use `[FlunityIdentity]` or `find` first. |
| No reply within timeout | `FlunityOutletTimeoutException` | Increase per-call timeout, or check Unity console for an exception. |
| WebGL / desktop / web | `FlunityNotAttachedException` | v1 is iOS / Android only. |

## Limitations to know about

- **Method shape**: zero or one parameter. The single parameter must be a `[Serializable]` C# class — primitives directly aren't supported (use `class FeedArgs { public int amount; }` rather than `void Feed(int amount)`). The arg field names must match the Dart `args:` map keys.
- **Public methods only.** Private / protected methods aren't picked up.
- **One outlet per name** — registry rejects duplicate static outlets at scan time.
- **Coroutines** (`IEnumerator` returns) aren't supported in v1. Use `async Task` instead.
- **Scene transitions**: the registry rescans on Awake, so newly-loaded scenes contribute outlets the next time the registry's GameObject's Awake fires. Since `FlunityBridgeBehaviour` is `DontDestroyOnLoad`, the registry survives — re-scanning happens via `Resources.FindObjectsOfTypeAll` at lookup time, so newly added scene MonoBehaviours are found without an explicit rescan.

## Why this over `OnMessage`?

The `OnMessage` event-style API still exists and works. Use it when you want full control over inbound dispatch (e.g., handle messages off the main thread, write your own routing). Use outlets when you want the typed-RPC ergonomics — most application code wants outlets.
