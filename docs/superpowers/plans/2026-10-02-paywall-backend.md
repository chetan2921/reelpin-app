# Paywall v1 — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce a daily free chat allowance and a Pro fair-use cap on both chat endpoints. Keep a server-side copy of each user's RevenueCat Pro entitlement, fed by a webhook.

**Architecture:**
- A new `app/services/billing.py` owns three things: entitlement sync from RevenueCat's REST API, the `is_pro` check, and `charge_chat_message`.
- Two new Supabase tables hold the entitlement copy and the per-day usage counter. An atomic RPC spends one message only while the day has room.
- The chat endpoints charge before streaming starts, so a 402 is plain JSON. They refund when no answer reaches the user.

**Tech Stack:** FastAPI, supabase-py 2.10, stdlib `urllib` for RevenueCat, stdlib `unittest`.

**Spec:** `reelpin/docs/superpowers/specs/2026-10-02-paywall-design.md` (in the app repo, next to this plan)

**Repo / branch:** `~/Desktop/reelpin-api`, branch `feature/paywall` (already created from `origin/dev`). Never work on `dev` or `main`.

## Global Constraints

- Error codes are exactly `chat_quota_exceeded` (HTTP 402) and `chat_fair_use_limit` (HTTP 429), both `retryable=False`.
- The allowance day is the calendar date in IST (UTC+05:30, a fixed offset with no tzdata).
- Defaults: `CHAT_FREE_DAILY_LIMIT=3`, `CHAT_PRO_DAILY_LIMIT=100`, `REVENUECAT_ENTITLEMENT_ID="pro"`.
- Pro is active only while `pro_expires_at > now`. A RevenueCat outage must never remove Pro: on a failed fetch, keep the stored row.
- A usage-store failure lets the message through (fail open) and logs an error.
- The webhook rejects everything when `REVENUECAT_WEBHOOK_AUTH` is unset.
- New SQL functions: `REVOKE ALL … FROM PUBLIC, anon, authenticated` and `GRANT EXECUTE … TO service_role`.
- The collection-chat `blocks` (share) branch is never charged.
- Tests: `python -m unittest discover -s tests` must stay green.
- **Never commit unless the user asks.** Each task ends with a checkpoint, not a commit.
- **Never touch the production Supabase or the production API.**

## File map

| File | Responsibility |
|---|---|
| `supabase/migrations/20261002120000_add_paywall.sql` (create) | `user_entitlements`, `chat_usage`, `consume_chat_message`, `refund_chat_message` |
| `app/services/database.py` (modify) | Five thin data helpers |
| `app/config.py` (modify) | Five settings |
| `app/services/billing.py` (create) | Entitlement sync, `is_pro`, `charge_chat_message`, webhook helpers |
| `app/models.py` (modify) | `UsageResponse.chat_messages_today`, `LimitResponse.chat_messages_per_day` |
| `app/services/display_data.py` (modify) | `build_entitlements_response` takes chat usage and limit |
| `app/main.py` (modify) | Webhook route, charging in both chat endpoints, `_chat_sse(on_failure=…)`, real plan in entitlements |
| `tests/test_billing_data.py` (create) | Data helper tests |
| `tests/test_billing.py` (create) | Billing service, webhook and entitlements endpoint tests |
| `tests/test_collection_chat.py` (modify) | Charging tests on both chat endpoints, plus patching the charge in the existing helpers |

---

### Task 1: Schema and data helpers

**Files:**
- Create: `supabase/migrations/20261002120000_add_paywall.sql`
- Modify: `app/services/database.py` (append at end of file)
- Test: `tests/test_billing_data.py`

**Interfaces:**
- Produces:
  - `get_user_entitlement(user_id: str) -> dict | None`
  - `upsert_user_entitlement(row: dict) -> None`
  - `consume_chat_usage(user_id: str, usage_date: str, daily_limit: int) -> int | None`
  - `refund_chat_usage(user_id: str, usage_date: str) -> None`
  - `get_chat_usage(user_id: str, usage_date: str) -> int`
  - All five let exceptions propagate. The caller decides whether to fail open.

- [x] **Step 1: Write the migration**

```sql
-- Paywall v1: who has Pro, and how many chat messages each user has spent today.
--
-- user_entitlements is a copy of RevenueCat's view of each user, refreshed by
-- the backend whenever RevenueCat's webhook says something changed. Pro is
-- active while pro_expires_at is in the future, so access ends on time even
-- if an expiration event is never delivered. NULL means no Pro entitlement.
--
-- Both tables are read and written only by the backend with the service-role
-- key: RLS is on with no policies, like the rest of the schema. Their user_id
-- column means delete_user_account_data clears both on account deletion.
CREATE TABLE IF NOT EXISTS user_entitlements (
    user_id TEXT PRIMARY KEY,
    pro_expires_at TIMESTAMPTZ,
    product_id TEXT,
    store TEXT,
    is_sandbox BOOLEAN NOT NULL DEFAULT FALSE,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE user_entitlements ENABLE ROW LEVEL SECURITY;

-- One row per user per allowance day: the calendar date in IST.
CREATE TABLE IF NOT EXISTS chat_usage (
    user_id TEXT NOT NULL,
    usage_date DATE NOT NULL,
    messages INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE chat_usage ENABLE ROW LEVEL SECURITY;

-- Spends one message if the day's allowance has room and returns the new
-- count, or NULL when it is already spent. One statement, so two requests
-- racing for the last message cannot both get it.
CREATE OR REPLACE FUNCTION consume_chat_message(
    p_user_id TEXT,
    p_usage_date DATE,
    p_daily_limit INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    used INTEGER;
BEGIN
    IF p_daily_limit IS NULL OR p_daily_limit < 1 THEN
        RETURN NULL;
    END IF;

    INSERT INTO chat_usage (user_id, usage_date, messages)
    VALUES (p_user_id, p_usage_date, 1)
    ON CONFLICT (user_id, usage_date)
    DO UPDATE SET messages = chat_usage.messages + 1
    WHERE chat_usage.messages < p_daily_limit
    RETURNING messages INTO used;

    RETURN used;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Gives back a message whose answer never reached the user.
CREATE OR REPLACE FUNCTION refund_chat_message(p_user_id TEXT, p_usage_date DATE)
RETURNS VOID AS $$
    UPDATE chat_usage
    SET messages = messages - 1
    WHERE user_id = p_user_id
      AND usage_date = p_usage_date
      AND messages > 0;
$$ LANGUAGE sql SET search_path = public;

-- Supabase grants EXECUTE on new functions to anon and authenticated directly,
-- so revoking from PUBLIC alone is not enough. A refund any client could call
-- would be unlimited free messages.
REVOKE ALL ON FUNCTION consume_chat_message(TEXT, DATE, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION refund_chat_message(TEXT, DATE) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION consume_chat_message(TEXT, DATE, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION refund_chat_message(TEXT, DATE) TO service_role;
```

