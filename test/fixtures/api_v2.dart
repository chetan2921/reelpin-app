import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A response captured from the Go service's real handlers. The files in
/// `test/fixtures/api_v2/` are verbatim copies of reelpin-go `api/fixtures/`
/// at commit c236a06 (`map_pins.json` at ee1e696), so a diff against that
/// folder shows any drift.
class ApiV2Fixture {
  ApiV2Fixture(String name)
    : _raw =
          jsonDecode(File('test/fixtures/api_v2/$name.json').readAsStringSync())
              as Map<String, dynamic>;

  final Map<String, dynamic> _raw;

  int get status => _raw['status'] as int;

  Map<String, dynamic> get body => _raw['response'] as Map<String, dynamic>;

  http.Response toResponse() => http.Response(jsonEncode(body), status);
}
