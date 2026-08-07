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
    fun extractsPinterestUrlsWithoutValidatingTheirPaths() {
        val cases = mapOf(
            "https://www.pinterest.com/pin/1234567890/" to
                "https://www.pinterest.com/pin/1234567890/",
            "https://pinterest.com/pin/1234567890/" to
                "https://pinterest.com/pin/1234567890/",
            "https://in.pinterest.com/pin/1234567890/" to
                "https://in.pinterest.com/pin/1234567890/",
            "https://www.pinterest.co.uk/pin/1234567890/" to
                "https://www.pinterest.co.uk/pin/1234567890/",
            "https://www.pinterest.com.au/pin/1234567890/" to
                "https://www.pinterest.com.au/pin/1234567890/",
            "https://pinterest.ca/pin/1234567890/" to
                "https://pinterest.ca/pin/1234567890/",
            "https://pin.it/AbCdEf123" to "https://pin.it/AbCdEf123",
            "Saved this https://www.pinterest.com/pin/1234567890/?sender=1" to
                "https://www.pinterest.com/pin/1234567890/?sender=1",
            "https://www.pinterest.com/someuser/some-board/" to
                "https://www.pinterest.com/someuser/some-board/",
        )

        cases.forEach { (payload, expected) ->
            assertEquals(expected, ShareIntentParser.extractSupportedUrl(payload))
        }
    }

    @Test
    fun rejectsPinterestLookalikeDomains() {
        assertNull(
            ShareIntentParser.extractSupportedUrl(
                "https://pinterest.com.example.com/pin/1234567890/",
            ),
        )
        assertNull(
            ShareIntentParser.extractSupportedUrl(
                "https://evil-pinterest.com/pin/1234567890/",
            ),
        )
    }

    @Test
    fun extractsRedditUrlsWithoutValidatingTheirPaths() {
        val cases = mapOf(
            "https://www.reddit.com/r/flutter/comments/abc123/some_title/" to
                "https://www.reddit.com/r/flutter/comments/abc123/some_title/",
            "https://reddit.com/r/flutter/comments/abc123/" to
                "https://reddit.com/r/flutter/comments/abc123/",
            "https://old.reddit.com/r/flutter/comments/abc123/" to
                "https://old.reddit.com/r/flutter/comments/abc123/",
            "https://redd.it/abc123" to "https://redd.it/abc123",
            "Look at this https://www.reddit.com/r/flutter/comments/abc123/?share_id=xyz" to
                "https://www.reddit.com/r/flutter/comments/abc123/?share_id=xyz",
            "https://www.reddit.com/r/flutter/" to "https://www.reddit.com/r/flutter/",
        )

        cases.forEach { (payload, expected) ->
            assertEquals(expected, ShareIntentParser.extractSupportedUrl(payload))
        }
    }

    @Test
    fun rejectsRedditLookalikeDomains() {
        assertNull(
            ShareIntentParser.extractSupportedUrl(
                "https://reddit.com.example.com/r/flutter/comments/abc123/",
            ),
        )
    }

    @Test
    fun extractsLinkedInUrlsWithoutValidatingTheirPaths() {
        val cases = mapOf(
            "https://www.linkedin.com/feed/update/urn:li:activity:1234567890123/" to
                "https://www.linkedin.com/feed/update/urn:li:activity:1234567890123/",
            "https://www.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c" to
                "https://www.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c",
            "https://linkedin.com/feed/update/urn:li:activity:1234567890123/" to
                "https://linkedin.com/feed/update/urn:li:activity:1234567890123/",
            "https://in.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c" to
                "https://in.linkedin.com/posts/someone_a-slug-activity-1234567890123-Ab1c",
            "https://www.linkedin.com/in/someone/" to "https://www.linkedin.com/in/someone/",
        )

        cases.forEach { (payload, expected) ->
            assertEquals(expected, ShareIntentParser.extractSupportedUrl(payload))
        }
    }

    @Test
    fun rejectsLinkedInLookalikeDomains() {
        assertNull(
            ShareIntentParser.extractSupportedUrl(
                "https://linkedin.com.example.com/feed/update/urn:li:activity:1/",
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
