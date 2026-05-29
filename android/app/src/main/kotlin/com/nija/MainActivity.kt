package com.nija

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val secretIntentChannelName = "nija/secret_intent"
    private val documentOpenChannelName = "nija/document_open"
    private var pendingSecretUri: Uri? = null
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
            secretIntentChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingSecret" -> {
                    val uri = pendingSecretUri
                    val label = pendingSecretLabel ?: "secret.nijas"
                    if (uri == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    pendingSecretUri = null
                    pendingSecretLabel = null
                    Thread {
                        val content = readTextFromUri(uri)
                        runOnUiThread {
                            if (content == null) {
                                result.success(null)
                            } else {
                                result.success(
                                    mapOf(
                                        "label" to label,
                                        "content" to content
                                    )
                                )
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            documentOpenChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDocument" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "document"
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (bytes == null) {
                        result.error("missing_bytes", "Document bytes are missing.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        openDocument(bytes, fileName, mimeType)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("open_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openDocument(bytes: ByteArray, fileName: String, mimeType: String) {
        val dir = File(cacheDir, "nija_document_open")
        if (!dir.exists()) dir.mkdirs()
        dir.listFiles()?.forEach { file ->
            runCatching { file.delete() }
        }
        val safeName = fileName
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .ifBlank { "document" }
        val file = File(dir, safeName)
        file.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData = ClipData.newUri(contentResolver, safeName, uri)
        }
        val chooser = Intent.createChooser(intent, "Open document")
        startActivity(chooser)
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
        pendingSecretLabel = if (normalizedLabel.endsWith(".nijas")) label else "secret.nijas"
        pendingSecretUri = uri
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
