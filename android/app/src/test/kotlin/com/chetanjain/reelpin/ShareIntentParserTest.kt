package com.chetanjain.reelpin

import kotlin.test.Test
import kotlin.test.assertEquals

class ShareIntentParserTest {
    @Test
    fun classifiesExpiredShareTokens() {
        assertEquals(
            ShareRequestResult.INVALID_SHARE_TOKEN,
            ShareResponseClassifier.classify(
                401,
                """{"error_code":"invalid_share_token"}""",
            ),
        )
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(401, """{"error_code":"invalid_url"}"""),
        )
    }

    @Test
    fun classifiesOutcomesByStatusCode() {
        assertEquals(
            ShareRequestResult.SUCCESS,
            ShareResponseClassifier.classify(200, "{}"),
        )
        assertEquals(
            ShareRequestResult.UNSUPPORTED,
            ShareResponseClassifier.classify(400, """{"error_code":"invalid_request"}"""),
        )
        assertEquals(
            ShareRequestResult.RATE_LIMITED,
            ShareResponseClassifier.classify(429, """{"error_code":"rate_limited"}"""),
        )
        assertEquals(
            ShareRequestResult.FAILURE,
            ShareResponseClassifier.classify(500, null),
        )
    }
}
