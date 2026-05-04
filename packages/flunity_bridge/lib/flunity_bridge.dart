/// Flunity bridge: embed Unity WebGL inside Flutter with a typed message bridge.
///
/// Consumers must call [registerBuiltInMessages] once at app startup (typically
/// in `main()`) before any [FlunityMessage.fromJson] calls. Plan C's templates
/// do this for generated apps. Direct consumers should call it themselves —
/// see the package README for an example.
library flunity_bridge;

export 'package:flunity_bridge/src/flunity_message.dart';
export 'package:flunity_bridge/src/flunity_webgl_config.dart';
export 'package:flunity_bridge/src/flunity_webgl_controller.dart';
export 'package:flunity_bridge/src/flunity_webgl_view.dart';
export 'package:flunity_bridge/src/messages/built_in.dart' show registerBuiltInMessages;
export 'package:flunity_bridge/src/messages/load_scene.dart';
export 'package:flunity_bridge/src/messages/ping.dart';
export 'package:flunity_bridge/src/messages/pong.dart';
export 'package:flunity_bridge/src/messages/scene_ready.dart';
export 'package:flunity_bridge/src/transport/message_transport.dart';
