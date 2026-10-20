package com.chetanjain.reelpin

import kotlin.test.Test
import kotlin.test.assertEquals

class ShareIntentParserTest {
    @Test
    fun keepsTikTokLinksAndCaptionsWithoutNormalizingThem() {
        val urls = listOf(
            "https://www.tiktok.com/@creator/video/123?_t=share",
            "https://www.tiktok.com/@creator/photo/123",
            "https://vm.tiktok.com/ABC/",
            "https://vt.tiktok.com/ABC/",
            "https://www.tiktok.com/t/ABC/",
            "https://www.tiktok.com/@/video/123",
            "https://www.tiktok.com/share/video/123",
            "https://www.tiktokv.com/share/video/123",
            "https://m.tiktok.com/v/123.html",
            "https://www.tiktok.com/embed/123",
            "https://www.tiktok.com/player/v1/123",
            "https://www.tiktok.com/@creator/live",
            "https://shop.tiktok.com/product/123",
        )
        for (url in urls) {
            assertEquals("Caption\n$url", ShareIntentParser.formatPayload(listOf("Caption", url, url)))
        }
    }

    @Test
    fun classifiesSubmissionsAndReelsAsSaved() {
        assertEquals(
            ShareRequestResult.SUCCESS,
            ShareResponseClassifier.classify(202, SUBMISSION_ACCEPTED),
        )
        assertEquals(
            ShareRequestResult.SUCCESS,
            ShareResponseClassifier.classify(202, SUBMISSION_IN_FLIGHT),
        )
        assertEquals(
            ShareRequestResult.ALREADY_SAVED,
            ShareResponseClassifier.classify(200, """{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","already_saved":true}"""),
        )
    }

    @Test
    fun classifiesExpiredAndMissingShareTokens() {
        assertEquals(
            ShareRequestResult.INVALID_SHARE_TOKEN,
            ShareResponseClassifier.classify(401, errorBody("invalid_share_token")),
        )
        assertEquals(
            ShareRequestResult.INVALID_SHARE_TOKEN,
            ShareResponseClassifier.classify(401, errorBody("share_token_required")),
        )
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(401, errorBody("unauthorized")),
        )
    }

    @Test
    fun classifiesAnUnsupportedLinkByItsField() {
        assertEquals(
            ShareRequestResult.UNSUPPORTED,
            ShareResponseClassifier.classify(422, validationBody("url")),
        )
        // A deleted collection is not the link's fault: keep it pending.
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(422, validationBody("collection_ids")),
        )
    }

    @Test
    fun classifiesBothLimitsAsRateLimited() {
        assertEquals(
            ShareRequestResult.RATE_LIMITED,
            ShareResponseClassifier.classify(429, errorBody("rate_limited", retryable = true)),
        )
        assertEquals(
            ShareRequestResult.RATE_LIMITED,
            ShareResponseClassifier.classify(429, errorBody("active_job_limit", retryable = true)),
        )
    }

    @Test
    fun classifiesEverythingElseAsFailure() {
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(503, errorBody("processing_unavailable", retryable = true)),
        )
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(503, errorBody("spend_limit_reached")),
        )
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(409, errorBody("idempotency_conflict")),
        )
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(500, null),
        )
    }

    private companion object {
        // Response bodies from reelpin-go api/fixtures (submission_accepted.json,
        // submission_in_flight.json, error_*.json).
        const val SUBMISSION_ACCEPTED =
            """{"already_saved":false,"collection_ids":[],"created_at":"2026-09-06T10:00:00Z","current_step":"queued","failure_code":null,"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","progress_percent":0,"result_reel_id":null,"source_platform":null,"status":"queued","status_message":"Queued for processing.","updated_at":"2026-09-06T10:00:00Z","url":"https://www.instagram.com/reel/C8abc123/"}"""
        const val SUBMISSION_IN_FLIGHT =
            """{"already_saved":true,"collection_ids":[],"created_at":"2026-09-06T10:00:00Z","current_step":"download","failure_code":null,"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","progress_percent":40,"result_reel_id":null,"source_platform":null,"status":"processing","status_message":"Processing is in progress.","updated_at":"2026-09-06T10:01:00Z","url":"https://www.instagram.com/reel/C8abc123/"}"""

        fun errorBody(code: String, retryable: Boolean = false) =
            """{"error":{"code":"$code","message":"m","request_id":"fixture-request-id","retryable":$retryable}}"""

        fun validationBody(field: String) =
            """{"error":{"code":"validation_error","details":{"field":"$field","reason":"r"},"message":"The request is missing required fields or contains invalid values.","request_id":"fixture-request-id","retryable":false}}"""
    }
}
