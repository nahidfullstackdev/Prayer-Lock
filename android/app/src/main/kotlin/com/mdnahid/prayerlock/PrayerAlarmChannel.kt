package com.mdnahid.prayerlock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ Android MethodChannel for prayer alarm scheduling.
 *
 * Channel name: com.mdnahid.prayerlock/prayer_alarm
 *
 * Exposed methods (called from NativeAlarmService.dart):
 *   scheduleExactPrayerAlarm(id, timeMs, prayerName, arabicName, adhanType, minutesBefore)
 *   cancelPrayerAlarm(id)
 *   cancelAllPrayerAlarms()
 *   isBatteryOptimizationIgnored() → bool
 *   openBatteryOptimizationSettings()
 *   openAutoStartSettings(manufacturer)
 *
 * SharedPreferences layout (file: "prayer_alarm_prefs"):
 *   alarm_<id>_time_ms        Long   — fire time in UTC milliseconds
 *   alarm_<id>_name           String — English prayer name
 *   alarm_<id>_arabic         String — Arabic prayer name
 *   alarm_<id>_adhan_type     Int    — 0=standard, 1=fajr, 2=silent
 *   alarm_<id>_minutes_before Int    — advance offset (for display in notification)
 */
class PrayerAlarmChannel(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.mdnahid.prayerlock/prayer_alarm"
        const val TAG = "PrayerAlarmChannel"
        const val PREFS_NAME = "prayer_alarm_prefs"
        const val PRAYER_COUNT = 5
    }

    fun register() {
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleExactPrayerAlarm" -> {
                val id     = call.argument<Int>("id")
                    ?: return result.error("INVALID_ARG", "id is required", null)
                // timeMs comes as Int from Dart on 32-bit builds — coerce to Long
                val timeMs: Long = (call.argument<Any>("timeMs") as? Number)?.toLong()
                    ?: return result.error("INVALID_ARG", "timeMs is required", null)
                val prayerName    = call.argument<String>("prayerName")    ?: "Prayer"
                val arabicName    = call.argument<String>("arabicName")    ?: ""
                val adhanType     = call.argument<Int>("adhanType")        ?: 0
                val minutesBefore = call.argument<Int>("minutesBefore")    ?: 0

                scheduleExactPrayerAlarm(id, timeMs, prayerName, arabicName, adhanType, minutesBefore)
                result.success(null)
            }

            "cancelPrayerAlarm" -> {
                val id = call.argument<Int>("id")
                    ?: return result.error("INVALID_ARG", "id is required", null)
                cancelPrayerAlarm(id)
                result.success(null)
            }

            "cancelAllPrayerAlarms" -> {
                cancelAllPrayerAlarms()
                result.success(null)
            }

            "isBatteryOptimizationIgnored" ->
                result.success(isBatteryOptimizationIgnored())

            "openBatteryOptimizationSettings" -> {
                openBatteryOptimizationSettings()
                result.success(null)
            }

            "openAutoStartSettings" -> {
                val manufacturer = call.argument<String>("manufacturer") ?: ""
                openAutoStartSettings(manufacturer)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ── schedule ─────────────────────────────────────────────────────────────────

    private fun scheduleExactPrayerAlarm(
        id: Int,
        timeMs: Long,
        prayerName: String,
        arabicName: String,
        adhanType: Int,
        minutesBefore: Int,
    ) {
        // Persist so PrayerBootReceiver can reschedule after reboot
        saveAlarmData(id, timeMs, prayerName, arabicName, adhanType, minutesBefore)

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildAlarmPendingIntent(id, prayerName, arabicName, adhanType, minutesBefore)

        // setAlarmClock — highest-priority alarm class, exempt from Doze deferral
        // and App Standby bucket throttling. setExactAndAllowWhileIdle is held
        // back after several hours of screen-off, which silently breaks Fajr
        // (4–5:30am, 6+ hours into deep Doze). The status-bar "Next alarm"
        // surface this exposes is a desirable side effect for prayer times.
        val showIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.let { launch ->
                PendingIntent.getActivity(
                    context, id + 200, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
        alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(timeMs, showIntent), pi)

        val inMs = timeMs - System.currentTimeMillis()
        Log.i(TAG, "Scheduled id=$id name=$prayerName in ${inMs}ms at $timeMs")
    }

    // ── cancel ───────────────────────────────────────────────────────────────────

    private fun cancelPrayerAlarm(id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Must use the same PendingIntent key (request code = id) to cancel correctly.
        val pi = buildCancelPendingIntent(id)
        alarmManager.cancel(pi)
        clearAlarmData(id)
        Log.i(TAG, "Cancelled alarm id=$id")
    }

    private fun cancelAllPrayerAlarms() {
        for (id in 0 until PRAYER_COUNT) {
            cancelPrayerAlarm(id)
        }
        Log.i(TAG, "All $PRAYER_COUNT prayer alarms cancelled")
    }

    // ── pending intents ──────────────────────────────────────────────────────────

    private fun buildAlarmPendingIntent(
        id: Int,
        prayerName: String,
        arabicName: String,
        adhanType: Int,
        minutesBefore: Int,
    ): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = PrayerAlarmReceiver.ACTION_PRAYER_ALARM
            putExtra("prayer_id", id)
            putExtra("prayer_name", prayerName)
            putExtra("arabic_name", arabicName)
            putExtra("adhan_type", adhanType)
            putExtra("minutes_before", minutesBefore)
        }
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Minimal intent used only for cancelling (extras don't matter for cancel). */
    private fun buildCancelPendingIntent(id: Int): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = PrayerAlarmReceiver.ACTION_PRAYER_ALARM
        }
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ── SharedPreferences ────────────────────────────────────────────────────────

    private fun saveAlarmData(
        id: Int,
        timeMs: Long,
        prayerName: String,
        arabicName: String,
        adhanType: Int,
        minutesBefore: Int,
    ) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putLong("alarm_${id}_time_ms", timeMs)
            .putString("alarm_${id}_name", prayerName)
            .putString("alarm_${id}_arabic", arabicName)
            .putInt("alarm_${id}_adhan_type", adhanType)
            .putInt("alarm_${id}_minutes_before", minutesBefore)
            .apply()
    }

    private fun clearAlarmData(id: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .remove("alarm_${id}_time_ms")
            .remove("alarm_${id}_name")
            .remove("alarm_${id}_arabic")
            .remove("alarm_${id}_adhan_type")
            .remove("alarm_${id}_minutes_before")
            .apply()
    }

    // ── battery optimisation ─────────────────────────────────────────────────────

    private fun isBatteryOptimizationIgnored(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun openBatteryOptimizationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        } else {
            Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Fall back to app settings if the direct intent isn't supported
            Log.w(TAG, "Battery opt intent failed, opening app settings: ${e.message}")
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }
    }

    // ── OEM auto-start ───────────────────────────────────────────────────────────

    /**
     * Attempts to open the OEM-specific auto-start / protected-apps settings.
     * Tries each known ComponentName for the given [manufacturer] in order,
     * falling back to the standard App Info screen if none resolve.
     */
    private fun openAutoStartSettings(manufacturer: String) {
        val candidates = oemAutoStartIntents(manufacturer)
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
                Log.i(TAG, "Opened auto-start settings for $manufacturer")
                return
            } catch (_: Exception) { /* try next candidate */ }
        }
        // Generic fallback
        Log.i(TAG, "No OEM auto-start match for '$manufacturer', opening App Info")
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    private fun oemAutoStartIntents(manufacturer: String): List<Intent> =
        when (manufacturer.lowercase().trim()) {
            "xiaomi", "redmi", "poco" -> listOf(
                Intent().setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                ),
            )
            "oppo", "realme" -> listOf(
                Intent().setClassName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.FakeActivity",
                ),
                Intent().setClassName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                ),
            )
            "oneplus" -> listOf(
                Intent().setClassName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                ),
            )
            "vivo" -> listOf(
                Intent().setClassName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                ),
                Intent().setClassName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.PurviewTabActivity",
                ),
            )
            "huawei", "honor" -> listOf(
                Intent().setClassName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                ),
                Intent().setClassName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                ),
            )
            "samsung" -> listOf(
                Intent().setClassName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            )
            // Transsion group — covers Tecno, Infinix, Itel
            "tecno", "infinix", "itel" -> listOf(
                Intent().setClassName(
                    "com.transsion.phonemaster",
                    "com.transsion.phonemaster.ui.main.MainActivity",
                ),
            )
            "asus" -> listOf(
                Intent().setClassName(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.powersaver.PowerSaverSettings",
                ),
            )
            "meizu" -> listOf(
                Intent().setClassName(
                    "com.meizu.safe",
                    "com.meizu.safe.permission.SmartPermissionActivity",
                ),
            )
            "lenovo" -> listOf(
                Intent().setClassName(
                    "com.lenovo.security",
                    "com.lenovo.security.purebackground.PureBackgroundActivity",
                ),
            )
            else -> emptyList()
        }
}
