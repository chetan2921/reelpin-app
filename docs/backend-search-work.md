# Backend: search quality work

**For:** whoever picks up `reelpin-api`
**From:** analysis done 2026-08-25 against `~/Desktop/reelpin-api` @ `main`
**Status:** investigation only — no backend code was changed

Standalone by design: no prior context needed. Client-side work is tracked
separately in `docs/superpowers/specs/2026-08-24-ai-search-query-understanding-design.md`.

## Symptoms reported

| Query | Result |
|---|---|
| `travel` | Works |
| `travel in Karnataka` | Nothing, despite many saved Bangalore places |
| `top 5 best places in Bangalore` | Nothing |
| `banglore` (typo) | Nothing |

## Root causes

`/api/v1/search` (`app/main.py:2325`) is a hybrid pipeline — Pinecone vector
search, Postgres full-text fallback, blended `0.72 * semantic + 0.28 * lexical`
behind `_is_relevant_match` (`app/main.py:3703`). The architecture is sound.
Three things underneath it are not.

### 1. The embeddings carry no semantic meaning (P0)

`app/services/embedder.py:22`:

```python
def _hash_embedding(text: str) -> list[float]:
    vector = [0.0] * EMBEDDING_DIMENSION          # 384
    for token, count in token_counts.items():
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        index = int.from_bytes(digest[:4], "big") % EMBEDDING_DIMENSION
        sign = 1.0 if digest[4] % 2 == 0 else -1.0
        vector[index] += sign * float(count)
```

This is the hashing trick: a bag of words scattered into 384 dimensions by
SHA256. Cosine similarity is non-zero only when two texts share *literal
tokens*.

- `"Bangalore"` vs `"Karnataka"` -> unrelated buckets -> ~0
- `"cofee"` vs `"coffee"` -> different digests -> exactly 0
- `"cafe"` vs `"coffee shop"` -> 0

Pinecone is functioning as an exact-token matcher. Every "semantic search"
symptom follows from this.

### 2. Locations are never embedded (P0, one line)

`app/pipeline.py:212`:

```python
search_text = (
    f"{extracted.title}. {extracted.summary}. "
    f"Primary Category: {extracted.category}. "
    f"Subcategory: {extracted.subcategory}. "
    f"Secondary Categories: {sec_cats}. "
    f"Caption: {caption}. Transcript: {transcript_text}"
)
```

`locations` is absent. City, state, and address never reach the vector index at
all, so location-based vector search cannot work — even after fixing #1.

Note `_lexical_score` (`app/main.py:3516`) *does* read
`location.city / state / country`, and the Postgres `search_vector` *does*
include `locations::text`. Only the embedding path omits them.

### 3. Full-text fallback ANDs every token (P1)

`supabase/migrations/20260524160000_add_reel_full_text_search.sql` uses
`websearch_to_tsquery('english', p_query)`, where unquoted terms combine with
`&`. Every token must be present.

So `travel in Karnataka` becomes `travel & karnataka`. A *food* reel in
Bangalore carries `karnataka` but not `travel`, and is excluded. Adding more
terms always narrows the result set.

There is also no `pg_trgm`, so there is no typo tolerance at the database
level.

## Proposed work, in order

### Task 1 — Replace `_hash_embedding` with real embeddings

Swap the hashing trick for a genuine embedding model. `app/services/
gemini_client.py` already wraps the Gemini SDK but exposes only `generate_text`
and `generate_json`, so an embedding call needs adding.

Requires:
- `EMBEDDING_DIMENSION` 384 -> the model's dimension (768 for EmbeddingGemma
  and text-embedding-004)
- **A new Pinecone index.** Dimension is fixed at creation; the existing index
  cannot be reused.
- A **full re-index** of existing reels (~419 at last check).
- Note the guard at `app/pipeline.py:219` — embedding is skipped when
  `pinecone_id` is already set. A backfill must clear that field or bypass the
  check.
- Batch the backfill and respect the embedding API's rate limits.

Recommend a feature flag so the old index stays queryable until the new one is
verified.

### Task 2 — Add locations to `search_text`

Append city / state / country / name from `extracted.locations` to the string
at `app/pipeline.py:212`. Cheap and independent of Task 1, though it only pays
off once re-indexing happens — so land it *before* the Task 1 backfill and let
one re-index cover both.

### Task 3 — Re-tune `_is_relevant_match` after Task 1

`app/main.py:3703`:

```python
if lexical_score >= 0.62:   return True
if semantic_score >= 0.76:  return True
if semantic_score >= 0.58 and lexical_score >= 0.20: return True
if len(query_tokens) >= 2 and lexical_score >= 0.32: return True
```

These thresholds were tuned against hash-embedding scores, whose distribution
is completely unlike a real model's. Left unchanged after Task 1 they will
either flood or starve results. Re-tune against real score distributions.

### Task 4 — Soften the full-text AND semantics

Consider OR-ing terms with ranking rather than requiring all of them, so
partial matches surface ranked instead of vanishing. `websearch_to_tsquery` ->
an OR-joined `to_tsquery`, keeping `ts_rank_cd` to order results.

### Task 5 — Enable `pg_trgm` for typo tolerance

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

Then trigram-match location names and titles so `banglore` reaches
`Bangalore` without an LLM in the path. One line, free, permanent.

### Task 6 — Confirm `locations[].state` is populated

`app/services/extractor.py:68` prompts the extractor for `city` and `state`,
and `display_data.py:827` returns them — but it is unverified how many stored
reels actually carry them. Query a known Bangalore reel and check. If sparse,
backfill via reverse geocoding; `geocode_location` (`extractor.py:101`) and the
`geocode_cache` table already exist.

## Contract note for the client

`search_mode` can return `"hybrid"` (`app/main.py:2431`), but the Flutter app's
`SearchMode.fromValue` only handles `"rag"` and defaults everything else to
`"keyword"`. Harmless today since nothing reads it, but it should be handled
client-side.

## What the client is doing meanwhile

A `firebase_ai` query-parsing layer on branch `fix/upgrading_search`, which
corrects typos into real tokens and routes concepts into the `category` /
`subcategory` filter params instead of the AND-ed query string. It is a
workaround for causes #1 and #3, not a fix. Once Task 1 lands, most of it can
likely be simplified or removed.
