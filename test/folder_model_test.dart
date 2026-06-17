import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/discover_response.dart';
import 'package:reelpin/models/folder.dart';

void main() {
  test('parses folder summary from backend json', () {
    final folder = FolderSummary.fromJson({
      'id': 'folder-123',
      'name': 'Goa trip',
      'note': ' Places to shortlist ',
      'reel_count': 3,
      'created_at': '2026-06-13T10:00:00Z',
      'updated_at': '2026-06-13T11:00:00Z',
    });

    expect(folder.id, 'folder-123');
    expect(folder.name, 'Goa trip');
    expect(folder.note, 'Places to shortlist');
    expect(folder.reelCount, 3);
    expect(folder.updatedAt, '2026-06-13T11:00:00Z');
  });

  test('discover response accepts folder summaries', () {
    final discover = DiscoverResponse.fromJson({
      'recent_saves': <Map<String, Object?>>[],
      'recent_saves_count': 0,
      'saved_dates': <Map<String, Object?>>[],
      'reels_for_selected_date': <Map<String, Object?>>[],
      'category_grid': <Map<String, Object?>>[],
      'quick_search_prompts': <String>[],
      'pagination': {'has_more': false, 'limit': 25, 'offset': 0},
      'folders': [
        {
          'id': 'folder-123',
          'name': 'Goa trip',
          'note': 'Places',
          'reel_count': 2,
          'updated_at': '2026-06-13T11:00:00Z',
        },
      ],
    });

    expect(discover.folders.single.id, 'folder-123');
    expect(discover.folders.single.reelCount, 2);
  });
}
