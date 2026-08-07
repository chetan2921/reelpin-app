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
        val shareToken = prefs.getString(KEY_SHARE_TOKEN, null)?.trim()
        val baseUrl = prefs.getString(KEY_BASE_URL, null)?.trim()?.trimEnd('/')
        val pushToken = prefs.getString(KEY_PUSH_TOKEN, null)?.trim()
        val pushPlatform = prefs.getString(KEY_PUSH_PLATFORM, null)?.trim()?.lowercase()

        // No background credential yet (first run before the app minted one, or
        // signed out): capture the URL for the app to enqueue on next open.
        if (shareToken.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            savePendingShare(prefs, sharedUrl)
            return
        }

        val result = runCatching { enqueueJob(baseUrl, shareToken, sharedUrl) }
            .getOrDefault(ShareRequestResult.FAILURE)
        when (result) {
            ShareRequestResult.SUCCESS -> {
                runCatching { registerStoredPushToken(baseUrl, shareToken, pushToken, pushPlatform) }
                showToast("Saved to ReelPin. Processing in background.")
            }
            ShareRequestResult.INVALID_SHARE_TOKEN -> {
                prefs.edit().remove(KEY_SHARE_TOKEN).commit()
                savePendingShare(prefs, sharedUrl)
                showToast("Open ReelPin and sign in again.")
            }
            ShareRequestResult.UNSUPPORTED -> showToast("ReelPin can't save this link.")
            ShareRequestResult.RATE_LIMITED -> {
                savePendingShare(prefs, sharedUrl)
                showToast("You're saving too fast. We'll retry when you open ReelPin.")
            }
            ShareRequestResult.FAILURE -> {
                savePendingShare(prefs, sharedUrl)
                showToast("Couldn't reach ReelPin. We'll retry when you open the app.")
            }
        }
    }

    private fun enqueueJob(
        baseUrl: String,
        shareToken: String,
        sharedUrl: String,
    ): ShareRequestResult {
        val connection = (URL(apiUrl(baseUrl, "processing-jobs/reels")).openConnection() as HttpURLConnection).apply {
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
            val statusCode = connection.responseCode
            val responseBody = runCatching {
                val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
                stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
            }.getOrNull()
            return ShareResponseClassifier.classify(statusCode, responseBody)
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
        val connection = (URL(apiUrl(baseUrl, "device-push-tokens")).openConnection() as HttpURLConnection).apply {
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
        val existing = prefs.getString(KEY_PENDING_URLS, "[]") ?: "[]"
        val array = try {
            JSONArray(existing)
        } catch (e: Exception) {
            JSONArray()
        }
        array.put(url)
        // commit() (not apply()) so the value is on disk before the Flutter app
        // reads it back to drain pending shares.
        prefs.edit().putString(KEY_PENDING_URLS, array.toString()).commit()
    }

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    private fun apiUrl(baseUrl: String, path: String): String {
        val cleanBase = baseUrl.trim().trimEnd('/')
        val cleanPath = path.trim().trimStart('/')
        val prefix = if (cleanBase.endsWith("/api/v1")) "" else "/api/v1"
        return "$cleanBase$prefix/$cleanPath"
    }

    companion object {
        private const val JOB_ID = 47231
        private const val EXTRA_SHARED_URL = "extra_shared_url"
        // Native-owned SharedPreferences file. The Flutter shared_preferences
        // plugin now stores values in a DataStore that native code cannot read,
        // so the app pushes these values here via a MethodChannel (see
        // MainActivity) and reads pending shares back the same way.
        const val PREFS_NAME = "reelpin_share_handoff"
        const val KEY_SHARE_TOKEN = "share_token"
        const val KEY_BASE_URL = "base_url"
        const val KEY_PUSH_TOKEN = "push_token"
        const val KEY_PUSH_PLATFORM = "push_platform"
        const val KEY_PENDING_URLS = "pending_urls"

        fun enqueue(context: Context, sharedUrl: String) {
            val intent = Intent(context, ShareEnqueueService::class.java).apply {
                putExtra(EXTRA_SHARED_URL, sharedUrl)
            }
            enqueueWork(context, ShareEnqueueService::class.java, JOB_ID, intent)
        }
    }
}
