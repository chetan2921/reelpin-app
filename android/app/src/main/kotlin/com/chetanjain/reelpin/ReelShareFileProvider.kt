package com.chetanjain.reelpin

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

class ReelShareFileProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String = "image/png"

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") {
            throw FileNotFoundException("Only read mode is supported")
        }

        val file = shareFile(uri)
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val file = shareFile(uri)
        val columns = projection ?: arrayOf(
            OpenableColumns.DISPLAY_NAME,
            OpenableColumns.SIZE,
        )
        val cursor = MatrixCursor(columns)
        val values = columns.map<String, Any?> { column ->
            when (column) {
                OpenableColumns.DISPLAY_NAME -> file.name
                OpenableColumns.SIZE -> file.length()
                else -> null
            }
        }.toTypedArray()
        cursor.addRow(values)
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    companion object {
        const val SHARE_DIR = "reel_shares"
    }

    private fun shareFile(uri: Uri): File {
        val context = context ?: throw FileNotFoundException("Missing context")
        val fileName = uri.lastPathSegment ?: throw FileNotFoundException("Missing file")
        val shareDir = File(context.cacheDir, SHARE_DIR).canonicalFile
        val file = File(shareDir, fileName).canonicalFile
        if (!file.path.startsWith(shareDir.path) || !file.exists()) {
            throw FileNotFoundException("File not found")
        }
        return file
    }
}
