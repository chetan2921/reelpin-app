package com.chetanjain.reelpin

import android.content.Context
import android.content.Intent
import java.net.URI

object ShareIntentParser {
    private val urlCandidateRegex = Regex(
        pattern = """https?://[^\s<>"']+""",
        option = RegexOption.IGNORE_CASE
    )
    private val videoIdRegex = Regex("""^[A-Za-z0-9_-]+$""")
    private val tiktokPathRegex = Regex("""^[A-Za-z0-9@._/\-]+$""")
    private val trailingPunctuation = setOf('.', ',', '!', '?', ';', ':', ')', ']', '}', '"')

    fun extractPayload(context: Context, intent: Intent): String {
        val parts = linkedSetOf<String>()

        intent.getStringExtra(Intent.EXTRA_TEXT)?.let(parts::add)
        intent.getStringExtra(Intent.EXTRA_SUBJECT)?.let(parts::add)
        intent.dataString?.let(parts::add)

        val clipData = intent.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                val item = clipData.getItemAt(index)
                item.coerceToText(context)?.toString()?.let(parts::add)
                item.uri?.toString()?.let(parts::add)
            }
        }

        return parts.joinToString(separator = "\n").trim()
    }

    fun extractSupportedUrl(payload: String): String? {
        if (payload.isBlank()) return null
        return urlCandidateRegex.findAll(payload)
            .map { trimTrailingPunctuation(it.value) }
            .firstOrNull(::isSupportedUrl)
    }

    private fun isSupportedUrl(value: String): Boolean {
        val uri = runCatching { URI(value) }.getOrNull() ?: return false
        val host = uri.host?.lowercase() ?: return false

        // Supported platforms are decided by the backend; accept any http(s)
        // link here so adding a platform needs only a backend change.
        val scheme = uri.scheme?.lowercase()
        return (scheme == "http" || scheme == "https") && host.isNotEmpty()
    }

    private fun isInstagramUrl(uri: URI, host: String): Boolean {
        if (host != "instagram.com" && host != "www.instagram.com") return false
        val segments = pathSegments(uri)
        if (segments.size < 2) return false

        val contentType = segments[0].lowercase()
        return (contentType == "reel" || contentType == "p" || contentType == "tv") &&
            videoIdRegex.matches(segments[1])
    }

    private fun isTikTokUrl(uri: URI, host: String): Boolean {
        if (host != "tiktok.com" && host != "vt.tiktok.com" && host != "vm.tiktok.com") {
            return false
        }
        val path = uri.path?.trim('/') ?: return false
        return path.isNotEmpty() && tiktokPathRegex.matches(path)
    }

    private fun isYoutubeUrl(uri: URI, host: String): Boolean {
        val segments = pathSegments(uri)
        if (host == "youtu.be") {
            return segments.firstOrNull()?.let(videoIdRegex::matches) == true
        }
        if (host != "youtube.com" && host != "www.youtube.com" && host != "m.youtube.com") {
            return false
        }
        if (
            segments.size >= 2 &&
            segments[0].equals("shorts", ignoreCase = true) &&
            videoIdRegex.matches(segments[1])
        ) {
            return true
        }
        return uri.path.equals("/watch", ignoreCase = true) &&
            queryValue(uri.rawQuery, "v")?.let(videoIdRegex::matches) == true
    }

    private fun isXUrl(host: String): Boolean {
        val normalizedHost = withoutMobileOrWebPrefix(host)
        return normalizedHost == "x.com" ||
            normalizedHost == "twitter.com" ||
            normalizedHost == "t.co"
    }

    private fun withoutMobileOrWebPrefix(host: String): String {
        return listOf("www.", "mobile.", "m.")
            .firstOrNull { prefix -> host.startsWith(prefix) }
            ?.let { prefix -> host.removePrefix(prefix) }
            ?: host
    }

    private fun pathSegments(uri: URI): List<String> {
        return uri.path
            ?.trim('/')
            ?.split('/')
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
    }

    private fun queryValue(rawQuery: String?, key: String): String? {
        if (rawQuery.isNullOrBlank()) return null
        return rawQuery.split('&')
            .firstNotNullOfOrNull { part ->
                val separator = part.indexOf('=')
                val name = if (separator >= 0) part.substring(0, separator) else part
                val value = if (separator >= 0) part.substring(separator + 1) else ""
                if (name.equals(key, ignoreCase = true) && value.isNotEmpty()) value else null
            }
    }

    private fun trimTrailingPunctuation(value: String): String {
        var end = value.length
        while (end > 0 && trailingPunctuation.contains(value[end - 1])) {
            end--
        }
        return value.substring(0, end)
    }
}

enum class ShareRequestResult {
    SUCCESS,
    INVALID_SHARE_TOKEN,
    FAILURE,
}

object ShareResponseClassifier {
    fun classify(statusCode: Int, responseBody: String?): ShareRequestResult {
        if (statusCode in 200..299) return ShareRequestResult.SUCCESS
        if (
            statusCode in setOf(401, 403) &&
            responseBody?.lowercase()?.contains("invalid_share_token") == true
        ) {
            return ShareRequestResult.INVALID_SHARE_TOKEN
        }
        return ShareRequestResult.FAILURE
    }
}
