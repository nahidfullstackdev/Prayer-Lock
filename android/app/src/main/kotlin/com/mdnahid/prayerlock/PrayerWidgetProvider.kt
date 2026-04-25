package com.mdnahid.prayerlock

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * AppWidgetProvider for the Prayer Lock home screen widget.
 *
 * Reads next-prayer data that the Dart side stashed via
 * [HomeWidget.saveWidgetData] and binds it to the layout. Also wires a tap
 * intent that launches [MainActivity] when the user taps the widget.
 *
 * Data keys (must match those written in HomeWidgetService.dart):
 *   next_prayer_name       — e.g. "Dhuhr"
 *   next_prayer_arabic     — e.g. "الظهر"
 *   next_prayer_time       — formatted "HH:mm"
 *   next_prayer_countdown  — e.g. "2h 15m"
 */
class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        val prayerName = widgetData.getString("next_prayer_name", null) ?: "—"
        val arabic = widgetData.getString("next_prayer_arabic", null) ?: ""
        val time = widgetData.getString("next_prayer_time", null) ?: "--:--"
        val countdown = widgetData.getString("next_prayer_countdown", null) ?: "—"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                setTextViewText(R.id.widget_prayer_name, prayerName)
                setTextViewText(R.id.widget_prayer_arabic, arabic)
                setTextViewText(R.id.widget_prayer_time, time)
                setTextViewText(R.id.widget_countdown, countdown)

                // Tap anywhere on the widget → open the app.
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pending = PendingIntent.getActivity(
                    context,
                    widgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.widget_root, pending)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        /** Broadcast an AppWidgetManager.ACTION_APPWIDGET_UPDATE to every live instance. */
        fun forceUpdateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, PrayerWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
