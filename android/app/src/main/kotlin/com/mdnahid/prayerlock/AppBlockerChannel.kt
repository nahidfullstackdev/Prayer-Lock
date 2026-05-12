package com.mdnahid.prayerlock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Base64
import android.util.Log
import android.view.accessibility.AccessibilityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Flutter ↔ Android MethodChannel for the App Blocker.
 *
 * Channel: com.mdnahid.prayerlock/app_blocker
 *
 * Detection runs in [PrayerLockAccessibilityService]; this channel only
 * configures it (which packages to block, whether auto-blocking is on)
 * and schedules the start/end window alarms via [AlarmManager].
 *
 * SharedPreferences layout (file: "prayer_lock_app_blocker"):
 *   blocked_packages   StringSet — packages the user picked
 *   auto_enabled       Boolean   — master switch, "Block during prayer windows"
 *   window_active      Boolean   — true between window start/end alarms
 *   window_<id>_start_ms  Long   — for boot-time reschedule
 *   window_<id>_end_ms    Long
 */
class AppBlockerChannel(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.mdnahid.prayerlock/app_blocker"
        const val TAG = "AppBlockerChannel"
        const val PRAYER_COUNT = 5
    }

    fun register() {
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> getInstalledApps(result)

            "hasAccessibilityPermission" ->
                result.success(hasAccessibilityPermission())
            "openAccessibilitySettings" -> {
                openAccessibilitySettings()
                result.success(null)
            }
            "hasOverlayPermission" ->
                result.success(Settings.canDrawOverlays(context))
            "openOverlaySettings" -> {
                openOverlaySettings()
                result.success(null)
            }

            "setBlockedPackages" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                setBlockedPackages(packages)
                result.success(null)
            }
            "setAutoBlockingEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setAutoBlockingEnabled(enabled)
                result.success(null)
            }
            "isAutoBlockingEnabled" ->
                result.success(getPrefs().getBoolean(
                    PrayerLockAccessibilityService.PREFS_KEY_AUTO_ENABLED, false,
                ))

            "scheduleBlockerWindows" -> {
                @Suppress("UNCHECKED_CAST")
                val windows = call.argument<List<Map<String, Any>>>("windows") ?: emptyList()
                scheduleBlockerWindows(windows)
                result.success(null)
            }
            "cancelAllBlockerWindows" -> {
                cancelAllBlockerWindows()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ── installed apps (launcher-only, no QUERY_ALL_PACKAGES) ────────────────

    private fun getInstalledApps(result: MethodChannel.Result) {
        Thread {
            try {
                val pm = context.packageManager
                val intent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                }
                val apps = pm.queryIntentActivities(intent, 0)
                    .filter { it.activityInfo.packageName != context.packageName }
                    .map { info ->
                        val pkgName = info.activityInfo.packageName
                        val appName = info.loadLabel(pm).toString()
                        val iconBase64 = try {
                            encodeIcon(info.loadIcon(pm))
                        } catch (_: Exception) {
                            null
                        }
                        mapOf(
                            "packageName" to pkgName,
                            "appName" to appName,
                            "iconBase64" to iconBase64,
                        )
                    }
                    .distinctBy { it["packageName"] as String }
                    .sortedBy { it["appName"] as String }

                Handler(Looper.getMainLooper()).post { result.success(apps) }
            } catch (e: Exception) {
                Log.e(TAG, "getInstalledApps failed", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("GET_APPS_FAILED", e.message, null)
                }
            }
        }.start()
    }

    private fun encodeIcon(drawable: Drawable): String {
        val source = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val w = drawable.intrinsicWidth.coerceAtLeast(48)
            val h = drawable.intrinsicHeight.coerceAtLeast(48)
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val scaled = Bitmap.createScaledBitmap(source, 48, 48, true)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 80, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    // ── permissions ──────────────────────────────────────────────────────────

    /**
     * True if Prayer Lock's accessibility service is enabled in system settings.
     *
     * Uses both the AccessibilityManager API (most reliable on modern Android)
     * and a fallback string-parse of Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
     * since some OEM forks return stale data from the manager service.
     */
    private fun hasAccessibilityPermission(): Boolean {
        val expected = "${context.packageName}/${PrayerLockAccessibilityService::class.java.name}"

        try {
            val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabled = am.getEnabledAccessibilityServiceList(
                android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
            )
            for (svc in enabled) {
                val id = svc.id ?: continue
                if (id.equals(expected, ignoreCase = true)) return true
                if (id.contains(PrayerLockAccessibilityService::class.java.name, ignoreCase = true) &&
                    id.startsWith(context.packageName)) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "AccessibilityManager check failed, falling back", e)
        }

        // Fallback: parse the raw setting string.
        val setting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(setting)
        while (splitter.hasNext()) {
            val component = splitter.next()
            if (component.equals(expected, ignoreCase = true)) return true
        }
        return false
    }

    private fun openAccessibilitySettings() {
        try {
            context.startActivity(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open Accessibility Settings", e)
        }
    }

    private fun openOverlaySettings() {
        try {
            context.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open Overlay Settings", e)
        }
    }

    // ── state for the accessibility service ──────────────────────────────────

    private fun setBlockedPackages(packages: List<String>) {
        getPrefs().edit()
            .putStringSet(PrayerLockAccessibilityService.PREFS_KEY_PACKAGES, packages.toSet())
            .apply()
        Log.i(TAG, "Blocked packages updated — count=${packages.size}")
    }

    private fun setAutoBlockingEnabled(enabled: Boolean) {
        val prefs = getPrefs()
        prefs.edit()
            .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_AUTO_ENABLED, enabled)
            .apply()
        // Disabling the master switch also clears any active window flag —
        // otherwise toggling off mid-window leaves the overlay armed until
        // the end alarm fires.
        if (!enabled) {
            prefs.edit()
                .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_WINDOW_ACTIVE, false)
                .apply()
        }
        Log.i(TAG, "Auto-blocking enabled=$enabled")
    }

    // ── window scheduling (AlarmManager.setAlarmClock pattern) ───────────────

    private fun scheduleBlockerWindows(windows: List<Map<String, Any>>) {
        cancelAllBlockerWindows()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val prefsEdit = getPrefs().edit()

        for (window in windows) {
            val prayerId = (window["prayerId"] as? Number)?.toInt() ?: continue
            val startMs = (window["startMs"] as? Number)?.toLong() ?: continue
            val endMs = (window["endMs"] as? Number)?.toLong() ?: continue

            // Persist for boot reschedule even if the times are in the past —
            // the boot receiver re-checks against `now` itself.
            prefsEdit
                .putLong("window_${prayerId}_start_ms", startMs)
                .putLong("window_${prayerId}_end_ms", endMs)

            if (endMs <= now) {
                Log.d(TAG, "Skipping past window for prayer id=$prayerId")
                continue
            }

            // Schedule START only if it's still in the future. If we're
            // already inside the window, flip window_active=true now and
            // skip directly to the END alarm.
            if (startMs > now) {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(startMs, null),
                    buildWindowPendingIntent(prayerId, BlockerWindowReceiver.ACTION_START),
                )
            } else {
                getPrefs().edit()
                    .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_WINDOW_ACTIVE, true)
                    .apply()
            }

            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(endMs, null),
                buildWindowPendingIntent(prayerId, BlockerWindowReceiver.ACTION_END),
            )

            Log.i(TAG, "Scheduled window prayer=$prayerId start=$startMs end=$endMs")
        }

        prefsEdit.apply()
    }

    private fun cancelAllBlockerWindows() {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefsEdit = getPrefs().edit()
        for (id in 0 until PRAYER_COUNT) {
            alarmManager.cancel(buildWindowPendingIntent(id, BlockerWindowReceiver.ACTION_START))
            alarmManager.cancel(buildWindowPendingIntent(id, BlockerWindowReceiver.ACTION_END))
            prefsEdit
                .remove("window_${id}_start_ms")
                .remove("window_${id}_end_ms")
        }
        prefsEdit
            .putBoolean(PrayerLockAccessibilityService.PREFS_KEY_WINDOW_ACTIVE, false)
            .apply()
        Log.i(TAG, "All blocker windows cancelled")
    }

    private fun buildWindowPendingIntent(prayerId: Int, action: String): PendingIntent {
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

    // ── helpers ──────────────────────────────────────────────────────────────

    private fun getPrefs() = context.getSharedPreferences(
        PrayerLockAccessibilityService.PREFS_FILE,
        Context.MODE_PRIVATE,
    )
}
