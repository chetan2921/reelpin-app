# AI Search Query Understanding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users type natural sentences with typos into ReelPin search and get their own saved reels back, by parsing the query with Gemini before calling the existing `/api/v1/search`.

**Architecture:** A `QueryUnderstandingService` wraps `firebase_ai` and turns a raw sentence into a `ParsedQuery` (cleaned query text, category, subcategory, limit). `SearchViewModel` gains `searchWithAi()`, wired to the search field's `onSubmitted` only — typing keeps the existing instant keyword path. Every failure falls back silently to today's behaviour, so search can never regress.

**Tech Stack:** Flutter, Riverpod (ChangeNotifier view models), `firebase_ai` (Gemini Developer API), `firebase_app_check`, existing `http` API client.

## Global Constraints

- Branch: `fix/upgrading_search`, branched from `dev`. All work lands here.
- Dart SDK `^3.11.0`. Flutter lints via `flutter_lints: ^6.0.0`.
- Firebase project `reelpin-6a18c`, **Spark (no-cost) plan**, **Gemini Developer API** provider.
- Model: `gemini-3.5-flash-lite`.
- Android applicationId `com.chetanjain.reelpin`; iOS bundle `com.chetan.reelpin`.
- iOS App Check is **Registered (Enforced)** — debug tokens are mandatory for Simulator testing.
- Tests use hand-rolled fakes with constructor injection. **No mockito.** Follow `test/view_models/search_view_model_test.dart`.
- No test may touch Firebase or the network.
- The existing keyword path (`SearchViewModel.search()`) must not be modified.
- Backend changes are **out of scope** — tracked separately in `docs/backend-search-work.md`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/data_models/discover/parsed_query.dart` | **Create.** `ParsedQuery` value object + facet validation |
| `lib/services/search/query_understanding_service.dart` | **Create.** Wraps `firebase_ai`; raw text -> `ParsedQuery?` |
| `lib/view_models/search_view_model.dart` | **Modify.** Add `searchWithAi()`; inject the service |
| `lib/providers.dart:145` | **Modify.** Construct the service into `SearchViewModel` |
| `lib/bootstrap.dart:62-75` | **Modify.** Activate App Check after `Firebase.initializeApp()` |
| `lib/screens/discover/discover_screen.dart:271-278` | **Modify.** `_doSearch` calls `searchWithAi` |
| `pubspec.yaml` | **Modify.** Add `firebase_ai`, `firebase_app_check` |
| `test/data_models/discover/parsed_query_test.dart` | **Create.** |
| `test/services/search/query_understanding_service_test.dart` | **Create.** |
| `test/view_models/search_view_model_test.dart` | **Modify.** Add AI-path cases |

---

### Task 1: Dependencies and App Check

Unblocks everything else: without a debug token, every Gemini call on Simulator/emulator fails.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/bootstrap.dart:62-75`

**Interfaces:**
- Consumes: nothing
- Produces: a live Firebase App Check registration, so `FirebaseAI.googleAI()` calls succeed at runtime.

- [ ] **Step 1: Add the packages**

```bash
flutter pub add firebase_ai firebase_app_check
```

- [ ] **Step 2: Activate App Check in bootstrap**

In `lib/bootstrap.dart`, add the imports:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
```

Then inside `_initializeMessaging()`, immediately after `await Firebase.initializeApp();`:

```dart
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
```

The existing `try/catch` around this block already logs failures via `AppLogger.error`, so a misconfigured App Check degrades to a logged warning rather than a crash on launch.

- [ ] **Step 3: Run the app and capture the debug token**

```bash
flutter run
```

Look in the console for a line containing `Enter this debug secret into the allow list`. Copy the UUID.

- [ ] **Step 4: Register the token (manual, Chetan)**

Firebase console -> App Check -> select the app -> kebab menu -> **Manage debug tokens** -> Add. Do this for whichever platform you are testing on.

- [ ] **Step 5: Verify a Gemini round-trip**

Temporarily add to `bootstrap()` after initialization, run once, confirm `OK` is logged, then remove it:

```dart
    final model = FirebaseAI.googleAI()
        .generativeModel(model: 'gemini-3.5-flash-lite');
    final res = await model.generateContent([Content.text('reply with OK')]);
    AppLogger.debug('GEMINI TEST: ${res.text}');
