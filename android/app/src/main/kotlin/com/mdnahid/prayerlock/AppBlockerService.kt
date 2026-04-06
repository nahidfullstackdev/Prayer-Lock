package com.mdnahid.prayerlock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class AppBlockerService : Service() {

    companion object {
        const val EXTRA_PACKAGES = "blockedPackages"

        @Volatile
        var isRunning = false

        private const val NOTIFICATION_ID = 9001
        private const val CHANNEL_ID = "prayer_lock_blocker"
        private const val POLL_INTERVAL_MS = 1000L
        private const val PREFS_FILE = "prayer_lock_app_blocker"
        private const val PREFS_KEY_PACKAGES = "blocked_packages"
    }

    private var blockedPackages: Set<String> = emptySet()
    private val handler = Handler(Looper.getMainLooper())

    // Guards against launching the overlay for the same app repeatedly while it stays foreground.
    private var currentlyBlockedPackage: String? = null

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packages = intent?.getStringArrayListExtra(EXTRA_PACKAGES)

        if (packages != null) {
            blockedPackages = packages.toHashSet()
            // Persist for START_STICKY restart recovery
            getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
                .edit()
                .putStringSet(PREFS_KEY_PACKAGES, blockedPackages)
                .apply()
        } else {
            // Restarted by OS after being killed — restore from prefs
            blockedPackages = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
                .getStringSet(PREFS_KEY_PACKAGES, emptySet()) ?: emptySet()
        }

        startForegroundWithNotification()
        isRunning = true
        currentlyBlockedPackage = null
        handler.post(pollRunnable)

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        currentlyBlockedPackage = null
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Foreground detection ─────────────────────────────────────────────────

    private fun checkForegroundApp() {
        val foreground = getForegroundPackage() ?: return

        // Skip our own app (overlay activity belongs to our package)
        if (foreground == packageName) {
            currentlyBlockedPackage = null
            return
        }

        if (foreground in blockedPackages) {
            if (currentlyBlockedPackage != foreground) {
                currentlyBlockedPackage = foreground
                launchOverlay(foreground)
            }
        } else {
            currentlyBlockedPackage = null
        }
    }

    private fun getForegroundPackage(): String? = try {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, now - 5_000L, now)
            ?.maxByOrNull { it.lastTimeUsed }
            ?.packageName
    } catch (_: Exception) {
        null
    }

    private fun launchOverlay(blockedPackage: String) {
        startActivity(
            Intent(this, BlockerOverlayActivity::class.java).apply {
                putExtra(BlockerOverlayActivity.EXTRA_BLOCKED_PACKAGE, blockedPackage)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
        )
    }

    // ── Notification ─────────────────────────────────────────────────────────

    private fun startForegroundWithNotification() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val tapIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Prayer Lock Active")
            .setContentText("Blocking selected apps during prayer time")
            .setSmallIcon(R.drawable.ic_blocker_notify)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(tapIntent)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "App Blocker",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Active while app blocking is enabled during prayer time"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
