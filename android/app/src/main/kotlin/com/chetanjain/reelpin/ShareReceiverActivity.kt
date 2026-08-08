package com.chetanjain.reelpin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

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
                "ReelPin could not find a supported post link.",
                Toast.LENGTH_SHORT
            ).show()
            finishQuietly()
            return
        }

        val prefs = applicationContext.getSharedPreferences(
            ShareEnqueueService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val shareToken = prefs.getString(ShareEnqueueService.KEY_SHARE_TOKEN, null)?.trim()
        val baseUrl = prefs.getString(ShareEnqueueService.KEY_BASE_URL, null)?.trim()
        // ShareEnqueueService shows the definitive outcome once the backend
        // responds, so there is no in-flight toast here. With no background
        // credential yet there is no backend call, so acknowledge terminally.
        if (shareToken.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            Toast.makeText(
                applicationContext,
                "Saved to ReelPin. Open the app to finish.",
                Toast.LENGTH_LONG
            ).show()
        }

        // ShareEnqueueService enqueues in the background with the device share
        // token, falling back to a pending list if it cannot enqueue.
        ShareEnqueueService.enqueue(applicationContext, sharedUrl)
        finishQuietly()
    }

    private fun finishQuietly() {
        finish()
        overridePendingTransition(0, 0)
    }
}
