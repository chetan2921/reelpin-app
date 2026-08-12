package com.chetanjain.reelpin

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import org.json.JSONArray

/**
 * Entry point for links shared into ReelPin from other apps.
 *
 * Stays completely invisible when the user has no collections — that is the
 * common case and sharing should cost one tap. When they do have collections,
 * a multi-select dialog appears so the reel can be filed at share time instead
 * of being hunted down later.
 *
 * The list is read from the snapshot the app syncs into SharedPreferences, not
 * the network: this activity has to appear instantly and may be killed the
 * moment the user leaves the share sheet.
 */
class ShareReceiverActivity : Activity() {
    private data class ShareCollection(val id: String, val name: String)

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
        // Forward the whole share payload; the backend extracts the URL and
        // decides what is supported, so there is no host gate here.
        val payload = ShareIntentParser.extractPayload(this, intent)

        if (payload.isBlank()) {
            Toast.makeText(
                applicationContext,
                "ReelPin didn't get anything to save.",
                Toast.LENGTH_SHORT
            ).show()
            finishQuietly()
            return
        }

        val collections = readCollections()
        if (collections.isEmpty()) {
            submit(payload, emptyList())
            return
        }
        promptForCollections(payload, collections)
    }

    private fun promptForCollections(
        sharedPayload: String,
        collections: List<ShareCollection>,
    ) {
        val names = collections.map { it.name }.toTypedArray()
        val checked = BooleanArray(collections.size)

        AlertDialog.Builder(this)
            .setTitle("Save to a collection")
            .setMultiChoiceItems(names, checked) { _, index, isChecked ->
                checked[index] = isChecked
            }
            // Saving without picking anything is the fast path, so it stays the
            // neutral button rather than a cancel.
            .setNeutralButton("Just save") { _, _ ->
                submit(sharedPayload, emptyList())
            }
            .setPositiveButton("Save") { _, _ ->
                val selected = collections.filterIndexed { index, _ -> checked[index] }
                submit(sharedPayload, selected.map { it.id })
            }
            .setOnCancelListener {
                // Dismissing must not silently drop the link the user shared.
                submit(sharedPayload, emptyList())
            }
            .show()
    }

    private fun submit(sharedPayload: String, collectionIds: List<String>) {
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
        ShareEnqueueService.enqueue(applicationContext, sharedPayload, collectionIds)
        finishQuietly()
    }

    /** Snapshot written by the app; absent or unparseable means "no picker". */
    private fun readCollections(): List<ShareCollection> {
        val raw = applicationContext
            .getSharedPreferences(ShareEnqueueService.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(ShareEnqueueService.KEY_COLLECTIONS, null)
            ?.trim()
        if (raw.isNullOrEmpty()) return emptyList()

        return runCatching {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                val id = item.optString("id").trim()
                val name = item.optString("name").trim()
                if (id.isEmpty()) null else ShareCollection(id, name.ifEmpty { "Untitled" })
            }
        }.getOrDefault(emptyList())
    }

    private fun finishQuietly() {
        finish()
        overridePendingTransition(0, 0)
    }
}