The functions are SECURITY INVOKER (the default) on purpose. Even if a grant were missed, RLS with no policies stops anon from writing `chat_usage`.

- [x] **Step 2: Write the failing data-helper tests** (`tests/test_billing_data.py`)

```python
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.services.database import (
    consume_chat_usage,
    get_chat_usage,
    get_user_entitlement,
    refund_chat_usage,
    upsert_user_entitlement,
)


def _client_returning(data):
    client = MagicMock()
    result = SimpleNamespace(data=data)
    client.rpc.return_value.execute.return_value = result
    chain = client.table.return_value
    chain.select.return_value = chain
    chain.eq.return_value = chain
    chain.limit.return_value = chain
    chain.upsert.return_value = chain
    chain.execute.return_value = result
    return client


class ChatUsageHelperTests(unittest.TestCase):
    def test_consume_passes_the_limit_and_returns_the_new_count(self):
        client = _client_returning(2)
        with patch("app.services.database._get_client", return_value=client):
            self.assertEqual(consume_chat_usage("u1", "2026-10-02", 3), 2)
        client.rpc.assert_called_once_with(
            "consume_chat_message",
            {"p_user_id": "u1", "p_usage_date": "2026-10-02", "p_daily_limit": 3},
        )

    def test_consume_is_none_once_the_day_is_spent(self):
        with patch("app.services.database._get_client", return_value=_client_returning(None)):
            self.assertIsNone(consume_chat_usage("u1", "2026-10-02", 3))

    def test_refund_calls_the_refund_rpc(self):
        client = _client_returning(None)
        with patch("app.services.database._get_client", return_value=client):
            refund_chat_usage("u1", "2026-10-02")
        client.rpc.assert_called_once_with(
            "refund_chat_message", {"p_user_id": "u1", "p_usage_date": "2026-10-02"}
        )

    def test_usage_is_zero_with_no_row(self):
        with patch("app.services.database._get_client", return_value=_client_returning([])):
            self.assertEqual(get_chat_usage("u1", "2026-10-02"), 0)

    def test_usage_reads_the_days_count(self):
        with patch("app.services.database._get_client", return_value=_client_returning([{"messages": 2}])):
            self.assertEqual(get_chat_usage("u1", "2026-10-02"), 2)


class EntitlementHelperTests(unittest.TestCase):
    def test_get_returns_the_row(self):
        row = {"user_id": "u1", "pro_expires_at": "2026-11-01T00:00:00+00:00"}
        with patch("app.services.database._get_client", return_value=_client_returning([row])):
            self.assertEqual(get_user_entitlement("u1"), row)

    def test_get_is_none_without_a_row(self):
        with patch("app.services.database._get_client", return_value=_client_returning([])):
            self.assertIsNone(get_user_entitlement("u1"))

    def test_upsert_conflicts_on_user_id(self):
        client = _client_returning([])
        row = {"user_id": "u1", "pro_expires_at": None}
        with patch("app.services.database._get_client", return_value=client):
            upsert_user_entitlement(row)
        client.table.assert_called_with("user_entitlements")
        client.table.return_value.upsert.assert_called_once_with(row, on_conflict="user_id")


if __name__ == "__main__":
    unittest.main()
```

- [x] **Step 3: Run the tests and confirm they fail**

Run: `python -m unittest tests.test_billing_data -v`
Expected: `ImportError: cannot import name 'consume_chat_usage'`

- [x] **Step 4: Implement the helpers** (append to `app/services/database.py`)

```python
USER_ENTITLEMENTS_TABLE = "user_entitlements"
CHAT_USAGE_TABLE = "chat_usage"


def get_user_entitlement(user_id: str) -> dict | None:
    """The stored copy of a user's RevenueCat Pro entitlement, or None."""
    result = (
        _get_client()
        .table(USER_ENTITLEMENTS_TABLE)
        .select("*")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    rows = result.data or []
    return rows[0] if rows else None


def upsert_user_entitlement(row: dict) -> None:
    _get_client().table(USER_ENTITLEMENTS_TABLE).upsert(row, on_conflict="user_id").execute()


def consume_chat_usage(user_id: str, usage_date: str, daily_limit: int) -> int | None:
    """Spends one chat message for the day and returns the new count, or None
    when the day's allowance is already spent."""
    result = (
        _get_client()
        .rpc(
            "consume_chat_message",
            {"p_user_id": user_id, "p_usage_date": usage_date, "p_daily_limit": daily_limit},
        )
        .execute()
    )
    return result.data if isinstance(result.data, int) else None


def refund_chat_usage(user_id: str, usage_date: str) -> None:
    _get_client().rpc(
        "refund_chat_message", {"p_user_id": user_id, "p_usage_date": usage_date}
    ).execute()


def get_chat_usage(user_id: str, usage_date: str) -> int:
    result = (
        _get_client()
        .table(CHAT_USAGE_TABLE)
        .select("messages")
        .eq("user_id", user_id)
        .eq("usage_date", usage_date)
        .limit(1)
        .execute()
    )
    rows = result.data or []
    return int(rows[0]["messages"]) if rows else 0
```

- [x] **Step 5: Run the tests and confirm they pass**

Run: `python -m unittest tests.test_billing_data -v`
Expected: 8 tests, OK

- [ ] **Step 6: Apply the migration to DEV Supabase only and check it**

Apply it the way earlier migrations in `supabase/migrations/` were applied, against the **dev** project. If you aren't sure how, ask the user; don't guess. Then run this in the dev SQL editor:

```sql
-- Free limit 2, Pro limit 5. Each row reads (used_messages, has_pro).
select * from consume_chat_message('plan-check', '2026-10-02', 2, 5);  -- 1, false
select * from consume_chat_message('plan-check', '2026-10-02', 2, 5);  -- 2, false
select * from consume_chat_message('plan-check', '2026-10-02', 2, 5);  -- NULL, false
select refund_chat_message('plan-check', '2026-10-02');
select * from consume_chat_message('plan-check', '2026-10-02', 2, 5);  -- 2, false
insert into user_entitlements (user_id, pro_expires_at) values ('plan-check', now() + interval '1 day');
select * from consume_chat_message('plan-check', '2026-10-02', 2, 5);  -- 3, true (the Pro limit applies now)
select * from consume_chat_message('plan-check', '2026-10-02', 0, 0);  -- NULL, true
select grantee from information_schema.routine_privileges
 where routine_name in ('consume_chat_message', 'refund_chat_message');  -- no anon / authenticated rows
delete from chat_usage where user_id = 'plan-check';
delete from user_entitlements where user_id = 'plan-check';
```

- [x] **Step 7: Checkpoint.** `python -m unittest discover -s tests` is green. Leave the changes uncommitted.

---

