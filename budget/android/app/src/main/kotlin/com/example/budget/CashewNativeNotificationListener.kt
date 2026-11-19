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
        const val CHANNEL_ID = "cashew_pending_notifications"
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

        postReviewNotification()
    }

    private fun isRelevantPaymentNotification(packageName: String, title: String, content: String): Boolean {
        if (RECOGNIZED_PACKAGES.contains(packageName)) {
            return true
        }

        val isDebug = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebug && (packageName == "android" || packageName == applicationContext.packageName || packageName.endsWith(".debug"))) {
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

    private fun postReviewNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        createNotificationChannel(manager)

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val notifTitle = getString(R.string.pending_transaction_notification_title)
        val notifText = getString(R.string.pending_transaction_notification_text)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(notifTitle)
            .setContentText(notifText)
            .setSmallIcon(R.drawable.notification_icon_android2)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = getString(R.string.pending_notification_channel_name)
            val desc = getString(R.string.pending_notification_channel_description)
            val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = desc
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        }
    }
}
