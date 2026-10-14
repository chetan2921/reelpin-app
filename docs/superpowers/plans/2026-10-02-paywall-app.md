# Paywall v1 — App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sell ReelPin Pro through RevenueCat. Turn the backend's 402 `chat_quota_exceeded` into an upgrade card in both chat screens, tie purchases to the Supabase user ID, and let Pro users manage their subscription.

**Architecture:**
- A singleton `BillingService` is the only code that talks to the RevenueCat SDK.
- `SessionViewModel`'s auth listener logs the RevenueCat user in and out.
- `openPaywall()` shows the RevenueCat paywall, then asks the backend to re-sync the plan.
- The chat view models map the 402 to a new `MessageStatus.limitReached`, and `ChatAnswerCard` renders it.

**Tech Stack:** Flutter (Dart ^3.11), Riverpod 2, `purchases_flutter` and `purchases_ui_flutter` 10.14.x, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-02-paywall-design.md`
**Depends on:** the backend plan `docs/superpowers/plans/2026-10-02-paywall-backend.md`. Task 3 needs its Task 5 (`?sync=true`); Task 6 needs it deployed to dev.

**Repo / branch:** `~/Desktop/Flutter/reelpin`, branch `feature/paywall` (already created from `origin/dev`). Never work on `dev` or `main`. The uncommitted `docs/index.html` change on this branch belongs to the user. Leave it alone.

## Global Constraints

- The RevenueCat app user ID is **always the Supabase user ID**. A purchase must never be made while RevenueCat holds a different or anonymous ID. `presentPaywall` re-logs-in first and refuses otherwise.
- The entitlement ID is `pro`, the same as the backend's `REVENUECAT_ENTITLEMENT_ID`.
- The backend error code that opens the upgrade card is exactly `chat_quota_exceeded`. Every other error stays `MessageStatus.failed`.
- Upgrade-card copy: "You've used today's free AI messages." The CTA is `GET PRO`.
- Every RevenueCat call is a no-op when the SDK isn't configured: no keys, web or desktop.
- Run against dev only: `tool/reelpin_flutter.sh --reelpin-env=dev …`. **Never the production API.**
- `pod install` needs `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`.
- **Never commit unless the user asks.** Each task ends with a checkpoint.

## Confirm before starting

The planning session couldn't read these files: the auto-mode safety check blocked the reads. Read them first, and adjust the snippets below if a name differs:

1. `test/view_models/session_view_model_test.dart`: how the fake `AuthService` is built and how it emits `AuthState` events (needed for Task 2's test).
2. `lib/providers.dart`: where `SessionViewModel(...)` is constructed. It already passes `unregisterPushToken:`.
3. `lib/http/account_http.dart`: `getAccountEntitlements(userId: …)` and how it builds the URL (Task 3).
4. `lib/view_models/entitlements_view_model.dart`: `refresh({bool reloadContent})` → `_refresh` → `_accountHttp.getAccountEntitlements(userId: userId)` (Task 3).
5. `lib/view_models/collection_chat_view_model.dart`: the public getter for the message list that the existing tests use. This plan assumes `messages`.
6. `lib/http/chat_api_http.dart` and `lib/http/collection_chat_api_http.dart`: confirm that a non-200 response becomes `ApiException(statusCode, errorCode: body['error_code'])` through `_exceptionFromResponse` before any SSE parsing. The backend's 402 is plain JSON.
7. The files that import `lib/screens/paywall/paywall_screen.dart` (at least `lib/router.dart` and `lib/screens/app_shell/app_shell.dart`), plus `lib/screens/reel_detail/reel_detail_screen.dart`, which uses `PaywallEntryPoint`.

## File map

| File | Responsibility |
|---|---|
| `pubspec.yaml` | Add `purchases_flutter`, `purchases_ui_flutter` |
| `android/app/src/main/kotlin/com/chetanjain/reelpin/MainActivity.kt` | `FlutterActivity` → `FlutterFragmentActivity` |
| `lib/env.dart` | `RevenueCatConfig` (public SDK keys, entitlement ID) |
| `lib/services/billing/billing_service.dart` (new) | Every RevenueCat SDK call |
| `lib/bootstrap.dart` | `BillingService.instance.configure()` |
| `lib/view_models/session_view_model.dart`, `lib/providers.dart` | `syncBillingUser` on every auth change |
| `lib/router.dart` | `PaywallEntryPoint` (+`chat`), `openPaywall()` → RevenueCat, returns `bool` |
| `lib/screens/paywall/paywall_screen.dart` | **Deleted**. The placeholder screen is replaced by the RevenueCat paywall. |
| `lib/http/account_http.dart`, `lib/view_models/entitlements_view_model.dart` | `sync` flag → `?sync=true` |
| `lib/http/api_exception.dart` | `isChatQuotaExceeded` |
| `lib/data_models/chat/chat_thread.dart` | `MessageStatus.limitReached` |
| `lib/view_models/chat_view_model.dart`, `lib/view_models/collection_chat_view_model.dart` | Map the 402 to `limitReached` |
| `lib/components/chat/chat_answer_card.dart` | Limit card with GET PRO (+ RETRY) |
| `lib/screens/chat/chat_screen.dart`, `lib/screens/collections/partials/collection_chat_panel.dart` | Wire `onUpgrade` |
| `lib/screens/profile/profile_screen.dart` | REELPIN PRO card |
| `tool/reelpin.sh` | Refuse to build without the RevenueCat keys (Task 6) |

---

### Task 1: SDK, native setup, `RevenueCatConfig`, `BillingService`

> **As built:** the package is 10.14.0. Every API name was checked against the installed source (`PaywallResult.purchased/.restored`, `Purchases.isAnonymous/appUserID/logIn/logOut`, `RevenueCatUI.presentPaywall/presentCustomerCenter`). The `purchases_ui_flutter` Android plugin itself requires `FlutterFragmentActivity`. `RevenueCatConfig.entitlementId` was **left out**: nothing in the app reads it (the backend owns the entitlement check). Verified: analyze clean, 504/504 tests, `pod install` OK, and the debug APK and unsigned iOS debug build both compile.

**Files:**
- Modify: `pubspec.yaml`, `MainActivity.kt`, `lib/env.dart`, `lib/bootstrap.dart`
- Create: `lib/services/billing/billing_service.dart`

**Interfaces:**
- Produces:
  - `RevenueCatConfig.apiKey`, `.isConfigured`, `.entitlementId`
  - `BillingService.instance` with:
    - `configure() -> Future<void>`
    - `syncUser(String? userId) -> Future<void>`
    - `presentPaywall() -> Future<bool>`
    - `manageSubscription() -> Future<void>`

- [x] **Step 1: Add the packages**

Run: `flutter pub add purchases_flutter purchases_ui_flutter`
Expected: both land in `pubspec.yaml` at `^10.14.0` or newer, and `pub get` succeeds.

- [x] **Step 2: Switch Android to `FlutterFragmentActivity`.** The RevenueCat paywall UI requires it. Confirm against RevenueCat's Flutter installation docs for the installed version.

In `MainActivity.kt`, replace `import io.flutter.embedding.android.FlutterActivity` with `import io.flutter.embedding.android.FlutterFragmentActivity`. Replace `class MainActivity : FlutterActivity() {` with `class MainActivity : FlutterFragmentActivity() {`. Nothing else changes; `configureFlutterEngine` exists on both.

- [x] **Step 3: Add `RevenueCatConfig`** (append to `lib/env.dart`, which already imports `package:flutter/foundation.dart`)

```dart
/// RevenueCat's public SDK keys (RevenueCat → Project settings → API keys).
/// They are made to ship inside the app; the secret key that can read
/// subscribers lives only on the backend. Committed rather than passed as
/// --dart-define so a release build cannot be cut without them, and
/// tool/reelpin.sh refuses to build while either is empty.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String appleApiKey = '';
  static const String googleApiKey = '';

  /// Must match the backend's REVENUECAT_ENTITLEMENT_ID.
  static const String entitlementId = 'pro';

  static String get apiKey => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => appleApiKey,
    TargetPlatform.android => googleApiKey,
    _ => '',
  };

  static bool get isConfigured => !kIsWeb && apiKey.isNotEmpty;
}
```

- [x] **Step 4: Create `lib/services/billing/billing_service.dart`**

```dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:reelpin/env.dart';
import 'package:reelpin/utils/app_logger.dart';

