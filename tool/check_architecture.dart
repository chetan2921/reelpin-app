import 'dart:io';

final _importPattern = RegExp("^import 'package:reelpin/([^']+)';");

void main() {
  final violations = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    final imports = file.readAsLinesSync().map(_importPath).whereType<String>();

    for (final importPath in imports) {
      final isApiImplementation = path == 'lib/core/network/api_service.dart';
      if (path.startsWith('lib/core/') &&
          !isApiImplementation &&
          (importPath.startsWith('app/') ||
              importPath.startsWith('features/'))) {
        violations.add('$path imports $importPath');
      }

      if (path.contains('/domain/') &&
          (importPath.startsWith('app/') ||
              importPath.contains('/presentation/') ||
              importPath.contains('/data/'))) {
        violations.add('$path imports $importPath');
      }

      if (path.contains('/data/') &&
          (importPath.startsWith('app/') ||
              importPath.contains('/presentation/'))) {
        violations.add('$path imports $importPath');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('Architecture boundaries are valid.');
    return;
  }

  stderr.writeln('Architecture boundary violations:');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exitCode = 1;
}

String? _importPath(String line) {
  return _importPattern.firstMatch(line.trim())?.group(1);
}
