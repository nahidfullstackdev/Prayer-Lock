package com.mdnahid.prayerlock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Reschedules all prayer alarms after the device boots.
 *
 * AlarmManager alarms are cleared on reboot.  This receiver reads the
 * persisted alarm data from SharedPreferences (written by [PrayerAlarmChannel]
 * each time an alarm is scheduled from Flutter) and recreates only the alarms
 * whose fire-time is still in the future.
 *
 * Alarms already in the past are skipped — the user will get up-to-date
 * alarms the next time the app is opened and [scheduleAllPrayers] is called.
 */
class PrayerBootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "PrayerBootReceiver"
        /** SharedPreferences file name — must match PrayerAlarmChannel */
        const val PREFS_NAME = "prayer_alarm_prefs"
        /** 5 daily prayers — IDs 0-4 match PrayerName.index on the Dart side */
        const val PRAYER_COUNT = 5

        private val HANDLED_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",       // HTC/OnePlus fast boot
            "com.htc.intent.action.QUICKBOOT_POWERON",       // HTC legacy
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in HANDLED_ACTIONS) {
            Log.d(TAG, "Ignoring action: $action")
            return
        }
        Log.i(TAG, "Received $action — rescheduling prayer alarms")
        rescheduleAlarms(context)
    }

    // ── reschedule ───────────────────────────────────────────────────────────────

    private fun rescheduleAlarms(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var rescheduled = 0
        var skipped = 0

        for (id in 0 until PRAYER_COUNT) {
            val timeMs = prefs.getLong("alarm_${id}_time_ms", -1L)

            if (timeMs <= 0) {
                Log.d(TAG, "id=$id: no stored alarm, skipping")
                continue
            }

            if (timeMs <= now) {
                Log.d(TAG, "id=$id: alarm in the past (${timeMs - now}ms ago), skipping")
                skipped++
                continue
            }

            val prayerName    = prefs.getString("alarm_${id}_name", "Prayer") ?: "Prayer"
            val arabicName    = prefs.getString("alarm_${id}_arabic", "") ?: ""
            val adhanType     = prefs.getInt("alarm_${id}_adhan_type", 0)
            val minutesBefore = prefs.getInt("alarm_${id}_minutes_before", 0)

            val alarmIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                action = PrayerAlarmReceiver.ACTION_PRAYER_ALARM
                putExtra("prayer_id", id)
                putExtra("prayer_name", prayerName)
                putExtra("arabic_name", arabicName)
                putExtra("adhan_type", adhanType)
                putExtra("minutes_before", minutesBefore)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            // Match PrayerAlarmChannel: setAlarmClock survives deep Doze /
            // App Standby bucket throttling; setExactAndAllowWhileIdle does not.
            val showIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.let { launch ->
                    PendingIntent.getActivity(
                        context, id + 200, launch,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                }
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(timeMs, showIntent),
                pendingIntent,
            )

            rescheduled++
            Log.i(TAG, "Rescheduled id=$id name=$prayerName at $timeMs (in ${timeMs - now}ms)")
        }

        Log.i(TAG, "Boot reschedule complete — rescheduled=$rescheduled skipped(past)=$skipped")
    }
}
