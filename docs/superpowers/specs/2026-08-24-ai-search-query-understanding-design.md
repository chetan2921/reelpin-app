# AI Search Query Understanding

**Date:** 2026-08-24
**Branch:** `fix/upgrading_search` (from `dev`)
**Status:** Design — awaiting review

## Problem

Search in ReelPin is keyword-based. Three concrete failures:

1. **Sentences return nothing.** "travel in Karnataka" or "show me the top 5 best places in Bangalore" produce no useful results, even though the library contains many matching food and travel saves.
2. **Typos return nothing.** "banglore" does not match "Bangalore".
3. **Region names match nothing.** A Bangalore cafe reel stores `location.name = "Bangalore"` with coordinates, but the string "Karnataka" appears nowhere in its record. No text-matching engine can match a word absent from the data.

The client is not the cause. `SearchViewModel.search()` trims the query and forwards it verbatim to `/api/v1/search`; the keyword behaviour is decided server-side.

## Goals

- Natural-language queries return relevant saved reels.
- Typos and spelling variants resolve to the intended term.
- Quantity intent ("top 5") maps to the request `limit`.
- Search never becomes worse or less available than it is today.

## Non-goals

- Conversational chat UI with message history — scoped to a separate branch.
- Any backend or database change. This branch is client-only.
- On-device inference (`flutter_gemma`) — rejected; see the package evaluation.
- Replacing the existing keyword search. It stays as the live-while-typing path.

## Approach

Insert a query-understanding step in front of the **existing**
`/api/v1/search` endpoint. Gemini translates a raw sentence into the structured
parameters the endpoint already accepts (`query`, `category`, `subcategory`,
`limit`).

Following the Phase 0 findings, the parsing layer has two concrete jobs:
correct spelling into tokens that exist in the index, and move concepts out of
the AND-ed query string into structured filter parameters. It is a token
corrector and filter router, not a semantic layer.

The LLM never sees reel content and never generates answers.

Rejected alternatives:

- **Region fan-out / query expansion** — disproven by D2. The backend ANDs
  every token, so adding city names strictly reduces results.
- **Widen and re-rank client-side** — bounded by the recall of a single search,
  and recall is exactly what the AND semantics constrain.
- **On-device inference (`flutter_gemma`)** — rejected earlier; the retrieval
  index lives server-side.

**The real long-term fix is server-side** and is out of scope for this branch:
replacing `_hash_embedding` with genuine embeddings would give the engine
actual semantic understanding, at which point most of this client layer becomes
unnecessary. See "Out of scope" below.

## Phase 0 — Diagnostics: ANSWERED (2026-08-24)

Both unknowns were resolved by reading the backend at `~/Desktop/reelpin-api`
(branch `main`, the deployed production code). No backend changes were made.

### D1 — What is the server actually doing?

Not keyword search. `/api/v1/search` (`app/main.py:2325`) is a hybrid pipeline:
Pinecone vector search first, Postgres full-text as fallback, blended
`0.72 * semantic + 0.28 * lexical`, behind a relevance gate
(`_is_relevant_match`, `app/main.py:3703`).

**But the vector search is not semantic.** `app/services/embedder.py:22`:

```python
def _hash_embedding(text: str) -> list[float]:
    for token, count in token_counts.items():
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        index = int.from_bytes(digest[:4], "big") % EMBEDDING_DIMENSION
```

This is the hashing trick — a bag-of-words projected into 384 dimensions via
SHA256. It carries **no semantic meaning whatsoever**. Two texts score as
similar only when they share *literal tokens*:

- `"Bangalore"` and `"Karnataka"` hash to unrelated buckets: similarity ~0
- `"cofee"` and `"coffee"` are different SHA256 digests: similarity 0

So Pinecone is being used as an exact-token matcher. The "RAG" mode is keyword
matching with extra steps, which is why the symptoms look like keyword search.

`search_mode` also returns a third value, `"hybrid"`, that the Flutter app does
not handle — `SearchMode.fromValue` falls through to `keyword`.

### D2 — How are multi-token queries treated?

**Strictly AND.** The fallback uses
`websearch_to_tsquery('english', p_query)` (`supabase/migrations/
20260524160000_add_reel_full_text_search.sql`), where unquoted terms combine
with `&`. Every token must be present in the reel.

The `search_vector` covers title, summary, category, subcategory, transcript,
key_facts, **locations**, people_mentioned, and actionable_items — so location
text *is* searchable. There is no `pg_trgm`, so there is no typo tolerance at
the database level either.

**This invalidates the region-expansion idea outright.** Rewriting
`"travel in Karnataka"` into `"travel Bangalore Mysore Hampi"` would require a
reel to contain *all four* tokens, returning strictly fewer results — likely
zero. Query expansion makes this backend worse, not better.