### Task 2: Billing service: entitlement sync, `is_pro`, `charge_chat_message`

**Files:**
- Modify: `app/config.py`. Add the settings right after `CHAT_HISTORY_MAX_MESSAGES`.
- Create: `app/services/billing.py`
- Test: `tests/test_billing.py`

**Interfaces:**
- Consumes (Task 1): `get_user_entitlement`, `upsert_user_entitlement`, `consume_chat_usage`, `refund_chat_usage`.
- Produces:
  - `chat_usage_date(now: datetime | None = None) -> str`
  - `pro_state(subscriber: dict, entitlement_id: str) -> dict`
  - `fetch_subscriber(app_user_id: str) -> dict | None`
  - `sync_entitlement(user_id: str) -> bool | None`
  - `is_pro(user_id: str, now: datetime | None = None) -> bool`
  - `charge_chat_message(user_id: str) -> Callable[[], None]`

- [x] **Step 1: Add the settings** (`app/config.py`, after `CHAT_HISTORY_MAX_MESSAGES: int = 6`)

```python
    # Paywall (RevenueCat). The secret key reads subscribers from RevenueCat's
    # REST API; the webhook auth must equal the Authorization header value set
    # on the RevenueCat webhook, and when unset every webhook call is refused.
    REVENUECAT_SECRET_API_KEY: str | None = None
    REVENUECAT_WEBHOOK_AUTH: str | None = None
    REVENUECAT_ENTITLEMENT_ID: str = "pro"
    # Chat messages per IST day. Pro's cap is fair use: paywall copy must quote
    # it rather than promise "unlimited".
    CHAT_FREE_DAILY_LIMIT: int = 3
    CHAT_PRO_DAILY_LIMIT: int = 100
```

- [x] **Step 2: Write the failing tests** (`tests/test_billing.py`)

```python
import io
import json
import unittest
import urllib.error
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.services import billing
from app.services.api_responses import ApiResponseError

NOW = datetime(2026, 10, 2, 12, 0, tzinfo=timezone.utc)


def _settings(**over):
    values = dict(
        CHAT_FREE_DAILY_LIMIT=3,
        CHAT_PRO_DAILY_LIMIT=100,
        REVENUECAT_ENTITLEMENT_ID="pro",
        REVENUECAT_SECRET_API_KEY="sk_test",
        REVENUECAT_WEBHOOK_AUTH="Bearer hook-secret",
    )
    values.update(over)
    return SimpleNamespace(**values)


def _subscriber(expires="2026-11-02T12:00:00Z", product="reelpin_pro_monthly"):
    return {
        "entitlements": {"pro": {"expires_date": expires, "product_identifier": product}},
        "subscriptions": {product: {"store": "app_store", "is_sandbox": True}},
    }


class UsageDateTests(unittest.TestCase):
    def test_the_day_turns_at_midnight_ist(self):
        self.assertEqual(
            billing.chat_usage_date(datetime(2026, 10, 1, 18, 29, tzinfo=timezone.utc)),
            "2026-10-01",
        )
        self.assertEqual(
            billing.chat_usage_date(datetime(2026, 10, 1, 18, 30, tzinfo=timezone.utc)),
            "2026-10-02",
        )


class ProStateTests(unittest.TestCase):
    def test_an_active_entitlement_carries_its_expiry_and_store(self):
        state = billing.pro_state(_subscriber(), "pro")
        self.assertEqual(state["pro_expires_at"], "2026-11-02T12:00:00+00:00")
        self.assertEqual(state["product_id"], "reelpin_pro_monthly")
        self.assertEqual(state["store"], "app_store")
        self.assertTrue(state["is_sandbox"])

    def test_no_entitlement_means_no_expiry(self):
        state = billing.pro_state({"entitlements": {}, "subscriptions": {}}, "pro")
        self.assertIsNone(state["pro_expires_at"])

    def test_a_grant_with_no_expiry_never_expires(self):
        state = billing.pro_state(_subscriber(expires=None), "pro")
        self.assertEqual(state["pro_expires_at"], "9999-12-31T00:00:00+00:00")


class FetchSubscriberTests(unittest.TestCase):
    def test_reads_the_subscriber_with_the_secret_key(self):
        response = MagicMock()
        response.__enter__.return_value = io.BytesIO(json.dumps({"subscriber": _subscriber()}).encode())
        with (
            patch("app.services.billing.get_settings", return_value=_settings()),
            patch("app.services.billing.urllib.request.urlopen", return_value=response) as urlopen,
        ):
            subscriber = billing.fetch_subscriber("user/1")
        request = urlopen.call_args.args[0]
        self.assertEqual(request.full_url, "https://api.revenuecat.com/v1/subscribers/user%2F1")
        self.assertEqual(request.get_header("Authorization"), "Bearer sk_test")
        self.assertEqual(subscriber["entitlements"]["pro"]["product_identifier"], "reelpin_pro_monthly")

    def test_a_network_failure_is_none(self):
        with (
            patch("app.services.billing.get_settings", return_value=_settings()),
            patch("app.services.billing.urllib.request.urlopen", side_effect=urllib.error.URLError("down")),
        ):
            self.assertIsNone(billing.fetch_subscriber("u1"))

    def test_no_secret_key_is_none(self):
        with patch("app.services.billing.get_settings", return_value=_settings(REVENUECAT_SECRET_API_KEY=None)):
            self.assertIsNone(billing.fetch_subscriber("u1"))


class SyncEntitlementTests(unittest.TestCase):
    def test_stores_the_subscriber_and_reports_pro(self):
        with (
            patch("app.services.billing.get_settings", return_value=_settings()),
            patch("app.services.billing.fetch_subscriber", return_value=_subscriber()),
            patch("app.services.billing.upsert_user_entitlement") as upsert,
            patch("app.services.billing._now", return_value=NOW),
        ):
            self.assertTrue(billing.sync_entitlement("u1"))
        row = upsert.call_args.args[0]
        self.assertEqual(row["user_id"], "u1")
        self.assertEqual(row["pro_expires_at"], "2026-11-02T12:00:00+00:00")
        self.assertEqual(row["synced_at"], NOW.isoformat())

    def test_an_unreachable_revenuecat_leaves_the_row_alone(self):
        with (
            patch("app.services.billing.fetch_subscriber", return_value=None),
            patch("app.services.billing.upsert_user_entitlement") as upsert,
        ):
            self.assertIsNone(billing.sync_entitlement("u1"))
        upsert.assert_not_called()


class IsProTests(unittest.TestCase):
    def _is_pro(self, row):
        with patch("app.services.billing.get_user_entitlement", return_value=row):
            return billing.is_pro("u1", now=NOW)

    def test_a_future_expiry_is_pro(self):
        self.assertTrue(self._is_pro({"pro_expires_at": "2026-10-03T00:00:00+00:00"}))

    def test_a_past_expiry_is_not_pro(self):
        self.assertFalse(self._is_pro({"pro_expires_at": "2026-10-01T00:00:00+00:00"}))

    def test_no_row_is_not_pro(self):
        self.assertFalse(self._is_pro(None))


class ChargeChatMessageTests(unittest.TestCase):
    def _charge(self, *, pro=False, consume=(1,), synced=None):
        patches = [
            patch("app.services.billing.get_settings", return_value=_settings()),
            patch("app.services.billing.is_pro", return_value=pro),
            patch("app.services.billing.consume_chat_usage", side_effect=list(consume)),
            patch("app.services.billing.sync_entitlement", return_value=synced),
            patch("app.services.billing.refund_chat_usage"),
            patch("app.services.billing.chat_usage_date", return_value="2026-10-02"),
        ]
        started = [p.start() for p in patches]
        self.addCleanup(lambda: [p.stop() for p in patches])
        self.consume, self.sync, self.refund = started[2], started[3], started[4]
        return billing.charge_chat_message("u1")

    def test_under_the_free_limit_spends_one_and_returns_a_refund(self):
        refund = self._charge(consume=(1,))
        self.consume.assert_called_once_with("u1", "2026-10-02", 3)
        refund()
        self.refund.assert_called_once_with("u1", "2026-10-02")

    def test_a_spent_free_allowance_is_402_after_one_recheck(self):
        with self.assertRaises(ApiResponseError) as ctx:
            self._charge(consume=(None,), synced=False)
        self.assertEqual(ctx.exception.status_code, 402)
        self.assertEqual(ctx.exception.error_code, "chat_quota_exceeded")
        self.assertFalse(ctx.exception.retryable)
        self.sync.assert_called_once_with("u1")

    def test_a_purchase_the_webhook_has_not_delivered_yet_still_counts(self):
        self._charge(consume=(None, 4), synced=True)
        self.assertEqual(self.consume.call_args_list[-1].args, ("u1", "2026-10-02", 100))

    def test_revenuecat_unreachable_at_the_limit_is_still_402(self):
        with self.assertRaises(ApiResponseError) as ctx:
            self._charge(consume=(None,), synced=None)
        self.assertEqual(ctx.exception.status_code, 402)

    def test_pro_uses_the_fair_use_cap(self):
        self._charge(pro=True, consume=(50,))
        self.consume.assert_called_once_with("u1", "2026-10-02", 100)
        self.sync.assert_not_called()

    def test_pro_over_the_cap_is_429_without_a_paywall(self):
        with self.assertRaises(ApiResponseError) as ctx:
            self._charge(pro=True, consume=(None,))
        self.assertEqual(ctx.exception.status_code, 429)
        self.assertEqual(ctx.exception.error_code, "chat_fair_use_limit")
        self.sync.assert_not_called()

    def test_a_usage_store_failure_lets_the_message_through(self):
        refund = self._charge(consume=(RuntimeError("supabase down"),))
        refund()  # a no-op, and it must not raise
        self.refund.assert_not_called()


if __name__ == "__main__":
    unittest.main()
```

