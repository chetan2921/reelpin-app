import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/services/sharing/collection_link.dart';

void main() {
  test('parses a share link', () {
    final link = CollectionLink.parse(Uri.parse('https://reelpin.in/c/abc123'));
    expect(link, isNotNull);
    expect(link!.token, 'abc123');
    expect(link.isInvite, isFalse);
  });

  test('parses an invite link', () {
    final link = CollectionLink.parse(
      Uri.parse('https://reelpin.in/c/invite/xyz789'),
    );
    expect(link, isNotNull);
    expect(link!.token, 'xyz789');
    expect(link.isInvite, isTrue);
  });

  test('ignores a trailing slash and query on a share link', () {
    final link = CollectionLink.parse(
      Uri.parse('https://reelpin.in/c/abc123/?utm_source=whatsapp'),
    );
    expect(link?.token, 'abc123');
  });

  test('parses a custom-scheme share link', () {
    final link = CollectionLink.parse(Uri.parse('reelpin://c/abc123'));
    expect(link, isNotNull);
    expect(link!.token, 'abc123');
    expect(link.isInvite, isFalse);
  });

  test('parses a custom-scheme invite link', () {
    final link = CollectionLink.parse(Uri.parse('reelpin://c/invite/xyz789'));
    expect(link, isNotNull);
    expect(link!.token, 'xyz789');
    expect(link.isInvite, isTrue);
  });

  test('parses links on the dedicated link host', () {
    // Links now come from link.reelpin.in, which serves nothing but /c/ links.
    // The parser matches on path, not host, so both hosts must keep working
    // while links already sent out point at the old one.
    final invite = CollectionLink.parse(
      Uri.parse('https://link.reelpin.in/c/invite/xyz789'),
    );
    expect(invite?.token, 'xyz789');
    expect(invite?.isInvite, isTrue);

    final share = CollectionLink.parse(
      Uri.parse('https://link.reelpin.in/c/abc123'),
    );
    expect(share?.token, 'abc123');
    expect(share?.isInvite, isFalse);
  });

  test('returns null for URLs that are not collection links', () {
    for (final url in [
      'https://reelpin.in/',
      'https://reelpin.in/c',
      'https://reelpin.in/c/',
      'https://reelpin.in/collections/abc',
      'https://reelpin.linkrunner.io/xyz',
      'com.chetanjain.reelpin://login-callback',
      'com.chetan.reelpin://login-callback',
      'reelpin://c',
    ]) {
      expect(
        CollectionLink.parse(Uri.parse(url)),
        isNull,
        reason: 'expected $url not to parse as a collection link',
      );
    }
  });
}
