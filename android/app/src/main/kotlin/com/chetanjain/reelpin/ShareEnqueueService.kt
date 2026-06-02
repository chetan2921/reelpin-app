package com.chetanjain.reelpin

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.JobIntentService
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class ShareEnqueueService : JobIntentService() {
    override fun onHandleWork(intent: Intent) {
        val sharedUrl = intent.getStringExtra(EXTRA_SHARED_URL)?.trim()
        if (sharedUrl.isNullOrEmpty()) return

        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val shareToken = prefs.getString(PREF_SHARE_TOKEN, null)?.trim()
        val baseUrl = prefs.getString(PREF_BASE_URL, null)?.trim()?.trimEnd('/')
        val pushToken = prefs.getString(PREF_PUSH_TOKEN, null)?.trim()
        val pushPlatform = prefs.getString(PREF_PUSH_PLATFORM, null)?.trim()?.lowercase()

        // No background credential yet (first run before the app minted one, or
        // signed out): capture the URL for the app to enqueue on next open.
        if (shareToken.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            savePendingShare(prefs, sharedUrl)
            showToast("Saved to ReelPin. Open the app to finish.")
            return
        }

        runCatching { registerStoredPushToken(baseUrl, shareToken, pushToken, pushPlatform) }

        val enqueued = runCatching { enqueueJob(baseUrl, shareToken, sharedUrl) }
            .getOrDefault(false)
        if (enqueued) {
            showToast("Saved to ReelPin. Processing in background.")
        } else {
            // Token rejected/expired or network failure: don't drop the share.
            savePendingShare(prefs, sharedUrl)
            showToast("Saved to ReelPin. Open the app to finish.")
        }
    }

    private fun enqueueJob(baseUrl: String, shareToken: String, sharedUrl: String): Boolean {
        val connection = (URL("$baseUrl/processing-jobs/reels").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 15000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            setRequestProperty("X-Share-Token", shareToken)
        }
        try {
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use {
                it.write(JSONObject().put("url", sharedUrl).toString())
            }
            return connection.responseCode in 200..299
        } finally {
            connection.disconnect()
        }
    }

    private fun registerStoredPushToken(
        baseUrl: String,
        shareToken: String,
        token: String?,
        platform: String?,
    ) {
        if (token.isNullOrEmpty()) return
        val normalizedPlatform = if (platform.isNullOrEmpty()) "android" else platform
        val connection = (URL("$baseUrl/device-push-tokens").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 15000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            setRequestProperty("X-Share-Token", shareToken)
        }
        try {
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use {
                it.write(JSONObject().put("token", token).put("platform", normalizedPlatform).toString())
            }
            connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    private fun savePendingShare(prefs: SharedPreferences, url: String) {
        val existing = prefs.getString(PREF_PENDING_URLS, "[]") ?: "[]"
        val array = try {
            JSONArray(existing)
        } catch (e: Exception) {
            JSONArray()
        }
        array.put(url)
        prefs.edit().putString(PREF_PENDING_URLS, array.toString()).apply()
    }

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    companion object {
        private const val JOB_ID = 47231
        private const val EXTRA_SHARED_URL = "extra_shared_url"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_SHARE_TOKEN = "flutter.share_handoff_share_token"
        private const val PREF_BASE_URL = "flutter.share_handoff_base_url"
        private const val PREF_PUSH_TOKEN = "flutter.share_handoff_push_token"
        private const val PREF_PUSH_PLATFORM = "flutter.share_handoff_push_platform"
        private const val PREF_PENDING_URLS = "flutter.share_pending_urls"

        fun enqueue(context: Context, sharedUrl: String) {
            val intent = Intent(context, ShareEnqueueService::class.java).apply {
                putExtra(EXTRA_SHARED_URL, sharedUrl)
            }
            enqueueWork(context, ShareEnqueueService::class.java, JOB_ID, intent)
        }
    }
}