/// The app's only door to RevenueCat.
///
/// Purchases belong to the Supabase user id: a subscription bought on one
/// device follows the account to the next, and the backend looks it up by
/// the id it already knows. A purchase made under any other RevenueCat id
/// would be paid for but never unlock anything, so [presentPaywall] refuses
/// to open until RevenueCat holds the signed-in user's id.
///
/// Every call is a no-op when RevenueCat is not configured for this build,
/// the way Linkrunner falls back when it has no token.
class BillingService {
  BillingService._();

  static final BillingService instance = BillingService._();

  Future<void>? _ready;
  bool _configured = false;
  String? _userId;

  /// Safe to call more than once; every other call awaits it, so the auth
  /// listener firing before bootstrap finishes cannot skip the log-in.
  Future<void> configure() => _ready ??= _configure();

  Future<void> _configure() async {
    if (!RevenueCatConfig.isConfigured) return;
    try {
      await Purchases.configure(
        PurchasesConfiguration(RevenueCatConfig.apiKey),
      );
      _configured = true;
    } catch (e) {
      AppLogger.error('RevenueCat configure failed: $e');
    }
  }

  /// Called on every auth change: the signed-in user's id, or null.
  Future<void> syncUser(String? userId) async {
    _userId = (userId == null || userId.isEmpty) ? null : userId;
    await configure();
    if (!_configured) return;
    try {
      final userId = _userId;
      if (userId != null) {
        await Purchases.logIn(userId);
      } else if (!await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
    } catch (e) {
      AppLogger.error('RevenueCat user sync failed: $e');
    }
  }

  /// Shows the paywall attached to RevenueCat's current offering. True when
  /// the user bought or restored Pro.
  Future<bool> presentPaywall() async {
    await configure();
    final userId = _userId;
    if (!_configured || userId == null) return false;
    try {
      if (await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
      final result = await RevenueCatUI.presentPaywall();
      return result == PaywallResult.purchased ||
          result == PaywallResult.restored;
    } catch (e) {
      AppLogger.error('RevenueCat paywall failed: $e');
      return false;
    }
  }

  /// RevenueCat's Customer Center: cancel, change plan, restore, refund.
  Future<void> manageSubscription() async {
    await configure();
    if (!_configured) return;
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      AppLogger.error('RevenueCat customer center failed: $e');
    }
  }
}
```

After `pub get`, check these names against the installed package source under `~/.pub-cache/hosted/pub.dev/purchases_*`: `PaywallResult.purchased` and `.restored`, `Purchases.isAnonymous`, `Purchases.appUserID`, `RevenueCatUI.presentCustomerCenter`. Fix any rename.

- [x] **Step 5: Configure at launch** (`lib/bootstrap.dart`)

Right after the `if (isSupabaseConfigured) { await Supabase.initialize(...); }` block, add this (and import `package:reelpin/services/billing/billing_service.dart`):

```dart
  // Not awaited: it is not needed for the first frame, and BillingService
  // makes every later call wait for it.
  unawaited(BillingService.instance.configure());
```

- [x] **Step 6: Verify it builds**

Run:
```bash
flutter analyze
flutter test
cd ios && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install && cd ..
tool/reelpin_flutter.sh --reelpin-env=dev build apk --debug
```
Expected: analyze is clean, all tests pass, pods install, and the APK builds.

- [x] **Step 7: Checkpoint.** Leave the changes uncommitted.

---

### Task 2: Log RevenueCat in and out with the Supabase session

> **As built:** the fake already accepted `stream:`, so the test drives a `StreamController<AuthState>` with `AuthState(AuthChangeEvent.signedIn, Session(accessToken:, tokenType:, user: _signedInUser))`, then `signedOut`, and expects `['user-1', null]`. The listener closure captures the constructor parameter directly; no `_syncBillingUser` field. Verified: analyze clean, 505/505 tests.

**Files:**
- Modify: `lib/view_models/session_view_model.dart`, `lib/providers.dart`
- Test: `test/view_models/session_view_model_test.dart`

**Interfaces:**
- Consumes (Task 1): `BillingService.instance.syncUser`
- Produces: a `SessionViewModel(..., {Future<void> Function(String? userId)? syncBillingUser})` constructor parameter

- [x] **Step 1: Write the failing test** (append inside `main()` in `test/view_models/session_view_model_test.dart`)

Build the view model exactly as the existing tests in this file do (same fake `AuthService` and factories), passing the new parameter. Then drive a sign-in and a sign-out through the fake's auth stream. If the fake can't emit yet, give it a `StreamController<AuthState>` behind `authStateChanges`.

```dart
  test('every auth change is passed on to billing', () async {
    final synced = <String?>[];
    final viewModel = SessionViewModel(
      /* same fake auth service and factories as the tests above */,
      syncBillingUser: (userId) async => synced.add(userId),
    );

    /* emit AuthState(AuthChangeEvent.signedIn, <session for user "user-a">) */
    /* emit AuthState(AuthChangeEvent.signedOut, null) */
    await Future<void>.delayed(Duration.zero);

    expect(synced, ['user-a', null]);
    viewModel.dispose();
  });
```

Replace the `/* … */` lines with the fake's real calls once you've read the file (see "Confirm before starting", item 1). The assertion stays as written.

- [x] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/view_models/session_view_model_test.dart`
Expected: a compile error, because `syncBillingUser` isn't a parameter yet.

- [x] **Step 3: Implement**

In `SessionViewModel`:
- Constructor: `{Future<void> Function()? unregisterPushToken, Future<void> Function(String? userId)? syncBillingUser}`, with initializer `_syncBillingUser = syncBillingUser`.
- Field: `final Future<void> Function(String? userId)? _syncBillingUser;`
- In the `authStateChanges.listen` callback, after `unawaited(_syncShareHandoffState());`:

```dart
      final syncBillingUser = _syncBillingUser;
      if (syncBillingUser != null) {
        unawaited(syncBillingUser(state.session?.user.id));
      }
```

In `lib/providers.dart`, where `SessionViewModel(` is constructed next to `unregisterPushToken:`, add `syncBillingUser: BillingService.instance.syncUser,` and the import.

- [x] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/view_models/session_view_model_test.dart`, then `flutter test`
Expected: all pass

- [x] **Step 5: Checkpoint.** Leave the changes uncommitted.

---

### Task 3: `openPaywall()` shows RevenueCat, and the placeholder screen goes

> **As built (deviations):** (1) `EntitlementsViewModel.refresh` does **not** start a parallel refresh for `syncBilling`. It mirrors the existing `_pendingReloadContent` queue with a `_pendingSyncBilling` flag, so a sync requested mid-refresh runs right after it, and two refreshes never race over `_refreshFuture`. (2) The `ApiClient` test `getAccountEntitlements asks for a billing sync only when told to` covers the `?sync=true` URL. With `sync` off the URL is unchanged, because `_apiUri` drops an empty query map. (3) The empty `lib/screens/paywall/` folder was removed with the file. Verified: analyze clean, 506/506 on three runs. One earlier run had a single flaky failure that did not recur.

**Files:**
- Modify: `lib/router.dart`, `lib/http/account_http.dart`, `lib/view_models/entitlements_view_model.dart`, and every importer of `paywall_screen.dart`
- Delete: `lib/screens/paywall/paywall_screen.dart`

**Interfaces:**
- Consumes (Task 1): `BillingService.instance.presentPaywall()`. Consumes (backend T5): `GET /api/v1/account/entitlements?sync=true`.
- Produces:
  - `enum PaywallEntryPoint { account, saveLimit, history, chat }`, now in `lib/router.dart`
  - `Future<bool> openPaywall(BuildContext context, {PaywallEntryPoint entryPoint = PaywallEntryPoint.account})`
  - `EntitlementsViewModel.refresh({bool reloadContent = false, bool syncBilling = false})`

- [x] **Step 1: The `sync` flag on the HTTP call**

In `AccountHttp.getAccountEntitlements`, add an optional named `bool sync = false` parameter. When it's true, request the same entitlements URL with the query parameter `sync=true`. Change nothing else in that method.

- [x] **Step 2: Thread it through `EntitlementsViewModel`**

`refresh({bool reloadContent = false, bool syncBilling = false})` passes `syncBilling` into `_refresh(...)`, which calls `_accountHttp.getAccountEntitlements(userId: userId, sync: syncBilling)`. If a refresh is already in flight when `syncBilling` is true, start a new one rather than returning the in-flight future, so the post-purchase sync isn't dropped:

```dart
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null && !syncBilling) {
      // …existing dedupe branch unchanged…
    }
