import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/commands/create_command.dart';
import 'package:flunity_cli/src/commands/doctor_command.dart';
import 'package:flunity_cli/src/commands/webgl_command.dart';
import 'package:mason_logger/mason_logger.dart';

const String flunityVersion = '0.1.0';

Future<int> runFlunityCli(List<String> args, {Logger? logger}) async {
  final log = logger ?? Logger();
  final runner = CommandRunner<int>(
    'flunity',
    'Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.',
  )
    ..argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the flunity version.',
    )
    ..addCommand(CreateCommand(logger: log))
    ..addCommand(DoctorCommand(logger: log))
    ..addCommand(WebGLCommand(logger: log));

  try {
    if (args.contains('--version') || args.contains('-v')) {
      log.info('flunity $flunityVersion');
      return 0;
    }
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    log.err(e.toString());
    return 64;
  }
}