- [x] **Step 3: Run the tests and confirm they fail**

Run: `python -m unittest tests.test_billing -v`
Expected: `ImportError: cannot import name 'billing'`, or `AttributeError` for each missing function.

- [x] **Step 4: Implement `app/services/billing.py`**

```python
"""Who has paid for Pro, and the daily chat allowance that depends on it.

RevenueCat is the source of truth for purchases. Its webhook only says that
something changed for a user; sync_entitlement then reads that user's current
state from RevenueCat's REST API and keeps a copy in user_entitlements, so a
chat message checks Pro with one row read instead of a network call. Reading
the current state rather than trusting the event is what RevenueCat
recommends, and it makes late, repeated and out-of-order events harmless.
"""

import hmac
import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from app.config import get_settings
from app.services.api_responses import ApiResponseError
from app.services.database import (
    consume_chat_usage,
    get_user_entitlement,
    refund_chat_usage,
    upsert_user_entitlement,
)
from app.services.observability import record_external_api_failure

logger = logging.getLogger(__name__)

# India has no daylight saving, so a fixed offset is exact and needs no tzdata.
IST = timezone(timedelta(hours=5, minutes=30))
_REVENUECAT_API_BASE_URL = "https://api.revenuecat.com/v1"
_REVENUECAT_TIMEOUT_SECONDS = 10
_ANONYMOUS_ID_PREFIX = "$RCAnonymousID:"
# RevenueCat reports a lifetime or promotional grant with no expires_date.
_NEVER_EXPIRES = "9999-12-31T00:00:00+00:00"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _parse_time(value) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def chat_usage_date(now: datetime | None = None) -> str:
    """The allowance day a message falls in: the calendar date in IST."""
    return (now or _now()).astimezone(IST).date().isoformat()


def pro_state(subscriber: dict, entitlement_id: str) -> dict:
    """The user_entitlements columns for one RevenueCat subscriber object.

    RevenueCat keeps an expired entitlement in the list with a past
    expires_date, so the expiry is stored either way and is_pro() compares it
    with the clock."""
    entitlement = (subscriber.get("entitlements") or {}).get(entitlement_id) or {}
    product_id = entitlement.get("product_identifier")
    subscription = (subscriber.get("subscriptions") or {}).get(product_id) or {}
    if not entitlement:
        expires_at = None
    elif entitlement.get("expires_date") is None:
        expires_at = _NEVER_EXPIRES
    else:
        parsed = _parse_time(entitlement.get("expires_date"))
        expires_at = parsed.isoformat() if parsed else None
    return {
        "pro_expires_at": expires_at,
        "product_id": product_id,
        "store": subscription.get("store"),
        "is_sandbox": bool(subscription.get("is_sandbox")),
    }


def fetch_subscriber(app_user_id: str) -> dict | None:
    """RevenueCat's current view of one user, or None when it cannot be read."""
    api_key = get_settings().REVENUECAT_SECRET_API_KEY
    if not api_key:
        logger.error("REVENUECAT_SECRET_API_KEY is not set; entitlements cannot sync.")
        return None
    request = urllib.request.Request(
        f"{_REVENUECAT_API_BASE_URL}/subscribers/{urllib.parse.quote(app_user_id, safe='')}",
        headers={"Authorization": f"Bearer {api_key}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=_REVENUECAT_TIMEOUT_SECONDS) as response:
            body = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError) as e:
        record_external_api_failure("revenuecat")
        logger.warning("RevenueCat subscriber fetch failed for %s: %s", app_user_id, e)
        return None
    subscriber = body.get("subscriber") if isinstance(body, dict) else None
    return subscriber if isinstance(subscriber, dict) else None


def _active(row: dict | None, now: datetime | None = None) -> bool:
    expires_at = _parse_time((row or {}).get("pro_expires_at"))
    return expires_at is not None and expires_at > (now or _now())


def sync_entitlement(user_id: str) -> bool | None:
    """Refreshes user_entitlements from RevenueCat and returns whether Pro is
    active. None means RevenueCat could not be read and the stored row was
    left as it was: an outage there must never take Pro away from anyone."""
    subscriber = fetch_subscriber(user_id)
    if subscriber is None:
        return None
    row = {
        "user_id": user_id,
        **pro_state(subscriber, get_settings().REVENUECAT_ENTITLEMENT_ID),
        "synced_at": _now().isoformat(),
    }
    upsert_user_entitlement(row)
    return _active(row)


def is_pro(user_id: str, now: datetime | None = None) -> bool:
    return _active(get_user_entitlement(user_id), now)


def charge_chat_message(user_id: str) -> Callable[[], None]:
    """Spends one of today's chat messages for user_id, or raises the 402/429
    the app turns into the paywall. Returns the refund to call when no answer
    reaches the user, so a failed answer never costs them a message."""
    settings = get_settings()
    usage_date = chat_usage_date()
    try:
        pro = is_pro(user_id)
        limit = settings.CHAT_PRO_DAILY_LIMIT if pro else settings.CHAT_FREE_DAILY_LIMIT
        used = consume_chat_usage(user_id, usage_date, limit)
        if used is None and not pro and sync_entitlement(user_id):
            # Paid moments ago and the webhook has not landed yet.
            pro = True
            used = consume_chat_usage(user_id, usage_date, settings.CHAT_PRO_DAILY_LIMIT)
    except Exception as e:
        # Same stance as RATE_LIMIT_FAIL_OPEN: a usage-store outage lets the
        # message through rather than blocking chat for everyone.
        logger.error("Chat allowance check failed for %s: %s", user_id, e)
        return lambda: None

    if used is None:
        if pro:
            raise ApiResponseError(
                status_code=429,
                error_code="chat_fair_use_limit",
                message="You've reached today's chat limit. It resets at midnight IST.",
                detail=f"Pro daily cap of {settings.CHAT_PRO_DAILY_LIMIT} messages reached.",
                retryable=False,
            )
        raise ApiResponseError(
            status_code=402,
            error_code="chat_quota_exceeded",
            message="You've used today's free AI messages. Get ReelPin Pro to keep chatting, or come back tomorrow.",
            detail=f"Free daily allowance of {settings.CHAT_FREE_DAILY_LIMIT} messages reached.",
            retryable=False,
        )

    def refund() -> None:
        try:
            refund_chat_usage(user_id, usage_date)
        except Exception as e:
            logger.error("Chat allowance refund failed for %s: %s", user_id, e)

    return refund
```