```

- [x] **Step 3: Replace the placeholder paywall** (`lib/router.dart`)

Move `enum PaywallEntryPoint { account, saveLimit, history }` out of `paywall_screen.dart` into `router.dart`, adding `chat`. Delete `paywallRoute`. Replace `openPaywall` with:

```dart
/// Shows RevenueCat's paywall. True when the user bought or restored Pro; the
/// plan is then re-read with a backend sync, because the purchase webhook may
/// not have landed yet and every screen gating on the plan should update now.
Future<bool> openPaywall(
  BuildContext context, {
  PaywallEntryPoint entryPoint = PaywallEntryPoint.account,
}) async {
  unawaited(
    AnalyticsService.log(
      AnalyticsEvent.paywallViewed,
      parameters: {'entry_point': entryPoint.name},
    ),
  );
  final container = ProviderScope.containerOf(context, listen: false);
  final unlocked = await BillingService.instance.presentPaywall();
  if (unlocked) {
    unawaited(
      container
          .read(entitlementsViewModelProvider)
          .refresh(reloadContent: true, syncBilling: true),
    );
  }
  return unlocked;
}
```

Remove `import 'package:reelpin/screens/paywall/paywall_screen.dart';` from `router.dart`. Add imports for `BillingService`, `flutter_riverpod` (if it's not already imported) and `providers.dart` (if it's not already imported).

- [x] **Step 4: Delete the placeholder and fix importers**

Run: `rm lib/screens/paywall/paywall_screen.dart` (a working-tree delete only; nothing is staged or committed).

In every file that imported `paywall_screen.dart` (`app_shell.dart` for sure), remove that import and make sure `package:reelpin/router.dart` is imported so `PaywallEntryPoint` resolves. Existing callers ignore the new `bool` return, which is fine.

- [x] **Step 5: Verify**

Run: `flutter analyze` and `flutter test`
Expected: clean, all pass. Then `grep -rn "PaywallScreen\|paywallRoute" lib test` should find nothing.

- [x] **Step 6: Checkpoint.** Leave the changes uncommitted.

---

### Task 4: The upgrade card in both chats

> **As built:** both HTTP clients were confirmed to turn a non-2xx reply into `ApiException(errorCode: body['error_code'])` before SSE parsing. The `messages` getter exists. `_historyFrom` already sends only `complete` answers, so `limitReached` is excluded with no change. Each fail helper had exactly one caller. **Extra:** two widget tests in `test/components/chat/chat_answer_card_test.dart`: the limit card's GET PRO and RETRY call back, and GET PRO is hidden with no `onUpgrade`. They were written right after the card, not strictly before it. Verified: analyze clean, 510/510.

**Files:**
- Modify: `lib/http/api_exception.dart`, `lib/data_models/chat/chat_thread.dart`, `lib/view_models/chat_view_model.dart`, `lib/view_models/collection_chat_view_model.dart`, `lib/components/chat/chat_answer_card.dart`, `lib/screens/chat/chat_screen.dart`, `lib/screens/collections/partials/collection_chat_panel.dart`
- Test: `test/view_models/chat_view_model_test.dart`, `test/view_models/collection_chat_view_model_test.dart`

**Interfaces:**
- Consumes (Task 3): `openPaywall(...) -> Future<bool>`, `PaywallEntryPoint.chat`
- Produces:
  - `MessageStatus.limitReached`
  - `ApiException.isChatQuotaExceeded`
  - `ChatAnswerCard({..., VoidCallback? onUpgrade})`

- [x] **Step 1: Write the failing view-model tests**

In `test/view_models/chat_view_model_test.dart`, add `import 'package:reelpin/http/api_exception.dart';` and:

```dart
class _QuotaChatHttp implements ChatHttp {
  @override
  Future<List<String>> fetchSuggestions() async => const [];

