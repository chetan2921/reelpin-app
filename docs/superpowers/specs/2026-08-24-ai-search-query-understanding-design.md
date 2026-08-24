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

Insert a query-understanding step in front of the **existing** `/api/v1/search`
endpoint. Gemini translates a raw sentence into the structured parameters the
endpoint already accepts (`query`, `category`, `subcategory`, `limit`).

The LLM's job is **translation, not retrieval**. It never sees reel content and
never generates answers. Typo correction is a side effect of reading intent.

Rejected alternatives:

- **Region fan-out** (N parallel searches, one per expanded city) — N× latency
  and cost, plus client-side merge and re-rank logic to maintain.
- **Widen and re-rank client-side** — bounded by the recall of a single search.

Both are workarounds for backend behaviour that has not been measured. Phase 0
measures it first so the decision carries evidence.

## Phase 0 — Diagnostics (gates everything else)

Two unknowns change the design, so they are resolved before any feature code.

**D1 — Which mode is the server actually using?**
Every response already carries `search_mode` (`keyword` | `rag`).
`SearchViewModel` stores it in `_backendSearchMode` and nothing reads it.
Surface it in debug builds and record the value for a real query.

- If `rag`: semantic matching already handles typos and phrasing. The parsing
  layer shrinks to facet and limit extraction, and the prompt gets simpler.
- If `keyword`: proceed with full parsing as designed below.

Also record whether the account returns `conversational_rag_search: true`. If
the server downgrades free-tier accounts to keyword mode, the test account's
entitlement — not the code — may be the whole problem.

**D2 — How does the endpoint treat multi-token queries?**
Issue `"travel Bangalore Mysore Hampi"` against `/api/v1/search` with a valid
token and inspect the results.

- If Bangalore reels surface, Approach A alone resolves the region case.
- If they do not, region handling is logged as a follow-up requiring the
  server-side `administrativeArea` fix, and is explicitly out of scope here.

**Exit criteria:** D1 and D2 both answered and written into this document
before any feature code is written (Phase 2).

## Phase 1 — Prerequisites (Firebase enablement)

Firebase AI Logic requires the **Blaze (pay-as-you-go)** plan and the AI Logic
API enabled. Plan status is currently unconfirmed, so Phase 1 begins with
verification:

1. Confirm the Firebase project's billing plan.
2. Enable the AI Logic API if absent.
3. Add `firebase_ai` and confirm a trivial call succeeds on a real device.
4. Configure App Check so the endpoint is not open to abuse.

No feature code is written until a round-trip call succeeds.

**Cost:** one small call per submitted search on `gemini-3.5-flash-lite`.
Prompt is the query plus a compact facet tree. Negligible per search, but it
scales with active users and should be watched after release.

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

- **Server-side `administrativeArea` enrichment.** Writing `city` / `state` /
  `country` onto `Location` records is the correct fix for region queries.
  `geocoding: ^4.0.0` is already a dependency and its `Placemark` exposes
  exactly these fields, but the ~419-reel backfill belongs on the server.
- **`pg_trgm`** on Supabase for database-level typo tolerance — one line to
  enable, free, and complements this work.
- **Conversational chat UI** (`flutter_gen_ai_chat_ui`), pending a backend
  endpoint that generates written answers rather than returning reels.
