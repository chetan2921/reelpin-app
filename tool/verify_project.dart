import 'dart:io';

void main() {
  const requiredPaths = [
    'analysis_options.yaml',
    'pubspec.yaml',
    'lib/main.dart',
    'assets/config',
    'assets/fonts',
    'assets/images',
    'android/app',
    'ios/Runner',
  ];
  const optionalLocalPaths = [
    'assets/config/local.env',
    'android/app/google-services.json',
    'ios/Runner/GoogleService-Info.plist',
  ];

  final missing = requiredPaths
      .where(
        (path) =>
            !FileSystemEntity.isFileSync(path) &&
            !FileSystemEntity.isDirectorySync(path),
      )
      .toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing required project paths:');
    for (final path in missing) {
      stderr.writeln('  $path');
    }
    exitCode = 1;
    return;
  }

  final missingLocal = optionalLocalPaths.where(
    (path) => !File(path).existsSync(),
  );
  for (final path in missingLocal) {
    stdout.writeln('Optional local configuration not found: $path');
  }
  stdout.writeln('Required project paths are present.');
}
