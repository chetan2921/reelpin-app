package com.chetanjain.reelpin

import android.app.Activity
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
                "ReelPin could not find a supported reel link.",
                Toast.LENGTH_SHORT
            ).show()
            finishQuietly()
            return
        }

        ShareEnqueueService.enqueue(applicationContext, sharedUrl)
        finishQuietly()
    }

    private fun finishQuietly() {
        finish()
        overridePendingTransition(0, 0)
    }
}
