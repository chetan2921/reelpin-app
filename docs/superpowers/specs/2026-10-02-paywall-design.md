# Paywall v1: daily free chat allowance + ReelPin Pro

**Date:** 2026-10-02
**Branches:** `feature/paywall` in `reelpin` (app) and `reelpin-api` (backend), both cut from `origin/dev`.
**Plans:** both live in this repo, next to this spec.
- Backend: `docs/superpowers/plans/2026-10-02-paywall-backend.md` (runs in `~/Desktop/reelpin-api`)
- App: `docs/superpowers/plans/2026-10-02-paywall-app.md`

## Goal

Every chat answer is a Gemini call we pay for. Ship chat (still behind `CHAT_ENABLED`, which no release build sets) together with a paywall. Free users get a few chat messages a day. **ReelPin Pro**, a monthly or yearly auto-renewing subscription, gets a much higher daily cap.

**Out of scope for v1:**
- Limits on reel saves or shares. That's planned next and will reuse the same `is_pro()` gate.
- Web payments, Stripe and Razorpay.
- Promo codes and free trials. These are store-console settings, so they can be added later without code.

## Decisions (made in the brainstorming session)

| Question | Decision |
|---|---|
| Billing rail | Apple App Store and Google Play in-app subscriptions in every country, India included. |
| Subscription tooling | RevenueCat: `purchases_flutter` plus `purchases_ui_flutter`. Free under $2.5K monthly tracked revenue, 1% above that. |
| Pricing model | Option A: a free daily allowance, then Pro. |
| Allowance window | Daily. Resets at midnight IST (UTC+05:30) for every user. |
| Collection chat | The person asking spends their own allowance. Sharing a private answer into a collection makes no model call and is never charged. |
| Paywall UI | RevenueCat Paywalls, designed in the RevenueCat dashboard and shown with `RevenueCatUI.presentPaywall()`. |
| Pro cap | A fair-use cap, kept in backend config. |

### Why no Stripe or Razorpay in v1

- **Apple:** digital features sold in India must use Apple's in-app purchase. Paying through an outside link is allowed only in the US and EU storefronts, and the US fee is still in litigation (Aug 2026).
- **Google, in India:** it lets an alternative biller sit next to Play billing, but only 4 points cheaper (15% → 11%). Gateway fees, GST invoicing and Google's reporting APIs use up most of that.
- **Stripe:** invite-only for Indian businesses. RevenueCat's Web Billing can't use Indian Stripe accounts yet.
- **Both stores** are the merchant of record (they handle GST), support UPI Autopay for subscriptions in India, and allow INR price points.
- **Store fee:** 15% on subscriptions. Apple needs Small Business Program enrollment for that; Google charges 15% on subscriptions by default.
- **Later:** RevenueCat can add web billing without app changes, so nothing here blocks it.

## Architecture

```
 App (Flutter)                       RevenueCat                    reelpin-api (FastAPI)            Supabase
 ─────────────                       ──────────                    ────────────────────             ────────
 Purchases.logIn(supabaseUserId) ──▶ subscriber = Supabase id
 RevenueCatUI.presentPaywall() ────▶ StoreKit / Play Billing
                                     purchase ─ webhook ─────────▶ POST /api/v1/webhooks/revenuecat
                                                                    ├ check Authorization header
                                     GET /v1/subscribers/{id} ◀──── ├ sync_entitlement(user_id)
                                                                    └ upsert ─────────────────────▶ user_entitlements

 POST /chat/messages ──────────────────────────────────────────────▶ charge_chat_message(user_id)
 POST /collections/{id}/chat/messages (live ask)                    ├ is_pro? ◀─────────────────── user_entitlements
                                                                    ├ consume_chat_message RPC ──▶ chat_usage (atomic)
                                                                    ├ over the limit and free → sync_entitlement once
                                                                    │   (covers "paid seconds ago, webhook not here yet")
                                                                    ├ still over → 402 chat_quota_exceeded / 429 chat_fair_use_limit
                                                                    └ model call; on any error event → refund
 402 → "used today's free messages" card → GET PRO → paywall → purchased → RETRY
```

