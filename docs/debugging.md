# Debugging

Two tools ship with Flunity for inspecting what's happening between Flutter and Unity at runtime: a **log stream** and a **scene inspector**. Both work over the same bridge, so they cost almost nothing — they're available the moment `[FlunityBridge]` is in your scene.

You wire them up in your Flutter app once; the C# side is auto-attached.

## Log stream

`FlunityLogStream` (singleton: `flunityLogs`) collects every Unity `Debug.Log/Warning/Error` line plus every Flutter `debugPrint` into a single in-memory ring buffer (default 500 entries). Outlet calls — `flunity.invoke` / `flunity.find` — are also recorded automatically as `← outlet_call` / `→ outlet_reply` rows.

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  flunityLogs;          // initialise early so startup logs are captured
  runApp(const App());
}

// Anywhere in your UI:
StreamBuilder<void>(
  stream: flunityLogs.changes,
  builder: (context, _) => ListView(
    children: [for (final e in flunityLogs.entries) Text(e.toString())],
  ),
);
```

Each `FlunityLogEntry` carries `timestamp`, `source` (`unity` / `flutter`), `level` (`info` / `warn` / `error`), `message`, optional `stackTrace`. The `toString()` is a compact single-line format suitable for monospace rendering.

The Unity-side forwarder (`FlunityLogStreamer` MonoBehaviour) is auto-attached on `[FlunityBridge]`. It skips logs in the Editor (no Flutter consumer there) and filters its own bridge diagnostics to avoid recursion.

## Scene inspector

Two system outlets, also auto-attached, expose Unity's scene to Flutter:

| Outlet | Returns |
| --- | --- |
| `Flunity.Scene.Tree()` | Full scene-graph as a tree of `{id, name, active, components[], children[]}` nodes. |
| `Flunity.Scene.Inspect({id})` | One GameObject's components + their public fields + the outlets each component exposes. |

Call them like any other outlet:

```dart
final tree = await flunity.invoke<Map<String, Object?>>('Flunity.Scene.Tree');
final info = await flunity.invoke<Map<String, Object?>>(
  'Flunity.Scene.Inspect',
  args: {'id': '12345'},
);
```

The jellx demo app wires these into a terminal-style **Inspector** tab where you type commands directly:

```
> tree
> find Creature
> inspect 12345
> call Creature.Feed
> call Pet.Feed {"target":"bunny","amount":10}
```

See `app/lib/unity/inspector_panel.dart` in jellx for the implementation — it's ~300 lines and reusable as-is in any flunity_bridge consumer.

## First thing to try when an outlet doesn't reply

If `flunity.invoke('X.Y')` times out:

1. Open your debug sheet → Inspector tab → type `tree`. If Tree returns the scene, the bridge is healthy and the issue is dispatch-side. If Tree itself times out, the bridge is broken — `[FlunityBridge]` GameObject probably missing or inactive.
2. Type `find <ClassName>`. Confirms whether an instance of the target component is actually loaded in any scene.
3. Type `call X.Y` directly from the Inspector. Bypasses your UI code — if this works but your button doesn't, the bug is on your Flutter side.
4. Filter the Logs tab to **Unity** — look for `[Flunity] outlet_call rx: X.Y`. Present → registry got the call (drill into the C# method). Absent → call never reached Unity (singleton issue, GameObject lookup failure).

In >90% of cases one of those four steps points at the line.

## Disabling

Both tools are pure-additive — if you don't initialize `flunityLogs` and don't call the Scene outlets, the auto-attached MonoBehaviours sit idle (one no-op `OnLog` registration, no per-frame work). You can also remove `FlunityLogStreamer` / `FlunitySceneInspector` from `[FlunityBridge]` if you really want zero overhead, but the cost is already negligible.
