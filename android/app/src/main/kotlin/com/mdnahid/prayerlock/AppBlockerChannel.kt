package com.mdnahid.prayerlock

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.util.Base64
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class AppBlockerChannel(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.mdnahid.prayerlock/app_blocker"
    }

    fun register() {
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> getInstalledApps(result)
            "startBlockerService" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                startBlockerService(packages, result)
            }
            "stopBlockerService" -> stopBlockerService(result)
            "isBlockerServiceRunning" -> result.success(AppBlockerService.isRunning)
            "hasUsageStatsPermission" -> result.success(hasUsageStatsPermission())
            "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(context))
            "openUsageStatsSettings" -> openUsageStatsSettings(result)
            "openOverlaySettings" -> openOverlaySettings(result)
            else -> result.notImplemented()
        }
    }

    // ── getInstalledApps ────────────────────────────────────────────────────

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
                    .sortedBy { it["appName"] as String }

                Handler(Looper.getMainLooper()).post { result.success(apps) }
            } catch (e: Exception) {
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
        // Scale down to 48×48 px to keep payload small
        val scaled = Bitmap.createScaledBitmap(source, 48, 48, true)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 80, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    // ── service control ─────────────────────────────────────────────────────

    private fun startBlockerService(packages: List<String>, result: MethodChannel.Result) {
        val intent = Intent(context, AppBlockerService::class.java).apply {
            putStringArrayListExtra(AppBlockerService.EXTRA_PACKAGES, ArrayList(packages))
        }
        ContextCompat.startForegroundService(context, intent)
        result.success(null)
    }

    private fun stopBlockerService(result: MethodChannel.Result) {
        context.stopService(Intent(context, AppBlockerService::class.java))
        result.success(null)
    }

    // ── permissions ─────────────────────────────────────────────────────────

    private fun hasUsageStatsPermission(): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = ops.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageStatsSettings(result: MethodChannel.Result) {
        context.startActivity(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        result.success(null)
    }

    private fun openOverlaySettings(result: MethodChannel.Result) {
        context.startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        result.success(null)
    }
}