**The source of truth for "has paid" is RevenueCat.** The backend keeps a copy in `user_entitlements`. A webhook only tells the backend that something changed; the backend then fetches the subscriber from RevenueCat's REST API and stores the current state. This follows RevenueCat's own recommendation, and it handles events arriving out of order or more than once.

**Pro is active when `pro_expires_at > now()`.** Access therefore ends at expiry even if a cancellation or expiration webhook is lost. A missed renewal webhook is caught by the re-check at the paywall boundary.

## Backend (`reelpin-api`)

### Data: new migration `supabase/migrations/20261002120000_add_paywall.sql`

- **`user_entitlements`**
  - Columns: `user_id TEXT PRIMARY KEY`, `pro_expires_at TIMESTAMPTZ` (NULL means no Pro entitlement), `product_id TEXT`, `store TEXT`, `is_sandbox BOOLEAN`, `synced_at TIMESTAMPTZ`.
  - RLS is enabled with no policies, like every other table.
- **`chat_usage`**
  - Columns: `user_id TEXT`, `usage_date DATE`, `messages INTEGER`, with `PRIMARY KEY (user_id, usage_date)`.
  - RLS is enabled with no policies.
- **`consume_chat_message(p_user_id, p_usage_date, p_free_limit, p_pro_limit) → TABLE(used_messages, has_pro)`**
  - Reads Pro from `user_entitlements` and picks the limit itself, so a message costs one database round trip.
  - One atomic `INSERT … ON CONFLICT DO UPDATE … WHERE messages < limit RETURNING messages`.
  - `used_messages` is NULL when the day's allowance is spent, so two concurrent requests can't both take the last message.
  - A limit below 1 always gives NULL.
- **`refund_chat_message(p_user_id, p_usage_date)`**
  - Decrements the count, never below 0.
- **Both functions:** `REVOKE ALL … FROM PUBLIC, anon, authenticated; GRANT EXECUTE … TO service_role`. An anon-callable refund would be a free-messages exploit.
- **Account deletion:** `delete_user_account_data` already deletes from every public table that has a `user_id` column, so both new tables are covered with no change.

### `app/services/billing.py` (new)

- `chat_usage_date(now=None) -> str`: today's date in IST, as `YYYY-MM-DD`.
- `fetch_subscriber(app_user_id) -> dict | None`
  - Calls `GET https://api.revenuecat.com/v1/subscribers/{id}` with `REVENUECAT_SECRET_API_KEY`, using `urllib` like the other outbound calls.
  - Returns `None` on any network or parse failure.
- `pro_state(subscriber, entitlement_id) -> dict`: pure function that turns a subscriber into a `user_entitlements` row.
  - Pro lasts until the later of `expires_date` and `grace_period_expires_date`, so a renewal stuck in the store's billing grace period keeps access.
  - The expiry is stored in whole seconds.
  - Timestamps are parsed with `display_data._parse_datetime`.
- `sync_entitlement(user_id) -> bool | None`
  - Fetches and upserts. Returns whether Pro is active.
  - Returns `None` if RevenueCat couldn't be reached, in which case the stored row is left alone. A RevenueCat outage never removes anyone's Pro.
- `is_pro(user_id, now=None) -> bool`: reads the stored row.
- `charge_chat_message(user_id) -> Callable[[], None]`
  - Spends one message, or raises `ApiResponseError`. Returns a refund callable.
  - **Free user over the limit:** one `sync_entitlement`. If that shows Pro, the message is charged against the Pro cap. Otherwise it raises 402 `chat_quota_exceeded`, `retryable=False`, with the message "You've used today's free AI messages. Get ReelPin Pro to keep chatting, or come back tomorrow."
  - **Pro user over the cap:** raises 429 `chat_fair_use_limit`, `retryable=False`, with the message "You've reached today's chat limit. It resets at midnight IST."
  - **Database failure** (usage RPC or entitlement read): it allows the message and logs an error. That matches the existing `RATE_LIMIT_FAIL_OPEN=True` stance, and chat needs Supabase anyway.
- `webhook_authorized(header) -> bool`
  - Constant-time comparison against `REVENUECAT_WEBHOOK_AUTH`.
  - When the setting is unset it returns False, so the webhook rejects every request.
