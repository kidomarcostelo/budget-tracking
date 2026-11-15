package com.budget.tracker_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.budget.tracker_app/ocr"
    private var pendingSharedData: Map<String, Any?>? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
        pendingSharedData?.let { data ->
            methodChannel?.invokeMethod("onSharedDataReceived", data)
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action == Intent.ACTION_SEND) {
            val type = intent.type ?: ""
            if (type.startsWith("image/")) {
                val imageUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (imageUri != null) {
                    try {
                        val tempFile = copyUriToTempFile(this, imageUri)
                        pendingSharedData = mapOf(
                            "type" to "image",
                            "filePath" to tempFile.absolutePath,
                            "uri" to imageUri.toString()
                        )
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            } else if (type.startsWith("text/") || intent.hasExtra(Intent.EXTRA_TEXT)) {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                pendingSharedData = mapOf(
                    "type" to "text",
                    "text" to text
                )
            }
        }
    }

    private fun copyUriToTempFile(context: Context, uri: Uri): File {
        val tempFile = File.createTempFile("shared_receipt_", ".png", context.cacheDir)
        context.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(tempFile).use { output ->
                input.copyTo(output)
            }
        }
        return tempFile
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedData" -> {
                        val data = pendingSharedData
                        pendingSharedData = null
                        result.success(data)
                    }
                    "recognizeText" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrEmpty()) {
                            result.error("INVALID_ARGUMENT", "filePath is required", null)
                            return@setMethodCallHandler
                        }
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val inputImage = InputImage.fromFilePath(this@MainActivity, Uri.fromFile(file))
                            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                            recognizer.process(inputImage)
                                .addOnSuccessListener { visionText ->
                                    val blocksList = visionText.textBlocks.map { block ->
                                        mapOf(
                                            "text" to block.text,
                                            "lines" to block.lines.map { line ->
                                                mapOf(
                                                    "text" to line.text,
                                                    "elements" to line.elements.map { el -> el.text }
                                                )
                                            }
                                        )
                                    }
                                    result.success(
                                        mapOf(
                                            "text" to visionText.text,
                                            "blocks" to blocksList
                                        )
                                    )
                                }
                                .addOnFailureListener { e ->
                                    result.error("OCR_FAILED", e.localizedMessage, null)
                                }
                        } catch (e: Exception) {
                            result.error("OCR_ERROR", e.localizedMessage, null)
                        }
                    }
                    "deleteTempFile" -> {
                        val filePath = call.argument<String>("filePath")
                        if (!filePath.isNullOrEmpty()) {
                            try {
                                val file = File(filePath)
                                if (file.exists() && file.parentFile == cacheDir) {
                                    file.delete()
                                }
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.budget.tracker_app/background_service").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startKeepAlive" -> {
                        CashewKeepAliveService.start(this@MainActivity)
                        result.success(true)
                    }
                    "stopKeepAlive" -> {
                        CashewKeepAliveService.stop(this@MainActivity)
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
                        } else {
                            true
                        }
                        result.success(isIgnoring)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                try {
                                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                    startActivity(intent)
                                    result.success(true)
                                } catch (e2: Exception) {
                                    result.error("INTENT_ERROR", e2.localizedMessage, null)
                                }
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