  @override
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
    List<ChatHistoryEntry> history = const [],
  }) async* {
    throw const ApiException(
      "You've used today's free AI messages.",
      402,
      errorCode: 'chat_quota_exceeded',
    );
  }
}
```

Inside `main()`:

```dart
  test('a spent daily allowance marks the answer limitReached', () async {
    final viewModel = build(_QuotaChatHttp());

    await viewModel.send('tennis');

    final messages = viewModel.activeThread!.messages;
    expect(messages.first.text, 'tennis');
    expect(messages.last.status, MessageStatus.limitReached);
  });
```

The existing `'a failure marks the answer failed and keeps the question'` test keeps proving that other errors stay `failed`.

In `test/view_models/collection_chat_view_model_test.dart`, add the `api_exception.dart` import and a fake shaped exactly like `_FailingCollectionChatHttp` whose `ask` throws the same `ApiException`:

```dart
class _QuotaCollectionChatHttp implements CollectionChatHttp {
  @override
  Future<List<CollectionChatThread>> fetchThreads(String collectionId) async =>
      const [];

  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    required String threadId,
    String? after,
  }) async => const CollectionChatPage();

  @override
  Stream<ChatEvent> ask({
    required String collectionId,
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
  }) async* {
    throw const ApiException(
      "You've used today's free AI messages.",
      402,
      errorCode: 'chat_quota_exceeded',
    );
  }

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String threadId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) async {}

  @override
  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  }) async {}
}
```

Inside `main()` (`cache()` is the file's existing helper):

```dart
  test('a spent daily allowance marks the pending answer limitReached', () async {
    final viewModel =
        CollectionChatViewModel(_QuotaCollectionChatHttp(), 'c1', cache: cache());

    await viewModel.ask('where do we start?');

    expect(viewModel.messages.last.status, MessageStatus.limitReached);
  });
