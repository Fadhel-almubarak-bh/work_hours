package com.example.work_hours;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.net.Uri;
import android.util.Log;
import android.view.View;
import android.widget.RemoteViews;
import android.content.ComponentName;

import es.antonborri.home_widget.HomeWidgetProvider;

public class MyHomeWidgetProvider extends HomeWidgetProvider {

    private static final String TAG = "MyHomeWidgetProvider";
    private static final String PREFS_NAME = "HomeWidgetPreferences";
    private static final String KEY_TRANSPARENCY = "widget_transparency";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        onUpdate(context, appWidgetManager, appWidgetIds, prefs);
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds, SharedPreferences prefs) {
        try {
            for (int appWidgetId : appWidgetIds) {
                RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.home_widget_layout);

                String clockInText = prefs.getString("_clockInText", "In: --:--");
                String clockOutText = prefs.getString("_clockOutText", "Out: --:--");
                String overtimeText = prefs.getString("_overtimeText", "Overtime: 0h 0m");
                int transparency = prefs.getInt(KEY_TRANSPARENCY, 255); // Default fully opaque

                // Determine login state from clock in/out text
                boolean hasClockIn = !clockInText.equals("In: --:--");
                boolean hasClockOut = !clockOutText.equals("Out: --:--") && !clockOutText.equals("Out: Pending");
                boolean isLoggedIn = hasClockIn && !hasClockOut;

                Log.d(TAG, "Widget data received - Clock In: " + clockInText);
                Log.d(TAG, "Widget data received - Clock Out: " + clockOutText);
                Log.d(TAG, "Widget data received - Overtime: " + overtimeText);
                Log.d(TAG, "Widget data received - Transparency: " + transparency);
                Log.d(TAG, "Widget data received - Has Clock In: " + hasClockIn);
                Log.d(TAG, "Widget data received - Has Clock Out: " + hasClockOut);
                Log.d(TAG, "Widget data received - Is Logged In: " + isLoggedIn);

                views.setTextViewText(R.id.widget_clock_in, clockInText);
                views.setTextViewText(R.id.widget_clock_out, clockOutText);
                views.setTextViewText(R.id.widget_overtime, overtimeText);

                // Set button visibility based on login state
                views.setViewVisibility(R.id.widget_button_clock_in, isLoggedIn ? View.GONE : View.VISIBLE);
                views.setViewVisibility(R.id.widget_button_clock_out, isLoggedIn ? View.VISIBLE : View.GONE);

                // Apply transparent background using argb (safe for RemoteViews)
                int backgroundColor = Color.argb(transparency, 0, 0, 0); // white with alpha
                views.setInt(R.id.widget_root, "setBackgroundColor", backgroundColor);

                // Set click listeners
                Intent clockInIntent = new Intent(context, MainActivity.class);
                clockInIntent.setAction("CLOCK_IN");
                PendingIntent clockInPendingIntent = PendingIntent.getActivity(
                    context, 0, clockInIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                views.setOnClickPendingIntent(R.id.widget_button_clock_in, clockInPendingIntent);

                Intent clockOutIntent = new Intent(context, MainActivity.class);
                clockOutIntent.setAction("CLOCK_OUT");
                PendingIntent clockOutPendingIntent = PendingIntent.getActivity(
                    context, 1, clockOutIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                views.setOnClickPendingIntent(R.id.widget_button_clock_out, clockOutPendingIntent);

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
        intent.setData(Uri.parse("homewidget://" + action)); // Ensures intent uniqueness

        return PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }

    private PendingIntent getSettingsIntent(Context context) {
        Intent intent = new Intent(context, TransparencyActivity.class);

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

    public static void updateWidget(Context context) {
        Log.d(TAG, "🔄 updateWidget() called");
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        ComponentName componentName = new ComponentName(context, MyHomeWidgetProvider.class);
        int[] appWidgetIds = appWidgetManager.getAppWidgetIds(componentName);

        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        MyHomeWidgetProvider provider = new MyHomeWidgetProvider();
        provider.onUpdate(context, appWidgetManager, appWidgetIds, prefs);
    }
}