### Why the reported queries fail

| Query | Outcome |
|---|---|
| `travel` | Works — single literal token, English-stemmed |
| `travel in Karnataka` | `travel & karnataka` AND-ed. A food reel in Bangalore has `karnataka` but not `travel`, so it is excluded |
| `banglore` | Different SHA256 bucket than `bangalore`; FTS stemming does not correct spelling; no trigram matching. Zero results |

### The consequence for this design

The parsing layer is still worth building, but **its job changes**. It is not a
semantic layer — it is a *token corrector and filter router* for a
token-matching engine:

1. **Correct spelling to real tokens.** `banglore` -> `Bangalore` turns a
   guaranteed miss into a hit. This is the single biggest win available
   client-side.
2. **Move concepts out of the query string into structured filters.**
   `category` and `subcategory` are separate request parameters, applied as
   filters rather than folded into the tsquery. Parsing
   `"travel in Karnataka"` into `query: "Karnataka"` + `category: "travel"`
   removes a token from the AND-chain instead of adding one. This works *with*
   the AND semantics rather than against them.
3. **Extract `limit`** from phrasing such as "top 5".

**Explicitly dropped:** region expansion into city lists. D2 proves it
backfires.

### Open data question (needs one check)

`app/services/extractor.py:68` prompts the extractor for `city` and `state`, and
`display_data.py:827` returns them, so `location.state = "Karnataka"` may
already be populated — in which case rule 2 above fixes the Karnataka case
outright. It is unconfirmed how many stored reels actually carry it.

Verification needed: for a known Bangalore reel, confirm whether
`locations[].state` is populated. Until then, treat the Karnataka fix as
probable, not certain. Typo correction is unaffected and works regardless.

## Phase 1 — Prerequisites (Firebase enablement, done by Chetan)

Firebase AI Logic offers two backend providers, and the choice determines
whether billing is needed:

| Provider | Billing | Use |
|---|---|---|
| **Gemini Developer API** | Free tier — starts at no cost | **Recommended.** Enough for query parsing |
| Agent Platform Gemini API (ex-Vertex AI) | Requires Blaze | Not needed here |

An earlier draft of this document stated that Blaze was required. That was
wrong: the Gemini Developer API path starts at no cost. Choose it.

**App Check is mandatory**, not optional — Firebase automatically enforces it
for AI Logic to protect the Gemini endpoint from abuse.

### Step-by-step

1. **Open the Firebase console** for the ReelPin project
   (the one already backing `firebase_core` / `firebase_messaging`).
2. Go to **AI Services -> AI Logic** in the left sidebar.
3. Click **Get started**. When prompted for a provider, select
   **Gemini Developer API** (the no-cost option).
4. Follow the workflow to register the app and enable the required APIs. This
   auto-enables the necessary Google Cloud APIs.
5. **Set up App Check** (Build -> App Check):
   - Android: register the **Play Integrity** provider
   - iOS: register **DeviceCheck** or **App Attest**
   - Add **debug tokens** for the simulator/emulator, or local testing fails
6. Confirm both `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist` are current — re-download if the
   console reports them stale after enabling AI Logic.
7. Report back which provider was selected and whether App Check debug tokens
   were registered.

### Verification before any feature code

A trivial round-trip must succeed on a real device:

```dart
final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-3.5-flash-lite');
final response = await model.generateContent([Content.text('reply with OK')]);
```

If this returns, the integration is live. If it fails with an App Check error,
step 5 is incomplete.

**Cost:** one small call per submitted search on the free tier's limits. The
prompt is the query plus a compact facet tree. Watch quota after release; the
free tier is rate-limited rather than unlimited.

## Phase 2 — Implementation

### Architecture

```
SearchViewModel.search()        unchanged — keyword, live while typing (300ms debounce)
SearchViewModel.searchWithAi()  new — fires on submit only
        |
        v
QueryUnderstandingService       new — wraps firebase_ai, returns ParsedQuery
        |                       on ANY failure -> silent fallback to raw query
        v
ReelRepository.search()         unchanged
```

`QueryUnderstandingService` is constructor-injected into `SearchViewModel`,
matching how `ReelRepository` is injected today. Tests supply a fake; no test
touches Firebase or the network.

### Why the facet tree is passed into the prompt

The model must emit category values the backend recognises, not invented ones.
The app already fetches the user's real facet tree via `ReelFiltersResponse`
(`lib/data_models/reels/reel_filters.dart`) — their actual categories,
subcategories, and counts.

Passing that tree into the prompt constrains output to values that exist in
*that user's* library. This is what makes "show me cafes" resolve to the real
`category: "food"` rather than a hallucinated `"cafes"`.

### Data contracts