```

Expected: the log prints `OK`. An App Check error means Step 4 is incomplete.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/bootstrap.dart
git commit -m "feat: add firebase_ai and App Check activation"
```

---

### Task 2: ParsedQuery model

**Files:**
- Create: `lib/data_models/discover/parsed_query.dart`
- Test: `test/data_models/discover/parsed_query_test.dart`

**Interfaces:**
- Consumes: `ReelCategoryGroup` from `lib/data_models/reels/reel_filters.dart`
- Produces:
  - `ParsedQuery({required String semanticQuery, String? category, String? subcategory, int? limit, required String rawQuery})`
  - `static ParsedQuery? fromGeminiJson(Map<String, dynamic> json, {required String rawQuery, required List<ReelCategoryGroup> facets})` — returns `null` when unusable (a `factory` cannot, since it may return null)
  - `ParsedQuery.fallback(String rawQuery)`

- [ ] **Step 1: Write the failing test**

Create `test/data_models/discover/parsed_query_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';

const _facets = <ReelCategoryGroup>[
  ReelCategoryGroup(
    category: 'food',
    label: 'Food',
    count: 3,
    subcategories: [
      ReelSubcategoryFilter(name: 'cafe', label: 'Cafe', count: 2),
    ],
  ),
];

void main() {
  test('parses a well-formed payload', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'coffee shops', 'category': 'food', 'limit': 5},
      rawQuery: 'top 5 cofee shops',
      facets: _facets,
    );

    expect(parsed!.semanticQuery, 'coffee shops');
    expect(parsed.category, 'food');
    expect(parsed.limit, 5);
    expect(parsed.rawQuery, 'top 5 cofee shops');
  });

  test('drops a category that is not in the facet tree', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'cafes', 'category': 'cafes'},
      rawQuery: 'cafes',
      facets: _facets,
    );

    expect(parsed!.category, isNull);
    expect(parsed.semanticQuery, 'cafes');
  });

  test('drops a subcategory that is not in the facet tree', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'cafes', 'category': 'food', 'subcategory': 'bistro'},
      rawQuery: 'cafes',
      facets: _facets,
    );

    expect(parsed!.category, 'food');
    expect(parsed.subcategory, isNull);
  });

  test('clamps out-of-range limits', () {
    final high = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'x', 'limit': 900},
      rawQuery: 'x',
      facets: _facets,
    );
    final low = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'x', 'limit': 0},
      rawQuery: 'x',
      facets: _facets,
    );

    expect(high!.limit, 50);
    expect(low!.limit, 1);
  });

  test('returns null when semantic_query is empty', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': '   '},
      rawQuery: 'x',
      facets: _facets,
    );

    expect(parsed, isNull);
  });

  test('fallback keeps the raw query and drops every facet', () {
    final parsed = ParsedQuery.fallback('travel in Karnataka');

    expect(parsed.semanticQuery, 'travel in Karnataka');
    expect(parsed.category, isNull);
    expect(parsed.limit, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data_models/discover/parsed_query_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:reelpin/data_models/discover/parsed_query.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/data_models/discover/parsed_query.dart`:

