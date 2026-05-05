import 'package:flunity_bridge/flunity_bridge.dart';

FlunityWebGLConfig resolveFlunityConfig() {
  const mode = String.fromEnvironment('FLUNITY_MODE', defaultValue: 'bundled');
  if (mode == 'dev') {
    const host =
        String.fromEnvironment('FLUNITY_DEV_HOST', defaultValue: '127.0.0.1');
    const port = int.fromEnvironment('FLUNITY_DEV_PORT', defaultValue: 8080);
    return FlunityWebGLConfig.dev(host: host, port: port);
  }
  return FlunityWebGLConfig.bundled();
}
