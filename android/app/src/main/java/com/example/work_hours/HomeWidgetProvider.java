package com.example.work_hours;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Log;
import android.widget.RemoteViews;

public class HomeWidgetProvider extends es.antonborri.home_widget.HomeWidgetProvider {
    private static final String TAG = "HomeWidgetProvider";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds, SharedPreferences prefs) {
        try {
            for (int appWidgetId : appWidgetIds) {
                RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.home_widget_layout);

                String clockInText = prefs.getString("_clockInText", "In: --:--");
                String clockOutText = prefs.getString("_clockOutText", "Out: --:--");
                String overtimeText = prefs.getString("_overtimeText", "Overtime: 0h 0m");

                views.setTextViewText(R.id.widget_clock_in, clockInText);
                views.setTextViewText(R.id.widget_clock_out, clockOutText);
                views.setTextViewText(R.id.widget_overtime, overtimeText);

                // Clock In Button
                Intent clockInIntent = new Intent(context, HomeWidgetProvider.class);
                clockInIntent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
                clockInIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
                clockInIntent.setData(Uri.parse("homewidget://clock_in"));
                PendingIntent clockInPendingIntent = PendingIntent.getBroadcast(
                        context, 0, clockInIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
                views.setOnClickPendingIntent(R.id.widget_button_clock_in, clockInPendingIntent);

                // Clock Out Button
                Intent clockOutIntent = new Intent(context, HomeWidgetProvider.class);
                clockOutIntent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
                clockOutIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
                clockOutIntent.setData(Uri.parse("homewidget://clock_out"));
                PendingIntent clockOutPendingIntent = PendingIntent.getBroadcast(
                        context, 1, clockOutIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
                views.setOnClickPendingIntent(R.id.widget_button_clock_out, clockOutPendingIntent);

                appWidgetManager.updateAppWidget(appWidgetId, views);

                Log.d(TAG, "✅ Widget updated successfully for appWidgetId: " + appWidgetId);
            }
        } catch (Exception e) {
            Log.e(TAG, "❌ Error updating widget: " + e.getMessage());
        }
    }
}
