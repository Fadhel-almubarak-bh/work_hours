package com.example.work_hours

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.Toast
import android.util.Log
import com.example.work_hours.R
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.*

class MyHomeWidgetProvider : AppWidgetProvider() {
    private val TAG = "MyHomeWidgetProvider"
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d(TAG, "[home_widget] Updating widgets: ${appWidgetIds.size} widgets")
        
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Update clock in/out time labels
            updateClockTimeLabels(context, views)

            // Intent for previous button
            val prevIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
                action = ACTION_PREVIOUS
            }
            val prevPendingIntent = PendingIntent.getBroadcast(context, 0, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_previous, prevPendingIntent)

            // Intent for next button
            val nextIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
                action = ACTION_NEXT
            }
            val nextPendingIntent = PendingIntent.getBroadcast(context, 1, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_next, nextPendingIntent)

            // Intent for settings button
            val settingsIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
                action = ACTION_SETTINGS
            }
            val settingsPendingIntent = PendingIntent.getBroadcast(context, 2, settingsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_settings, settingsPendingIntent)

            // Intent for clock in/out button - use HomeWidgetBackgroundReceiver for background callback
            try {
                val clockIntent = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                    action = "HOME_WIDGET_UPDATE"
                    data = Uri.parse("myapp://clock_in_out")
                }
                val clockPendingIntent = PendingIntent.getBroadcast(context, 100, clockIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.btn_clock_in_out, clockPendingIntent)
                Log.d(TAG, "[home_widget] ✅ Clock in/out button configured with HomeWidgetBackgroundReceiver (requestCode 100)")
            } catch (e: Exception) {
                Log.e(TAG, "[home_widget] ❌ Error setting up clock in/out button: ${e.message}")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "[home_widget] ✅ Widget $appWidgetId updated successfully")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "[home_widget] onReceive called with action: ${intent.action}")
        Log.d(TAG, "[home_widget] Intent extras: ${intent.extras}")
        
        when (intent.action) {
            ACTION_PREVIOUS -> {
                Log.d(TAG, "[home_widget] Previous button clicked")
                Toast.makeText(context, "Previous clicked", Toast.LENGTH_SHORT).show()
            }
            ACTION_NEXT -> {
                Log.d(TAG, "[home_widget] Next button clicked")
                Toast.makeText(context, "Next clicked", Toast.LENGTH_SHORT).show()
            }
            ACTION_SETTINGS -> {
                Log.d(TAG, "[home_widget] Settings button clicked")
                Toast.makeText(context, "Settings clicked", Toast.LENGTH_SHORT).show()
            }
            ACTION_CLOCK_IN_OUT -> {
                Log.d(TAG, "[home_widget] 🎯 CLOCK IN/OUT BUTTON CLICKED!")
                Toast.makeText(context, "Clock in/out button pressed!", Toast.LENGTH_SHORT).show()
                try {
                    // Forward to MainActivity to handle in Flutter
                    val flutterIntent = Intent(context, MainActivity::class.java)
                    flutterIntent.action = ACTION_CLOCK_IN_OUT
                    flutterIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(flutterIntent)
                    Log.d(TAG, "[home_widget] ✅ Successfully forwarded clock in/out action to MainActivity")
                    Toast.makeText(context, "Clock in/out action sent to app", Toast.LENGTH_SHORT).show()
                } catch (e: Exception) {
                    Log.e(TAG, "[home_widget] ❌ Error forwarding clock in/out action: ${e.message}", e)
                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
            ACTION_TEST -> {
                Log.d(TAG, "[home_widget] 🧪 TEST BUTTON CLICKED!")
                Toast.makeText(context, "Test button works!", Toast.LENGTH_LONG).show()
            }
            else -> {
                Log.d(TAG, "[home_widget] Unknown action received: ${intent.action}")
            }
        }
    }

    companion object {
        private const val ACTION_PREVIOUS = "com.example.work_hours.ACTION_PREVIOUS"
        private const val ACTION_NEXT = "com.example.work_hours.ACTION_NEXT"
        private const val ACTION_SETTINGS = "com.example.work_hours.ACTION_SETTINGS"
        private const val ACTION_CLOCK_IN_OUT = "com.example.work_hours.ACTION_CLOCK_IN_OUT"
        private const val ACTION_TEST = "com.example.work_hours.ACTION_TEST"
    }
    
    private fun updateClockTimeLabels(context: Context, views: RemoteViews) {
        try {
            // Get clock in/out times from HomeWidget data
            val prefs = HomeWidgetPlugin.getData(context)
            val clockInTime = prefs.getString("clockIn", null)
            val clockOutTime = prefs.getString("clockOut", null)
            
            // Format the times for display
            val clockInText = if (clockInTime != null) {
                val time = formatTimeForDisplay(clockInTime)
                "Clock In: $time"
            } else {
                "Clock In: --:--"
            }
            
            val clockOutText = if (clockOutTime != null) {
                val time = formatTimeForDisplay(clockOutTime)
                "Clock Out: $time"
            } else {
                "Clock Out: --:--"
            }
            
            // Update the text views
            views.setTextViewText(R.id.tv_clock_in_time, clockInText)
            views.setTextViewText(R.id.tv_clock_out_time, clockOutText)
            
            Log.d(TAG, "[home_widget] Updated clock times - In: $clockInText, Out: $clockOutText")
        } catch (e: Exception) {
            Log.e(TAG, "[home_widget] Error updating clock time labels: ${e.message}", e)
            // Set default values on error
            views.setTextViewText(R.id.tv_clock_in_time, "Clock In: --:--")
            views.setTextViewText(R.id.tv_clock_out_time, "Clock Out: --:--")
        }
    }
    
    private fun formatTimeForDisplay(isoTime: String): String {
        return try {
            val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS", Locale.getDefault())
            val outputFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            val date = inputFormat.parse(isoTime)
            outputFormat.format(date ?: Date())
        } catch (e: Exception) {
            Log.e(TAG, "[home_widget] Error formatting time: ${e.message}", e)
            "--:--"
        }
    }
} 