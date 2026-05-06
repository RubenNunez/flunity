import 'package:flunity_bridge/src/messages/load_scene.dart';
import 'package:flunity_bridge/src/messages/outlet_call.dart';
import 'package:flunity_bridge/src/messages/outlet_find.dart';
import 'package:flunity_bridge/src/messages/outlet_find_reply.dart';
import 'package:flunity_bridge/src/messages/outlet_reply.dart';
import 'package:flunity_bridge/src/messages/ping.dart';
import 'package:flunity_bridge/src/messages/pong.dart';
import 'package:flunity_bridge/src/messages/scene_ready.dart';

/// Registers all built-in [FlunityMessage] subclasses with the parser registry.
/// Called automatically when `package:flunity_bridge/flunity_bridge.dart` is
/// imported (see `lib/flunity_bridge.dart`). Safe to call repeatedly.
void registerBuiltInMessages() {
  Ping.register();
  Pong.register();
  LoadScene.register();
  SceneReady.register();
  OutletCall.register();
  OutletReply.register();
  OutletFind.register();
  OutletFindReply.register();
}