```

- [x] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/view_models/chat_view_model_test.dart test/view_models/collection_chat_view_model_test.dart`
Expected: a compile error, because `MessageStatus.limitReached` doesn't exist yet.

- [x] **Step 3: Model and exception**

`lib/data_models/chat/chat_thread.dart`: `enum MessageStatus { sending, complete, failed, limitReached }`. `fromJson` already looks values up by name.

`lib/http/api_exception.dart`, next to the other getters:

```dart
  /// The backend's daily free chat allowance is spent; the app offers Pro.
  bool get isChatQuotaExceeded => errorCode == 'chat_quota_exceeded';
```

- [x] **Step 4: Map the error in both view models**

`chat_view_model.dart`: in `_consume`'s `catch (e)`, replace `_failAnswer(threadId, pendingId);` with `_failAnswer(threadId, pendingId, e);`, and change `_failAnswer` to:

```dart
  void _failAnswer(String threadId, String pendingId, Object error) {
    final status = error is ApiException && error.isChatQuotaExceeded
        ? MessageStatus.limitReached
        : MessageStatus.failed;
    _updateMessage(
      threadId,
      pendingId,
      (message) => message.copyWith(status: status),
    );
  }
```

Search the file for other `_failAnswer(` callers and pass the error they caught. If one has no error in hand, pass a plain `StateError('…')`, which maps to `failed`.

