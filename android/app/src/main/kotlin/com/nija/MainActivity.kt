package com.nija

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
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
    private var pendingSharedText: String? = null
    private var pendingSharedSourceApplication: String? = null
    private var pendingSharedSourcePackage: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureSecretFromIntent(intent)
        captureSharedTextFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureSecretFromIntent(intent)
        captureSharedTextFromIntent(intent)
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
                "consumePendingSharedText" -> {
                    val text = pendingSharedText
                    if (text.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val sourceApplication = pendingSharedSourceApplication ?: "Unknown app"
                    val sourcePackage = pendingSharedSourcePackage ?: ""
                    pendingSharedText = null
                    pendingSharedSourceApplication = null
                    pendingSharedSourcePackage = null
                    result.success(
                        mapOf(
                            "text" to text,
                            "sourceApplication" to sourceApplication,
                            "sourcePackage" to sourcePackage
                        )
                    )
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

    private fun captureSharedTextFromIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val mime = (intent.type ?: "").lowercase()
        if (mime != "text/plain") return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        if (text.isBlank()) return
        val sourcePackage = sourcePackageFromIntent(intent)
        pendingSharedText = text
        pendingSharedSourcePackage = sourcePackage
        pendingSharedSourceApplication =
            sourcePackage?.let { applicationLabelForPackage(it) }
                ?: intent.getStringExtra(Intent.EXTRA_TITLE)?.trim()?.takeIf { it.isNotBlank() }
                ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim()?.takeIf { it.isNotBlank() }
                ?: "Unknown app"
    }

    private fun sourcePackageFromIntent(intent: Intent): String? {
        val referrerPackage = referrer?.host?.takeIf { it.isNotBlank() }
        if (referrerPackage != null) return referrerPackage
        val referrerName = intent.getStringExtra(Intent.EXTRA_REFERRER_NAME)
            ?.removePrefix("android-app://")
            ?.substringBefore('/')
            ?.takeIf { it.isNotBlank() }
        return referrerName
    }

    private fun applicationLabelForPackage(packageName: String): String? {
        return try {
            val appInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
            packageManager.getApplicationLabel(appInfo).toString().takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        }
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
