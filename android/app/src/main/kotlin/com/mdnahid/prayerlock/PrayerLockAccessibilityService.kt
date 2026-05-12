package com.mdnahid.prayerlock

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * Detects which app is in the foreground and launches the prayer-reminder
 * overlay when a blocked app is opened during an active prayer window.
 *
 * Event-driven (no polling). The system delivers a TYPE_WINDOW_STATE_CHANGED
 * exactly once per foreground transition, so this is far cheaper and more
 * responsive than the previous UsageStatsManager polling.
 *
 * Privacy:
 *   - canRetrieveWindowContent="false" in accessibility_service_config.xml
 *   - Only reads event.packageName (the app's identifier, not its content)
 *   - Never reads, records, or transmits screen text
 *
 * Activation gate (both must be true):
 *   - PREFS_KEY_AUTO_ENABLED  — user has enabled "Block during prayer windows"
 *   - PREFS_KEY_WINDOW_ACTIVE — set/cleared by [BlockerWindowReceiver] at the
 *                               window start/end alarm boundaries
 */
class PrayerLockAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "PrayerLockA11y"

        /** Shared SharedPreferences file used by Channel + Receiver + Service. */
        const val PREFS_FILE = "prayer_lock_app_blocker"
        const val PREFS_KEY_PACKAGES = "blocked_packages"
        const val PREFS_KEY_AUTO_ENABLED = "auto_enabled"
        const val PREFS_KEY_WINDOW_ACTIVE = "window_active"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    /**
     * Dedupe guard — while a blocked app stays in the foreground we'd otherwise
     * re-launch the overlay on every TYPE_WINDOW_STATE_CHANGED inside that app
     * (e.g. dialog open/close). Reset on any non-blocked window so re-opening
     * the same blocked app launches a fresh overlay.
     */
    private var lastBlockedPackage: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        Log.i(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkg = event.packageName?.toString() ?: return

        // Ignore our own windows (overlay activity, settings, etc.) — re-trigger
        // protection would otherwise loop on the overlay itself.
        if (pkg == packageName) {
            lastBlockedPackage = null
            return
        }

        // System UI / launcher transitions — never block.
        if (pkg == "android" || pkg.startsWith("com.android.systemui")) {
            lastBlockedPackage = null
            return
        }

        val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val autoEnabled = prefs.getBoolean(PREFS_KEY_AUTO_ENABLED, false)
        val windowActive = prefs.getBoolean(PREFS_KEY_WINDOW_ACTIVE, false)
        if (!autoEnabled || !windowActive) {
            lastBlockedPackage = null
            return
        }

        val blocked = prefs.getStringSet(PREFS_KEY_PACKAGES, emptySet()) ?: emptySet()
        if (pkg in blocked) {
            if (lastBlockedPackage != pkg) {
                lastBlockedPackage = pkg
                launchOverlay(pkg)
            }
        } else {
            lastBlockedPackage = null
        }
    }

    override fun onInterrupt() {
        // Required override — no-op. We don't hold any feedback resources to release.
    }

    override fun onDestroy() {
        isRunning = false
        lastBlockedPackage = null
        Log.i(TAG, "Accessibility service destroyed")
        super.onDestroy()
    }

    private fun launchOverlay(blockedPackage: String) {
        try {
            startActivity(
                Intent(this, BlockerOverlayActivity::class.java).apply {
                    putExtra(BlockerOverlayActivity.EXTRA_BLOCKED_PACKAGE, blockedPackage)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch overlay for $blockedPackage", e)
        }
    }
}
