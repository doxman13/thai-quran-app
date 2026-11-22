package com.thaiquran.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : AudioServiceFragmentActivity() {
    private var channel: MethodChannel? = null
    private var mediaShareChannel: MethodChannel? = null
    private var interceptVolumeKeys: Boolean = false

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.thaiquran.app/key_events")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setInputMode" -> {
                    val mode = call.argument<String>("mode")
                    interceptVolumeKeys = (mode == "bluetoothShutter")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        mediaShareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.thaiquran.app/media_share")
        mediaShareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "quran_share.png"
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_args", "Missing image bytes", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            insertPngToMediaStore(bytes, fileName)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("save_failed", e.localizedMessage ?: "Failed to save image", null)
                            }
                        }
                    }.start()
                }
                "copyImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "quran_share.png"
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_args", "Missing image bytes", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val uri = insertPngToMediaStore(bytes, fileName)
                            runOnUiThread {
                                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                                if (clipboard == null) {
                                    result.error("clipboard_unavailable", "ClipboardManager unavailable", null)
                                    return@runOnUiThread
                                }
                                clipboard.setPrimaryClip(ClipData.newUri(contentResolver, "Thai Quran", uri))
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("copy_failed", e.localizedMessage ?: "Failed to copy image", null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun insertPngToMediaStore(bytes: ByteArray, fileName: String): Uri {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/ThaiQuran")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("Failed to create MediaStore entry")

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IOException("Failed to open MediaStore output stream")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val publishValues = ContentValues().apply {
                    put(MediaStore.Images.Media.IS_PENDING, 0)
                }
                resolver.update(uri, publishValues, null, null)
            }
            return uri
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (!interceptVolumeKeys) {
            return super.onKeyDown(keyCode, event)
        }

        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_CAMERA,
            KeyEvent.KEYCODE_FOCUS,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE,
            KeyEvent.KEYCODE_MEDIA_NEXT,
            KeyEvent.KEYCODE_MEDIA_PREVIOUS,
            KeyEvent.KEYCODE_SPACE,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_BUTTON_A,
            KeyEvent.KEYCODE_BUTTON_B -> {
                channel?.invokeMethod("keyClick", keyCode)
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
}
