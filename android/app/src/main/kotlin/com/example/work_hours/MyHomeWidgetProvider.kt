package com.example.work_hours

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
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
    
    companion object {
        private const val ACTION_PREVIOUS = "com.example.work_hours.ACTION_PREVIOUS"
        private const val ACTION_NEXT = "com.example.work_hours.ACTION_NEXT"
        private const val ACTION_SETTINGS = "com.example.work_hours.ACTION_SETTINGS"
        private const val ACTION_CLOCK_IN_OUT = "com.example.work_hours.ACTION_CLOCK_IN_OUT"
        private const val ACTION_TEST = "com.example.work_hours.ACTION_TEST"
        
        // Tab navigation constants
        private const val TAB_HOME_SCREEN = 0
        private const val TAB_HISTORY = 1
        private const val TAB_SUMMARY = 2
        private const val TAB_SALARY = 3
        private const val TOTAL_TABS = 4
        
        private val TAB_NAMES = arrayOf("Home Screen", "History", "Summary", "Salary")
    }
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Get current tab from shared preferences
            val currentTab = getCurrentTab(context)
            
            // Update page title
            updatePageTitle(views, currentTab)
            
            // Show different content based on current tab
            when (currentTab) {
                TAB_HOME_SCREEN -> {
                    // Show clock in/out functionality for home screen
                    showHomeScreenContent(context, views)
                }
                else -> {
                    // Show only title for other tabs (History, Summary, Salary)
                    showEmptyTabContent(views)
                }
            }

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

            // Intent for clock in/out button - only for home screen
            if (currentTab == TAB_HOME_SCREEN) {
                try {
                    val clockIntent = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                        action = "HOME_WIDGET_UPDATE"
                        data = Uri.parse("myapp://clock_in_out")
                    }
                    val clockPendingIntent = PendingIntent.getBroadcast(context, 100, clockIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    views.setOnClickPendingIntent(R.id.btn_clock_in_out, clockPendingIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "[home_widget] ❌ Error setting up clock in/out button: ${e.message}")
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_PREVIOUS -> {
                val currentTab = getCurrentTab(context)
                val newTab = if (currentTab == 0) TOTAL_TABS - 1 else currentTab - 1
                setCurrentTab(context, newTab)
                updateAllWidgets(context)
                Toast.makeText(context, "Previous: ${TAB_NAMES[newTab]}", Toast.LENGTH_SHORT).show()
            }
            ACTION_NEXT -> {
                val currentTab = getCurrentTab(context)
                val newTab = (currentTab + 1) % TOTAL_TABS
                setCurrentTab(context, newTab)
                updateAllWidgets(context)
                Toast.makeText(context, "Next: ${TAB_NAMES[newTab]}", Toast.LENGTH_SHORT).show()
            }
            ACTION_SETTINGS -> {
                Toast.makeText(context, "Settings clicked", Toast.LENGTH_SHORT).show()
            }
            ACTION_CLOCK_IN_OUT -> {
                Toast.makeText(context, "Clock in/out button pressed!", Toast.LENGTH_SHORT).show()
                try {
                    // Forward to MainActivity to handle in Flutter
                    val flutterIntent = Intent(context, MainActivity::class.java)
                    flutterIntent.action = ACTION_CLOCK_IN_OUT
                    flutterIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(flutterIntent)
                    Toast.makeText(context, "Clock in/out action sent to app", Toast.LENGTH_SHORT).show()
                } catch (e: Exception) {
                    Log.e(TAG, "[home_widget] ❌ Error forwarding clock in/out action: ${e.message}", e)
                    Toast.makeText(context, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
            ACTION_TEST -> {
                Toast.makeText(context, "Test button works!", Toast.LENGTH_LONG).show()
            }
        }
    }
    
    private fun getCurrentTab(context: Context): Int {
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        return prefs.getInt("current_tab", TAB_HOME_SCREEN)
    }
    
    private fun setCurrentTab(context: Context, tab: Int) {
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().putInt("current_tab", tab).apply()
    }
    
    private fun updatePageTitle(views: RemoteViews, currentTab: Int) {
        val title = TAB_NAMES[currentTab]
        views.setTextViewText(R.id.tv_page_title, title)
    }
    
    private fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, MyHomeWidgetProvider::class.java))
        if (appWidgetIds.isNotEmpty()) {
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
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
    
    private fun showHomeScreenContent(context: Context, views: RemoteViews) {
        // Show clock in/out time labels
        updateClockTimeLabels(context, views)
        
        // Show the clock in/out button
        views.setViewVisibility(R.id.tv_clock_in_time, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.tv_clock_out_time, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.btn_clock_in_out, android.view.View.VISIBLE)
    }
    
    private fun showEmptyTabContent(views: RemoteViews) {
        // Hide clock in/out time labels and button
        views.setViewVisibility(R.id.tv_clock_in_time, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_clock_out_time, android.view.View.GONE)
        views.setViewVisibility(R.id.btn_clock_in_out, android.view.View.GONE)
    }
} 