`collection_chat_view_model.dart`: in `ask`'s `catch (e)`, replace `_failPending(pendingId);` with `_failPending(pendingId, e);`. Change `_failPending` the same way:

```dart
  void _failPending(String pendingId, Object error) {
    final status = error is ApiException && error.isChatQuotaExceeded
        ? MessageStatus.limitReached
        : MessageStatus.failed;
    _replace(pendingId, (m) => m.copyWith(status: status));
  }
```

Add `import 'package:reelpin/http/api_exception.dart';` to both files if it's missing. Check that `_historyFrom` in `chat_view_model.dart` sends only `complete` answers as history. If it filters with `!= failed` instead, extend the check so `limitReached` is excluded too.

- [x] **Step 5: Run the tests and confirm they pass**

Run: `flutter test test/view_models/chat_view_model_test.dart test/view_models/collection_chat_view_model_test.dart`
Expected: all pass

- [x] **Step 6: Render it** (`lib/components/chat/chat_answer_card.dart`)

Add the field and the constructor parameter:

```dart
  /// Opens the paywall from a limitReached answer. Null hides GET PRO.
  final VoidCallback? onUpgrade;
```

(`this.onUpgrade,` goes in the constructor.) Replace the `children:` expression of the card's `Column` with:

```dart
        children: switch (message.status) {
          MessageStatus.failed => [_buildFailure(context)],
          MessageStatus.limitReached => [_buildLimitReached(context)],
          _ => [
            if (message.isShared) _buildSharedMarker(context),
            ...message.blocks.map((b) => _buildBlock(context, b)),
            if (message.status == MessageStatus.complete)
              ChatAnswerActions(
                message: message,
                onSaveToCollection: onSaveToCollection,
              ),
          ],
        },
```

