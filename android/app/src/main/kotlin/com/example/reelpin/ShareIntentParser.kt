package com.example.reelpin

import android.content.Context
import android.content.Intent

object ShareIntentParser {
    private val supportedUrlRegex = Regex(
        pattern = """https?://(www\.)?(instagram\.com/(reel|p|tv)/[A-Za-z0-9_-]+|((vt|vm)\.)?tiktok\.com/[A-Za-z0-9@._/\-]+|youtube\.com/shorts/[A-Za-z0-9_-]+|youtu\.be/[A-Za-z0-9_-]+)(/?\S*)?""",
        option = RegexOption.IGNORE_CASE
    )

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
        return supportedUrlRegex.find(payload)?.value
    }
}
