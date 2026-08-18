import 'dart:async';

import 'package:reelpin/data_models/collections/collection_models.dart';

/// Carries an in-flight shared-collection fetch from the splash to the screen
/// that displays it.
///
/// The screen can only start its own fetch once it is mounted, which on a cold
/// start is behind session bootstrap and the shell. That leaves the whole round
/// trip on the critical path, as a spinner the user watches after already
/// waiting for the app to open. The link token is known far earlier — the launch
/// URL is captured in bootstrap — and the endpoint is public, so the request can
/// run alongside everything else instead of after it.
class SharedCollectionPrefetch {
  SharedCollectionPrefetch._();

  static String? _token;
  static Future<CollectionDetail>? _pending;

  /// Starts [load] for [token] unless it is already running.
  static void start(String token, Future<CollectionDetail> Function() load) {
    if (_token == token) return;
    _token = token;
    // A failure has no listener until the screen mounts. `ignore` only silences
    // the unawaited-error report for that window; whoever calls [take] still
    // receives the error and shows it.
    _pending = load()..ignore();
  }

  /// The fetch started for [token], once. Null when this token was never
  /// prefetched, which leaves the caller to load it the usual way.
  static Future<CollectionDetail>? take(String token) {
    if (_token != token) return null;
    final pending = _pending;
    _token = null;
    _pending = null;
    return pending;
  }
}
