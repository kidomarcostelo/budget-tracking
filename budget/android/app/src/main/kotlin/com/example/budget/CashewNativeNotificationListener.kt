package com.budget.tracker_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native Android NotificationListenerService that captures Google Wallet and payment
 * notifications even when the Flutter Engine or main Activity is killed or in the background.
 *
 * Buffers captured events as JSON into SharedPreferences ("FlutterSharedPreferences")
 * under key "flutter.cashew_notification_buffer". Upon opening or resuming Cashew,
 * Dart's NotificationDispatcher flushes this buffer through the existing parser and
 * deduplication ledger pipeline.
 */
class CashewNativeNotificationListener : NotificationListenerService() {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val BUFFER_KEY = "flutter.cashew_notification_buffer"
        const val TEMPLATE_KEYWORDS_KEY = "flutter.cashew_template_keywords"
        const val CHANNEL_ID = "pendingTransactions"
        const val NOTIFICATION_ID = 9992
        const val MAX_BUFFER_SIZE = 50

        val RECOGNIZED_PACKAGES = setOf(
            "com.google.android.apps.walletnfcrel",
            "com.google.android.apps.nbu.paisa.user",
            "com.google.android.gms"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // Ignore notifications posted by Cashew itself or by our review notification
        if (packageName == applicationContext.packageName ||
            packageName == "com.budget.tracker_app" ||
            packageName == "com.budget.tracker_app.debug" ||
            sbn.id == NOTIFICATION_ID ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && sbn.notification?.channelId == CHANNEL_ID)
        ) {
            return
        }

        val extras = sbn.notification?.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val content = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        if (!isRelevantPaymentNotification(packageName, title, content)) {
            return
        }

        bufferNotification(
            id = sbn.id,
            packageName = packageName,
            title = title,
            content = content,
            timestamp = sbn.postTime
        )

