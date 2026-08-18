package com.chetanjain.reelpin

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_HANDOFF_CHANNEL)
            .setMethodCallHandler { call, result ->
                val prefs = applicationContext.getSharedPreferences(
                    ShareEnqueueService.PREFS_NAME,
                    Context.MODE_PRIVATE,
                )
                when (call.method) {
                    "sync" -> {
                        prefs.edit()
                            .putString(ShareEnqueueService.KEY_SHARE_TOKEN, arg(call, "shareToken"))
                            .putString(ShareEnqueueService.KEY_BASE_URL, arg(call, "baseUrl"))
                            .putString(ShareEnqueueService.KEY_PUSH_TOKEN, arg(call, "pushToken"))
                            .putString(ShareEnqueueService.KEY_PUSH_PLATFORM, arg(call, "pushPlatform"))
                            .putString(ShareEnqueueService.KEY_COLLECTIONS, arg(call, "collections"))
                            .putString(ShareEnqueueService.KEY_COLLECTIONS_DIR, arg(call, "collectionsDir"))
                            .commit()
                        result.success(true)
                    }
                    "clear" -> {
                        prefs.edit()
                            .remove(ShareEnqueueService.KEY_SHARE_TOKEN)
                            .remove(ShareEnqueueService.KEY_BASE_URL)
                            .remove(ShareEnqueueService.KEY_PUSH_TOKEN)
                            .remove(ShareEnqueueService.KEY_PUSH_PLATFORM)
                            .remove(ShareEnqueueService.KEY_COLLECTIONS)
                            .remove(ShareEnqueueService.KEY_COLLECTIONS_DIR)
                            .commit()
                        result.success(true)
                    }
                    "shareAssetsDir" -> {
                        val dir = File(applicationContext.filesDir, "share_assets")
                        dir.mkdirs()
                        result.success(dir.absolutePath)
                    }
                    "drainPending" -> {
                        val pending = prefs.getString(ShareEnqueueService.KEY_PENDING_URLS, null)
                        prefs.edit().remove(ShareEnqueueService.KEY_PENDING_URLS).commit()
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REEL_SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareReelCard" -> shareReelCard(call, result)
                    "shareText" -> shareText(call, result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_METADATA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> result.success(deviceMetadata())
                    else -> result.notImplemented()
                }
            }
    }

    private fun arg(call: MethodCall, key: String): String {
        return call.argument<String>(key)?.trim() ?: ""
    }

    /** Text-only share for collection links, which have no card image. */
    private fun shareText(call: MethodCall, result: MethodChannel.Result) {
        val text = arg(call, "text")
        val subject = arg(call, "subject")

        if (text.isEmpty()) {
            result.error("bad_args", "Missing share text", null)
            return
        }

        try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
            }
            startActivity(Intent.createChooser(sendIntent, "Share collection"))
            result.success(true)
        } catch (error: Exception) {
            result.error("share_failed", error.message, null)
        }
    }

    private fun shareReelCard(call: MethodCall, result: MethodChannel.Result) {
        val pngBytes = call.argument<ByteArray>("pngBytes")
        val text = arg(call, "text")
        val subject = arg(call, "subject")

        if (pngBytes == null || pngBytes.isEmpty()) {
            result.error("bad_args", "Missing share image", null)
            return
        }

        try {
            val shareDir = File(cacheDir, ReelShareFileProvider.SHARE_DIR)
            shareDir.mkdirs()
            shareDir.listFiles()?.forEach { file ->
                if (file.isFile) file.delete()
            }

            val shareFile = File(shareDir, "reelpin-card.png")
            shareFile.writeBytes(pngBytes)
            val uri = Uri.Builder()
                .scheme("content")
                .authority("${applicationContext.packageName}.reelshare")
                .appendPath(shareFile.name)
                .build()

            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, text)
                putExtra(Intent.EXTRA_SUBJECT, subject)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(sendIntent, "Share ReelPin card")
            startActivity(chooser)
            result.success(true)
        } catch (error: Exception) {
            result.error("share_failed", error.message, null)
        }
    }

    @Suppress("DEPRECATION")
    private fun deviceMetadata(): Map<String, String> {
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val buildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }
        return mapOf(
            "appVersion" to (packageInfo.versionName ?: "unknown"),
            "appBuild" to buildNumber.toString(),
            "timezone" to TimeZone.getDefault().id,
            "locale" to Locale.getDefault().toLanguageTag(),
        )
    }

    companion object {
        private const val SHARE_HANDOFF_CHANNEL = "com.chetanjain.reelpin/share_handoff"
        private const val REEL_SHARE_CHANNEL = "com.chetanjain.reelpin/reel_share"
        private const val DEVICE_METADATA_CHANNEL = "com.chetanjain.reelpin/device_metadata"
    }
}
