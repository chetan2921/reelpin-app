package com.chetanjain.reelpin

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.JobIntentService
import org.json.JSONObject
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class ShareEnqueueService : JobIntentService() {
    override fun onHandleWork(intent: Intent) {
        val sharedUrl = intent.getStringExtra(EXTRA_SHARED_URL)?.trim()
        if (sharedUrl.isNullOrEmpty()) return

        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val userId = prefs.getString(PREF_USER_ID, null)?.trim()
        val baseUrl = prefs.getString(PREF_BASE_URL, null)?.trim()?.trimEnd('/')
        val pushToken = prefs.getString(PREF_PUSH_TOKEN, null)?.trim()
        val pushPlatform = prefs.getString(PREF_PUSH_PLATFORM, null)?.trim()?.lowercase()

        if (userId.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            showToast("Open ReelPin and sign in before sharing.")
            return
        }

        runCatching {
            registerStoredPushToken(
                baseUrl = baseUrl,
                userId = userId,
                token = pushToken,
                platform = pushPlatform
            )
        }

        val enqueueResult = runCatching {
            enqueueJob(baseUrl, userId, sharedUrl)
        }.getOrNull()

        if (enqueueResult == null) {
            showToast("Could not start background save.")
            return
        }

        if (enqueueResult.isCompleted) {
            return
        }
    }

    private fun enqueueJob(baseUrl: String, userId: String, sharedUrl: String): EnqueueResult {
        val endpoint = URL("$baseUrl/processing-jobs/reels")
        val connection = (endpoint.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 15000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
        }

        try {
            val payload = JSONObject()
                .put("url", sharedUrl)
                .put("user_id", userId)
                .toString()

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(payload)
            }

            val code = connection.responseCode
            if (code !in 200..299) {
                val errorBody = connection.errorStream?.bufferedReader()?.use(BufferedReader::readText)
                throw IllegalStateException("Queue request failed with $code${if (errorBody.isNullOrBlank()) "" else ": $errorBody"}")
            }

            val body = connection.inputStream.bufferedReader().use(BufferedReader::readText)
            val response = JSONObject(body)
            val status = response.optString("status").trim().lowercase()
            val resultReelId = response.optString("result_reel_id").trim()
            return EnqueueResult(
                isCompleted = status == "completed" || resultReelId.isNotEmpty()
            )
        } finally {
            connection.disconnect()
        }
    }

    private fun registerStoredPushToken(
        baseUrl: String,
        userId: String,
        token: String?,
        platform: String?,
    ) {
        if (token.isNullOrEmpty()) return
        val normalizedPlatform = if (platform.isNullOrEmpty()) "android" else platform

        val endpoint = URL("$baseUrl/device-push-tokens")
        val connection = (endpoint.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 15000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
        }

        try {
            val payload = JSONObject()
                .put("user_id", userId)
                .put("token", token)
                .put("platform", normalizedPlatform)
                .toString()

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(payload)
            }

            val code = connection.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("Token registration failed with $code")
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        private const val JOB_ID = 47231
        private const val EXTRA_SHARED_URL = "extra_shared_url"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_USER_ID = "flutter.share_handoff_user_id"
        private const val PREF_BASE_URL = "flutter.share_handoff_base_url"
        private const val PREF_PUSH_TOKEN = "flutter.share_handoff_push_token"
        private const val PREF_PUSH_PLATFORM = "flutter.share_handoff_push_platform"

        fun enqueue(context: Context, sharedUrl: String) {
            val intent = Intent(context, ShareEnqueueService::class.java).apply {
                putExtra(EXTRA_SHARED_URL, sharedUrl)
            }
            enqueueWork(context, ShareEnqueueService::class.java, JOB_ID, intent)
        }
    }
}

private data class EnqueueResult(
    val isCompleted: Boolean
)