Add the builder next to `_buildFailure`, using the same button style:

```dart
  Widget _buildLimitReached(BuildContext context) {
    final onUpgrade = this.onUpgrade;
    final onRetry = this.onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "You've used today's free AI messages.",
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (onUpgrade != null) _cardButton(context, 'GET PRO', onUpgrade),
            if (onUpgrade != null && onRetry != null) const SizedBox(width: 8),
            if (onRetry != null) _cardButton(context, 'RETRY', onRetry),
          ],
        ),
      ],
    );
  }

  Widget _cardButton(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.yellow,
          border: Border.all(color: AppColors.fg(context)),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            color: AppColors.black,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
```

Leave `_buildFailure` unchanged. Don't refactor it onto `_cardButton`; that's outside this change.

- [x] **Step 7: Wire the screens**

`lib/screens/chat/chat_screen.dart`, in the `ChatAnswerCard(` call:

```dart
          onUpgrade: () async {
            final unlocked = await openPaywall(
              context,
              entryPoint: PaywallEntryPoint.chat,
            );
            // Pro now: the backend re-checks RevenueCat at the limit, so the
            // same question goes through without the user typing it again.
            if (unlocked && isLastMessage) unawaited(viewModel.retryLast());
          },
```

`lib/screens/collections/partials/collection_chat_panel.dart`, in its `ChatAnswerCard(` call:

```dart
          // No auto-retry after buying: a shared thread only gets questions
          // someone deliberately asks (see onRetry above).
          onUpgrade: () => unawaited(
            openPaywall(context, entryPoint: PaywallEntryPoint.chat),
          ),
```

- [x] **Step 8: Verify**

Run: `flutter analyze` and `flutter test`
Expected: clean, all pass

- [x] **Step 9: Checkpoint.** Leave the changes uncommitted.

---

### Task 5: REELPIN PRO card in Profile

> **As built:** `isPro` is read with `ref.watch(entitlementsViewModelProvider)` at the top of `build`, next to the existing session and theme watches, rather than inside a `Builder`. Verified: analyze clean, 510/510. **Still open (Step 2):** the on-device look needs a signed-in account, which the agent does not do, so it is folded into Task 6's manual run.

**Files:**
- Modify: `lib/screens/profile/profile_screen.dart`

- [x] **Step 1: Add the section** right before `_sectionTitle(context, 'ACCOUNT'),`, matching the HELP card's layout:

```dart
                _sectionTitle(context, 'REELPIN PRO'),
                SizedBox(height: layout.gap(10)),
                Builder(
                  builder: (context) {
                    final isPro =
                        ref.watch(entitlementsViewModelProvider).entitlement?.isPro ==
                        true;
                    return GestureDetector(
                      onTap: () => isPro
                          ? unawaited(BillingService.instance.manageSubscription())
                          : unawaited(openPaywall(context)),
                      child: _actionCard(
                        context,
                        color: AppColors.bg(context),
                        title: isPro ? 'YOU HAVE PRO' : 'GET REELPIN PRO',
                        subtitle: isPro
                            ? 'MANAGE, CHANGE OR CANCEL YOUR SUBSCRIPTION.'
                            : 'MORE AI CHAT MESSAGES EVERY DAY.',
                        trailing: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.inset(12),
                            vertical: layout.gap(10),
                          ),
                          decoration: AppTheme.brutalBox(
                            context,
                            color: AppColors.yellow,
                            shadow: false,
                          ),
                          child: Text(
                            isPro ? 'MANAGE' : 'GET PRO',
                            style: GoogleFonts.spaceMono(
                              color: AppColors.black,
                              fontSize: layout.font(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: layout.gap(18)),
```

