package com.example.reelpin

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

        if (userId.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            showToast("Open ReelPin and sign in before sharing.")
            return
        }

        val success = runCatching {
            enqueueJob(baseUrl, userId, sharedUrl)
        }.isSuccess

        if (success) {
            showToast("Saved to ReelPin. Processing in background.")
        } else {
            showToast("Could not start background save.")
        }
    }

    private fun enqueueJob(baseUrl: String, userId: String, sharedUrl: String) {
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

        fun enqueue(context: Context, sharedUrl: String) {
            val intent = Intent(context, ShareEnqueueService::class.java).apply {
                putExtra(EXTRA_SHARED_URL, sharedUrl)
            }
            enqueueWork(context, ShareEnqueueService::class.java, JOB_ID, intent)
        }
    }
}