- `webhook_user_ids(event) -> list[str]`
  - Collects `app_user_id`, `original_app_user_id`, `aliases`, plus `transferred_from` and `transferred_to` for TRANSFER events.
  - Drops `$RCAnonymousID:*` IDs and duplicates.

### Database helpers (`app/services/database.py`)

- `get_user_entitlement(user_id)`
- `upsert_user_entitlement(row)`
- `consume_chat_usage(user_id, usage_date, free_limit, pro_limit) -> (int | None, bool)`
- `refund_chat_usage(user_id, usage_date)`

### Endpoints (`app/main.py`)

- **`POST /api/v1/webhooks/revenuecat`** (new)
  - Returns 401 if the header is wrong.
  - Returns 200 without syncing for `TEST` events.
  - Otherwise syncs every user ID from `webhook_user_ids`. If RevenueCat is unreachable it returns 503, so RevenueCat retries (5 retries, up to 80 minutes apart).
- **`POST /api/v1/chat/messages`:** calls `charge_chat_message` after the rate limit and before streaming starts. That way the 402 is a plain JSON error, not an SSE event.
- **`POST /api/v1/collections/{id}/chat/messages`:** the live-ask branch only, after the blank-text check and the rate limit. The `blocks` (share) branch is never charged.
- **`_chat_sse`:** gains `on_failure`, which is called before each `error` event (retrieval failed, model failed, save failed). The rule: a message only counts if an answer reaches the user.
- **`GET /api/v1/account/entitlements`:**
  - `plan` becomes `"pro"` when `is_pro(user_id)` is true.
  - Takes `?sync=true`, which re-reads RevenueCat first. The app sends it only right after a purchase, so the plan shows Pro before the webhook lands.
  - `?sync=true` has its own rate limit (6 per user per minute), so it can't be used to flood RevenueCat's API.

### Config (`app/config.py`)

| Setting | Default | Notes |
|---|---|---|
| `REVENUECAT_SECRET_API_KEY` | `None` | RevenueCat → Project settings → API keys → secret key (`sk_…`). Server only. |
| `REVENUECAT_WEBHOOK_AUTH` | `None` | A long random string. It must equal the "Authorization header value" set on the RevenueCat webhook. Use a different value for dev and prod. |
| `REVENUECAT_ENTITLEMENT_ID` | `"pro"` | |
| `CHAT_FREE_DAILY_LIMIT` | `3` | |
| `CHAT_PRO_DAILY_LIMIT` | `100` | |

## App (`reelpin`)

- **Dependencies:** `purchases_flutter` and `purchases_ui_flutter` (10.14.0 or newer). iOS is already at 15.0 and Android's minSdk is already 24 through Flutter's default, so both meet the paywall minimums.
- **`lib/env.dart` → `RevenueCatConfig`:**
  - Holds the two public SDK keys (`appl_…`, `goog_…`) as constants.
  - These keys are designed to ship inside the app. They're hard-coded so a release build can't be shipped without them.
  - `tool/reelpin.sh check_common_setup` refuses to build when either key is missing.
- **`lib/services/billing/billing_service.dart`** (new):
  - `configure()`: called once from `bootstrap()`. Does nothing when not configured, on web, or on desktop.
  - `syncUser(String? userId)`: `Purchases.logIn` on sign-in, `Purchases.logOut` on sign-out. Called from `SessionViewModel`'s auth listener.
  - `presentPaywall() -> Future<bool>`: true when the result is purchased or restored.
    - Before showing the paywall, it checks that RevenueCat's current app user ID is the signed-in Supabase user, and logs in again if not. If that fails, it doesn't open. A purchase under an anonymous or stale ID would be paid for but never unlock anything.
    - After a purchase it refreshes entitlements with `sync=true`.
  - `manageSubscription()`: opens RevenueCat's Customer Center.
- **`openPaywall()` in `lib/router.dart`:**
  - Now presents the RevenueCat paywall and returns `Future<bool>`.
  - After a purchase or restore it refreshes `entitlementsViewModelProvider`.
  - The placeholder `lib/screens/paywall/paywall_screen.dart` is deleted. `PaywallEntryPoint` moves to `lib/router.dart` and gains `chat`.
