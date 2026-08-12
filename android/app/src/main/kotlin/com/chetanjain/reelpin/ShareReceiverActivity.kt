package com.chetanjain.reelpin

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.Window
import android.view.WindowManager
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
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

    /**
     * Bottom sheet mirroring the system share sheet: a short row of folder
     * tiles scrolled horizontally, so picking a collection costs one tap and
     * never covers the screen.
     */
    private fun promptForCollections(sharedPayload: String, collections: List<ShareCollection>) {
        val selected = linkedSetOf<String>()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
            setPadding(0, dp(14), 0, dp(10))
        }

        root.addView(TextView(this).apply {
            text = "Save to a collection"
            setTextColor(Color.BLACK)
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textSize = 15f
            setPadding(dp(20), 0, dp(20), dp(12))
        })

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(16), dp(4), dp(16), dp(4))
        }
        collections.forEachIndexed { index, collection ->
            val tile = CollectionFolderView(this).apply {
                title = collection.name
                accent = CollectionFolderView.accentFor(index)
                layoutParams = LinearLayout.LayoutParams(dp(104), dp(112)).apply {
                    marginEnd = dp(12)
                }
                setOnClickListener {
                    if (!selected.remove(collection.id)) selected.add(collection.id)
                    isChecked = selected.contains(collection.id)
                }
            }
            row.addView(tile)
        }
        root.addView(HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(row)
        })

        val dialog = Dialog(this)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(16), dp(12), dp(16), 0)
        }
        fun action(label: String, filled: Boolean, onClick: () -> Unit) = TextView(this).apply {
            text = label
            gravity = Gravity.CENTER
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textSize = 13f
            setTextColor(if (filled) Color.BLACK else Color.BLACK)
            setBackgroundColor(if (filled) 0xFFFFD600.toInt() else Color.WHITE)
            setPadding(0, dp(12), 0, dp(12))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                .apply { marginEnd = dp(10) }
            setOnClickListener { dialog.dismiss(); onClick() }
        }
        // "Just save" stays a first-class choice: sharing without a collection
        // is the fast path and must not feel like cancelling.
        actions.addView(action("Just save", false) { submit(sharedPayload, emptyList()) })
        actions.addView(action("Save", true) { submit(sharedPayload, selected.toList()) })
        root.addView(actions)

        dialog.setContentView(root)
        dialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.WHITE))
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
            setGravity(Gravity.BOTTOM)
        }
        // Dismissing must not silently drop the link the user shared.
        dialog.setOnCancelListener { submit(sharedPayload, emptyList()) }
        dialog.show()
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics
        ).toInt()

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
