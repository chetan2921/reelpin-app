package com.chetanjain.reelpin

import android.content.Context
import android.content.Intent

object ShareIntentParser {
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

        return formatPayload(parts)
    }

    fun formatPayload(parts: Iterable<String>): String =
        parts.distinct().joinToString(separator = "\n").trim()
}

enum class ShareRequestResult {
    SUCCESS,
    ALREADY_SAVED,
    INVALID_SHARE_TOKEN,
    UNSUPPORTED,
    RATE_LIMITED,
    FAILURE,
}

/** 200 (reel already saved) and 202 (job queued or in flight) are both a save; every v2 failure is the error envelope. */
object ShareResponseClassifier {
    // A regex rather than org.json, which is a throwing stub in JVM unit tests.
    private val errorCodePattern = Regex(""""code"\s*:\s*"([^"]*)"""")
    private val errorFieldPattern = Regex(""""field"\s*:\s*"([^"]*)"""")

    fun classify(statusCode: Int, responseBody: String?): ShareRequestResult {
        if (statusCode == 200) return ShareRequestResult.ALREADY_SAVED
        if (statusCode in 201..299) return ShareRequestResult.SUCCESS
        val body = responseBody.orEmpty()
        val errorCode = errorCodePattern.find(body)?.groupValues?.get(1)
        if (
            statusCode == 401 &&
            errorCode in setOf("invalid_share_token", "share_token_required")
        ) {
            return ShareRequestResult.INVALID_SHARE_TOKEN
        }
        if (
            statusCode == 422 &&
            errorCode == "validation_error" &&
            errorFieldPattern.find(body)?.groupValues?.get(1) == "url"
        ) {
            return ShareRequestResult.UNSUPPORTED
        }
        if (statusCode == 429) return ShareRequestResult.RATE_LIMITED
        return ShareRequestResult.FAILURE
    }
}
