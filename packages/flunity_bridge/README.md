# flunity_bridge

Flutter package providing the runtime side of [Flunity](https://github.com/RubenNunez/flunity):
the `FlunityNativeView` widget embedding a native Unity instance (iOS/Android,
vendored from flutter_embed_unity v2.0.0, MIT), typed `FlunityMessage` types,
the outlet invoker (`flunity.invoke`), and the Unity log stream.

Use the `flunity_cli` tool to scaffold projects that consume this package.

## Quickstart

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

void main() {
  registerBuiltInMessages(); // <-- call once at startup
  runApp(const MyApp());
}

// Inside a screen (native iOS/Android target):
FlunityNativeView(
  onMessageFromUnity: (msg) => print('Unity says: $msg'),
);

// Call an outlet:
final reply = await flunity.invoke<bool>('SceneBlur.Set', args: {'amount': 1.0});
```

## License

MIT.