- **Chat:**
  - New `MessageStatus.limitReached` (free allowance spent) and `MessageStatus.capReached` (Pro fair-use cap spent). `lib/utils/chat_error_status.dart` maps the backend's error code to the right one.
  - The `capReached` card says "You've reached today's chat limit. It resets at midnight IST." and offers RETRY, with no GET PRO.
  - If the paywall or Customer Center can't open, a snackbar says the store couldn't be reached. `presentPaywall` returns `PaywallOutcome`.
  - Both chat view models set it when the error is `ApiException` with `errorCode == 'chat_quota_exceeded'`. Any other error is still `failed`.
  - `ChatAnswerCard` gains `onUpgrade` and shows "You've used today's free AI messages." with a GET PRO button.
  - Private chat: a successful purchase triggers `retryLast()`. Collection chat has no retry, by design, so the user asks again.
- **Profile:** a new "REELPIN PRO" card. Free users get GET PRO, which opens the paywall. Pro users get MANAGE, which opens Customer Center.
- **Android:** `MainActivity` extends `FlutterFragmentActivity` instead of `FlutterActivity`, because the RevenueCat paywall UI requires it.
- **Home banner:** unchanged. It now opens the real paywall.

## RevenueCat and store configuration

**Product IDs are permanent on Apple** and can never be reused once created. Use exactly these:

| Where | What |
|---|---|
| App Store Connect | Subscription group `ReelPin Pro`, with products `reelpin_pro_monthly` (1 month) and `reelpin_pro_annual` (1 year). |
| Play Console | One subscription, `reelpin_pro`, with base plans `monthly` (auto-renewing, 1 month) and `annual` (auto-renewing, 1 year). |
| RevenueCat entitlement | `pro`, with all four store products attached. |
| RevenueCat offering | `default` (current), with packages `$rc_monthly` and `$rc_annual`. The paywall is attached to this offering. |
| RevenueCat webhook (prod) | URL `https://api.reelpin.in/api/v1/webhooks/revenuecat`. Environment: **production and sandbox**, because App Review buys with sandbox accounts against the production backend. Authorization header = prod `REVENUECAT_WEBHOOK_AUTH`. |
| RevenueCat webhook (dev) | URL `https://api-dev.reelpin.in/api/v1/webhooks/revenuecat`. Environment: **sandbox only**. Authorization header = dev `REVENUECAT_WEBHOOK_AUTH`. |

- **Paywall copy must match the cap.** Don't say "unlimited" while `CHAT_PRO_DAILY_LIMIT` exists. Say "Up to 100 AI chat messages a day", or whatever the configured cap is. The paywall also has to show the price, billing period, a restore button and links to the Terms and Privacy Policy. RevenueCat templates include these slots; fill in the URLs.
- **Separate dev and prod user IDs:** dev and prod Supabase users have different IDs. A sandbox event for a dev user that also reaches the prod webhook creates a harmless orphan row with no matching user.

## Setup guide (owner actions)

Do these in order. Steps 1–3 can take days to be approved, so start them first.

**Apple**
1. In App Store Connect → Business, accept the **Paid Apps Agreement**, then add bank account and tax forms. Indian businesses fill in the W-8BEN.
2. Apply to the **App Store Small Business Program**, which takes Apple's cut from 30% to 15%.
3. Under App Store Connect → ReelPin → Subscriptions, create the group and the two products from the table above. Set prices with the "India" storefront priced separately in INR.
4. Under Users and Access → Integrations → **In-App Purchase**, generate a key (.p8) and note the Key ID and Issuer ID. You'll upload these to RevenueCat.
5. Under App Store Connect → ReelPin → App Information → **App Store Server Notifications**, set the URL RevenueCat gives you in step 13, for both production and sandbox.
6. Under Users and Access → Sandbox, create **2 sandbox Apple accounts**: one for India, one for the US.

**Google**