`hmac` is imported for Task 3. If the linter complains in this task, add it in Task 3 instead.

- [x] **Step 5: Run the tests and confirm they pass**

Run: `python -m unittest tests.test_billing -v`
Expected: all OK

- [x] **Step 6: Checkpoint.** `python -m unittest discover -s tests` is green. Leave the changes uncommitted.

---

### Task 3: RevenueCat webhook

**Files:**
- Modify: `app/services/billing.py`. Append `webhook_authorized` and `webhook_user_ids`.
- Modify: `app/main.py`. Add the route next to the other account routes, after `get_account_entitlements`.
- Test: `tests/test_billing.py`. Append the classes below.

**Interfaces:**
- Consumes (Task 2): `sync_entitlement(user_id) -> bool | None`
- Produces:
  - `webhook_authorized(authorization: str | None) -> bool`
  - `webhook_user_ids(event: dict) -> list[str]`
  - `POST /api/v1/webhooks/revenuecat`: 200 `{"ok": true}`, 401 `invalid_webhook_auth`, or 503 `upstream_unavailable`.

- [x] **Step 1: Write the failing tests** (append to `tests/test_billing.py`; add `import asyncio` at the top)

```python
from app.main import revenuecat_webhook


class _JsonRequest:
    def __init__(self, payload):
        self._payload = payload

    async def json(self):
        return self._payload


class WebhookAuthTests(unittest.TestCase):
    def test_the_configured_header_is_accepted(self):
        with patch("app.services.billing.get_settings", return_value=_settings()):
            self.assertTrue(billing.webhook_authorized("Bearer hook-secret"))

    def test_a_wrong_or_missing_header_is_refused(self):
        with patch("app.services.billing.get_settings", return_value=_settings()):
            self.assertFalse(billing.webhook_authorized("Bearer nope"))
            self.assertFalse(billing.webhook_authorized(None))

    def test_no_configured_secret_refuses_everything(self):
        with patch("app.services.billing.get_settings", return_value=_settings(REVENUECAT_WEBHOOK_AUTH=None)):
            self.assertFalse(billing.webhook_authorized("Bearer hook-secret"))


class WebhookUserIdsTests(unittest.TestCase):
    def test_collects_every_real_id_once(self):
        event = {
            "app_user_id": "u1",
            "original_app_user_id": "u1",
            "aliases": ["u1", "$RCAnonymousID:abc", "u2"],
        }
        self.assertEqual(billing.webhook_user_ids(event), ["u1", "u2"])

    def test_a_transfer_rereads_both_sides(self):
        event = {"type": "TRANSFER", "transferred_from": ["u1"], "transferred_to": ["u3"]}
        self.assertEqual(billing.webhook_user_ids(event), ["u1", "u3"])


class WebhookEndpointTests(unittest.TestCase):
    def _post(self, payload, *, authorized=True, synced=True):
        with (
            patch("app.main.webhook_authorized", return_value=authorized),
            patch("app.main.sync_entitlement", return_value=synced) as sync,
        ):
            result = asyncio.run(revenuecat_webhook(_JsonRequest(payload), authorization="x"))
        return result, sync

    def test_a_bad_header_is_401_and_syncs_nothing(self):
        with self.assertRaises(ApiResponseError) as ctx:
            self._post({"event": {"app_user_id": "u1"}}, authorized=False)
        self.assertEqual(ctx.exception.status_code, 401)

    def test_a_purchase_event_resyncs_the_user(self):
        result, sync = self._post({"event": {"type": "INITIAL_PURCHASE", "app_user_id": "u1"}})
        self.assertTrue(result.ok)
        sync.assert_called_once_with("u1")

    def test_the_dashboard_test_event_syncs_nothing(self):
        _, sync = self._post({"event": {"type": "TEST", "app_user_id": "u1"}})
        sync.assert_not_called()

    def test_revenuecat_unreachable_is_503_so_it_retries(self):
        with self.assertRaises(ApiResponseError) as ctx:
            self._post({"event": {"type": "RENEWAL", "app_user_id": "u1"}}, synced=None)
        self.assertEqual(ctx.exception.status_code, 503)
        self.assertTrue(ctx.exception.retryable)
```

