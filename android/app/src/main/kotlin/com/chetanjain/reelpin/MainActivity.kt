package com.chetanjain.reelpin

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
                            .commit()
                        result.success(true)
                    }
                    "clear" -> {
                        prefs.edit()
                            .remove(ShareEnqueueService.KEY_SHARE_TOKEN)
                            .remove(ShareEnqueueService.KEY_BASE_URL)
                            .remove(ShareEnqueueService.KEY_PUSH_TOKEN)
                            .remove(ShareEnqueueService.KEY_PUSH_PLATFORM)
                            .commit()
                        result.success(true)
                    }
                    "drainPending" -> {
                        val pending = prefs.getString(ShareEnqueueService.KEY_PENDING_URLS, null)
                        prefs.edit().remove(ShareEnqueueService.KEY_PENDING_URLS).commit()
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun arg(call: MethodCall, key: String): String {
        return call.argument<String>(key)?.trim() ?: ""
    }

    companion object {
        private const val CHANNEL = "com.chetanjain.reelpin/share_handoff"
    }
}
