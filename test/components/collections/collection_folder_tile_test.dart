import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/components/collections/collection_folder_tile.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';

CollectionSummary _c(String id, String createdAt) =>
    CollectionSummary(id: id, name: id, createdAt: createdAt);

void main() {
  final five = [
    _c('a', '2026-01-01T00:00:00Z'),
    _c('b', '2026-01-02T00:00:00Z'),
    _c('c', '2026-01-03T00:00:00Z'),
    _c('d', '2026-01-04T00:00:00Z'),
    _c('e', '2026-01-05T00:00:00Z'),
  ];

  test('every collection gets a different colour while the palette lasts', () {
    final accents = CollectionFolderTile.accentsFor(five);
    expect(accents.values.toSet().length, five.length);
  });

  test('a collection keeps its colour when the grid reorders', () {
    // Saving into a collection moves it to the front of the grid. That must not
    // repaint it, or any of the folders it moved past.
    final before = CollectionFolderTile.accentsFor(five);
    final reordered = [five.last, ...five.take(five.length - 1)];
    expect(CollectionFolderTile.accentsFor(reordered), before);
  });

  test('creating a collection does not recolour the existing ones', () {
    final existing = [five[0], five[1]];
    final before = CollectionFolderTile.accentsFor(existing);

    final after = CollectionFolderTile.accentsFor([
      ...existing,
      _c('new', '2026-02-01T00:00:00Z'),
    ]);

    expect(after['a'], before['a']);
    expect(after['b'], before['b']);
    expect(after['new'], isNot(before['a']));
    expect(after['new'], isNot(before['b']));
  });

  test('the palette cycles once every colour is taken', () {
    final six = [...five, _c('f', '2026-01-06T00:00:00Z')];
    final accents = CollectionFolderTile.accentsFor(six);
    expect(accents['f'], accents['a']);
  });
}
