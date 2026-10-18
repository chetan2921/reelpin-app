# ReelPin

Goal: production. The app is live in the App Store and Play Store and the
backend serves real users, so changes get shipped-product care: tests first,
real error handling, and never breaking an app version already installed.

Repos: reelpin-api (FastAPI backend and worker), reelpin-app (Flutter client for
Android and iOS). This file is an identical copy in both repos at
`.claude/plan/reelpin/SPEC.md`; change both together.

## Who and what

For people who save reels, posts, and links to come back to and then cannot
find them again. Share a link into ReelPin; the backend reads it (video, audio,
caption, images, or the page) and turns it into a summary, key facts, places,
people, and action items. The app lets you browse by category, see places on a
map, search in plain language, group saves into collections you can share and
edit with others, and ask questions across your saves.

Shelved as of 2026-10-15: the personal context engine design (reelpin-app
`docs/superpowers/specs/2026-09-17-personal-context-engine-design.md`) and the
chat built toward it. No plan is built on either; do not extend them unless the
user asks.

## Flows

### Save from another app
1. The user taps Share on a post (Instagram, YouTube, X, and so on) and picks ReelPin, optionally choosing collections in the share sheet.
2. Native share code (Android activity and service, iOS share extension) posts the link straight to the backend with the device's share token and shows a short confirmation. If the post fails, the share is kept as pending and the app sends it on its next launch or resume.
3. The backend dedupes it (the same post under any URL shape), queues a job (Pro accounts in a priority lane), and processes it in the background.
4. A `reel_ready` push arrives and opens the saved item. Meanwhile the app shows a processing card while it polls the job list.

When it fails: the backend retries transient failures and dead-letters the rest;
the app drops the card for a job that has not finished after 20 minutes. Free
accounts hit submission limits sooner than Pro.

### Browse
- Home: grid of saves with category and subcategory chips and filters. Categories are per user, assigned by the backend.
- Discover: live search, recent saves, date and category browsing.
- Map: places extracted from saves, plus places pinned by hand through place search.
- Reel detail: summary, key facts, places, people, action items, transcript, open the original, delete.

### Search
Plain-language search over saves (`POST /api/v1/search`), debounced while typing.

### Collections
Create a collection, add saves, share a public link or invite members as editor
or viewer, leave or remove members. Each collection has its own chat with
threads.

### Ask (chat): parked, not shipping
Chat over your saves (private chat with taste-based suggestions, and a chat per
collection) exists in code on both `dev` branches; the app shows it only when
built with `CHAT_ENABLED`. As of 2026-10-15 it is not going to the store build
and is not being developed further. The store build (app `main`) has none of
it. Leave the chat code alone unless the user asks.

### Plans
Free and Pro. Pro has higher limits and a priority processing lane. Until
in-app purchase ships, Pro is granted by hand in SQL (`user_entitlements`,
`store = 'manual'`). The RevenueCat paywall lives on the app's `feature/paywall`
branch, not on `dev`.

### Account
Sign in with email, Google, or Apple (Supabase Auth). Delete the account from
Profile.

## Milestones

Shipped: ingestion from many sources, feed, map, search, collections with
sharing and members, the Pro plan backend. Dated lines are in each repo's
`IMPLEMENTATION.md`.

In flight: TikTok support on separate branches from `dev`, with existing
architecture and Mumbai hosting. Blocked public posts can use the existing
Apify provider for retrieval. Videos use the existing media pipeline;
photos use caption/author plus cover-image OCR only; other pages use readable
public metadata. Merge into `dev` only after user confirmation. No production
promotion or hosting change is part of this milestone.

Not in scope: chat in a store build, and everything in the personal context
engine design (taste-ranked answers, the action registry, preference learning).

## Stack

| Layer | Choice | Why |
|-------|--------|-----|
| front end | Flutter (Dart 3.11), Riverpod as dependency injection, `ChangeNotifier` view models, Navigator 1.0 | one codebase for Android and iOS |
| native share | Kotlin share activity and service; Swift share extension | a share must work before Flutter has started |
| back end | FastAPI API plus a Dramatiq worker on Redis; two systemd services per EC2 host | slow ingestion runs off the request path |
| AI | Google Gemini for transcription, extraction, OCR, categories, chat, and pgvector embeddings | not recorded |
| data | Supabase Postgres with pgvector, one project for dev and prod (rows stamped by `environment`); Pinecone with hashed-lexical vectors | not recorded |
| auth | Supabase Auth (email, Google, Apple) as Bearer tokens; long-lived share tokens for native share | native share has no user session |
| push | Firebase Cloud Messaging | |
| maps | Google Maps: geocoding, Places, the map SDK | |
| hosting | EC2 per environment, deployed by GitHub Actions on push to `dev` and `main`; app store builds made locally | |

## Architecture

The app talks REST and SSE to the API; the API writes a job row and a Redis
message; the worker processes the job against Gemini, Google Maps, Apify, and
the source sites, writes Supabase (and Pinecone), and pushes through FCM. Native
share code talks to the API directly. Every seam is in `.claude/contracts/`; the
schema is reelpin-api `supabase/migrations/`; the request and response shapes
are reelpin-api `app/models.py`.
