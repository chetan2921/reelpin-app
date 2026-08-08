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

        return parts.joinToString(separator = "\n").trim()
    }
}

enum class ShareRequestResult {
    SUCCESS,
    INVALID_SHARE_TOKEN,
    UNSUPPORTED,
    RATE_LIMITED,
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
        if (statusCode == 400) return ShareRequestResult.UNSUPPORTED
        if (statusCode == 429) return ShareRequestResult.RATE_LIMITED
        return ShareRequestResult.FAILURE
    }
}
