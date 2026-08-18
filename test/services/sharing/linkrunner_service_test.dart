import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/env.dart';
import 'package:reelpin/services/sharing/linkrunner_service.dart';

/// These run in the default (unconfigured) build, where no LINKRUNNER_TOKEN is
/// defined. That is the state every existing build ships in today, so the
/// contract that matters most is: the SDK stays out of the way entirely and
/// direct /c/ links keep resolving exactly as they did before.
void main() {
  test('an unconfigured build reports no token', () {
    expect(LinkrunnerConfig.isConfigured, isFalse);
    expect(LinkrunnerConfig.token, isEmpty);
    expect(LinkrunnerConfig.secretKey, isNull);
    expect(LinkrunnerConfig.keyId, isNull);
  });

  test('init is a no-op without a token', () async {
    await LinkrunnerService.instance.init();

    expect(LinkrunnerService.instance.isInitialised, isFalse);
  });

  test('resolve returns a share link untouched when uninitialised', () async {
    final incoming = Uri.parse('https://reelpin.in/c/tok-abc');

    expect(await LinkrunnerService.instance.resolve(incoming), incoming);
  });

  test('resolve returns an invite link untouched when uninitialised', () async {
    final incoming = Uri.parse('https://reelpin.in/c/invite/inv-1');

    expect(await LinkrunnerService.instance.resolve(incoming), incoming);
  });

  test('deferredLink is null when uninitialised', () async {
    expect(await LinkrunnerService.instance.deferredLink(), isNull);
  });
}