- [x] **Step 2: Run the tests and confirm they fail**

Run: `python -m unittest tests.test_billing -v`
Expected: `ImportError: cannot import name 'revenuecat_webhook'`

- [x] **Step 3: Implement the helpers** (append to `app/services/billing.py`)

Task 2 left these out because nothing used them yet. Add `import hmac` to the imports and `_ANONYMOUS_ID_PREFIX = "$RCAnonymousID:"` next to the other module constants, then append:

```python
def webhook_authorized(authorization: str | None) -> bool:
    """Whether a webhook call carries the Authorization value configured on the
    RevenueCat webhook. With none configured, nothing is trusted."""
    expected = get_settings().REVENUECAT_WEBHOOK_AUTH
    if not expected or not authorization:
        return False
    return hmac.compare_digest(authorization.encode("utf-8"), expected.encode("utf-8"))


def webhook_user_ids(event: dict) -> list[str]:
    """Every ReelPin user an event can change. A TRANSFER moves a purchase
    between accounts, so both sides are re-read; RevenueCat's anonymous ids
    are not ReelPin users and are skipped."""
    candidates = [event.get("app_user_id"), event.get("original_app_user_id")]
    for key in ("aliases", "transferred_from", "transferred_to"):
        values = event.get(key)
        if isinstance(values, list):
            candidates.extend(values)
    user_ids: list[str] = []
    for value in candidates:
        if not isinstance(value, str):
            continue
        value = value.strip()
        if value and not value.startswith(_ANONYMOUS_ID_PREFIX) and value not in user_ids:
            user_ids.append(value)
    return user_ids
```

- [x] **Step 4: Add the route** (`app/main.py`)

Add this import next to `from app.services import chat` (around `app/main.py:96`):

(Done in Task 3 with only `sync_entitlement`, `webhook_authorized` and `webhook_user_ids`. Tasks 4 and 5 add `charge_chat_message`, `chat_usage_date` and `is_pro` to that same import when they first use them.)

```python
from app.services.billing import (
    charge_chat_message,
    chat_usage_date,
    is_pro,
    sync_entitlement,
    webhook_authorized,
    webhook_user_ids,
)
```

Add the route right after `get_account_entitlements`:

```python
@app.post("/api/v1/webhooks/revenuecat", response_model=OkResponse)
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(default=None, alias="Authorization"),
):
    """RevenueCat says a subscriber changed. The payload is only a hint: each
    affected user is re-read from RevenueCat's API, so events that arrive
    late, twice or out of order still leave the right state behind. A 503
    makes RevenueCat retry (five times, backing off to 80 minutes)."""
    if not webhook_authorized(authorization):
        raise ApiResponseError(
            status_code=401,
            error_code="invalid_webhook_auth",
            message="Webhook authorization failed.",
        )
    body = await request.json()
    event = body.get("event") if isinstance(body, dict) else None
    if not isinstance(event, dict) or event.get("type") == "TEST":
        return OkResponse()
    for user_id in webhook_user_ids(event):
        if await run_in_threadpool(sync_entitlement, user_id) is None:
            raise ApiResponseError(
                status_code=503,
                error_code="upstream_unavailable",
                message="RevenueCat could not be reached.",
                retryable=True,
            )
    return OkResponse()
```

`Header`, `Request`, `run_in_threadpool`, `OkResponse` and `ApiResponseError` are already imported in `main.py`.

- [x] **Step 5: Run the tests and confirm they pass**

Run: `python -m unittest tests.test_billing -v`
Expected: all OK

- [x] **Step 6: Checkpoint.** The full suite is green. Leave the changes uncommitted.

---

### Task 4: Charge both chat endpoints and refund failed answers

> **As built (deviation from Steps 5–6):** in both endpoints the charge runs as `refund = await run_in_threadpool(charge_chat_message, user_id)` **immediately before** `return _chat_sse(...)`, not right after the rate limit. Private chat now looks up the user's taste (and collection chat reads the thread) before streaming; charging last means a failure there never costs a message. The threadpool keeps the DB and RevenueCat calls off the event loop. In the tests, the share-branch "never charged" assertion lives in the `_share` helper (`self.charge`), not in the test's own `with` block.

**Files:**
- Modify: `app/main.py`: `_chat_sse`, `chat_messages`, `post_collection_chat_message`
- Modify/Test: `tests/test_collection_chat.py`

**Interfaces:**
- Consumes (Task 2): `charge_chat_message(user_id) -> Callable[[], None]`, already imported into `app.main` in Task 3.
- Produces: `_chat_sse(*, retrieve, answer, on_answer=None, on_failure=None, search_label=...)`

- [x] **Step 1: Patch the charge in the existing helpers so they never touch Supabase**

In `tests/test_collection_chat.py`:
- `CollectionChatLiveAskTests._ask`: add a `charge=None` keyword parameter. Right after the `patches = [...]` list and **before** `if answer is not None:`, add:
  ```python
  patches.append(patch("app.main.charge_chat_message", side_effect=charge))
  ```
  After `started = [...]`, add `self.charge = started[8]`. Index 8 is the appended patch. Indexes 3, 4 and 6, which the helper already uses, are unchanged.
- Each of the three `with (...)` blocks that call `chat_messages(` (the private-chat tests near the end of the file): add `patch("app.main.charge_chat_message"),` as the first line after `patch("app.main.enforce_rate_limit"),`.
- `test_share_in_stores_the_pair_verbatim_and_never_calls_the_model`: add `patch("app.main.charge_chat_message") as charge` to its `with` block, and `charge.assert_not_called()` at the end.

- [x] **Step 2: Write the failing charging tests** (append to `tests/test_collection_chat.py`)

