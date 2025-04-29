package com.example.work_hours;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Log;
import android.widget.RemoteViews;

import es.antonborri.home_widget.HomeWidgetProvider; // ✅ correct import

public class MyHomeWidgetProvider extends HomeWidgetProvider { // ✅ rename your class

    private static final String TAG = "MyHomeWidgetProvider";

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

                views.setOnClickPendingIntent(R.id.widget_button_clock_in, getPendingIntent(context, "clock_in", appWidgetId, 0));
                views.setOnClickPendingIntent(R.id.widget_button_clock_out, getPendingIntent(context, "clock_out", appWidgetId, 1));
                views.setOnClickPendingIntent(R.id.widget_button_settings, getSettingsIntent(context));

                appWidgetManager.updateAppWidget(appWidgetId, views);

                Log.d(TAG, "✅ Widget updated successfully for appWidgetId: " + appWidgetId);
            }
        } catch (Exception e) {
            Log.e(TAG, "❌ Error updating widget: " + e.getMessage(), e);
        }
    }

    private PendingIntent getPendingIntent(Context context, String action, int appWidgetId, int requestCode) {
        Intent intent = new Intent(context, MyHomeWidgetProvider.class);
        intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
        intent.setData(Uri.parse("homewidget://" + action));

        return PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }

    private PendingIntent getSettingsIntent(Context context) {
        Intent intent = new Intent(context, TransparencyActivity.class);
        Log.d(TAG, "Intent: " + intent.toString());
        if (intent.resolveActivity(context.getPackageManager()) == null) {
            Log.e(TAG, "❌ TransparencyActivity is not resolvable by PackageManager.");
        }

        return PendingIntent.getActivity(
                context,
                100,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }
}