```dart
import 'package:reelpin/data_models/reels/reel_filters.dart';

/// A search sentence after Gemini has turned it into the parameters
/// `/api/v1/search` already accepts.
///
/// The backend ANDs every token in the query string, so moving a concept out
/// of [semanticQuery] and into [category] or [subcategory] widens the result
/// set rather than narrowing it.
class ParsedQuery {
  const ParsedQuery({
    required this.semanticQuery,
    required this.rawQuery,
    this.category,
    this.subcategory,
    this.limit,
  });

  final String semanticQuery;
  final String rawQuery;
  final String? category;
  final String? subcategory;
  final int? limit;

  /// What the app sends when parsing is unavailable: today's behaviour.
  factory ParsedQuery.fallback(String rawQuery) =>
      ParsedQuery(semanticQuery: rawQuery, rawQuery: rawQuery);

  /// Validates a Gemini payload against the user's real facet tree.
  ///
  /// A facet the backend does not know would filter out correct results, so
  /// unrecognised values are dropped rather than forwarded. Returns null when
  /// the payload carries no usable query text.
  static ParsedQuery? fromGeminiJson(
    Map<String, dynamic> json, {
    required String rawQuery,
    required List<ReelCategoryGroup> facets,
  }) {
    final semanticQuery = json['semantic_query']?.toString().trim() ?? '';
    if (semanticQuery.isEmpty) return null;

    final rawCategory = json['category']?.toString().trim();
    final group = _groupNamed(facets, rawCategory);
    final category = group?.category;

    final rawSubcategory = json['subcategory']?.toString().trim();
    final subcategory = group?.subcategoryNamed(rawSubcategory)?.name;

    final rawLimit = json['limit'];
    final limit = rawLimit is num ? rawLimit.toInt().clamp(1, 50) : null;

    return ParsedQuery(
      semanticQuery: semanticQuery,
      rawQuery: rawQuery,
      category: category,
      subcategory: subcategory,
      limit: limit,
    );
  }

  static ReelCategoryGroup? _groupNamed(
    List<ReelCategoryGroup> facets,
    String? name,
  ) {
    if (name == null || name.isEmpty) return null;
    for (final group in facets) {
      if (group.category == name) return group;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data_models/discover/parsed_query_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/data_models/discover/parsed_query.dart test/data_models/discover/parsed_query_test.dart
git commit -m "feat: add ParsedQuery with facet validation"
```

---

### Task 3: QueryUnderstandingService

**Files:**
- Create: `lib/services/search/query_understanding_service.dart`
- Test: `test/services/search/query_understanding_service_test.dart`

**Interfaces:**
- Consumes: `ParsedQuery` from Task 2
- Produces:
  - `abstract class QueryUnderstandingService` with `Future<ParsedQuery?> parse(String rawQuery, {required List<ReelCategoryGroup> facets})`
  - `class GeminiQueryUnderstandingService implements QueryUnderstandingService`
  - `@visibleForTesting String buildPrompt(String rawQuery, List<ReelCategoryGroup> facets)`

The abstract class is what `SearchViewModel` depends on, so tests fake it without Firebase.

- [ ] **Step 1: Write the failing test**

Create `test/services/search/query_understanding_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/services/search/query_understanding_service.dart';

const _facets = <ReelCategoryGroup>[
  ReelCategoryGroup(
    category: 'food',
    label: 'Food',
    count: 3,
    subcategories: [
      ReelSubcategoryFilter(name: 'cafe', label: 'Cafe', count: 2),
    ],
  ),
  ReelCategoryGroup(
    category: 'travel',
    label: 'Travel',
    count: 5,
    subcategories: [],
  ),
];

void main() {
  test('prompt lists every real category so the model cannot invent one', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('cafes in bangalore', _facets);

    expect(prompt, contains('food'));
    expect(prompt, contains('travel'));
    expect(prompt, contains('cafe'));
    expect(prompt, contains('cafes in bangalore'));
  });

  test('prompt survives an empty facet tree', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('cafes', const []);

    expect(prompt, contains('cafes'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/search/query_understanding_service_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/services/search/query_understanding_service.dart`:

