import 'dart:io';

/// Enforces the layer-first folder contract under `lib/`.
///
/// Layout:
///   components/   widgets reused by more than one screen
///   constants/    colours, spacing, layout, theme
///   data_models/  data-only classes grouped by area
///   http/         backend endpoint groups + the shared client
///   repositories/ stateful caches over http
///   screens/      full pages, with screen-only widgets in `partials/`
///   services/     platform and lifecycle integrations
///   utils/        pure helpers
///   view_models/  ChangeNotifier state classes
///   root files    entry points, providers, router, env
void main() {
  final violations = <String>[];

  for (final directory in _retiredDirectories) {
    if (Directory('lib/$directory').existsSync()) {
      violations.add(
        'lib/$directory still exists; it was replaced by the '
        'layer-first folders',
      );
    }
  }

  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.path.replaceAll('\\', '/'))
          .toList()
        ..sort();

  for (final path in files) {
    final relative = path.substring('lib/'.length);
    violations.addAll(_namingViolations(relative));

    final layer = _layerOf(relative);
    final allowed = _allowedImports[layer];

    for (final importPath in _importPaths(File(path))) {
      final importLayer = _layerOf(importPath);
      if (allowed != null && !allowed.contains(importLayer)) {
        violations.add(
          '$path imports $importPath ($layer must not depend on '
          '$importLayer)',
        );
      }
      if (layer == 'screens' && importLayer == 'screens') {
        violations.addAll(_partialsViolations(path, relative, importPath));
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

const _retiredDirectories = ['app', 'core', 'features'];

/// Every layer may import itself. `screens` may import anything, and the root
/// entry points wire the whole app together, so neither is listed here.
const _allowedImports = <String, Set<String>>{
  'constants': {'constants'},
  'data_models': {'data_models'},
  'utils': {'utils', 'constants', 'data_models', 'http', 'root'},
  'http': {'http', 'constants', 'data_models', 'services', 'utils', 'root'},
  'services': {'services', 'constants', 'data_models', 'http', 'utils', 'root'},
  'repositories': {
    'repositories',
    'constants',
    'data_models',
    'http',
    'services',
    'utils',
    'root',
  },
  'view_models': {
    'view_models',
    'constants',
    'data_models',
    'http',
    'repositories',
    'services',
    'utils',
    'root',
  },
  'components': {
    'components',
    'constants',
    'data_models',
    'http',
    'repositories',
    'services',
    'utils',
    'view_models',
    'root',
  },
};

String _layerOf(String relativePath) {
  final segments = relativePath.split('/');
  return segments.length == 1 ? 'root' : segments.first;
}

Iterable<String> _importPaths(File file) {
  final pattern = RegExp("^import 'package:reelpin/([^']+)';");
  return file
      .readAsLinesSync()
      .map((line) => pattern.firstMatch(line.trim())?.group(1))
      .whereType<String>();
}

/// A screen may only use its own `partials/`.
Iterable<String> _partialsViolations(
  String path,
  String relative,
  String importPath,
) {
  if (!importPath.contains('/partials/')) return const [];
  final owner = importPath.split('/partials/').first;
  if (relative.startsWith('$owner/')) return const [];
  return [
    '$path imports $importPath (partials belong to $owner only; promote the '
        'widget to components/ if more than one screen needs it)',
  ];
}

Iterable<String> _namingViolations(String relative) {
  final violations = <String>[];
  final name = relative.split('/').last;
  final layer = _layerOf(relative);

  if (layer == 'view_models' &&
      !name.endsWith('_view_model.dart') &&
      !_viewModelExceptions.contains(name)) {
    violations.add('lib/$relative should be named *_view_model.dart');
  }

  if (layer == 'http' &&
      !name.endsWith('_http.dart') &&
      !_httpExceptions.contains(name)) {
    violations.add('lib/$relative should be named *_http.dart');
  }

  if (name.endsWith('_viewmodel.dart')) {
    violations.add('lib/$relative uses _viewmodel.dart; use _view_model.dart');
  }

  if (_vagueNames.any((vague) => name == vague)) {
    violations.add(
      'lib/$relative has a vague name; describe the subject and '
      'the responsibility',
    );
  }

  if (layer == 'screens') {
    final segments = relative.split('/');
    if (segments.length < 2) {
      violations.add('lib/$relative must live in screens/<screen_name>/');
    } else if (!relative.contains('/partials/') &&
        segments.length > 2 &&
        !name.endsWith('_screen.dart') &&
        !name.endsWith('_shell.dart')) {
      violations.add(
        'lib/$relative is neither a screen nor a shell; '
        'screen-only widgets belong in partials/',
      );
    }
  }

  if (name.endsWith('_screen.dart') && layer != 'screens') {
    violations.add('lib/$relative is a screen and belongs under screens/');
  }

  return violations;
}

const _viewModelExceptions = ['user_state_coordinator.dart'];
const _httpExceptions = ['api_client.dart', 'api_exception.dart'];
const _vagueNames = [
  'helper.dart',
  'helpers.dart',
  'common.dart',
  'data.dart',
  'utils.dart',
  'misc.dart',
  'shared.dart',
];
