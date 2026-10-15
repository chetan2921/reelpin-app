# API surface

The REST and SSE interface between reelpin-api (server) and reelpin-app
(client). This file is an identical copy in both repos at
`.claude/contracts/api-surface.md`; change both together.

| Side | Where the truth lives |
|------|-----------------------|
| server routes | reelpin-api `app/main.py` route decorators; every route is a `[METHOD /path]` line in reelpin-api's `.claude/STRUCTURE.md` |
| server shapes | reelpin-api `app/models.py`: request and response models, `ProcessingJobStatus`, `FailureCode`, `ApiErrorResponse`, `PaginationMetadata` |
| server auth | reelpin-api `app/services/auth.py`: `require_authenticated_user` (Bearer) and the `X-Share-Token` dependency |
| server errors | reelpin-api `app/main.py` exception handlers; `ApiResponseError` and poll hints in `app/services/api_responses.py` |
| client REST | reelpin-app `lib/http/api_client.dart`; it implements every `lib/http/*_http.dart` interface |
| client chat | reelpin-app `lib/http/chat_api_http.dart`, `lib/http/collection_chat_api_http.dart`, SSE parser `lib/http/chat_sse_http.dart` |
| client shapes | reelpin-app `lib/data_models/` (`fromJson` per area); chat blocks in `lib/data_models/chat/answer_block.dart` |
| client errors | reelpin-app `lib/http/api_exception.dart`, `ApiClient._exceptionFromResponse` in `lib/http/api_client.dart`, user text in `lib/utils/error_message.dart` |

List every server route from the reelpin-api root with:

    grep -E '\[(GET|POST|PUT|PATCH|DELETE) ' .claude/STRUCTURE.md

## What both sides assume

- Every path is under `/api/v1`. The server also mounts some routes without the prefix; the client always sends it. `ApiClient` strips a doubled `/api/v1` from its base URL; the chat clients do not.
- Auth is `Authorization: Bearer <Supabase access token>`. The server takes the user from the token and ignores any `user_id` in a body, so the client never needs to send one. `ApiClient` renews the session once on a 401 and resends; the chat clients do not.
- Errors use one envelope (`ApiErrorResponse`: `success`, `error_code`, `message`, `detail`, `retryable`, optional `allowed`). The client shows only `message`, falling back to its own text. Exceptions: the folder-conflict 409 has its own shape, and SSE errors arrive as an `error` event.
- JSON is snake_case. Some inputs also accept camelCase, and the client relies on it for `POST /map/pins`. Display models say `sub_category` where `ReelResponse` and search say `subcategory`. Do not "fix" naming on one side.
- Pagination: `offset`, `cursor`, `limit` in; `PaginationMetadata` out. `GET /processing-jobs` returns a bare list; collection chat pages with `after`.
- The client polls `GET /processing-jobs` at the largest `recommended_poll_after_seconds` the server returns, clamped on the client.
- Chat SSE: `stage` events, then exactly one `answer` (with `blocks`) or `error`. The server's answer schema is in reelpin-api `app/services/chat.py`; the client drops block types it does not know, so a new block type needs both sides.

## Rule

Change one side and the other needs the same change, in a matching PR in the
other repo. The client fails at runtime, not at build time, so nothing catches a
drift for you. A server route with no client caller is fine; a client call with
no live route is dead app code (the app's Folders code, `/process-reel`,
`/processing-jobs/{id}`, `/process-video`, `/health`).

## Known drift when this was written (2026-10-15)

- The old Folders feature (`/api/v1/folders`) is switched off on both `main` and `dev`: `GET /api/v1/folders` returns an empty list (see reelpin-api `AGENTS.md`), and the app has no screen for folders. What users see as folders are Collections (`/api/v1/collections`), which work. Nothing visible breaks.
- The `README.md` endpoint lists in both repos are stale; trust the code.