```dart
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Turns a search sentence into the parameters `/api/v1/search` accepts.
///
/// Every failure returns null; the caller falls back to sending the raw query,
/// which is exactly today's behaviour.
abstract class QueryUnderstandingService {
  Future<ParsedQuery?> parse(
    String rawQuery, {
    required List<ReelCategoryGroup> facets,
  });
}

class GeminiQueryUnderstandingService implements QueryUnderstandingService {
  GeminiQueryUnderstandingService({this.timeout = const Duration(seconds: 3)});

  final Duration timeout;

  static const _modelName = 'gemini-3.5-flash-lite';

  @override
  Future<ParsedQuery?> parse(
    String rawQuery, {
    required List<ReelCategoryGroup> facets,
  }) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'semantic_query': Schema.string(),
              'category': Schema.string(nullable: true),
              'subcategory': Schema.string(nullable: true),
              'limit': Schema.integer(nullable: true),
            },
            optionalProperties: const ['category', 'subcategory', 'limit'],
          ),
        ),
      );

      final response = await model
          .generateContent([Content.text(buildPrompt(rawQuery, facets))])
          .timeout(timeout);

      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;

      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;

      return ParsedQuery.fromGeminiJson(
        Map<String, dynamic>.from(decoded),
        rawQuery: rawQuery,
        facets: facets,
      );
    } catch (e) {
      AppLogger.error('Query understanding unavailable: $e');
      return null;
    }
  }

  /// The model must map onto categories this user actually has, so the real
  /// facet tree goes into the prompt rather than a fixed list.
  @visibleForTesting
  String buildPrompt(String rawQuery, List<ReelCategoryGroup> facets) {
    final buffer = StringBuffer()
      ..writeln(
        'You convert a search sentence into filters for a personal library '
        'of saved social media posts. Correct spelling mistakes.',
      )
      ..writeln()
      ..writeln('Available categories (use these exact values or null):');

    if (facets.isEmpty) {
      buffer.writeln('  (none known — return null for category)');
    } else {
      for (final group in facets) {
        final subs = group.subcategories.map((s) => s.name).join(', ');
        buffer.writeln(
          '  - ${group.category}${subs.isEmpty ? '' : ' (subcategories: $subs)'}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('Rules:')
      ..writeln(
        '- semantic_query: the search terms only, spelling corrected. '
        'Remove words you moved into category or subcategory.',
      )
      ..writeln('- Keep place names in semantic_query.')
      ..writeln('- category/subcategory: only values listed above, else null.')
      ..writeln('- limit: only if the user asked for a count, else null.')
      ..writeln()
      ..writeln('Query: $rawQuery');

    return buffer.toString();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/search/query_understanding_service_test.dart`
Expected: PASS, 2 tests.

If `Schema.string(nullable: true)` or `optionalProperties` fails to compile, check the installed `firebase_ai` API surface with `flutter pub deps` and adjust — the schema shape is the only version-sensitive part of this file.

- [ ] **Step 5: Verify the whole suite still passes**

Run: `flutter test`
Expected: PASS. Confirms the new import does not break existing tests.

- [ ] **Step 6: Commit**

```bash
git add lib/services/search/query_understanding_service.dart test/services/search/query_understanding_service_test.dart
git commit -m "feat: add Gemini query understanding service"
```

---

### Task 4: SearchViewModel.searchWithAi

**Files:**
- Modify: `lib/view_models/search_view_model.dart`
- Modify: `lib/providers.dart:145`
- Test: `test/view_models/search_view_model_test.dart`

**Interfaces:**
- Consumes: `QueryUnderstandingService.parse` (Task 3), `ParsedQuery` (Task 2)
- Produces: `Future<void> searchWithAi(String query, {List<ReelCategoryGroup> facets = const []})` on `SearchViewModel`

- [ ] **Step 1: Write the failing tests**

Append to `test/view_models/search_view_model_test.dart` inside `main()`:

```dart
  test('searchWithAi sends parsed params to the repository', () async {
    String? seenQuery;
    String? seenCategory;
    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) async {
            seenQuery = query;
            seenCategory = category;
            return _searchResponse(query, [_resultFor(query)]);
          },
    );
    final viewModel = SearchViewModel(
      repository,
      queryUnderstanding: _FakeQueryUnderstanding(
        const ParsedQuery(
          semanticQuery: 'Bangalore',
          rawQuery: 'travel in banglore',
          category: 'travel',
        ),
      ),
    );

    await viewModel.searchWithAi('travel in banglore');

    expect(seenQuery, 'Bangalore');
    expect(seenCategory, 'travel');
    expect(viewModel.results, hasLength(1));
  });

  test('searchWithAi falls back to the raw query when parsing fails', () async {
    String? seenQuery;
    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) async {
            seenQuery = query;
            return _searchResponse(query, [_resultFor(query)]);
          },
    );
    final viewModel = SearchViewModel(
      repository,
      queryUnderstanding: _FakeQueryUnderstanding(null),
    );

    await viewModel.searchWithAi('travel in Karnataka');

    expect(seenQuery, 'travel in Karnataka');
    expect(viewModel.results, hasLength(1));
    expect(viewModel.error, isNull);
  });

  test('searchWithAi skips parsing for queries below the minimum', () async {
    final parser = _FakeQueryUnderstanding(null);
    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) async =>
              _searchResponse(query, const []),
    );
    final viewModel = SearchViewModel(repository, queryUnderstanding: parser);

    await viewModel.searchWithAi('ab');

    expect(parser.calls, 0);
    expect(repository.searchCalls, 0);
  });

  test('keyword search never invokes the parser', () async {
    final parser = _FakeQueryUnderstanding(null);
    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) async =>
              _searchResponse(query, [_resultFor(query)]),
    );
    final viewModel = SearchViewModel(repository, queryUnderstanding: parser);

    await viewModel.search('travel');

    expect(parser.calls, 0);
    expect(repository.searchCalls, 1);
  });
```