### `ParsedQuery` (`lib/data_models/discover/parsed_query.dart`)

```dart
class ParsedQuery {
  final String semanticQuery;  // cleaned search text, typos corrected
  final String? category;      // must match a value from the facet tree
  final String? subcategory;   // must match a value from the facet tree
  final int? limit;            // from "top 5"; null when unspecified
  final String rawQuery;       // original input, for fallback and logging
}
```

### Gemini response schema

Structured JSON output via `responseSchema` with `responseMimeType:
'application/json'`. Model: `gemini-3.5-flash-lite` (cheapest tier; the prompt
is small and the task is mechanical).

```json
{
  "semantic_query": "coffee shops",
  "category": "food",
  "subcategory": null,
  "limit": 5
}
```

### Validation

`category` and `subcategory` are checked against the facet tree after parsing.
Unrecognised values are dropped to `null` rather than forwarded — a wrong facet
filters out correct results, whereas a null facet merely widens the search.
`limit` is clamped to 1..50.

### Error handling

Every failure path degrades to today's behaviour, silently:

| Failure | Behaviour |
|---|---|
| Firebase not configured / unavailable | Raw query to existing search |
| Gemini timeout (3s budget) | Raw query to existing search |
| Malformed or unparseable JSON | Raw query to existing search |
| Facet value not in tree | Drop that facet, keep the rest |
| Empty `semantic_query` returned | Raw query to existing search |

The user never sees an AI-related error. Worst case, search behaves exactly as
it does today. A debug-only indicator shows which path ran, for testing.

## Testing strategy

TDD, following the existing hand-rolled-fake pattern in
`test/view_models/search_view_model_test.dart` (no mockito, constructor
injection, explicit race-condition coverage).

**New — `test/services/search/query_understanding_service_test.dart`**
- Valid JSON parses into `ParsedQuery`
- Malformed JSON returns null (triggering fallback)
- Facet values absent from the tree are dropped to null
- `limit` clamps out-of-range values
- Timeout returns null within the budget

**Extended — `test/view_models/search_view_model_test.dart`**
- `searchWithAi` sends parsed params to the repository
- Parser failure falls back to the raw query, and results still render
- Parser is not called for queries below `minimumQueryLength`
- Existing race-condition guarantees still hold: latest request wins
- `search()` (keyword path) never invokes the parser

**Manual verification** on device, against a real library:
`"travel in Karnataka"`, `"top 5 best places in banglore"` (deliberate typo),
`"cofee"`, `"travel"` (single keyword regression), and airplane-mode fallback.

## Risks

| Risk | Mitigation |
|---|---|
| Blaze upgrade blocked or unwanted | Phase 1 verification surfaces this before code is written |
| Added latency on submit (300–800ms) | Fires on submit only; typing stays instant. 3s timeout caps the worst case |
| Model returns wrong facet | Validated against the real facet tree; unknown values dropped |
| Region case still fails after A | Phase 0 D2 measures this; follow-up is server-side, documented not attempted |
| API key exposure | Firebase AI Logic + App Check keeps credentials off the device |

## Rollback

`QueryUnderstandingService` is additive and injected. Disabling it means
routing submit back to `search()` instead of `searchWithAi()` — a one-line
change. The existing keyword path is never modified, so it cannot regress.

## Out of scope, recorded for later

- **Replace `_hash_embedding` with real embeddings (highest impact).**
  `app/services/embedder.py` projects a bag of words through SHA256 into 384
  dimensions, which gives the vector index no semantic understanding at all.
  Swapping in a real embedding model would make "cafe" match "coffee shop" and
  "Bangalore" relate to "Karnataka" natively. Cost: a new Pinecone index (the
  dimension changes from 384) plus a full re-index of existing reels. This is
  the change that actually fixes search; everything in this branch works around
  its absence.
- **Enable `pg_trgm`** on Supabase for database-level typo tolerance, and
  consider `websearch_to_tsquery` OR-semantics for multi-token queries.
- **Handle `search_mode: "hybrid"`** in `SearchMode.fromValue`, which currently
  falls through to `keyword`.
- **Parse `city` / `state` / `country`** in the Flutter `Location` model. The
  backend already returns them (`display_data.py:827`); the client drops them.
- **Server-side `administrativeArea` enrichment.** Writing `city` / `state` /
  `country` onto `Location` records is the correct fix for region queries.
  `geocoding: ^4.0.0` is already a dependency and its `Placemark` exposes
  exactly these fields, but the ~419-reel backfill belongs on the server.
- **`pg_trgm`** on Supabase for database-level typo tolerance — one line to
  enable, free, and complements this work.
- **Conversational chat UI** (`flutter_gen_ai_chat_ui`), pending a backend
  endpoint that generates written answers rather than returning reels.
