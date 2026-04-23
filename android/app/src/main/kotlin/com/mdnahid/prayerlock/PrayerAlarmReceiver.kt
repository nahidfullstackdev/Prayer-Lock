package com.mdnahid.prayerlock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Native BroadcastReceiver that fires when AlarmManager triggers a prayer alarm.
 *
 * This runs entirely in the Android process — no Flutter Dart isolate is started.
 * That makes it immune to OEM battery-optimization systems (Xiaomi MIUI, Infinix
 * HiOS, OPPO ColorOS, etc.) that kill background Dart isolates.
 *
 * Notification channel IDs intentionally match the IDs created by
 * flutter_local_notifications so a single channel set is used across both paths.
 *
 * adhan_type encoding (set by PrayerAlarmChannel / NativeAlarmService):
 *   0 — standard adhan  (adhan.mp3)
 *   1 — Fajr adhan      (adhan_fajr.mp3)
 *   2 — silent          (vibration only)
 */
class PrayerAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "PrayerAlarmReceiver"
        const val ACTION_PRAYER_ALARM = "com.mdnahid.prayerlock.PRAYER_ALARM"

        // Must match the IDs in notification_service.dart
        const val ADHAN_CHANNEL_ID = "prayer_adhan"
        const val FAJR_ADHAN_CHANNEL_ID = "prayer_fajr_adhan"
        const val SILENT_CHANNEL_ID = "prayer_silent"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "onReceive action=${intent.action}")

        val prayerId = intent.getIntExtra("prayer_id", -1)
        if (prayerId < 0) {
            Log.e(TAG, "Missing prayer_id — dropping alarm")
            return
        }

        val prayerName   = intent.getStringExtra("prayer_name")   ?: "Prayer"
        val arabicName   = intent.getStringExtra("arabic_name")   ?: ""
        val adhanType    = intent.getIntExtra("adhan_type", 0)    // 0=std, 1=fajr, 2=silent
        val minutesBefore = intent.getIntExtra("minutes_before", 0)

        // Ensure channels exist — safe to call even if they were already created
        // by flutter_local_notifications (Android is a no-op on duplicate creation).
        ensureChannels(context)
        showNotification(context, prayerId, prayerName, arabicName, adhanType, minutesBefore)
    }

    // ── notification channels ────────────────────────────────────────────────────

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (nm.getNotificationChannel(ADHAN_CHANNEL_ID) == null) {
            val soundUri = rawUri(context, "adhan")
            val audioAttr = audioAttr()
            nm.createNotificationChannel(
                NotificationChannel(
                    ADHAN_CHANNEL_ID,
                    "Prayer Time Adhan",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Plays adhan when prayer time arrives"
                    setSound(soundUri, audioAttr)
                    enableVibration(true)
                    enableLights(true)
                },
            )
            Log.d(TAG, "Created channel: $ADHAN_CHANNEL_ID")
        }

        if (nm.getNotificationChannel(FAJR_ADHAN_CHANNEL_ID) == null) {
            val soundUri = rawUri(context, "adhan_fajr")
            val audioAttr = audioAttr()
            nm.createNotificationChannel(
                NotificationChannel(
                    FAJR_ADHAN_CHANNEL_ID,
                    "Fajr Prayer Adhan",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Plays Fajr adhan at dawn"
                    setSound(soundUri, audioAttr)
                    enableVibration(true)
                    enableLights(true)
                },
            )
            Log.d(TAG, "Created channel: $FAJR_ADHAN_CHANNEL_ID")
        }

        if (nm.getNotificationChannel(SILENT_CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    SILENT_CHANNEL_ID,
                    "Prayer Time Reminder",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Vibration-only prayer time reminder"
                    setSound(null, null)
                    enableVibration(true)
                },
            )
            Log.d(TAG, "Created channel: $SILENT_CHANNEL_ID")
        }
    }

    // ── show notification ────────────────────────────────────────────────────────

    private fun showNotification(
        context: Context,
        prayerId: Int,
        prayerName: String,
        arabicName: String,
        adhanType: Int,
        minutesBefore: Int,
    ) {
        val channelId = when (adhanType) {
            1    -> FAJR_ADHAN_CHANNEL_ID
            2    -> SILENT_CHANNEL_ID
            else -> ADHAN_CHANNEL_ID
        }

        val title: String
        val body: String
        if (minutesBefore > 0) {
            title = "$minutesBefore min until $prayerName"
            body  = "$arabicName  •  Prepare for prayer"
        } else {
            title = "$prayerName — Prayer Time"
            body  = "$arabicName  •  Time to pray"
        }

        // Tapping the notification opens the app
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
        val tapPi = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                prayerId + 100,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_prayer_notify)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(tapPi)

        // For pre-O devices we also set the sound here; on O+ the channel handles it.
        if (adhanType != 2) {
            val soundFile = if (adhanType == 1) "adhan_fajr" else "adhan"
            builder.setSound(rawUri(context, soundFile))
        }

        try {
            NotificationManagerCompat.from(context).notify(prayerId, builder.build())
            Log.i(TAG, "Notification posted: id=$prayerId name=$prayerName channel=$channelId")
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS was denied at runtime — nothing we can do here
            Log.w(TAG, "POST_NOTIFICATIONS denied for id=$prayerId: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post notification id=$prayerId", e)
        }
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    private fun rawUri(context: Context, name: String): Uri {
        val resId = context.resources.getIdentifier(name, "raw", context.packageName)
        return Uri.parse("android.resource://${context.packageName}/$resId")
    }

    private fun audioAttr(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
}