Add this fake at the bottom of the file, next to `_FakeReelRepository`:

```dart
class _FakeQueryUnderstanding implements QueryUnderstandingService {
  _FakeQueryUnderstanding(this._result);

  final ParsedQuery? _result;
  int calls = 0;

  @override
  Future<ParsedQuery?> parse(
    String rawQuery, {
    required List<ReelCategoryGroup> facets,
  }) async {
    calls += 1;
    return _result;
  }
}
```

Add the imports at the top of the test file:

```dart
import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/services/search/query_understanding_service.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/view_models/search_view_model_test.dart`
Expected: FAIL — `SearchViewModel` has no named parameter `queryUnderstanding`.

- [ ] **Step 3: Implement searchWithAi**

In `lib/view_models/search_view_model.dart`, add the imports:

```dart
import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/services/search/query_understanding_service.dart';
```

Change the constructor:

```dart
  SearchViewModel(this._repository, {QueryUnderstandingService? queryUnderstanding})
      : _queryUnderstanding = queryUnderstanding;

  final QueryUnderstandingService? _queryUnderstanding;
```

Add the method after `search()`:

```dart
  /// Submit-time search: Gemini corrects spelling and moves concepts into the
  /// category filters before the request goes out.
  ///
  /// Any parsing failure degrades to [search]'s exact behaviour, so this path
  /// can never return fewer results than typing the same text would.
  Future<void> searchWithAi(
    String query, {
    List<ReelCategoryGroup> facets = const [],
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < minimumQueryLength) {
      return search(normalizedQuery);
    }

    final parser = _queryUnderstanding;
    if (parser == null) return search(normalizedQuery);

    _isSearching = true;
    _error = null;
    notifyListeners();

    final parsed =
        await parser.parse(normalizedQuery, facets: facets) ??
            ParsedQuery.fallback(normalizedQuery);

    _lastQuery = normalizedQuery;

    final requestId = ++_searchRequestId;
    try {
      final response = await _repository.search(
        parsed.semanticQuery,
        category: parsed.category ?? _selectedCategory,
        subcategory: parsed.subcategory ?? _selectedSubcategory,
      );
      if (requestId != _searchRequestId) return;

      _results = response.results;
      _total = response.total;
      _backendSearchMode = response.searchMode;
      _error = null;
    } on SearchCancelledException {
      return;
    } catch (e) {
      if (requestId != _searchRequestId) return;
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Search is not available right now.',
      );
    } finally {
      if (requestId == _searchRequestId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/view_models/search_view_model_test.dart`
Expected: PASS — including the pre-existing race-condition tests, which must still hold.

- [ ] **Step 5: Wire the provider**

In `lib/providers.dart`, replace line 145-147:

```dart
final searchViewModelProvider = ChangeNotifierProvider<SearchViewModel>((ref) {
  return SearchViewModel(
    ref.read(reelRepositoryProvider),
    queryUnderstanding: GeminiQueryUnderstandingService(),
  );
});
```

Add the import:

