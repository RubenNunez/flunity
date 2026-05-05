# Bridge API

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
