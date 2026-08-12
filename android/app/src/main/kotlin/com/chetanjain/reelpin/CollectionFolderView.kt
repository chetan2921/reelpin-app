package com.chetanjain.reelpin

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.util.TypedValue
import android.view.View

/**
 * Native port of the app's collection folder tile: a hard-edged folder with a
 * tab, an offset shadow slab, and the name in uppercase monospace.
 *
 * Drawn rather than composed from drawables so the brutalist look — 2dp black
 * borders, no rounding, a solid shadow slab rather than a blur — survives
 * intact. Keeps the share picker visually identical to the SAVED grid.
 */
class CollectionFolderView(context: Context) : View(context) {

    var title: String = ""
        set(value) {
            field = value
            invalidate()
        }

    var accent: Int = ACCENTS[0]
        set(value) {
            field = value
            invalidate()
        }

    var isChecked: Boolean = false
        set(value) {
            field = value
            invalidate()
        }

    private fun dp(value: Float) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics
    )

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.BLACK
    }
    private val label = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLACK
        typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val border = dp(2f)
        val shadow = dp(5f)
        val tabHeight = dp(14f)
        stroke.strokeWidth = border
        label.textSize = dp(10f)

        val bodyTop = tabHeight
        val bodyRight = width - shadow
        val bodyBottom = height - shadow

        // Shadow slab, offset down-right like the Flutter tile.
        fill.color = Color.BLACK
        canvas.drawRect(shadow, bodyTop + shadow, width.toFloat(), height.toFloat(), fill)

        // Folder tab, top-left.
        val tabWidth = bodyRight * 0.46f
        fill.color = accent
        canvas.drawRect(0f, 0f, tabWidth, tabHeight + dp(3f), fill)
        canvas.drawRect(0f, 0f, tabWidth, tabHeight + dp(3f), stroke)

        // Body.
        canvas.drawRect(0f, bodyTop, bodyRight, bodyBottom, fill)
        canvas.drawRect(0f, bodyTop, bodyRight, bodyBottom, stroke)

        drawTitle(canvas, bodyTop + dp(10f), bodyRight - dp(8f))

        if (isChecked) drawCheck(canvas, bodyRight, bodyBottom)
    }

    /** Two lines maximum, ellipsised — a picker only needs recognition. */
    private fun drawTitle(canvas: Canvas, top: Float, maxRight: Float) {
        val text = title.uppercase()
        val left = dp(8f)
        val available = maxRight - left
        if (available <= 0) return

        var start = 0
        var line = 0
        var y = top + label.textSize
        while (start < text.length && line < 2) {
            var count = label.breakText(text, start, text.length, true, available, null)
            if (count <= 0) break
            var end = start + count
            if (line == 1 && end < text.length) {
                count = label.breakText(text, start, text.length, true, available - dp(10f), null)
                end = start + count
                canvas.drawText(text.substring(start, end) + "…", left, y, label)
                return
            }
            canvas.drawText(text, start, end, left, y, label)
            start = end
            y += label.textSize * 1.25f
            line++
        }
    }

    private fun drawCheck(canvas: Canvas, right: Float, bottom: Float) {
        val size = dp(22f)
        val pad = dp(6f)
        val box = RectF(right - size - pad, bottom - size - pad, right - pad, bottom - pad)
        fill.color = Color.BLACK
        canvas.drawRect(box, fill)

        val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2.5f)
            color = Color.WHITE
        }
        canvas.drawLine(
            box.left + size * 0.24f, box.centerY(),
            box.centerX() - size * 0.03f, box.bottom - size * 0.28f, tick
        )
        canvas.drawLine(
            box.centerX() - size * 0.03f, box.bottom - size * 0.28f,
            box.right - size * 0.22f, box.top + size * 0.30f, tick
        )
    }

    companion object {
        /** Mirrors CollectionFolderTile._accents so the grids match. */
        val ACCENTS = intArrayOf(
            0xFF7DB5FF.toInt(),
            0xFFFFD600.toInt(),
            0xFFFF6B6B.toInt(),
            0xFF00FFFF.toInt(),
            0xFF39FF14.toInt(),
        )

        fun accentFor(index: Int): Int = ACCENTS[index % ACCENTS.size]
    }
}
