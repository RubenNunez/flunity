import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

const String flunityVersion = '0.1.0';

Future<int> runFlunityCli(List<String> args, {Logger? logger}) async {
  final log = logger ?? Logger();
  final runner = CommandRunner<int>(
    'flunity',
    'Flutter-first toolkit and CLI for embedding Unity inside Flutter apps.',
  )..argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the flunity version.',
    );

  // Commands wired in later phases. For now just version + --help.
  try {
    final results = runner.argParser.parse(args);
    if (results['version'] == true) {
      log.info('flunity $flunityVersion');
      return 0;
    }
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    log.err(e.toString());
    return 64;
  }
}
