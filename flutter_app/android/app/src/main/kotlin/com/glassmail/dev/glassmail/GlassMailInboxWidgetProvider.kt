package com.glassmail.dev.glassmail

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class GlassMailInboxWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val unreadCount = widgetData.getInt("unreadCount", 0).coerceAtLeast(0)
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.glassmail_inbox_widget)
            views.setTextViewText(R.id.unread_count, unreadCount.toString())
            pendingIntent?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
