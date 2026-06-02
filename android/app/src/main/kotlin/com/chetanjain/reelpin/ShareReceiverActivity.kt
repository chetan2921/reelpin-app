package com.chetanjain.reelpin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import org.json.JSONArray

class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            setIntent(intent)
            handleIntent(intent)
        } else {
            finishQuietly()
        }
    }

    private fun handleIntent(intent: Intent) {
        val payload = ShareIntentParser.extractPayload(this, intent)
        val sharedUrl = ShareIntentParser.extractSupportedUrl(payload)

        if (sharedUrl == null) {
            Toast.makeText(
                applicationContext,
                "ReelPin could not find a supported reel link.",
                Toast.LENGTH_SHORT
            ).show()
            finishQuietly()
            return
        }

        savePendingShare(sharedUrl)
        Toast.makeText(
            applicationContext,
            "Saved to ReelPin. Open the app to finish.",
            Toast.LENGTH_LONG
        ).show()
        finishQuietly()
    }

    // Capture the shared URL into a pending list that the Flutter app drains and
    // enqueues with its live session. We deliberately do NOT call the backend
    // here: a background POST would use a stored access token that may have
    // expired, which 401s and silently drops the share.
    private fun savePendingShare(url: String) {
        val prefs = applicationContext.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val existing = prefs.getString(PREF_PENDING_URLS, "[]") ?: "[]"
        val array = try {
            JSONArray(existing)
        } catch (e: Exception) {
            JSONArray()
        }
        array.put(url)
        prefs.edit().putString(PREF_PENDING_URLS, array.toString()).apply()
    }

    private fun finishQuietly() {
        finish()
        overridePendingTransition(0, 0)
    }

    private companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val PREF_PENDING_URLS = "flutter.share_pending_urls"
    }
}
