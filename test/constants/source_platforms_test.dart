import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/constants/source_platforms.dart';

void main() {
  test('TikTok is available on every shared platform surface', () {
    final platform = SourcePlatform.byId(' TIKTOK ');
    expect(platform, isNotNull);
    expect(platform!.name, 'TikTok');
    expect(platform.assetPath, 'assets/images/tiktok.png');
    expect(
      SourcePlatform.all.where((value) => value.id == 'tiktok'),
      hasLength(1),
    );
  });

  test('TikTok copy distinguishes videos, photos and page links', () {
    final platform = SourcePlatform.tiktok;
    expect(platform.itemNoun(contentType: 'video'), 'VIDEO');
    expect(platform.itemNoun(contentType: 'post'), 'POST');
    expect(platform.itemNoun(contentType: 'link'), 'LINK');
    expect(
      platform.itemNoun(sourceUrl: 'https://www.tiktok.com/@a/photo/123'),
      'POST',
    );
    expect(
      platform.itemNoun(sourceUrl: 'https://www.tiktok.com/@a/live'),
      'LINK',
    );
    expect(platform.itemNoun(sourceUrl: 'https://vm.tiktok.com/ABC'), 'VIDEO');
    expect(SourcePlatform.instagram.itemNoun(contentType: 'post'), 'REEL');
  });

  test('legacy TikTok URLs resolve without matching lookalike hosts', () {
    for (final url in [
      'https://www.tiktok.com/@a/video/123',
      'https://vm.tiktok.com/ABC',
      'https://vt.tiktok.com/ABC',
      'https://www.tiktokv.com/share/video/123',
      'https://shop.tiktok.com/product/123',
    ]) {
      expect(SourcePlatform.fromTikTokUrl(url), SourcePlatform.tiktok);
    }
    expect(
      SourcePlatform.fromTikTokUrl('https://tiktok.com.example.com/123'),
      isNull,
    );
    expect(SourcePlatform.fromTikTokUrl('https://nottiktok.com/123'), isNull);
  });
}
