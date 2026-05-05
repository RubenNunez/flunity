import 'package:flunity_bridge/flunity_bridge.dart';

/// Typed wrapper over [FlunityWebGLController] for app-specific messages.
/// Extend with your own [FlunityMessage] subclasses as the app grows.
class UnityWebGLBridge {
  UnityWebGLBridge(this.controller);
  final FlunityWebGLController controller;

  Future<void> loadScene(String name) =>
      controller.send(LoadScene(scene: name));

  Stream<SceneReady> get sceneReady =>
      controller.messages.where((m) => m is SceneReady).cast<SceneReady>();

  Future<String> ping() async {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final pong = controller.messages
        .firstWhere((m) => m is Pong && m.nonce == nonce)
        .timeout(const Duration(seconds: 5));
    await controller.send(Ping(nonce: nonce));
    final p = await pong as Pong;
    return p.nonce;
  }
}
