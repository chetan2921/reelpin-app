package com.chetanjain.reelpin

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
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

        val enqueueResult = runCatching {
            enqueueJob(baseUrl, userId, sharedUrl)
        }.getOrNull()

        if (enqueueResult == null) {
            showToast("Could not start background save.")
            return
        }

        if (enqueueResult.isCompleted) {
            showCompletionNotification()
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

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    private fun showCompletionNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        createNotificationChannelIfNeeded()

        val notification = NotificationCompat.Builder(applicationContext, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Reel pinned in ReelPin")
            .setContentText("Reel saved and is ready in ReelPin.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        runCatching {
            NotificationManagerCompat.from(applicationContext).notify(
                COMPLETION_NOTIFICATION_ID,
                notification
            )
        }
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (manager?.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Reel Updates",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifications for completed reel processing."
        }
        manager?.createNotificationChannel(channel)
    }

    companion object {
        private const val JOB_ID = 47231
        private const val EXTRA_SHARED_URL = "extra_shared_url"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_USER_ID = "flutter.share_handoff_user_id"
        private const val PREF_BASE_URL = "flutter.share_handoff_base_url"
        private const val NOTIFICATION_CHANNEL_ID = "reelpin_updates"
        private const val COMPLETION_NOTIFICATION_ID = 47232

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
