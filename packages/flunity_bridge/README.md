# flunity_bridge

Flutter package providing the runtime side of [Flunity](https://github.com/RubenNunez/flunity): a `FlunityWebGLView` widget, a controller, typed `FlunityMessage` types, and a dev/bundled config switch for running Unity WebGL inside Flutter.

Use the `flunity_cli` tool to scaffold projects that consume this package.

## Quickstart

```dart
import 'package:flunity_bridge/flunity_bridge.dart';

void main() {
  registerBuiltInMessages(); // <-- call once at startup
  runApp(const MyApp());
}

// Inside a screen:
FlunityWebGLView(
  config: const FlunityWebGLConfig.dev(port: 8080),
  onReady: (controller) {
    controller.send(const Ping(nonce: 'hello'));
  },
  onMessage: (msg) {
    if (msg is Pong) print('Got pong: ${msg.nonce}');
  },
);
```

## License

MIT.
