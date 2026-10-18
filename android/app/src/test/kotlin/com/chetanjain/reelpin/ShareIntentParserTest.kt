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
