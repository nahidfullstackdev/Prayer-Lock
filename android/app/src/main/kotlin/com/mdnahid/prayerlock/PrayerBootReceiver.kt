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
 *
 * Also reschedules the App Blocker prayer-window start/end alarms persisted
 * by [AppBlockerChannel] so the Accessibility Service stays armed for the
 * remainder of today's prayer windows after a reboot.
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
        rescheduleBlockerWindows(context)
    }

    // ── reschedule prayer alarms ─────────────────────────────────────────────

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

    // ── reschedule App Blocker prayer windows ────────────────────────────────

    /**
     * Recreates today's blocker-window start/end alarms from the persisted
     * timestamps written by [AppBlockerChannel.scheduleBlockerWindows]. Only
     * touches windows whose end time is still in the future. The Dart side
     * will overwrite these on next app open with fresh times.
     */
    private fun rescheduleBlockerWindows(context: Context) {
        val prefs = context.getSharedPreferences(
            PrayerLockAccessibilityService.PREFS_FILE,
            Context.MODE_PRIVATE,
        )
        val autoEnabled = prefs.getBoolean(
            PrayerLockAccessibilityService.PREFS_KEY_AUTO_ENABLED, false,
        )
        if (!autoEnabled) {
            Log.d(TAG, "Auto-blocking disabled — skipping window reschedule")
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var rescheduled = 0

        // Reset window_active — boot wiped any in-flight state. Either an end
        // alarm fires first (no-op) or a start alarm fires first (sets it).
        prefs.edit()
            .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_WINDOW_ACTIVE, false)
            .apply()

        for (id in 0 until PRAYER_COUNT) {
            val startMs = prefs.getLong("window_${id}_start_ms", -1L)
            val endMs = prefs.getLong("window_${id}_end_ms", -1L)
            if (startMs <= 0 || endMs <= 0 || endMs <= now) continue

            if (startMs > now) {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(startMs, null),
                    buildWindowPendingIntent(context, id, BlockerWindowReceiver.ACTION_START),
                )
            } else {
                // We rebooted mid-window — flip it active immediately.
                prefs.edit()
                    .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_WINDOW_ACTIVE, true)
                    .apply()
            }

            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(endMs, null),
                buildWindowPendingIntent(context, id, BlockerWindowReceiver.ACTION_END),
            )
            rescheduled++
        }

        Log.i(TAG, "Boot blocker-window reschedule complete — count=$rescheduled")
    }

    private fun buildWindowPendingIntent(
        context: Context,
        prayerId: Int,
        action: String,
    ): PendingIntent {
        val requestCode = when (action) {
            BlockerWindowReceiver.ACTION_START -> BlockerWindowReceiver.REQ_BASE_START + prayerId
            BlockerWindowReceiver.ACTION_END -> BlockerWindowReceiver.REQ_BASE_END + prayerId
            else -> error("Unknown action: $action")
        }
        val intent = Intent(context, BlockerWindowReceiver::class.java).apply {
            this.action = action
            putExtra(BlockerWindowReceiver.EXTRA_PRAYER_ID, prayerId)
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
