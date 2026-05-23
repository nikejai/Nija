package com.nija

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "nija/secret_intent"
    private var pendingSecretContent: String? = null
    private var pendingSecretLabel: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureSecretFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureSecretFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingSecret" -> {
                    val content = pendingSecretContent
                    if (content == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "label" to (pendingSecretLabel ?: "secret.nijas"),
                                "content" to content
                            )
                        )
                        pendingSecretContent = null
                        pendingSecretLabel = null
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun captureSecretFromIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        val label = extractFileName(uri)
        val normalizedLabel = label.lowercase()
        val mime = (intent.type ?: contentResolver.getType(uri) ?: "").lowercase()
        val looksLikeEncryptedSecret =
            normalizedLabel.endsWith(".nijas") ||
            uri.toString().lowercase().contains(".nijas") ||
            mime.contains("nijas") ||
            mime == "application/octet-stream" ||
            mime == "text/plain"
        if (!looksLikeEncryptedSecret) return
        val content = readTextFromUri(uri) ?: return
        pendingSecretLabel = if (normalizedLabel.endsWith(".nijas")) label else "secret.nijas"
        pendingSecretContent = content
    }

    private fun extractFileName(uri: Uri): String {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) {
                        val name = cursor.getString(index)
                        if (!name.isNullOrBlank()) return name
                    }
                }
                val path = uri.lastPathSegment ?: return "secret.nijas"
                return path.substringAfterLast('/')
            } ?: run {
                val path = uri.lastPathSegment ?: return "secret.nijas"
                path.substringAfterLast('/')
            }
        } catch (_: Exception) {
            val path = uri.lastPathSegment ?: return "secret.nijas"
            return path.substringAfterLast('/')
        }
    }

    private fun readTextFromUri(uri: Uri): String? {
        return try {
            contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
        } catch (_: Exception) {
            null
        }
    }
}
