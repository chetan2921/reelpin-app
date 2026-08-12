package com.chetanjain.reelpin

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.res.ResourcesCompat
import java.io.File
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
    private companion object {
        /** AppTheme.shadowOffset — 4dp, zero blur. */
        const val SHADOW_DP = 4
        const val ACCENT_YELLOW = 0xFFFFD600.toInt()
    }

    private data class ShareCollection(val id: String, val name: String, val image: String?)

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
     * Bottom sheet mirroring the system share sheet it replaces: a short row of
     * folder tiles scrolled horizontally, so filing a reel costs one tap and
     * never takes over the screen.
     *
     * Tiles are PNGs rendered by the app from the real CollectionFolderTile, so
     * the artwork is identical to the SAVED tab rather than a native lookalike.
     */
    private fun promptForCollections(sharedPayload: String, collections: List<ShareCollection>) {
        val selected = linkedSetOf<String>()
        lateinit var action: TextView

        fun actionLabel(): String = when (selected.size) {
            0 -> "SAVE TO REELPIN"
            1 -> "SAVE TO 1 COLLECTION"
            else -> "SAVE TO ${selected.size} COLLECTIONS"
        }

        // Matches AddToCollectionSheet: brutalCard chrome, a drag handle, and
        // 24dp gutters, so the share sheet reads as part of the same app.
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = brutalCard()
            setPadding(0, dp(18), 0, dp(24))
        }

        // Drag handle: 40x4 solid, same as the sheets inside the app.
        root.addView(View(this).apply {
            setBackgroundColor(Color.BLACK)
            layoutParams = LinearLayout.LayoutParams(dp(40), dp(4)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(18)
            }
        })

        root.addView(TextView(this).apply {
            text = "SAVE TO A COLLECTION"
            setTextColor(Color.BLACK)
            typeface = spaceMono(bold = true)
            textSize = 17f
            letterSpacing = 0.06f
            setPadding(dp(24), 0, dp(24), dp(6))
        })
        root.addView(TextView(this).apply {
            text = "Tap the ones it belongs in. Skip to just save it."
            setTextColor(0xFF444444.toInt())
            typeface = spaceMono(bold = false)
            textSize = 12f
            setPadding(dp(24), 0, dp(24), dp(16))
        })

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(18), dp(2), dp(18), dp(6))
        }
        collections.forEach { collection ->
            row.addView(buildTile(collection, selected) { action.text = actionLabel() })
        }
        root.addView(HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            clipChildren = false
            clipToPadding = false
            addView(row)
        })

        val dialog = Dialog(this)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)

        // One button whose label states exactly what will happen. A pair of
        // "Save" / "Just save" buttons read as the same action twice.
        action = TextView(this).apply {
            text = actionLabel()
            gravity = Gravity.CENTER
            typeface = spaceMono(bold = true)
            textSize = 13.5f
            letterSpacing = 0.05f
            setTextColor(Color.BLACK)
            background = brutalBox(ACCENT_YELLOW)
            // Bottom padding absorbs the shadow slab so the label stays centred
            // on the face rather than on the whole box.
            setPadding(0, dp(15), 0, dp(15) + SHADOW_DP)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { setMargins(dp(24), dp(16), dp(24), dp(4)) }
            setOnClickListener {
                dialog.dismiss()
                submit(sharedUrl, selected.toList())
            }
        }
        root.addView(action)

        dialog.setContentView(root)
        dialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
            setGravity(Gravity.BOTTOM)
        }
        // Dismissing must not silently drop the link the user shared.
        dialog.setOnCancelListener { submit(sharedPayload, emptyList()) }
        dialog.show()
    }

    /** Rendered tile plus a selection tint; falls back to a plain chip if the
     *  artwork is missing so a render failure never hides a collection. */
    private fun buildTile(
        collection: ShareCollection,
        selected: MutableSet<String>,
        onToggle: () -> Unit,
    ): View {
        val container = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(112), dp(104))
                .apply { marginEnd = dp(6) }
        }

        val bitmap = collection.image?.let { name ->
            runCatching { BitmapFactory.decodeFile(File(collectionsDir(), name).absolutePath) }
                .getOrNull()
        }

        if (bitmap != null) {
            container.addView(ImageView(this).apply {
                setImageBitmap(bitmap)
                scaleType = ImageView.ScaleType.FIT_CENTER
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                )
            })
        } else {
            container.addView(TextView(this).apply {
                text = collection.name.uppercase()
                setTextColor(Color.BLACK)
                typeface = spaceMono(bold = true)
                textSize = 11f
                gravity = Gravity.CENTER
                setBackgroundColor(0xFF7DB5FF.toInt())
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                )
            })
        }

        val check = TextView(this).apply {
            text = "✓"
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            typeface = spaceMono(bold = true)
            textSize = 15f
            setBackgroundColor(Color.BLACK)
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(dp(26), dp(26)).apply {
                gravity = Gravity.END or Gravity.BOTTOM
                setMargins(0, 0, dp(10), dp(8))
            }
        }
        container.addView(check)

        container.setOnClickListener {
            if (!selected.remove(collection.id)) selected.add(collection.id)
            check.visibility = if (selected.contains(collection.id)) View.VISIBLE else View.GONE
            onToggle()
        }
        return container
    }

    private fun collectionsDir(): String =
        applicationContext
            .getSharedPreferences(ShareEnqueueService.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(ShareEnqueueService.KEY_COLLECTIONS_DIR, null)
            ?.trim()
            .orEmpty()

    /**
     * Port of AppTheme.brutalBox: flat fill, 1dp black border and a solid black
     * slab offset down-right with no blur. Built as a LayerDrawable because a
     * real Android elevation shadow is soft and would read as a different
     * design language entirely.
     */
    /** The app's Space Mono, so native copy matches the rendered tiles. */
    private fun spaceMono(bold: Boolean): Typeface {
        val id = if (bold) R.font.space_mono_bold else R.font.space_mono_regular
        // ResourcesCompat rather than Resources.getFont, which is API 26+ and
        // would silently leave older devices on the platform monospace.
        return runCatching { ResourcesCompat.getFont(this, id) }.getOrNull()
            ?: Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
    }

    /** AppTheme.brutalCard: flat fill with a 1dp black border, no rounding. */
    private fun brutalCard(): Drawable = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(Color.WHITE)
        setStroke(dp(1), Color.BLACK)
    }

    private fun brutalBox(fill: Int): Drawable {
        val slab = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.BLACK)
        }
        val face = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(fill)
            setStroke(dp(1), Color.BLACK)
        }
        return LayerDrawable(arrayOf(slab, face)).apply {
            val offset = dp(SHADOW_DP)
            setLayerInset(0, offset, offset, 0, 0)
            setLayerInset(1, 0, 0, offset, offset)
        }
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
                val image = item.optString("image").trim().ifEmpty { null }
                if (id.isEmpty()) null else ShareCollection(id, name.ifEmpty { "Untitled" }, image)
            }
        }.getOrDefault(emptyList())
    }

    private fun finishQuietly() {
        finish()
        overridePendingTransition(0, 0)
    }
}