```python
class ChatChargingTests(unittest.TestCase):
    QUOTA = ApiResponseError(
        status_code=402,
        error_code="chat_quota_exceeded",
        message="You've used today's free AI messages.",
    )

    def _private_patches(self, **charge):
        return (
            patch("app.main.enforce_rate_limit"),
            patch("app.main.charge_chat_message", **charge),
            patch("app.services.chat.get_cached_user_taste", return_value=[]),
            patch("app.services.chat.embed_query_text", return_value=[0.0]),
            patch("app.services.chat.search_reels_hybrid", return_value=[_reel(REEL_MINE)]),
        )

    def test_private_chat_over_the_allowance_is_402_before_any_model_call(self):
        rate, charge, taste, embed, search = self._private_patches(side_effect=self.QUOTA)
        with rate, charge, taste, embed, search, patch("app.services.chat.generate_json") as model:
            with self.assertRaises(ApiResponseError) as ctx:
                asyncio.run(
                    chat_messages(
                        ChatMessageRequest(thread_id="t1", text="sports to watch"),
                        request=None,
                        current_user=U("editor-1"),
                    )
                )
        self.assertEqual(ctx.exception.status_code, 402)
        model.assert_not_called()

    def test_private_chat_refunds_when_the_model_fails(self):
        rate, charge, taste, embed, search = self._private_patches()
        with rate, charge as charged, taste, embed, search, patch(
            "app.services.chat.answer", side_effect=RuntimeError("model down")
        ):
            resp = asyncio.run(
                chat_messages(
                    ChatMessageRequest(thread_id="t1", text="sports to watch"),
                    request=None,
                    current_user=U("editor-1"),
                )
            )
            events = _events(resp)
        self.assertEqual(events[-1]["type"], "error")
        charged.return_value.assert_called_once()

    def test_private_chat_keeps_the_charge_when_an_answer_arrives(self):
        rate, charge, taste, embed, search = self._private_patches()
        with rate, charge as charged, taste, embed, search, patch(
            "app.services.chat.generate_json", return_value=_plan(cited=[REEL_MINE])
        ):
            events = _events(
                asyncio.run(
                    chat_messages(
                        ChatMessageRequest(thread_id="t1", text="sports to watch"),
                        request=None,
                        current_user=U("editor-1"),
                    )
                )
            )
        self.assertEqual(events[-1]["type"], "answer")
        charged.assert_called_once_with("editor-1")
        charged.return_value.assert_not_called()


class CollectionChatChargingTests(CollectionChatLiveAskTests):
    def test_the_asker_over_their_allowance_gets_402_and_nothing_is_stored(self):
        with self.assertRaises(ApiResponseError) as ctx:
            self._ask("Where do we start?", charge=ChatChargingTests.QUOTA)
        self.assertEqual(ctx.exception.status_code, 402)

    def test_the_asker_is_the_one_charged(self):
        self._ask("Where do we start?")
        self.charge.assert_called_once_with("editor-1")

    def test_a_failed_answer_is_refunded(self):
        def boom(*_args, **_kwargs):
            raise RuntimeError("model down")

        events, _, _ = self._ask("Where do we start?", answer=boom)
        self.assertEqual(events[-1]["type"], "error")
        self.charge.return_value.assert_called_once()
```

`CollectionChatChargingTests` subclasses the live-ask tests to reuse `_ask`, so it also re-runs them. That's acceptable, and they stay green.

- [x] **Step 3: Run the tests and confirm the new ones fail**

Run: `python -m unittest tests.test_collection_chat -v`
Expected: the new tests FAIL (no 402, no charge call), and the pre-existing tests pass.

- [x] **Step 4: Add `on_failure` to `_chat_sse`** (`app/main.py`)

Add the parameter to the signature: `*, retrieve, answer, on_answer=None, on_failure=None, search_label: str = "SEARCHING YOUR SAVES"`. Extend the docstring with: "`on_failure()` runs before any error event, so a message whose answer never reached the user is given back."

Inside `_stream()`, under `def sse(...)`, add:

```python
        async def failed(payload: dict) -> str:
            if on_failure is not None:
                await run_in_threadpool(on_failure)
            return sse(payload)
```

Replace each of the three `yield sse({"type": "error", ...})` calls (retrieval failed, model failed, save failed) with `yield await failed({...})`, keeping the same dict.

- [x] **Step 5: Charge in `chat_messages`**

Right after the `enforce_rate_limit(..., rule=CHAT_RATE_LIMIT)` call, add:

```python
    refund = charge_chat_message(current_user.user_id)
```

Add `on_failure=refund,` to the `_chat_sse(...)` call that ends the function.

- [x] **Step 6: Charge in `post_collection_chat_message`, live-ask branch only**

Right after `enforce_rate_limit(request=request, user_id=user_id, rule=CHAT_RATE_LIMIT)`, which comes after the blocks branch has already returned, add:

```python
    # The asker spends their own allowance; sharing an answer in (the blocks
    # branch above) makes no model call and is never charged.
    refund = charge_chat_message(user_id)
```

Add `on_failure=refund,` to its `_chat_sse(...)` call.

- [x] **Step 7: Run the tests and confirm they pass**

Run: `python -m unittest tests.test_collection_chat -v`, then `python -m unittest discover -s tests`
Expected: all OK

- [x] **Step 8: Checkpoint.** Leave the changes uncommitted.

---

### Task 5: The real plan in `/account/entitlements`, plus `?sync=true`

> **As built (deviations):** (1) The billing read sits behind `_billing_state(user_id) -> (is_pro, chat_messages_today)`, which falls back to `(False, 0)` and logs. A billing-data failure shows the free plan, never `restricted` (which would have turned off features across the app). (2) A failed `sync_entitlement` on `?sync=true` is logged and the endpoint still answers. (3) `tests/test_apple_startup.py`'s two entitlements tests now patch `app.services.billing.get_user_entitlement` (→ None) and `app.main.get_chat_usage` (→ 0), so they never reach a database. (4) An extra test, `test_a_billing_lookup_failure_is_free_not_restricted`.

**Files:**
- Modify: `app/models.py` (`UsageResponse`, `LimitResponse`)
- Modify: `app/services/display_data.py` (`build_entitlements_response`)
- Modify: `app/main.py` (`get_account_entitlements`, plus a small rate-limit rule)
- Test: `tests/test_billing.py` (append)

**Interfaces:**
- Consumes (Tasks 1–2): `is_pro`, `sync_entitlement`, `chat_usage_date`, `get_chat_usage`.
- Produces: `GET /api/v1/account/entitlements?sync=true|false`. Its response gains `usage.chat_messages_today: int` and `limits.chat_messages_per_day: int | null`. `plan` is `"pro"` while Pro is active. `sync=true` re-reads RevenueCat first; the app sends it only right after a purchase.

- [x] **Step 1: Write the failing tests** (append to `tests/test_billing.py`)

```python
from app.config import get_settings
from app.main import get_account_entitlements
from app.services.auth import AuthenticatedUser


class EntitlementsEndpointTests(unittest.TestCase):
    def _get(self, *, pro, sync=False):
        with (
            patch("app.main.list_reels_for_display", return_value=[]),
            patch("app.main.is_pro", return_value=pro),
            patch("app.main.get_chat_usage", return_value=2),
            patch("app.main.sync_entitlement") as synced,
            patch("app.main.enforce_rate_limit"),
        ):
            resp = asyncio.run(
                get_account_entitlements(
                    request=None,
                    sync=sync,
                    current_user=AuthenticatedUser(user_id="u1"),
                )
            )
        return resp, synced

    def test_an_active_entitlement_is_the_pro_plan(self):
        resp, synced = self._get(pro=True)
        self.assertEqual(resp.plan, "pro")
        self.assertTrue(resp.is_premium)
        self.assertEqual(resp.usage.chat_messages_today, 2)
        self.assertEqual(resp.limits.chat_messages_per_day, get_settings().CHAT_PRO_DAILY_LIMIT)
        synced.assert_not_called()

    def test_no_entitlement_is_the_free_plan(self):
        resp, _ = self._get(pro=False)
        self.assertEqual(resp.plan, "free")
        self.assertEqual(resp.limits.chat_messages_per_day, get_settings().CHAT_FREE_DAILY_LIMIT)

    def test_sync_rereads_revenuecat_first(self):
        _, synced = self._get(pro=True, sync=True)
        synced.assert_called_once_with("u1")
```

