# Bridge API

> **Looking for the typed Flutter→Unity invoke API?** See [outlets.md](outlets.md). Outlets are the recommended way to call Unity from Flutter for new code; this page covers the lower-level `FlunityMessage` envelope they're built on, plus the manual `OnMessage` event pattern for cases where outlets don't fit — background telemetry streams, multi-receiver fanout, custom routing.

Flutter and Unity exchange JSON messages of the form:

```json
{ "type": "<string>", "payload": <JSON object> }
```

## Built-in message types

| Type | Direction | Payload |
| --- | --- | --- |
| `ping` | Flutter → Unity | `{ "nonce": "<string>" }` |
| `pong` | Unity → Flutter | `{ "nonce": "<string>" }` (echoes the ping nonce) |
| `load_scene` | Flutter → Unity | `{ "scene": "<string>" }` |
| `scene_ready` | Unity → Flutter | `{}` |
| `outlet_call` | Flutter → Unity | `{ "name": "Class.Method", "nonce": ..., "target"?, "args"? }` — see [outlets.md](outlets.md) |
| `outlet_reply` | Unity → Flutter | `{ "nonce": ..., "ok": bool, "value"?, "error"? }` |
| `outlet_find` | Flutter → Unity | `{ "nonce": ..., "component": "Pet" }` |
| `outlet_find_reply` | Unity → Flutter | `{ "nonce": ..., "components": [{id, name, path}] }` |

`FlunityBridge.cs` auto-handles `ping` (replies with `pong`). The default `FlunityBridgeDemo.cs` handles `load_scene` and replies with `scene_ready`.

## Flutter side

Sealed-style hierarchy with a `RawMessage` escape hatch:

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

void main() {
  registerBuiltInMessages();        // call once at startup
  // ...
}

// Sending:
controller.send(const Ping(nonce: 'hello'));
controller.send(const LoadScene(scene: 'ProductViewer'));

// Receiving (typed):
controller.messages.listen((msg) {
  if (msg is Pong) print('pong: ${msg.nonce}');
  else if (msg is SceneReady) print('scene loaded');
  else if (msg is RawMessage) {
    // Unknown message type — payload is a Map<String, Object?>
    print('${msg.type}: ${msg.payload}');
  }
});
```

## Adding your own message types

```dart
final class TakeScreenshot extends FlunityMessage {
  const TakeScreenshot({required this.format});

  static const String typeName = 'take_screenshot';
  static void register() {
    FlunityMessage.registerType(typeName, (payload) {
      final fmt = payload['format'];
      if (fmt is! String) {
        throw const FormatException('TakeScreenshot requires string format');
      }
      return TakeScreenshot(format: fmt);
    });
  }

  final String format;

  @override
  String get type => typeName;

  @override
  Map<String, Object?> get payload => <String, Object?>{'format': format};
}

void main() {
  registerBuiltInMessages();
  TakeScreenshot.register();
  runApp(...);
}
```

Custom types are not exhaustively matchable; they coexist with built-ins because `FlunityMessage` is `abstract` (not `sealed`) — the trade-off is that users can extend it from their own libraries.

## Unity side

Subscribe to `FlunityBridge.OnMessage`:

```csharp
using Flunity;
using UnityEngine;

public class MyHandler : MonoBehaviour {
    void OnEnable()  { FlunityBridge.OnMessage += Handle; }
    void OnDisable() { FlunityBridge.OnMessage -= Handle; }

    void Handle(string type, string payloadJson) {
        if (type == "take_screenshot") {
            var p = JsonUtility.FromJson<ScreenshotPayload>(payloadJson);
            // … snap, encode, return …
            FlunityBridge.Send("screenshot_ready", new ScreenshotResult { png = encoded });
        }
    }

    [System.Serializable] public class ScreenshotPayload { public string format; }
    [System.Serializable] public class ScreenshotResult  { public string png; }
}
```

`FlunityBridge.Send<T>(type, payload)` JSON-serializes `payload` via Unity's `JsonUtility` (so the type must be `[Serializable]` with public fields). For richer scenarios, use `FlunityBridge.SendRaw(type, jsonString)` and serialize yourself.

## When to use this vs. outlets

Reach for `OnMessage` + custom message types when you need:
- **Stream-style data** — Unity pushes telemetry / scene events on its own cadence; Flutter listens. Outlets are a request/reply RPC, not a stream.
- **Multi-receiver fanout** — several Flutter widgets each want to react to the same Unity event independently. The `OnMessage` event is multi-listener; outlets correlate to one awaiting `Future`.
- **Stable wire format you control** — when shipping a public protocol where you don't want to commit to outlet naming conventions or auto-discovery.

For everything else — "tell Unity to do X and let me know when it's done" — use outlets ([outlets.md](outlets.md)). They handle nonce correlation, error routing, async (`Task<T>`), and scene discovery so you don't have to.
