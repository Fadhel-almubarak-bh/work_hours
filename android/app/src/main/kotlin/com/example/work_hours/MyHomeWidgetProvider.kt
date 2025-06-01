package com.example.work_hours

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.example.work_hours.HomeWidgetPlugin

class MyHomeWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "MyHomeWidgetProvider"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_CURRENT_PAGE = "widget_current_page"
        private const val KEY_TRANSPARENCY = "widget_transparency"
        private const val KEY_THEME = "widget_theme"
        private const val KEY_PAGE = "widget_page"
        private const val PAGE_MAIN = 0
        private const val PAGE_SUMMARY = 1
        private const val PAGE_SETTINGS = 2
        private const val TRANSPARENCY_STEP = 10
        private const val MAX_NAVIGATION_PAGE = PAGE_SUMMARY  // Maximum page for next/previous navigation

        fun exitSettingsMode(context: Context) {
            try {
                Log.d(TAG, "Exiting widget settings mode")
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putInt(KEY_PAGE, PAGE_MAIN).apply()
                
                // Force widget update
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, MyHomeWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                
                val intent = Intent(context, MyHomeWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                }
                context.sendBroadcast(intent)
                
                Log.d(TAG, "Widget settings mode exited successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error exiting widget settings mode: ${e.message}", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "Updating widgets: ${appWidgetIds.joinToString()}")
        
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Get current settings
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currentPage = prefs.getInt(KEY_PAGE, PAGE_MAIN)
            val transparency = prefs.getInt(KEY_TRANSPARENCY, 100)
            val currentTheme = prefs.getString(KEY_THEME, "black") ?: "black"
            
            // Apply theme
            val themeColor = when (currentTheme) {
                "blue" -> Color.parseColor("#1A237E")
                "purple" -> Color.parseColor("#4A148C")
                "dark_gray" -> Color.parseColor("#212121")
                else -> Color.BLACK
            }
            
            // Apply transparency to theme color
            val alpha = (transparency * 255 / 100)
            val colorWithAlpha = Color.argb(alpha, Color.red(themeColor), Color.green(themeColor), Color.blue(themeColor))
            views.setInt(R.id.widget_background, "setBackgroundColor", colorWithAlpha)
            
            // Update theme text
            views.setTextViewText(R.id.widget_theme_value, currentTheme.capitalize())
            
            // Update transparency text
            views.setTextViewText(R.id.widget_transparency_value, "$transparency%")
            
            // Set up click listeners first
            setupClickListeners(context, views, prefs)
            
            // Update widget data based on current page
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                
                // Show/hide appropriate content based on current page
                views.setViewVisibility(R.id.widget_main_content, if (currentPage == PAGE_MAIN) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.widget_summary_content, if (currentPage == PAGE_SUMMARY) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.widget_settings_content, if (currentPage == PAGE_SETTINGS) View.VISIBLE else View.GONE)
                
                // Show/hide navigation buttons and clock button
                views.setViewVisibility(R.id.widget_button_previous, if (currentPage == PAGE_SETTINGS) View.GONE else View.VISIBLE)
                views.setViewVisibility(R.id.widget_button_next, if (currentPage == PAGE_SETTINGS) View.GONE else View.VISIBLE)
                views.setViewVisibility(R.id.widget_button_settings, if (currentPage == PAGE_SETTINGS) View.GONE else View.VISIBLE)
                views.setViewVisibility(R.id.widget_button_back, if (currentPage == PAGE_SETTINGS) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.widget_clock_button, if (currentPage == PAGE_SETTINGS) View.GONE else View.VISIBLE)
                
                when (currentPage) {
                    PAGE_MAIN -> {
                        // Update clock in/out button
                        val clockIn = widgetData.getString("clockIn", null)
                        val clockOut = widgetData.getString("clockOut", null)
                        views.setTextViewText(R.id.widget_clock_button,
                            if (clockIn == null) "Clock In" else if (clockOut == null) "Clock Out" else "Clock In")
                        
                        // Update status information
                        views.setTextViewText(R.id.widget_clock_in_text,
                            if (clockIn != null) "In: $clockIn" else "In: --:--")
                        views.setTextViewText(R.id.widget_clock_out_text,
                            if (clockOut != null) "Out: $clockOut" else "Out: --:--")
                        
                        val duration = widgetData.getString("duration", null)
                        views.setTextViewText(R.id.widget_duration_text,
                            if (duration != null) "Duration: $duration" else "Duration: 0h 0m")
                        
                        val overtime = widgetData.getString("overtime", null)
                        views.setTextViewText(R.id.widget_overtime_text,
                            if (overtime != null) "Overtime: $overtime" else "Overtime: 0h 0m")
                    }
                    PAGE_SUMMARY -> {
                        // Update summary information
                        val monthlyHours = widgetData.getString("monthlyHours", "0h 0m")
                        val monthlyOvertime = widgetData.getString("monthlyOvertime", "0h 0m")
                        val workDays = widgetData.getString("workDays", "0")
                        
                        views.setTextViewText(R.id.widget_monthly_hours, "Monthly Hours: $monthlyHours")
                        views.setTextViewText(R.id.widget_monthly_overtime, "Monthly Overtime: $monthlyOvertime")
                        views.setTextViewText(R.id.widget_work_days, "Work Days: $workDays")
                    }
                    PAGE_SETTINGS -> {
                        // Load transparency controls layout
                        val transparencyViews = RemoteViews(context.packageName, R.layout.widget_transparency_controls)
                        
                        // Set up transparency control click listeners
                        transparencyViews.setOnClickPendingIntent(R.id.transparency_level_0, createPendingIntent(context, "transparency_20", appWidgetId))
                        transparencyViews.setOnClickPendingIntent(R.id.transparency_level_1, createPendingIntent(context, "transparency_40", appWidgetId))
                        transparencyViews.setOnClickPendingIntent(R.id.transparency_level_2, createPendingIntent(context, "transparency_60", appWidgetId))
                        transparencyViews.setOnClickPendingIntent(R.id.transparency_level_3, createPendingIntent(context, "transparency_80", appWidgetId))
                        transparencyViews.setOnClickPendingIntent(R.id.transparency_level_4, createPendingIntent(context, "transparency_100", appWidgetId))
                        transparencyViews.setOnClickPendingIntent(R.id.widget_button_save_settings, createPendingIntent(context, "save_settings", appWidgetId))
                        
                        // Hide the cancel button
                        transparencyViews.setViewVisibility(R.id.widget_button_close_settings, View.GONE)
                        
                        // Replace the settings content with transparency controls
                        views.removeAllViews(R.id.widget_settings_content)
                        views.addView(R.id.widget_settings_content, transparencyViews)
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget data: ${e.message}", e)
            }
            
            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun setupClickListeners(context: Context, views: RemoteViews, prefs: SharedPreferences) {
        Log.d(TAG, "Setting up click listeners")
        
        // Get the app widget ID
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, MyHomeWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
        val appWidgetId = appWidgetIds.firstOrNull() ?: AppWidgetManager.INVALID_APPWIDGET_ID
        
        Log.d(TAG, "Setting up click listeners for widget ID: $appWidgetId")
        
        // Navigation buttons
        views.setOnClickPendingIntent(R.id.widget_button_previous, createPendingIntent(context, "previous", appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_button_next, createPendingIntent(context, "next", appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_button_settings, createPendingIntent(context, "settings", appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_button_back, createPendingIntent(context, "back", appWidgetId))
        
        Log.d(TAG, "Navigation button click listeners set up")
        
        // Theme controls
        views.setOnClickPendingIntent(R.id.widget_theme_previous, createPendingIntent(context, "theme_previous", appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_theme_next, createPendingIntent(context, "theme_next", appWidgetId))
        
        // Transparency controls
        views.setOnClickPendingIntent(R.id.widget_transparency_decrease, createPendingIntent(context, "transparency_decrease", appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_transparency_increase, createPendingIntent(context, "transparency_increase", appWidgetId))
        
        // Clock button
        views.setOnClickPendingIntent(R.id.widget_clock_button, createPendingIntent(context, "clock", appWidgetId))
        
        Log.d(TAG, "All click listeners set up")
    }

    private fun createPendingIntent(context: Context, action: String, appWidgetId: Int): android.app.PendingIntent {
        val intent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        return android.app.PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        Log.d(TAG, "Received intent action: ${intent.action}")
        
        val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            Log.e(TAG, "Invalid app widget ID")
            return
        }
        
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var currentPage = prefs.getInt(KEY_PAGE, PAGE_MAIN)
        var transparency = prefs.getInt(KEY_TRANSPARENCY, 100)
        
        Log.d(TAG, "Current page: $currentPage, Transparency: $transparency")
        
        when (intent.action) {
            "previous" -> {
                if (currentPage > PAGE_MAIN) {
                    prefs.edit().putInt(KEY_PAGE, currentPage - 1).apply()
                    updateWidget(context)
                }
            }
            "next" -> {
                if (currentPage < MAX_NAVIGATION_PAGE) {  // Only allow navigation up to summary page
                    prefs.edit().putInt(KEY_PAGE, currentPage + 1).apply()
                    updateWidget(context)
                }
            }
            "settings" -> {
                Log.d(TAG, "Settings action received")
                prefs.edit().putInt(KEY_PAGE, PAGE_SETTINGS).apply()
                Log.d(TAG, "Updated page to settings")
                updateWidget(context)
                Log.d(TAG, "Widget updated after settings action")
            }
            "back" -> {
                prefs.edit().putInt(KEY_PAGE, PAGE_MAIN).apply()
                updateWidget(context)
            }
            "theme_previous" -> {
                val themes = context.resources.getStringArray(R.array.widget_theme_values)
                val currentTheme = prefs.getString(KEY_THEME, "black") ?: "black"
                val currentIndex = themes.indexOf(currentTheme)
                val newIndex = if (currentIndex > 0) currentIndex - 1 else themes.size - 1
                prefs.edit().putString(KEY_THEME, themes[newIndex]).apply()
                updateWidget(context)
            }
            "theme_next" -> {
                val themes = context.resources.getStringArray(R.array.widget_theme_values)
                val currentTheme = prefs.getString(KEY_THEME, "black") ?: "black"
                val currentIndex = themes.indexOf(currentTheme)
                val newIndex = if (currentIndex < themes.size - 1) currentIndex + 1 else 0
                prefs.edit().putString(KEY_THEME, themes[newIndex]).apply()
                updateWidget(context)
            }
            "transparency_decrease" -> {
                if (transparency > 0) {
                    prefs.edit().putInt(KEY_TRANSPARENCY, transparency - TRANSPARENCY_STEP).apply()
                    updateWidget(context)
                }
            }
            "transparency_increase" -> {
                if (transparency < 100) {
                    prefs.edit().putInt(KEY_TRANSPARENCY, transparency + TRANSPARENCY_STEP).apply()
                    updateWidget(context)
                }
            }
            "clock" -> {
                // Handle clock in/out action
                HomeWidgetPlugin.getData(context)?.let { data ->
                    val isClockedIn = data.getBoolean("isClockedIn", false)
                    val action = if (isClockedIn) "clock_out" else "clock_in"
                    
                    // Save the action to be handled by the app
                    HomeWidgetPlugin.saveData(context, "action", action)
                    Log.d(TAG, "Saved widget action: $action")
                    
                    // Launch the Flutter app
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    launchIntent?.let {
                        it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        it.putExtra("widget_action", action)
                        context.startActivity(it)
                        Log.d(TAG, "Launched app with action: $action")
                    }
                }
            }
            "transparency_20" -> {
                prefs.edit().putInt(KEY_TRANSPARENCY, 20).apply()
                updateWidget(context)
            }
            "transparency_40" -> {
                prefs.edit().putInt(KEY_TRANSPARENCY, 40).apply()
                updateWidget(context)
            }
            "transparency_60" -> {
                prefs.edit().putInt(KEY_TRANSPARENCY, 60).apply()
                updateWidget(context)
            }
            "transparency_80" -> {
                prefs.edit().putInt(KEY_TRANSPARENCY, 80).apply()
                updateWidget(context)
            }
            "transparency_100" -> {
                prefs.edit().putInt(KEY_TRANSPARENCY, 100).apply()
                updateWidget(context)
            }
            "save_settings" -> {
                prefs.edit().putInt(KEY_PAGE, PAGE_MAIN).apply()
                updateWidget(context)
            }
        }
    }

    private fun updateWidget(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, MyHomeWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
        onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d(TAG, "Widget disabled")
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        Log.d(TAG, "Widgets deleted: ${appWidgetIds.joinToString()}")
    }
} 