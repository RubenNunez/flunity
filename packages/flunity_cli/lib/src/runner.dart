import 'package:args/command_runner.dart';
import 'package:flunity_cli/src/commands/bridge_command.dart';
import 'package:flunity_cli/src/commands/build_command.dart';
import 'package:flunity_cli/src/commands/bundle_command.dart';
import 'package:flunity_cli/src/commands/create_command.dart';
import 'package:flunity_cli/src/commands/doctor_command.dart';
import 'package:flunity_cli/src/commands/webgl_command.dart';
import 'package:mason_logger/mason_logger.dart';

const String flunityVersion = '0.1.0';

Future<int> runFlunityCli(List<String> args, {Logger? logger}) async {
  final log = logger ?? Logger();
  final runner =
      CommandRunner<int>(
          'flunity',
          'Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.',
        )
        ..argParser.addFlag(
          'version',
          abbr: 'v',
          negatable: false,
          help: 'Print the flunity version.',
        )
        ..addCommand(BridgeCommand(logger: log))
        ..addCommand(BuildCommand(logger: log))
        ..addCommand(BundleCommand(logger: log))
        ..addCommand(CreateCommand(logger: log))
        ..addCommand(DoctorCommand(logger: log))
        ..addCommand(WebGLCommand(logger: log));

  try {
    // Only treat --version / -v as a top-level short-circuit when it's the
    // FIRST argument. Otherwise let it pass through to the subcommand so
    // `flunity create -v my_app` doesn't print the version and exit.
    if (args.isNotEmpty && (args.first == '--version' || args.first == '-v')) {
      log.info('flunity $flunityVersion');
      return 0;
    }
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    log.err(e.toString());
    return 64;
  }
}
