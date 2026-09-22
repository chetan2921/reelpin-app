# ReelPin as a Personal Context Engine

**Status:** design, awaiting approval
**Date:** 2026-09-17
**Repos:** `reelpin` (Flutter client), `reelpin-api` (FastAPI backend)

## 1. Purpose

ReelPin today is a library you can search. This design turns it into a
productivity tool that knows the user: it reads taste out of what they save,
answers in terms of that taste, recommends beyond the library when doing so
serves them, and ends every answer in something they can act on — in the apps
they personally use.

The primary feature, stated as one sentence:

> Ask a question, get answers from your saves ranked by your taste, **plus**
> things you have not saved that fit that taste, each carrying actions that open
> **your** preferred app.

Everything below serves that sentence. Anything that does not is out of scope.

### Before and after

| | Today | After |
|---|---|---|
| Scope | Only your saves | Your saves, plus outside suggestions clearly marked as such |
| Ranking | Query relevance | Query relevance shaped by taste read from your saves |
| Reasoning shown | None | "You keep saving slow-burn supernatural over gore" |
| Ending | A list | A list plus actions: watch, book, order, navigate, remind, calendar |
| Apps | Google Maps only | The user's preferred app per domain, per region |

## 2. What already exists

Established by reading the code, not assumed:

- **Semantic retrieval is real.** `supabase/migrations/20260829120000_add_reel_embeddings_hybrid_search.sql`
  adds `reels.embedding vector(768)`, populated by Gemini via
  `embedder.embed_document_text`, and `search_reels_hybrid` fuses dense,
  full-text and trigram arms with Reciprocal Rank Fusion. The SHA-256
  `_hash_embedding` Pinecone path in `embedder.py` is legacy and is not on this
  path. The backend's own `CLAUDE.md` still describes only the hash path; that
  section is stale.
- **The answer pipeline is structured.** `app/services/chat.py` retrieves, asks
  Gemini for a `ChatAnswerPlan`, and assembles typed blocks.
- **Block rendering is forward compatible.** `AnswerBlock.fromJson`
  (`lib/data_models/chat/answer_block.dart:11`) returns `null` for an unknown
  `type`, with the comment stating this explicitly: a thread written by a newer
  build still opens on an older one with its other blocks intact. **New block
  types can therefore ship server-first without breaking installed clients.**
- **Reminders ship.** `supabase/migrations/20260730120000_add_reminders.sql`
  plus a worker sweep and FCM push. `reels.events` already holds extracted
  `{name, date, time}` items.
- **Handoff has a house pattern.** `lib/utils/location_maps_uri.dart` builds an
  **https** Google Maps URL rather than a `comgooglemaps://` scheme, relying on
  App Links / Universal Links to open the native app. This is the template for
  all app handoff in this design.
- **Structured extraction is rich.** `app/services/extractor.py` yields content
  domain, topical tags, locations, key facts, people and actionable items;
  `app/services/user_categories.py` maintains a per-user two-level taxonomy.

**What does not exist:** any notion of the user's region (nothing in `lib/`
reads a locale or country), any preference store, any action vocabulary, and any
path by which an answer may reference something outside the user's library.

## 3. Invariants

These hold in every version of this feature. They are the reason the design has
the shape it does.

1. **A `reel_refs` block may only cite reels retrieved for this user.**
   Enforced today at `chat.py:568-578` by filtering against `valid_ids`. This
   filter stays exactly as it is. Outside suggestions are a *different block
   type carrying no reel id*, so a suggestion can never be rendered as
   something the user saved, in the code or on screen.
2. **The model never emits a URL.** It emits an intent from a closed
   vocabulary plus a plain-text query. The client builds every URL from a
   vetted template. A model-authored link that a user taps is a phishing
   vector wearing ReelPin's branding; this rule reduces that blast radius to
   zero.
3. **Grounded web text is data, never instructions.** Search results are
   untrusted input, handled the same way as any other user-supplied content.
