import 'dart:io';

void main() {
  final assetDirectory = Directory('assets/images');
  if (!assetDirectory.existsSync()) {
    stderr.writeln('Missing assets/images.');
    exitCode = 1;
    return;
  }

  final sourceFiles = [
    ...Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
    File('pubspec.yaml'),
  ];
  final source = sourceFiles.map((file) => file.readAsStringSync()).join('\n');
  final unused = assetDirectory
      .listSync()
      .whereType<File>()
      .where((file) => !source.contains(file.uri.pathSegments.last))
      .map((file) => file.path)
      .toList(growable: false);

  if (unused.isEmpty) {
    stdout.writeln('All image assets are referenced.');
    return;
  }

  stderr.writeln('Unreferenced image assets:');
  for (final path in unused) {
    stderr.writeln('  $path');
  }
  exitCode = 1;
}
