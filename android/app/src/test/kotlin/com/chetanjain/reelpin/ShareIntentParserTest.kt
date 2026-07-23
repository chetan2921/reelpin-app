package com.chetanjain.reelpin

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ShareIntentParserTest {
    @Test
    fun extractsYoutubeUrls() {
        val cases = mapOf(
            "https://www.youtube.com/shorts/VIDEO_ID" to
                "https://www.youtube.com/shorts/VIDEO_ID",
            "https://youtube.com/shorts/VIDEO_ID" to
                "https://youtube.com/shorts/VIDEO_ID",
            "https://youtu.be/VIDEO_ID" to "https://youtu.be/VIDEO_ID",
            "https://m.youtube.com/shorts/VIDEO_ID" to
                "https://m.youtube.com/shorts/VIDEO_ID",
            "https://www.youtube.com/watch?v=VIDEO_ID" to
                "https://www.youtube.com/watch?v=VIDEO_ID",
            "https://www.youtube.com/shorts/VIDEO_ID?si=abc123" to
                "https://www.youtube.com/shorts/VIDEO_ID?si=abc123",
            "Check this out https://www.youtube.com/shorts/VIDEO_ID?si=abc123" to
                "https://www.youtube.com/shorts/VIDEO_ID?si=abc123",
        )

        cases.forEach { (payload, expected) ->
            assertEquals(expected, ShareIntentParser.extractSupportedUrl(payload))
        }
    }

    @Test
    fun extractsMobileYoutubeWatchUrlsWithExtraQueryParams() {
        val url = "https://m.youtube.com/watch?v=VIDEO_ID&feature=share&utm_source=x"

        assertEquals(url, ShareIntentParser.extractSupportedUrl(url))
    }

    @Test
    fun keepsInstagramExtractionUnchanged() {
        assertEquals(
            "https://www.instagram.com/reel/abc_123/?utm_source=ig",
            ShareIntentParser.extractSupportedUrl(
                "Saved this https://www.instagram.com/reel/abc_123/?utm_source=ig",
            ),
        )
    }

    @Test
    fun ignoresUnsupportedUrls() {
        assertNull(ShareIntentParser.extractSupportedUrl("https://example.com/video/123"))
    }

    @Test
    fun extractsXUrlsWithoutValidatingTheirPaths() {
        val cases = mapOf(
            "https://x.com/OpenAI/status/1234567890" to
                "https://x.com/OpenAI/status/1234567890",
            "https://twitter.com/OpenAI/status/1234567890?s=20&utm_source=share" to
                "https://twitter.com/OpenAI/status/1234567890?s=20&utm_source=share",
            "https://mobile.twitter.com/OpenAI/status/1234567890" to
                "https://mobile.twitter.com/OpenAI/status/1234567890",
            "https://x.com/i/web/status/1234567890" to
                "https://x.com/i/web/status/1234567890",
            "https://t.co/AbCdEf123" to "https://t.co/AbCdEf123",
            "Check this post https://x.com/OpenAI/status/1234567890?s=20" to
                "https://x.com/OpenAI/status/1234567890?s=20",
            "https://MoBiLe.TwItTeR.CoM/OpenAI/status/1234567890" to
                "https://MoBiLe.TwItTeR.CoM/OpenAI/status/1234567890",
            "https://x.com/OpenAI/status/not-a-number" to
                "https://x.com/OpenAI/status/not-a-number",
            "https://x.com/OpenAI" to "https://x.com/OpenAI",
        )

        cases.forEach { (payload, expected) ->
            assertEquals(expected, ShareIntentParser.extractSupportedUrl(payload))
        }
    }

    @Test
    fun rejectsXLookalikeDomains() {
        assertNull(
            ShareIntentParser.extractSupportedUrl(
                "https://x.com.example.com/OpenAI/status/1234567890",
            ),
        )
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
}