- [x] **Step 2: Run the tests and confirm they fail**

Run: `python -m unittest tests.test_billing -v`
Expected: a `TypeError` about the unexpected `request` and `sync` keywords, or missing attributes.

- [x] **Step 3: Add the fields** (`app/models.py`)

Add `chat_messages_today: int = 0` to `UsageResponse`. Add `chat_messages_per_day: Optional[int] = None` to `LimitResponse`.

- [x] **Step 4: Thread them through `build_entitlements_response`** (`app/services/display_data.py`)

Add two keyword parameters, `chat_messages_today: int = 0` and `chat_messages_per_day: int | None = None`. Then:
- Replace `limits = PRO_LIMITS if is_premium else FREE_LIMITS` with:
  ```python
  limits = (PRO_LIMITS if is_premium else FREE_LIMITS).model_copy(
      update={"chat_messages_per_day": chat_messages_per_day}
  )
  ```
- Add `chat_messages_today=chat_messages_today,` to the `UsageResponse(...)` call.
- Leave `plan_cards` on the shared `FREE_LIMITS`/`PRO_LIMITS` constants. The app's paywall no longer reads them.

- [x] **Step 5: Use the real plan** (`app/main.py`)

Add `get_chat_usage` to the existing `from app.services.database import (` block. Next to `CHAT_RATE_LIMIT`, add:

```python
# Only the app's post-purchase refresh asks for a sync; this keeps a client
# from turning the entitlements call into a RevenueCat API flood.
BILLING_SYNC_RATE_LIMIT = RateLimitRule(action="billing_sync", user_limit=6, ip_limit=30)
```

Replace `get_account_entitlements` with:

```python
@app.get("/api/v1/account/entitlements", response_model=AccountEntitlementsResponse)
@app.get("/account/entitlements", response_model=AccountEntitlementsResponse)
async def get_account_entitlements(
    request: Request,
    sync: bool = Query(default=False),
    current_user: AuthenticatedUser = Depends(require_authenticated_user),
):
    """The caller's plan and usage. `sync=true` re-reads RevenueCat first; the
    app sends it right after a purchase, before the webhook may have landed."""
    user_id = current_user.user_id
    try:
        if sync:
            enforce_rate_limit(request=request, user_id=user_id, rule=BILLING_SYNC_RATE_LIMIT)
            await run_in_threadpool(sync_entitlement, user_id)
        pro = await run_in_threadpool(is_pro, user_id)
        records = list_reels_for_display(user_id)
        return build_entitlements_response(
            user_id=user_id,
            records=records,
            plan="pro" if pro else "free",
            chat_messages_today=get_chat_usage(user_id, chat_usage_date()),
            chat_messages_per_day=(
                settings.CHAT_PRO_DAILY_LIMIT if pro else settings.CHAT_FREE_DAILY_LIMIT
            ),
        )
    except ApiResponseError:
        raise
    except Exception as e:
        logger.error(f"Account entitlement lookup failed: {e}")
        return build_restricted_entitlement_response(
            user_id=user_id,
            error_message="Plan access could not be verified right now.",
        )
```

`settings`, `Query`, `RateLimitRule` and `enforce_rate_limit` are already in scope in `main.py`. `RateLimitRule` is already used for `CHAT_RATE_LIMIT`.

- [x] **Step 6: Run the tests and confirm they pass**

Run: `python -m unittest tests.test_billing -v`, then `python -m unittest discover -s tests`
Expected: all OK

- [x] **Step 7: Checkpoint.** Leave the changes uncommitted.

---

### Task 6: Dev deploy and end-to-end check

Owner-assisted. Production is never touched.

- [ ] **Step 1:** The owner sets `REVENUECAT_SECRET_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`, `CHAT_FREE_DAILY_LIMIT` and `CHAT_PRO_DAILY_LIMIT` on the **dev** host (spec setup step 19).
- [ ] **Step 2:** Deploy `feature/paywall` to dev only. Ask the owner how. Pushing `dev` auto-deploys, and this branch must not be merged into `dev` without their go-ahead.
- [ ] **Step 3:** Check webhook auth against dev:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://api-dev.reelpin.in/api/v1/webhooks/revenuecat -H "Authorization: wrong" -H "Content-Type: application/json" -d '{"event":{"type":"TEST"}}'
```

Expected: `401`. Then use RevenueCat dashboard → Webhooks → "Send test event" on the dev webhook. Expected: 200 in the RevenueCat delivery log.

- [ ] **Step 4:** Run manual scenarios 1, 2, 5, 7, 8, 9 and 10 from the spec's testing table against dev, using the app branch (app plan, Task 6).

## Self-review notes

- **Spec coverage:**
  - Tables, RPCs and grants → T1.
  - Settings, sync, `is_pro`, charge, fail-open and the lifetime case → T2.
  - Webhook, its auth, TEST events, TRANSFER events and 503 retry → T3.
  - Both endpoints, the share branch uncharged and refund on error → T4.
  - The entitlements plan, usage fields and post-purchase sync → T5.
  - Account deletion is covered by the `user_id` column; no task is needed.
- **`?sync=true` is new** relative to the spec text. The spec has been updated to include it.

## Post-review changes (2026-10-02)

The code review's ten findings were all fixed. The tasks above describe the first build; where they disagree, this section wins:
- **`consume_chat_message`:** now takes `(p_user_id, p_usage_date, p_free_limit, p_pro_limit)` and returns `TABLE(used_messages, has_pro)`. It reads Pro itself, so a message costs one round trip.
- **`consume_chat_usage`:** returns `(used | None, has_pro)`. `charge_chat_message` no longer calls `is_pro`.
- **`pro_state`:** Pro lasts until the later of `expires_date` and `grace_period_expires_date`. The expiry is stored in whole seconds, and timestamps are parsed with `display_data._parse_datetime`, which treats a timestamp with no timezone as UTC.
- **Removed (no consumer):** `usage.chat_messages_today`, `limits.chat_messages_per_day`, `get_chat_usage` and `CHAT_USAGE_TABLE`. `_billing_state` became `_is_pro_or_free`.
- **Tests:**
  - `tests/test_billing.py` and `tests/test_billing_data.py` use the repo's `app.config` stub pattern and run without env vars.
  - The endpoint tests moved to `tests/test_billing_endpoints.py`.
  - New tests cover the grace period, whole-second storage, an expiry with no timezone, and refunds on search failure and save failure.
