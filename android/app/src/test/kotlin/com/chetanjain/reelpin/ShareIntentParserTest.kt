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
}