7. In Play Console → Setup → **Payments profile**, link the payments profile and bank account.
8. Under Play Console → ReelPin → Monetize → Products → **Subscriptions**, create `reelpin_pro` with the two base plans. Set INR pricing for India.
9. In Google Cloud, create a **service account** with "View financial data" and "Manage orders and subscriptions" access in Play Console → Users and permissions. Download its JSON key for RevenueCat. Google can take up to 36 hours before these credentials work.
10. Set up **Real-time developer notifications**: a Pub/Sub topic that RevenueCat walks you through.
11. Under Play Console → Setup → **License testing**, add your test Gmail accounts. Their purchases are free, and subscriptions renew every few minutes.
12. Upload a build that contains the Billing library to the **Internal testing** track, or Play won't let you create or sell products.

**RevenueCat**

13. Create a project named "ReelPin". Add an **App Store app** (bundle ID; upload the .p8 key from step 4) and a **Play Store app** (package `com.chetanjain.reelpin`; upload the service account JSON from step 9).
14. Import products, create the entitlement `pro`, and attach all products to it.
15. Create the offering `default` with the monthly and annual packages, and mark it current.
16. **Paywalls → New paywall** on `default`. Pick a template, then write the copy (see the rule about "unlimited" above), Terms and Privacy URLs, and the INR price display.
17. **Integrations → Webhooks**: add the two webhooks from the table above. Generate the two auth secrets yourself, for example with `openssl rand -hex 32`.
18. **Project settings → API keys**: copy the two public SDK keys into `lib/env.dart`, and the secret key into both backends' `REVENUECAT_SECRET_API_KEY`.

**Backend**

19. Set `REVENUECAT_SECRET_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`, `CHAT_FREE_DAILY_LIMIT` and `CHAT_PRO_DAILY_LIMIT` on the dev EC2 first.
20. Apply the migration to the **dev** Supabase project first.

## Testing

**Automated**
- Backend `unittest`:
  - IST date boundary, `pro_state` (active, expired, missing entitlement).
  - `charge_chat_message`: under the limit, at the limit (free), a just-purchased re-check, Pro cap, database failing open, refund.
  - Webhook: auth rejected, auth unset, TEST event, sync per user, anonymous IDs dropped, 503 when RevenueCat is down.
  - Both chat endpoints: 402 before streaming, the share branch never charged, refund on model failure.
  - Entitlements endpoint plan.
- Flutter tests: both view models map `chat_quota_exceeded` to `limitReached`, and other errors stay `failed`. The answer card shows GET PRO only when `limitReached`.

**Manual (dev backend, `--reelpin-env=dev`, never production)**

| # | Scenario | Expected |
|---|---|---|
| 1 | A free user sends 3 messages, then a 4th. | The 4th shows the limit card. The `chat_usage` row for today shows 3. |
| 2 | GET PRO → buy monthly with an iOS sandbox account. | The webhook arrives (check the dev logs) and the `user_entitlements` row has a future `pro_expires_at`. The question is retried and answered. |
| 3 | Same as 2 on Android with a license tester. | Same as 2. |
| 4 | Sign in on a second device with the same ReelPin account. | Pro straight away, with no restore needed. |
| 5 | Cancel in the store and wait for sandbox expiry (minutes). | The row expires and chat is limited again. |
| 6 | Restore purchases on a fresh install. | Pro comes back. |
| 7 | Refund (Play: Order management → refund; iOS: StoreKit test refund). | Pro is removed after the webhook. |
| 8 | A failed model call (temporarily point `CHAT_MODEL` at a bad name on dev). | The error card appears and the count isn't increased. |
| 9 | Collection chat: an editor asks over the limit. | That editor sees the limit card, and only their count changes. |
| 10 | Send a webhook with the wrong auth header via curl. | 401, and nothing changes. |

**Real money:** sandbox and license-tester purchases are never charged and never paid out. To check the bank side, make **one real purchase in the live store build** after launch, confirm it in App Store Connect → Sales and Trends and in the Play Console order management, then refund it. Apple pays about 33 days after the end of its fiscal month, once your balance passes the payment threshold. Google pays monthly. Expect the first deposit 1–2 months after launch.

## Known limitations (accepted for v1)

- The day resets at midnight IST for everyone, including users outside India.
- If Supabase is unreachable, chat is allowed. That's fail-open, deliberately.
- **Open question:** check whether `GET /chat/suggestions` calls the model. If it does, it's an uncapped cost outside this paywall.
- **Existing gap, tracked separately:** `delete_user_account_data` has no execute revoke.
