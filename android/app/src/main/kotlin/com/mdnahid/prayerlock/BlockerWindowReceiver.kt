package com.mdnahid.prayerlock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Fired by AlarmManager at prayer-window boundaries.
 *
 *   ACTION_START → flips PREFS_KEY_WINDOW_ACTIVE to true  (adhan time)
 *   ACTION_END   → flips PREFS_KEY_WINDOW_ACTIVE to false (adhan + N min)
 *
 * The Accessibility Service reads the flag on every event, so this receiver
 * does no other work — it just toggles a boolean.
 */
class BlockerWindowReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "BlockerWindowReceiver"
        const val ACTION_START = "com.mdnahid.prayerlock.BLOCK_WINDOW_START"
        const val ACTION_END = "com.mdnahid.prayerlock.BLOCK_WINDOW_END"

        const val EXTRA_PRAYER_ID = "prayer_id"

        /** Distinct request-code spaces so window alarms never collide with
         *  the existing prayer-notification alarms (codes 0..4 + 200..204). */
        const val REQ_BASE_START = 1000
        const val REQ_BASE_END = 2000
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val active = when (action) {
            ACTION_START -> true
            ACTION_END -> false
            else -> {
                Log.w(TAG, "Ignoring unknown action: $action")
                return
            }
        }
        val prayerId = intent.getIntExtra(EXTRA_PRAYER_ID, -1)

        context.getSharedPreferences(
            PrayerLockAccessibilityService.PREFS_FILE,
            Context.MODE_PRIVATE,
        ).edit()
            .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_WINDOW_ACTIVE, active)
            .apply()

        Log.i(TAG, "Window ${if (active) "START" else "END"} for prayer id=$prayerId")
    }
}
