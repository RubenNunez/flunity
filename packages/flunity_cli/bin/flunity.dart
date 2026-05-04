import 'dart:io';

import 'package:flunity_cli/src/runner.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runFlunityCli(args);
  exit(exitCode);
}
