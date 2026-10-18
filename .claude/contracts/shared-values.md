# Shared values

Strings and limits both repos hard-code and compare at runtime. This file is an
identical copy in both repos at `.claude/contracts/shared-values.md`; change both
together.

| Value set | Server (reelpin-api) | Client (reelpin-app) |
|-----------|----------------------|----------------------|
| platform ids and labels | `app/services/platform_filters.py` (`PLATFORM_LABELS`, `PLATFORM_ALIASES`, `ALLOWED_PLATFORM_VALUES`), `app/services/source_identity.py` | `lib/constants/source_platforms.dart`; the iOS share extension keeps its own list in `ios/Share Extension/ShareViewController.swift` |
| job status, step, failure codes | `app/models.py` (`ProcessingJobStatus`, `FailureCode`), poll hints in `app/services/api_responses.py` | `lib/data_models/reels/processing_job.dart` |
| stale-job window | `WORKER_STALE_JOB_MINUTES` in `app/config.py` | the cutoff in `lib/view_models/processing_jobs_view_model.dart` |
| content type, parse status | `source_content_type` and `parse_status` written by `app/pipeline.py` and `app/tasks.py` | `lib/data_models/reels/reel.dart` |
| plans and limits | `app/services/display_data.py` (`FREE_LIMITS`, `PRO_LIMITS`, plan cards), `app/services/pro_plans.py`, table `user_entitlements` | `lib/data_models/account/user_entitlement.dart`, `lib/screens/paywall/paywall_screen.dart` |
| error codes the app acts on | raised per route in `app/main.py`, `app/services/auth.py`, `app/services/cost_controls.py` | `lib/http/api_exception.dart`, then `lib/screens/app_shell/app_shell.dart` and `lib/screens/reel_detail/reel_detail_screen.dart` |
| collection roles, visibility | collection models in `app/models.py` | `lib/data_models/collections/collection_models.dart` |
| collection link URLs | `/c/{token}` and `/c/invite/{token}`, built from `COLLECTION_SHARE_BASE_URL` in `app/main.py` | `lib/services/sharing/collection_link.dart`, App Links in `android/app/src/main/AndroidManifest.xml`, associated domains in `ios/Runner/Runner.entitlements` |

The website that serves the collection link pages and the app-association files
lives outside both repos; a change to the link shape needs it too.

## Rule

These are compared as strings at runtime. Adding or renaming a value on one side
does not fail any build: the app shows a wrong label, routes to the wrong place,
or silently ignores the case. Search both repos for the old string before
renaming it.

## Known drift when this was written (2026-10-15)

- The app opens the paywall on `monthly_reel_limit_reached` and the upgrade prompt on `history_upgrade_required` (`lib/http/api_exception.dart`), but nothing in reelpin-api `dev` sends either code.

## TikTok

The existing platform id is `tiktok`, label `TikTok`. Both registries include it.
Public posts use numeric `source_content_id` across canonical, short, share,
legacy, embed, and player aliases. Photos use `source_content_type=post`, videos
`video`, and non-post pages `link` with a URL-derived identity. Embed/player
links keep their ID while the worker determines video versus photo from public
metadata. A temporarily unresolved short link keeps its host and no ID; the
worker resolves it before media processing and saves the recovered identity.

Photos use caption/author and one cover image's OCR only. Other TikTok pages
use readable public metadata, without profile crawling or LIVE recording.
Existing `parse_status`, failure codes, queue lanes, and response fields remain
in use. Timeout/rate-limit failures remain retryable. Video metadata fallback
is labeled `ingestion_method=tiktok_metadata_only` and is not shared-cached as
full video processing. Photo metadata/cover results may be cached normally.

TikTok cards and detail/share actions use VIDEO, POST, or LINK. Older saves
without platform metadata can use their TikTok URL for labeling. Public post
URL support does not guarantee access to private, deleted, or restricted content.

TikTok About/login landing redirects cannot replace a requested post/profile.
Post redirects must keep the same numeric ID. A short share redirected to a
landing page keeps its original unresolved identity for the existing retry flow.

When direct TikTok post retrieval is blocked, the worker may use the existing
Apify provider to recover that same public post. Provider results must match
the requested numeric ID. Unresolved short shares may recover their canonical
post through this path; the existing job and reel models remain unchanged.
Videos still use Gemini audio transcription, photos still OCR one cover only,
and non-post pages are not expanded into an account/feed import.
