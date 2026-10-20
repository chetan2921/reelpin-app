# API surface

The REST interface between the backend (server) and reelpin-app (client). The
app talks to the Go service's `/api/v2`. This file was an identical copy in
reelpin-api at `.claude/contracts/api-surface.md`; that copy still describes
the Python `/api/v1`, which keeps serving installed builds.

| Side | Where the truth lives |
|------|-----------------------|
| server contract | reelpin-go `api/openapi.yaml` (machine-readable, the source of truth), `docs/api-contract.md` (rules), `docs/plans/active/flutter-changes.md` (what the app had to change) |
| server shapes | reelpin-go `api/fixtures/*.json`, captured from the real handlers; the app's tests use verbatim copies in `test/fixtures/api_v2/` |
| client REST | reelpin-app `lib/http/api_client.dart`; it implements every `lib/http/*_http.dart` interface |
| client shapes | reelpin-app `lib/data_models/` (`fromJson` per area) |
| client errors | reelpin-app `lib/http/api_exception.dart`, `ApiClient._exceptionFromResponse` in `lib/http/api_client.dart`, user text in `lib/utils/error_message.dart` |

List every server route from the reelpin-go root with:

    grep -nE '^  /api/v2' api/openapi.yaml

## What both sides assume

- Every path is `/api/v2/<path>`; there are no bare aliases. `ApiClient` strips a doubled `/api/v2` from its base URL.
- Auth is `Authorization: Bearer <Supabase access token>`. The server takes the user from the token. `ApiClient` renews the session once on a 401 and resends. The shared-collection read is public.
- Every error is `{error: {code, message, request_id, retryable, details}}`. Match on `code`, never on `message`. `ApiException` carries `errorCode`, `requestId`, `details` and `retryable`; the client shows `message`, falling back to its own text.
- Request bodies are strict: an unknown field is a `422`. Push registration sends only `token` and `platform`; share resolve sends only `raw_payload_text`.
- Pagination is opaque cursors: pass `next_cursor` back as `cursor`, never build one. There is no `offset` and no `total_count`; `has_more` is `next_cursor` being present. Page size is 1 to 100; the client caps it.
- `POST /processing-jobs/reels` needs an `Idempotency-Key` UUID per attempt (a 401 resend reuses it). `200` is the ready reel, which the client hands on as a completed job with no id; `202` is a job to poll. Both carry `already_saved`.
- A list reel (`GET /reels`, search, discover, a job's `reel`) says `sub_category` and carries display fields (`category_label`, `relative_date`, `mappable_locations`). A single reel (`GET /reels/{id}`, a submission's `200`) says `subcategory`, carries `transcript` and raw `locations`, and has no display fields. `Reel.fromJson` reads both.
- `GET /reels` and `POST /search` are sent with `view=concise`; the reel detail uses the default detailed view.
- Collection detail and the shared view return item cards (`reel_id`, title, summary, links, thumbnail, platform), not full reels, under `items` with a `page`. Members carry no names.
- The map loads `GET /map/pins` with a whole-world box and filters by category on the client. A content pin is removed by its bare location id, a manual pin as `manual:{pin_id}`.
- The client polls `GET /processing-jobs` (a `{jobs: [...]}` list) at the largest `recommended_poll_after_seconds` the server returns, clamped on the client.

## Rule

Change one side and the other needs the same change. The client fails at
runtime, not at build time, so nothing catches a drift for you. A server route
with no client caller is fine; a client call with no live route is dead app
code.

## Known drift (2026-10-20)

- v2 has no plan-limit or history-lock error. `ApiException.isMonthlyReelLimitReached` and `isHistoryUpgradeRequired` still match the v1 codes, so the save-limit paywall and the locked-history state never trigger against v2.
- `MapPlaceSearchResponse.googleStatus` reads `google_status`, which v2 does not send, so it is always `ok`.
- `Reel.caption`, `sourceUrl` and `originalUrl` are never sent by v2 and stay empty.
- The chat clients were removed; the chat providers return the in-memory mocks.