        postReviewNotification(title, content)
    }

    private fun matchesTemplateKeyword(title: String, content: String): Boolean {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(TEMPLATE_KEYWORDS_KEY, null) ?: return false
            val array = JSONArray(raw)
            val combined = "$title $content"
            for (i in 0 until array.length()) {
                val keyword = array.optString(i)?.trim() ?: continue
                if (keyword.isNotEmpty() && combined.contains(keyword, ignoreCase = true)) {
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun isNotificationScanningDebugEnabled(): Boolean {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.contains("flutter.notificationScanningDebug")) {
                return prefs.getBoolean("flutter.notificationScanningDebug", false)
            }
            val raw = prefs.getString("flutter.userSettings", null) ?: return false
            val json = JSONObject(raw)
            json.optBoolean("notificationScanningDebug", false)
        } catch (_: Exception) {
            false
        }
    }

    private fun isRelevantPaymentNotification(packageName: String, title: String, content: String): Boolean {
        if (RECOGNIZED_PACKAGES.contains(packageName)) {
            return true
        }

        // BT-0019: Capture bank notifications matching user-configured scanner templates
        if (matchesTemplateKeyword(title, content)) {
            return true
        }

        val isSimulationAllowed = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0 || isNotificationScanningDebugEnabled()
        if (isSimulationAllowed && (packageName == "android" || packageName == "com.android.shell")) {
            val combined = "$title $content"
            if (combined.contains("Google Pay", ignoreCase = true) ||
                combined.contains("Google Wallet", ignoreCase = true) ||
                combined.contains("Paid", ignoreCase = true) ||
                combined.contains("Payment", ignoreCase = true) ||
                combined.contains("PHP", ignoreCase = true) ||
                combined.contains("USD", ignoreCase = true) ||
                combined.contains("₱") ||
                combined.contains("$")
            ) {
                return true
            }
        }

        return false
    }

    @Synchronized
    private fun bufferNotification(
        id: Int,
        packageName: String,
        title: String,
        content: String,
        timestamp: Long
    ) {
        try {
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currentRaw = prefs.getString(BUFFER_KEY, "[]") ?: "[]"
            val array = try {
                JSONArray(currentRaw)
            } catch (e: Exception) {
                JSONArray()
            }

            val item = JSONObject().apply {
                put("id", id)
                put("packageName", packageName)
                put("title", title)
                put("content", content)
                put("timestamp", timestamp)
            }

            array.put(item)

            // Cap buffer size to avoid unbounded memory growth
            val trimmedArray = if (array.length() > MAX_BUFFER_SIZE) {
                val newArray = JSONArray()
                for (i in (array.length() - MAX_BUFFER_SIZE) until array.length()) {
                    newArray.put(array.getJSONObject(i))
                }
                newArray
            } else {
                array
            }

            prefs.edit().putString(BUFFER_KEY, trimmedArray.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun postReviewNotification(incomingTitle: String, incomingContent: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        createNotificationChannel(manager)

        val parsed = parsePaymentDetails(incomingTitle, incomingContent)
        val merchantEncoded = try {
            if (!parsed.merchant.isNullOrBlank()) java.net.URLEncoder.encode(parsed.merchant, "UTF-8") else ""
        } catch (e: Exception) {
            ""
        }
        val payloadUri = "openPendingTransaction?latest=true&amount=${parsed.amountNum}&merchant=$merchantEncoded"

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            action = "SELECT_NOTIFICATION"
            putExtra("notificationId", NOTIFICATION_ID)
            putExtra("payload", payloadUri)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val notifTitle = getString(R.string.new_transaction_detected)
        val notifText = formatNotificationBody(parsed, incomingContent)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(notifTitle)
            .setContentText(notifText)
            .setSmallIcon(R.drawable.notification_icon_android2)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun formatNotificationBody(parsed: ParsedPaymentInfo, content: String): String {
        return when {
            parsed.amount.isNotBlank() && !parsed.merchant.isNullOrBlank() ->
                "${parsed.amount} • ${parsed.merchant}"
            parsed.amount.isNotBlank() ->
                parsed.amount
            content.isNotBlank() ->
                content
            else ->
                getString(R.string.pending_transaction_notification_text)
        }
    }

    private data class ParsedPaymentInfo(val amount: String, val amountNum: String, val merchant: String?)

    private fun parsePaymentDetails(title: String, content: String): ParsedPaymentInfo {
        val merchantRegex = Regex("""\b(?:at|to|in)\s+([^,.\n]+)""", RegexOption.IGNORE_CASE)
        val merchantMatch = merchantRegex.find(content)
        var merchant = merchantMatch?.groupValues?.get(1)?.trim()
        if (merchant != null) {
            val withIdx = merchant.indexOf(" with ", ignoreCase = true)
            if (withIdx != -1) {
                merchant = merchant.substring(0, withIdx).trim()
            }
        }

        val amountRegex = Regex(
            """(?:([₱$€£¥₹]|PHP|USD|EUR|GBP|P)\s*)?([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})|[0-9]+\.[0-9]{2})(?:\s*([₱$€£¥₹]|PHP|USD|EUR|GBP|P))?""",
            RegexOption.IGNORE_CASE
        )
        val amountMatch = amountRegex.find(content)

        val rawCurr = amountMatch?.groupValues?.get(1)?.takeIf { it.isNotBlank() }
            ?: amountMatch?.groupValues?.get(3)?.takeIf { it.isNotBlank() }
            ?: "PHP"
        val rawNum = amountMatch?.groupValues?.get(2)?.takeIf { it.isNotBlank() } ?: ""

        val curr = when (rawCurr.uppercase()) {
            "P", "₱", "PHP" -> "PHP"
            "$", "USD" -> "USD"
            "€", "EUR" -> "EUR"
            "£", "GBP" -> "GBP"
            "¥", "JPY" -> "JPY"
            "₹", "INR" -> "INR"
            else -> rawCurr
        }

        val formattedAmount = if (rawNum.isNotBlank()) "-$curr $rawNum" else ""
        return ParsedPaymentInfo(formattedAmount, rawNum, merchant)
    }

    private fun createNotificationChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = getString(R.string.pending_notification_channel_name)
            val desc = getString(R.string.pending_notification_channel_description)
            val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = desc
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        }
    }
}