Add `import 'package:reelpin/services/billing/billing_service.dart';`. `router.dart` and `providers.dart` are already imported, and `ref` is available (the screen already calls `ref.read(entitlementsViewModelProvider)`). If the screen's `build` already watches `entitlementsViewModelProvider` higher up, use that value instead of the `Builder`.

- [ ] **Step 2: Verify**

Run: `flutter analyze` and `flutter test`. Then run `tool/reelpin_flutter.sh --reelpin-env=dev run --dart-define=CHAT_ENABLED=true` and check that the card shows GET PRO for a free account.

- [x] **Step 3: Checkpoint.** Leave the changes uncommitted.

---

### Task 6: Keys, build guard, and sandbox end-to-end

Owner-assisted, against dev only.

> **As built (2026-10-04):** the public keys are in `RevenueCatConfig`, and the guard is in `check_common_setup`. `tool/reelpin.sh doctor all` passes, and a copy of `env.dart` with an empty key fails the guard. The dev build launches on the iOS simulator with RevenueCat configured (StoreKit listener running) and no crash. Analyze is clean and 514/514 tests pass.


- [x] **Step 1:** Once the owner has finished spec setup steps 13–18, paste the two public SDK keys into `RevenueCatConfig.appleApiKey` and `RevenueCatConfig.googleApiKey`.
- [x] **Step 2: Build guard.** In `tool/reelpin.sh` `check_common_setup`, after the existing `require_text "$ROOT_DIR/lib/env.dart" …` lines, add:

```bash
  require_text "$ROOT_DIR/lib/env.dart" "appleApiKey = 'appl_" \
    "RevenueCatConfig.appleApiKey is empty. Paste the Apple public SDK key from RevenueCat → API keys."
  require_text "$ROOT_DIR/lib/env.dart" "googleApiKey = 'goog_" \
    "RevenueCatConfig.googleApiKey is empty. Paste the Google public SDK key from RevenueCat → API keys."
```

- [ ] **Step 3: iOS.** In Xcode → Runner → Signing & Capabilities, add **In-App Purchase**. Paywalls don't render in the Simulator without a StoreKit configuration, so test on a device with a sandbox Apple account (Settings → App Store → Sandbox Account).
- [ ] **Step 4: Android.** Build with `tool/reelpin_flutter.sh --reelpin-env=dev build appbundle --dart-define=CHAT_ENABLED=true`, upload it to the **Internal testing** track, and install it from the opt-in link on a license-tester account.
- [ ] **Step 4b: Two extra device checks found later:**
  - **Pending UPI payment.** On Android, a license tester buys with Google's **"Slow test card, approves after a few minutes"**. Record what the paywall shows and what `presentPaywall` returns. If the user sees "Couldn't reach the store", add handling for `PurchasesErrorCode.paymentPendingError` (an `onPurchaseError` callback) that says the payment is processing. If RevenueCat already shows a sensible message, change nothing.
  - **No Apple ID prompt at launch.** On a real iPhone with a normal Apple ID, cold-start the app and confirm no "Apple Account Verification" prompt appears. One appeared on the simulator on 2026-10-04, because the simulator's Apple account needed its password re-entered, and RevenueCat touches StoreKit at configure time.
- [ ] **Step 5:** Run every row of the spec's manual testing table (1–10) and record the result of each. Report failures with screenshots and logs. Don't call it done without that table filled in.
- [ ] **Step 6: Checkpoint.** Leave the changes uncommitted. The owner decides about commits, PRs and promotion.

## Self-review notes

- **Spec coverage:**
  - SDK, keys and the Android activity → T1.
  - Log-in and log-out → T2.
  - The paywall replacing the placeholder, plus post-purchase sync → T3.
  - The limit card in both chats; auto-retry in private chat and none in collection chat → T4.
  - Profile Manage and Get Pro → T5.
  - The build guard and the sandbox matrix → T6.
  - The home banner needs no change: it calls `openPaywall`, which is now real.
- **Known gaps in this plan.** Task 2's test body and the Task 3 HTTP edit depend on files the planning session couldn't read. "Confirm before starting" lists them. Everything else is spelled out.