```dart
import 'package:reelpin/services/search/query_understanding_service.dart';
```

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/view_models/search_view_model.dart lib/providers.dart test/view_models/search_view_model_test.dart
git commit -m "feat: add AI-parsed search path to SearchViewModel"
```

---

### Task 5: Wire the search field

**Files:**
- Modify: `lib/screens/discover/discover_screen.dart:271-278`

**Interfaces:**
- Consumes: `SearchViewModel.searchWithAi` (Task 4), `ReelFiltersViewModel.categoryGroups`
- Produces: nothing downstream

- [ ] **Step 1: Route submit through the AI path**

`_doSearch` currently calls `vm.search(query)`. Change its body to:

```dart
  void _doSearch(SearchViewModel vm, String query) {
    _searchDebounce?.cancel();
    _focusNode.unfocus();
    vm.searchWithAi(
      query,
      facets: ref.read(reelFiltersViewModelProvider).categoryGroups,
    );
  }
```

Leave `_handleSearchChanged` untouched — typing must stay on the instant keyword path.

- [ ] **Step 2: Verify the suite still passes**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 3: Verify on a device**

Run: `flutter run`

Type each query, press the keyboard's search key, and confirm results appear:

| Query | Expected |
|---|---|
| `travel` | Results, as before — regression check |
| `cofee` | Results for coffee — typo corrected |
| `top 5 best places in banglore` | Bangalore results, at most 5 |
| `travel in Karnataka` | Bangalore/Karnataka results if `locations[].state` is populated |
| Airplane mode, any query | Falls back silently, no error banner |

`travel in Karnataka` is the one that may still fail — it depends on backend data. See the backend note below.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/discover/discover_screen.dart
git commit -m "feat: route search submit through AI query understanding"
```

---

### Task 6: Surface search_mode in debug builds

Answers, at a glance, whether the backend served `rag`, `hybrid`, or `keyword` for a given query — the diagnostic that has been missing all along.

**Files:**
- Modify: `lib/view_models/search_view_model.dart`

**Interfaces:**
- Consumes: `_backendSearchMode`
- Produces: nothing

- [ ] **Step 1: Log the mode after each search**

In both `search()` and `searchWithAi()`, immediately after `_backendSearchMode = response.searchMode;`:

```dart
      if (kDebugMode) {
        AppLogger.debug(
          'SEARCH MODE: ${response.searchMode.name} '
          'query="${response.query}" total=${response.total}',
        );
      }
```

Add the imports:

```dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:reelpin/utils/app_logger.dart';
```

- [ ] **Step 2: Verify**

Run: `flutter run`, search, read the log line.

Note the backend can return `"hybrid"`, which `SearchMode.fromValue` maps to `keyword` because it only recognises `"rag"`. So a logged `keyword` means "not pure rag" — it does not prove semantic search was skipped. Recorded in `docs/backend-search-work.md`.

- [ ] **Step 3: Run the suite and commit**

```bash
flutter test
git add lib/view_models/search_view_model.dart
git commit -m "chore: log backend search_mode in debug builds"
```

---

## Backend changes (not in this branch)

Full detail in `docs/backend-search-work.md`. Summary of what someone else must do in `reelpin-api`:

| # | Change | Why it matters here |
|---|---|---|
| 1 | Replace `_hash_embedding` (`app/services/embedder.py:22`) with real embeddings | Vectors currently match only on literal shared tokens; there is no semantic search |
| 2 | Add `locations` to `search_text` (`app/pipeline.py:212`) | City/state never reach the index, so `travel in Karnataka` cannot work from the vector side |
| 3 | Re-tune `_is_relevant_match` (`app/main.py:3703`) after #1 | Thresholds were fitted to hash-embedding scores |
| 4 | Soften `websearch_to_tsquery` AND semantics | Every extra token currently narrows results |
| 5 | `CREATE EXTENSION pg_trgm` | Database-level typo tolerance |
| 6 | Confirm `locations[].state` is populated | Decides whether Task 5's Karnataka case passes |

**Once #1 and #2 land, revisit this client layer.** Real embeddings handle typos and place relationships natively, at which point the prompt can shrink or the parsing step may become unnecessary.

## Manual steps for Chetan

- [ ] Register **Play Integrity** for `com.chetanjain.reelpin` (App Check page)
- [ ] Register the **debug token** printed in Task 1 Step 3
- [ ] Check whether `locations[].state` is populated for a known Bangalore reel
- [ ] Before shipping a release build: confirm the Play app signing SHA-256 is registered in Firebase