4. **An action is rendered only when it resolves.** A button that cannot open
   anything is hidden rather than shown broken.
5. **Availability claims carry their region.** "On Netflix (IN)", never a bare
   "on Netflix". A confidently wrong availability claim is worse than silence,
   because it sends the user to an empty search.

What is removed, deliberately: the "answer using ONLY the user's saved reels"
instruction at `chat.py:99` and the unconditional `_NOT_FOUND_TEXT` exits at
`chat.py:543` and `chat.py:610`. Those are the box; invariant 1 is the safety
property, and it is not the same thing.

## 4. Architecture

```
question
   │
   ├─► search_reels_hybrid  ──► the user's relevant saves      [exists]
   │
   ├─► ANSWER STEP (Gemini, structured output)                 [modified]
   │     reads the retrieved saves, infers taste in-context,
   │     writes answer_text, cites reel ids, and emits
   │     suggestion *intents* and action *intents*
   │
   ├─► SUGGEST STEP (Gemini + Google Search grounding)         [new, optional]
   │     turns suggestion intents into real, current, regional
   │     facts with source links — degrades to ungrounded, then
   │     to omitted, without failing the answer
   │
   ├─► ACTION RESOLVER (client)                                [new]
   │     intent + region + preferred app  ──► https URL
   │     from the registry; unresolvable actions are dropped
   │
   └─► blocks: text · reel_refs · places · table · chart
                  · suggestions (new) · actions (new)
```

The two Gemini steps are separate on purpose. The answer over the user's own
library must not become slower, more expensive, or less reliable because the
outside half failed.

## 5. Component A — just-in-time taste

**No stored taste profile in v1.**

Retrieval already returns the user's saves relevant to the question. Ask about
horror and it returns their horror saves. The answer step reads the pattern out
of that set in-context: not just the category, but the *why* — pacing, era,
price bracket, format (they save trailers, never reviews), what they
consistently avoid.

Why not a stored profile: it is an optimisation for things v1 does not do —
unprompted recommendation and "what am I like" — and it adds a staleness
problem, a rebuild schedule and a correction UI. Just-in-time taste is always
current, costs one larger prompt, and is strictly simpler. A stored profile
becomes worth building when we want recommendations without a question; that is
a later spec.

The taste reading surfaces in the answer as an explicit reason line tied to the
user's own saves — *"you keep saving slow-burn supernatural over gore"*. This
line is the entire perceived intelligence of the feature and it is the cheapest
part of it.

**Cold start.** With fewer than four relevant retrieved saves the taste reason
is omitted entirely and suggestions fall back to generic quality
recommendations, labelled as such. The system never invents a pattern from two
saves. Four is a starting value to tune against real answers, not a derived
constant.

## 6. Component B — beyond your saves

A new `suggestions` block, visually distinct from `reel_refs`, never interleaved
with it. Each item:

```
{ title, why, availability, availability_region, source_url, actions[] }
```

`why` must reference the user's own saves by name. A suggestion whose `why`
cannot be tied to the retrieved set is dropped rather than shown with a generic
justification.

**Grounding.** The suggest step runs with Google Search so suggestions are real
and current, and so availability can be answered truthfully per region. Without
grounding, the model's knowledge cutoff makes every "where to watch" claim a
guess, and it will invent titles.

**Degradation ladder** — each rung is a working answer:

1. Grounded suggestions with availability and sources.
2. Grounding unavailable, over budget, or failed → ungrounded suggestions, with
   no availability claims at all.
3. Suggest step fails entirely → the saves half of the answer ships alone.

The answer from the user's own library never depends on the outside half.

## 7. Component C — the action registry

A closed intent vocabulary, small and deliberately boring:

`watch` · `book_tickets` · `order_food` · `reserve_table` · `navigate` ·
`calendar` · `remind` · `shop` · `listen`

The model emits `{kind, label, query, payload}`. The client resolves it.

**Three-layer resolution:**

