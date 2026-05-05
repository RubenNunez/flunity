import 'dart:io';

import 'package:flunity_cli/src/templates/template_renderer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late Directory templateDir;
  late Directory outputDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flunity_template_');
    templateDir = Directory(p.join(tmp.path, 'tpl'))..createSync();
    outputDir = Directory(p.join(tmp.path, 'out'))..createSync();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('substitutes __var__ in file contents', () async {
    File(
      p.join(templateDir.path, 'README.md'),
    ).writeAsStringSync('Project: __app_name__');

    await renderTemplate(
      from: templateDir.path,
      to: outputDir.path,
      variables: {'app_name': 'my_app'},
    );

    expect(
      File(p.join(outputDir.path, 'README.md')).readAsStringSync(),
      'Project: my_app',
    );
  });

  test('substitutes __var__ in file and directory names', () async {
    final nested = Directory(p.join(templateDir.path, '__app_name__'))
      ..createSync();
    File(
      p.join(nested.path, '__app_name___main.dart'),
    ).writeAsStringSync('// __app_name__');

    await renderTemplate(
      from: templateDir.path,
      to: outputDir.path,
      variables: {'app_name': 'my_app'},
    );

    expect(
      File(
        p.join(outputDir.path, 'my_app', 'my_app_main.dart'),
      ).readAsStringSync(),
      '// my_app',
    );
  });

  test('preserves files without placeholders untouched', () async {
    File(p.join(templateDir.path, 'static.txt')).writeAsStringSync('hello');
    await renderTemplate(
      from: templateDir.path,
      to: outputDir.path,
      variables: {'app_name': 'x'},
    );
    expect(
      File(p.join(outputDir.path, 'static.txt')).readAsStringSync(),
      'hello',
    );
  });

  test('throws when required variable is missing', () async {
    File(p.join(templateDir.path, 'a.txt')).writeAsStringSync('__missing__');
    expect(
      () => renderTemplate(
        from: templateDir.path,
        to: outputDir.path,
        variables: {},
      ),
      throwsA(isA<TemplateException>()),
    );
  });

  test(
    'refuses to overwrite an existing destination unless force=true',
    () async {
      File(p.join(outputDir.path, 'existing.txt')).writeAsStringSync('keep me');
      File(p.join(templateDir.path, 'existing.txt')).writeAsStringSync('NEW');

      expect(
        () => renderTemplate(
          from: templateDir.path,
          to: outputDir.path,
          variables: const {},
        ),
        throwsA(isA<TemplateException>()),
      );

      await renderTemplate(
        from: templateDir.path,
        to: outputDir.path,
        variables: const {},
        force: true,
      );
      expect(
        File(p.join(outputDir.path, 'existing.txt')).readAsStringSync(),
        'NEW',
      );
    },
  );
}
