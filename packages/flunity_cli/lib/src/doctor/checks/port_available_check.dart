import 'dart:io';

import 'package:flunity_cli/src/doctor/check.dart';

class PortAvailableCheck implements Check {
  PortAvailableCheck({required this.host, required this.port});
  final String host;
  final int port;

  @override
  String get name => 'Dev server port $port available';

  @override
  Future<CheckResult> run() async {
    try {
      final socket = await ServerSocket.bind(host, port);
      await socket.close();
      return CheckResult.ok('$host:$port is free');
    } on SocketException {
      return CheckResult.warn(
        '$host:$port is already in use.',
        hint:
            'Either stop the other process, or set webgl.dev_server.port in flunity.yaml.',
      );
    }
  }
}