```
1. CURATED   (kind, country) → District · Swiggy · Zomato
                               DoorDash · Fandango · Deliveroo
     ↓ no row for this country
2. UNIVERSAL (kind)          → Google Maps · "where to watch X" search
                               · OS calendar · ReelPin's own reminders
     ↓ nothing sensible even generically
3. HIDE — never render a button that breaks
```

Layer 2 is what makes international users work on day one. An unsupported
country loses the one-tap jump into a local delivery app; it does not lose
directions, calendar, reminders or a working "where to watch". Layer 1 then
grows market by market, chosen by measured demand rather than guesswork.

**https only, no custom schemes.** `AndroidManifest.xml:125` already declares
`<queries>` for https `VIEW` intents and no specific packages, and `Info.plist`
declares no `LSApplicationQueriesSchemes` at all. Custom schemes would mean
editing both files for every app added, against an iOS cap of 50 schemes. https
URLs open the native app via App Links / Universal Links when installed and the
browser when not — one code path, no manifest churn, graceful fallback. The
cost is that installation cannot be detected; component D addresses that
better than detection would.

The registry ships from the backend as configuration, so adding an app is a row,
not a release.

**Tier boundary, stated plainly:** deep links land the user *inside* the app on
the right screen. They cannot select seats or fill a cart. "Book two tickets in
District" means District opens on that film's page. Actual transactional booking
requires a partner or affiliate agreement — a commercial conversation, not
engineering, and one better had after tier 2 demonstrates the demand.

## 8. Component D — preference learning

**No device scanning.** Android's `QUERY_ALL_PACKAGES` is restricted by Google
Play to a narrow set of app categories that ReelPin does not fall into;
declaring it risks rejection or removal. iOS cannot enumerate installed apps at
all, and using `canOpenURL` against a declared scheme list to profile a user's
installed apps is the pattern App Review pushes back on. Both would also need
disclosure in the Play Data Safety form and the App Store privacy label.

It also answers the wrong question. Many users have both Swiggy and Zomato
installed; installation says nothing about which they open.

**Learn from taps instead.** The signal is already flowing through the feature:

```
first food action  → show both:  [Swiggy]  [Zomato]
user taps Zomato   → record {kind: order_food, app: zomato}
by the third       → [Order on Zomato] · small "use Swiggy instead"
```

Zero permissions, zero platform declarations, identical on both platforms, and
it measures preference rather than presence.

**Cold start:** an optional, skippable onboarding screen — "which do you use?"
— with a few icons per domain. Fifteen seconds, and the first suggestion already
lands correctly. Skipping it yields the two-option version until taps accumulate.

**Storage:** a `user_app_preferences` table, server-side rather than
`shared_preferences`, so preferences survive reinstall and device change and
ride the request that already fetches the answer. Note the privacy distinction
that makes this comfortable: the stored fact is *"prefers Zomato for food"*, not
*"has Zomato, Swiggy, Blinkit and Zepto installed"*. A preference, not a device
inventory.

**Failure modes designed for:** a single tap must not lock a user in —
weights decay and the alternative stays one tap away; and preferences are
per-`kind`, since preferring Zomato for food implies nothing about District
versus BookMyShow.

Preference data doubles as market research: users in an uncurated country
repeatedly falling through to layer 2 is a measured signal, with volume
attached, for which market to curate next.

## 9. Region model

Region comes from the device locale, with an explicit override in settings —
someone Indian living in Berlin, or travelling, must be able to say so. Not IP
geolocation: VPNs make it noisy and it is a worse privacy story for a weaker
signal.

Region is not only a button concern. It enters the grounding query, and it is
rendered alongside every availability claim (invariant 5).

## 10. Data model changes

| Change | Where | Why |
|---|---|---|
| `user_app_preferences (user_id, kind, app_key, weight, updated_at)` | new table | component D |
| `app_registry` rows | backend config, not a migration | so an app is a row, not a release |
| `preferred_region` | user settings | component C and grounding |
| — | `reels` unchanged | no schema change to saves |

No change to `reels`, `reminders`, or the embedding columns.

