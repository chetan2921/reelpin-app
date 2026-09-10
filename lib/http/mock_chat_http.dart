import 'dart:async';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/chat_http.dart';

/// Whether chat answers come from [MockChatHttp].
///
/// Defaults to **false** now that the real backend is live. Pass
/// `--dart-define=MOCK_CHAT=true` to fall back to the mock — useful when
/// working offline or without a dev-backend session.
const bool useMockChat = bool.fromEnvironment('MOCK_CHAT', defaultValue: false);

/// Answers from the user's own library so the feature can be demonstrated
/// before any backend exists.
///
/// Matching is a plain keyword overlap against category, subcategory and title
/// — it is a stand-in for retrieval, not an approximation of it.
class MockChatHttp implements ChatHttp {
  MockChatHttp({
    required List<Reel> Function() reelsSource,
    Duration stageDelay = const Duration(milliseconds: 650),
  }) : _reelsSource = reelsSource,
       _stageDelay = stageDelay;

  final List<Reel> Function() _reelsSource;
  final Duration _stageDelay;

  static const _stopWords = {
    'what',
    'which',
    'who',
    'where',
    'when',
    'how',
    'did',
    'do',
    'does',
    'i',
    'my',
    'me',
    'the',
    'a',
    'an',
    'about',
    'save',
    'saved',
    'saves',
    'is',
    'this',
    'that',
    'and',
    'for',
    'from',
    'have',
    'anything',
    'any',
  };

  @override
  Future<List<String>> fetchSuggestions() async {
    final library = _reelsSource();
    if (library.isEmpty) return const [];

    final topCategory = library.first.category.trim();
    return [
      if (topCategory.isNotEmpty)
        'What did I save about ${topCategory.toLowerCase()}?',
      'What have I been saving this week?',
      'Summarize what I saved this month.',
    ];
  }

  @override
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
    // Ignored: keyword matching has no notion of a conversation.
    List<ChatHistoryEntry> history = const [],
  }) async* {
    final library = _reelsSource();
    final matches = _match(text, library);
    final usingFallback = library.isEmpty;
    final reels = usingFallback ? _seedReels(text) : matches;

    yield* _stage('SEARCHING YOUR SAVES');

    if (reels.isNotEmpty) {
      final category = reels.first.category.toUpperCase();
      final subCategory = reels.first.subCategory.toUpperCase();
      yield* _stage('MATCHED → $category / $subCategory');
      yield* _stage('READING ${reels.length} REELS');
    }

    yield* _stage('WRITING ANSWER');

    yield AnswerEvent(_answer(text, reels, usingFallback: usingFallback));
  }

  Stream<ChatEvent> _stage(String label) async* {
    yield StageEvent(
      ThinkingStage(label: label, state: ThinkingStageState.active),
    );
    if (_stageDelay > Duration.zero) await Future<void>.delayed(_stageDelay);
    yield StageEvent(
      ThinkingStage(label: label, state: ThinkingStageState.done),
    );
  }

  List<Reel> _match(String query, List<Reel> library) {
    final terms = _terms(query);
    if (terms.isEmpty) return const [];

    return library.where((reel) {
      final haystack = [
        reel.category,
        reel.subCategory,
        reel.title,
        reel.summary,
      ].join(' ').toLowerCase();
      return terms.any(haystack.contains);
    }).toList();
  }

  Set<String> _terms(String query) {
    return query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 2 && !_stopWords.contains(word))
        .toSet();
  }

  List<AnswerBlock> _answer(
    String query,
    List<Reel> reels, {
    required bool usingFallback,
  }) {
    if (reels.isEmpty) {
      return const [
        TextBlock(
          "I couldn't find anything in your saves that matches this. Try "
          'asking about a topic, a place, or something you know you saved.',
        ),
      ];
    }

    final category = reels.first.category;
    final subCategory = reels.first.subCategory;
    final blocks = <AnswerBlock>[
      TextBlock(
        'You have saved ${reels.length} '
        '${reels.length == 1 ? 'thing' : 'things'} about this, mostly in '
        '$category › $subCategory.',
      ),
      // Seed ids don't exist in the user's library, so ChatReelStrip would
      // resolve none of them and +COLLECTION would offer to save fake ids —
      // omit the block rather than promise cards that cannot render.
      if (!usingFallback) ReelRefsBlock(reels.map((reel) => reel.id).toList()),
    ];

    final places = _places(reels);
    if (places.isNotEmpty) blocks.add(PlacesBlock(places));

    if (reels.length >= 3) {
      blocks.add(
        TableBlock(
          columns: const ['SAVED', 'CATEGORY', 'WHEN'],
          rows: reels
              .take(4)
              .map(
                (reel) => [
                  reel.title.isEmpty ? 'Untitled' : reel.title,
                  reel.subCategory,
                  reel.relativeDate.isEmpty ? '—' : reel.relativeDate,
                ],
              )
              .toList(),
        ),
      );
      blocks.add(ChartBlock(title: 'WHAT YOU SAVE MOST', bars: _bars(reels)));
    }

    return blocks;
  }

  List<AnswerPlace> _places(List<Reel> reels) {
    final places = <AnswerPlace>[];
    for (final reel in reels) {
      for (final location in reel.mappableLocations) {
        final latitude = location.latitude;
        final longitude = location.longitude;
        if (latitude == null || longitude == null) continue;
        places.add(
          AnswerPlace(
            name: location.name,
            latitude: latitude,
            longitude: longitude,
            category: reel.category,
            reelId: reel.id,
          ),
        );
        if (places.length == 6) return places;
      }
    }
    return places;
  }

  List<ChartBar> _bars(List<Reel> reels) {
    final counts = <String, int>{};
    for (final reel in reels) {
      counts.update(reel.subCategory, (n) => n + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(5)
        .map(
          (entry) => ChartBar(
            label: entry.key.toUpperCase(),
            value: entry.value.toDouble(),
            category: entry.key,
          ),
        )
        .toList();
  }

  /// Used only when the library is empty, so a fresh install still shows every
  /// block type instead of an apology.
  List<Reel> _seedReels(String query) {
    Reel make(
      String id,
      String title,
      String category,
      String subCategory,
      String place,
      double latitude,
      double longitude,
    ) {
      return Reel(
        id: id,
        userId: 'mock-me',
        url: 'https://example.com/$id',
        title: title,
        summary: '',
        caption: '',
        transcript: '',
        category: category,
        subCategory: subCategory,
        keyFacts: const [],
        locations: const [],
        peopleMentioned: const [],
        actionableItems: const [],
        relativeDate: '2W AGO',
        sourcePlatform: 'instagram',
        mappableLocations: [
          Location(name: place, latitude: latitude, longitude: longitude),
        ],
      );
    }

    return [
      make(
        'seed-1',
        'Ichiran, Shibuya',
        'Food',
        'Ramen',
        'Ichiran',
        35.66,
        139.70,
      ),
      make(
        'seed-2',
        'Standing sushi bar',
        'Food',
        'Sushi',
        'Uogashi',
        35.69,
        139.70,
      ),
      make(
        'seed-3',
        'Yakitori alley',
        'Food',
        'Izakaya',
        'Omoide',
        35.69,
        139.69,
      ),
      make('seed-4', 'Fuglen coffee', 'Food', 'Cafe', 'Fuglen', 35.66, 139.69),
    ];
  }
}