## 11. Wire contract

Two new block types, both additive. Because `AnswerBlock.fromJson` returns
`null` on an unknown `type`, older installed clients ignore them and still
render the rest of the answer — so the backend may ship first.

```
{ "type": "suggestions",
  "items": [{ "title", "why", "availability", "availability_region",
              "source_url", "actions": [...] }] }

{ "type": "actions",
  "items": [{ "kind", "label", "query", "payload" }] }
```

The two carriers of actions are not redundant. Actions nested inside a
`suggestions` item belong to that item — "watch The Conjuring". A standalone
`actions` block belongs to the answer as a whole or to a cited save — "add all
three to your calendar", "directions to the cafe you saved". A resolver handles
both identically; only the anchoring differs.

`ChatAnswerPlan` in `chat.py` gains the corresponding fields. Note that Gemini's
`response_schema` rejects field defaults, so every new field is required and the
model returns empty arrays where they do not apply — matching the existing
convention in that file.

## 12. Security and trust

- Invariant 1 keeps the `valid_ids` filter intact; suggestions carry no reel id
  and cannot be confused with saves.
- Invariant 2 keeps URL construction on the client, from templates, never from
  model output.
- Grounded search results are treated as untrusted data; instructions appearing
  inside them are ignored (invariant 3).
- Suggestion and action blocks published into a shared collection go through the
  same size and type validation as existing shared blocks
  (`_SHAREABLE_BLOCK_TYPES` in `chat.py`), extended to the new types.
- Preference writes are scoped to the requesting user under existing RLS.

## 13. Cost control

The suggest step is the only new recurring cost. `app/services/cost_controls.py`
already exists and gates it: grounding is a flag on the step, off by default for
domains where it adds nothing, with a per-user and global budget. Exhausting the
budget drops the ladder to rung 2 rather than failing the answer. The current
Google Search grounding quota must be checked against the project's free-tier
constraint before enabling it in production.

## 14. Testing strategy

Backend (`unittest`, stubbing external SDKs at module level per the repo
convention):

- An answer plan citing an id outside the retrieved set still drops it —
  invariant 1 holds after the prompt change.
- A suggestion whose `why` references no retrieved save is dropped.
- Suggest-step failure yields a complete saves-only answer.
- Grounding disabled yields suggestions with no availability claims.
- Region flows into the grounding query and onto the rendered claim.

Client (`flutter_test`):

- `AnswerBlock.fromJson` returns `null` for an unknown type — regression guard
  on the forward-compatibility property this design depends on.
- Action resolution: curated hit, universal fallback, and the hide case.
- Preference weighting: first tap does not lock in; per-`kind` isolation.
- Rendering: a suggestion is never presented as a saved reel.

## 15. Open decisions

Both carry a stated default so implementation is not blocked; confirm or
override before the first plan is executed.

1. **Grounding.** *Assumed: enabled, with the degradation ladder in §6.*
   Overriding to ungrounded means no truthful availability claims in any
   region, and the `watch` action degrades to a web search.
2. **Launch set for curated registry rows.** *Assumed: India first, on the
   basis that the user base is India-led.* Not yet verified — a read-only query
   of the dev database for the `reels.category` distribution should confirm the
   domain order and, if any region signal exists, the market order. Never
   against production.

## 16. Out of scope

Named so they are not smuggled in: a stored taste profile; per-domain content
APIs (TMDB, JustWatch); transactional booking via partner APIs; installed-app
detection; cross-user or social taste; a taste-correction UI; any change to
`reels` or the embedding pipeline.

## 17. Build order

One design, three implementation plans, each shippable and useful before the
next lands.

1. **Beyond-your-saves with just-in-time taste** — components A and B. The
   answer changes; no new tables. Delivers the headline feature.
2. **Action registry** — component C, universal layer first (global from day
   one), then curated rows for the launch market.
3. **Preference learning** — component D. Makes actions personal; needs plan 2
   in place to have anything to learn from.
