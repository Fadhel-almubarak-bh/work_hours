package com.example.work_hours

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
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
        private const val ACTION_BACK = "com.example.work_hours.ACTION_BACK"
        private const val ACTION_CLOCK_IN_OUT = "com.example.work_hours.ACTION_CLOCK_IN_OUT"
        private const val ACTION_TEST = "com.example.work_hours.ACTION_TEST"
        private const val ACTION_TRANSPARENCY_CHANGE = "com.example.work_hours.ACTION_TRANSPARENCY_CHANGE"
        private const val ACTION_COLOR_CHANGE = "com.example.work_hours.ACTION_COLOR_CHANGE"
        
        // Tab navigation constants
        private const val TAB_HOME_SCREEN = 0
        private const val TAB_HISTORY = 1
        private const val TAB_SUMMARY = 2
        private const val TAB_SALARY = 3
        private const val TOTAL_TABS = 4
        
        private val TAB_NAMES = arrayOf("Home Screen", "History", "Summary", "Salary")
        
        // Settings constants
        private const val SETTINGS_PAGE = -1
    }
    
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Apply widget settings (transparency and background color)
            applyWidgetSettings(context, views)
            
            // Get current tab from shared preferences
            val currentTab = getCurrentTab(context)
            
            // Check if we're in settings mode
            if (isInSettingsMode(context)) {
                // Show only settings page
                showSettingsPage(context, views)
                // Hide home screen content
                views.setViewVisibility(R.id.home_screen_content, android.view.View.GONE)
            } else {
                // Always hide settings content when not in settings mode
                views.setViewVisibility(R.id.settings_content, android.view.View.GONE)
                // Update page title
                updatePageTitle(views, currentTab)
                
                // Show different content based on current tab
                when (currentTab) {
                    TAB_HOME_SCREEN -> {
                        // Ensure home screen content is visible
                        views.setViewVisibility(R.id.home_screen_content, android.view.View.VISIBLE)
                        showHomeScreenContent(context, views)
                    }
                    TAB_HISTORY -> {
                        // Show history content
                        views.setViewVisibility(R.id.home_screen_content, android.view.View.VISIBLE)
                        showHistoryTabContent(context, views)
                    }
                    TAB_SUMMARY -> {
                        // Show summary content
                        views.setViewVisibility(R.id.home_screen_content, android.view.View.VISIBLE)
                        showSummaryTabContent(context, views)
                    }
                    TAB_SALARY -> {
                        // Show salary content
                        views.setViewVisibility(R.id.home_screen_content, android.view.View.VISIBLE)
                        showSalaryTabContent(context, views)
                    }
                    else -> {
                        showEmptyTabContent(views)
                    }
                }
            }

            // Setup navigation buttons
            setupNavigationButtons(context, views, currentTab)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_PREVIOUS -> {
                if (isInSettingsMode(context)) {
                    // In settings, previous button does nothing
                    return
                }
                val currentTab = getCurrentTab(context)
                val newTab = if (currentTab == 0) TOTAL_TABS - 1 else currentTab - 1
                setCurrentTab(context, newTab)
                updateAllWidgets(context)
            }
            ACTION_NEXT -> {
                if (isInSettingsMode(context)) {
                    // In settings, next button does nothing
                    return
                }
                val currentTab = getCurrentTab(context)
                val newTab = (currentTab + 1) % TOTAL_TABS
                setCurrentTab(context, newTab)
                updateAllWidgets(context)
            }
            ACTION_SETTINGS -> {
                // Toggle settings mode
                setSettingsMode(context, !isInSettingsMode(context))
                updateAllWidgets(context)
            }
            ACTION_CLOCK_IN_OUT -> {
                if (isInSettingsMode(context)) {
                    return
                }
                Toast.makeText(context, "Clock in/out button pressed!", Toast.LENGTH_SHORT).show()
                try {
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
            ACTION_TRANSPARENCY_CHANGE -> {
                val transparency = intent.getIntExtra("transparency", 100)
                setTransparency(context, transparency)
                applyWidgetSettings(context)
                updateAllWidgets(context)
                
                // Update the transparency label if in settings mode
                if (isInSettingsMode(context)) {
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, MyHomeWidgetProvider::class.java))
                    for (appWidgetId in appWidgetIds) {
                        val views = RemoteViews(context.packageName, R.layout.widget_layout)
                        views.setTextViewText(R.id.tv_transparency_label, "Transparency: $transparency%")
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                }
            }
            ACTION_COLOR_CHANGE -> {
                val color = intent.getStringExtra("color") ?: "white"
                setBackgroundColor(context, color)
                applyWidgetSettings(context)
                updateAllWidgets(context)
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

        // Set up clock in/out button click to use HomeWidgetBackgroundReceiver
        val clockInOutIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
            action = "com.example.work_hours.ACTION_CLOCK_IN_OUT"
            data = Uri.parse("myapp://clock_in_out")
        }
        val clockInOutPendingIntent = PendingIntent.getBroadcast(
            context, 100, clockInOutIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_clock_in_out, clockInOutPendingIntent)

        // Show/hide loading label based on _isLoading
        val prefs = HomeWidgetPlugin.getData(context)
        val isLoading = prefs.getBoolean("_isLoading", false)
        if (isLoading) {
            views.setViewVisibility(R.id.tv_loading_label, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.tv_loading_label, android.view.View.GONE)
        }

        // Hide Remaining and Overtime labels/values for home screen
        views.setViewVisibility(R.id.tv_remaining_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_remaining_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_value, android.view.View.GONE)
        
        // Hide earnings labels/values for home screen
        views.setViewVisibility(R.id.tv_today_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_today_earnings_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_value, android.view.View.GONE)
        
        // Hide mini calendar for home screen
        views.setViewVisibility(R.id.mini_calendar_container, android.view.View.GONE)
    }

    private fun showHistoryTabContent(context: Context, views: RemoteViews) {
        // Hide clock in/out time labels and button
        views.setViewVisibility(R.id.tv_clock_in_time, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_clock_out_time, android.view.View.GONE)
        views.setViewVisibility(R.id.btn_clock_in_out, android.view.View.GONE)
        
        // Hide remaining and overtime labels/values
        views.setViewVisibility(R.id.tv_remaining_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_remaining_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_value, android.view.View.GONE)
        
        // Hide earnings labels/values
        views.setViewVisibility(R.id.tv_today_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_today_earnings_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_value, android.view.View.GONE)

        // Show mini calendar
        views.setViewVisibility(R.id.mini_calendar_container, android.view.View.VISIBLE)
        
        // Populate mini calendar
        populateMiniCalendar(context, views)
    }
    
    private fun showSummaryTabContent(context: Context, views: RemoteViews) {
        // Hide clock in/out time labels and button
        views.setViewVisibility(R.id.tv_clock_in_time, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_clock_out_time, android.view.View.GONE)
        views.setViewVisibility(R.id.btn_clock_in_out, android.view.View.GONE)

        // Show Remaining and Overtime labels/values
        views.setViewVisibility(R.id.tv_remaining_label, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.tv_remaining_value, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.tv_overtime_label, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.tv_overtime_value, android.view.View.VISIBLE)

        // Hide earnings labels/values for summary tab
        views.setViewVisibility(R.id.tv_today_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_today_earnings_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_value, android.view.View.GONE)

        // Hide mini calendar for summary tab
        views.setViewVisibility(R.id.mini_calendar_container, android.view.View.GONE)

        try {
            val prefs = HomeWidgetPlugin.getData(context)
            
            val remainingText = prefs.getString("_remainingText", "--h --m")
            val overtimeText = prefs.getString("_overtimeText", "--h --m")
            
            Log.d(TAG, "[home_widget] Retrieved remainingText: '$remainingText'")
            Log.d(TAG, "[home_widget] Retrieved overtimeText: '$overtimeText'")
            
            views.setTextViewText(R.id.tv_remaining_value, remainingText)
            views.setTextViewText(R.id.tv_overtime_value, overtimeText)
        } catch (e: Exception) {
            Log.e(TAG, "[home_widget] Error updating summary tab content: ${e.message}", e)
            views.setTextViewText(R.id.tv_remaining_value, "--h --m")
            views.setTextViewText(R.id.tv_overtime_value, "--h --m")
        }
    }
    
    private fun showSalaryTabContent(context: Context, views: RemoteViews) {
        // Hide clock in/out time labels and button
        views.setViewVisibility(R.id.tv_clock_in_time, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_clock_out_time, android.view.View.GONE)
        views.setViewVisibility(R.id.btn_clock_in_out, android.view.View.GONE)
        
        // Hide remaining and overtime labels/values
        views.setViewVisibility(R.id.tv_remaining_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_remaining_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_value, android.view.View.GONE)

        // Show today's earnings and monthly earnings labels/values
        views.setViewVisibility(R.id.tv_today_earnings_label, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.tv_today_earnings_value, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.tv_monthly_earnings_label, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.tv_monthly_earnings_value, android.view.View.VISIBLE)

        // Hide mini calendar for salary tab
        views.setViewVisibility(R.id.mini_calendar_container, android.view.View.GONE)

        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val todayEarnings = prefs.getString("_todayEarnings", "$0.00")
            val monthlyEarnings = prefs.getString("_monthlyEarnings", "$0.00")
            
            Log.d(TAG, "[home_widget] Retrieved todayEarnings: '$todayEarnings'")
            Log.d(TAG, "[home_widget] Retrieved monthlyEarnings: '$monthlyEarnings'")
            
            views.setTextViewText(R.id.tv_today_earnings_value, todayEarnings)
            views.setTextViewText(R.id.tv_monthly_earnings_value, monthlyEarnings)
        } catch (e: Exception) {
            Log.e(TAG, "[home_widget] Error updating salary tab content: ${e.message}", e)
            views.setTextViewText(R.id.tv_today_earnings_value, "$0.00")
            views.setTextViewText(R.id.tv_monthly_earnings_value, "$0.00")
        }
    }
    
    private fun showEmptyTabContent(views: RemoteViews) {
        // Hide clock in/out time labels and button
        views.setViewVisibility(R.id.tv_clock_in_time, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_clock_out_time, android.view.View.GONE)
        views.setViewVisibility(R.id.btn_clock_in_out, android.view.View.GONE)
        
        // Hide remaining and overtime labels/values
        views.setViewVisibility(R.id.tv_remaining_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_remaining_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_overtime_value, android.view.View.GONE)
        
        // Hide earnings labels/values
        views.setViewVisibility(R.id.tv_today_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_today_earnings_value, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_label, android.view.View.GONE)
        views.setViewVisibility(R.id.tv_monthly_earnings_value, android.view.View.GONE)
        
        // Hide mini calendar
        views.setViewVisibility(R.id.mini_calendar_container, android.view.View.GONE)
    }
    
    private fun setupNavigationButtons(context: Context, views: RemoteViews, currentTab: Int) {
        if (isInSettingsMode(context)) {
            // In settings mode, hide prev/next buttons
            views.setViewVisibility(R.id.btn_previous, android.view.View.GONE)
            views.setViewVisibility(R.id.btn_next, android.view.View.GONE)
            // Settings button toggles settings mode, so keep it enabled
        } else {
            // Normal mode, show prev/next buttons
            views.setViewVisibility(R.id.btn_previous, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.btn_next, android.view.View.VISIBLE)
            // Settings button toggles settings mode, so keep it enabled
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
        }
        // Settings button always toggles settings mode
        val settingsIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_SETTINGS
        }
        val settingsPendingIntent = PendingIntent.getBroadcast(context, 2, settingsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_settings, settingsPendingIntent)
        // Remove back button logic
    }
    
    private fun isInSettingsMode(context: Context): Boolean {
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("settings_mode", false)
    }
    
    private fun setSettingsMode(context: Context, isSettingsMode: Boolean) {
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("settings_mode", isSettingsMode).apply()
    }
    
    private fun setTransparency(context: Context, transparency: Int) {
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().putInt("transparency", transparency).apply()
    }
    
    private fun setBackgroundColor(context: Context, color: String) {
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().putString("backgroundColor", color).apply()
    }
    
    private fun showSettingsPage(context: Context, views: RemoteViews) {
        // Update page title
        views.setTextViewText(R.id.tv_page_title, "Settings")
        
        // Hide home screen content
        views.setViewVisibility(R.id.home_screen_content, android.view.View.GONE)
        
        // Show settings content
        views.setViewVisibility(R.id.settings_content, android.view.View.VISIBLE)
        
        // Get current transparency and background color
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        val transparency = prefs.getInt("transparency", 100)
        val backgroundColor = prefs.getString("backgroundColor", "white") ?: "white"
        
        // Update transparency label to show current value
        views.setTextViewText(R.id.tv_transparency_label, "Transparency: $transparency%")
        
        // Setup transparency and color buttons
        setupTransparencyButtons(context, views)
        setupColorButtons(context, views)
    }
    
    private fun setupTransparencyButtons(context: Context, views: RemoteViews) {
        // 25% transparency button
        val transparency25Intent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_TRANSPARENCY_CHANGE
            putExtra("transparency", 25)
        }
        val transparency25PendingIntent = PendingIntent.getBroadcast(context, 300, transparency25Intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_transparency_25, transparency25PendingIntent)
        
        // 50% transparency button
        val transparency50Intent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_TRANSPARENCY_CHANGE
            putExtra("transparency", 50)
        }
        val transparency50PendingIntent = PendingIntent.getBroadcast(context, 301, transparency50Intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_transparency_50, transparency50PendingIntent)
        
        // 75% transparency button
        val transparency75Intent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_TRANSPARENCY_CHANGE
            putExtra("transparency", 75)
        }
        val transparency75PendingIntent = PendingIntent.getBroadcast(context, 302, transparency75Intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_transparency_75, transparency75PendingIntent)
        
        // 100% transparency button
        val transparency100Intent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_TRANSPARENCY_CHANGE
            putExtra("transparency", 100)
        }
        val transparency100PendingIntent = PendingIntent.getBroadcast(context, 303, transparency100Intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_transparency_100, transparency100PendingIntent)
    }
    
    private fun setupColorButtons(context: Context, views: RemoteViews) {
        // White color button
        val whiteIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_COLOR_CHANGE
            putExtra("color", "white")
        }
        val whitePendingIntent = PendingIntent.getBroadcast(context, 200, whiteIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_color_white, whitePendingIntent)
        
        // Black color button
        val blackIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_COLOR_CHANGE
            putExtra("color", "black")
        }
        val blackPendingIntent = PendingIntent.getBroadcast(context, 201, blackIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_color_black, blackPendingIntent)
        
        // Blue color button
        val blueIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_COLOR_CHANGE
            putExtra("color", "blue")
        }
        val bluePendingIntent = PendingIntent.getBroadcast(context, 202, blueIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_color_blue, bluePendingIntent)
        
        // Green color button
        val greenIntent = Intent(context, MyHomeWidgetProvider::class.java).apply {
            action = ACTION_COLOR_CHANGE
            putExtra("color", "green")
        }
        val greenPendingIntent = PendingIntent.getBroadcast(context, 203, greenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.btn_color_green, greenPendingIntent)
    }

    private fun applyWidgetSettings(context: Context, views: RemoteViews) {
        // Get current background color and transparency
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        val backgroundColor = prefs.getString("backgroundColor", "white") ?: "white"
        val transparency = prefs.getInt("transparency", 100)
        
        // Calculate alpha value (0-255) from transparency percentage
        val alpha = (transparency * 255 / 100).coerceIn(0, 255)
        
        // Apply background color with transparency to the entire widget
        val baseColor = when (backgroundColor) {
            "white" -> Color.WHITE
            "black" -> Color.BLACK
            "blue" -> Color.parseColor("#2196F3") // Material Blue
            "green" -> Color.parseColor("#4CAF50") // Material Green
            else -> Color.WHITE
        }
        
        // Create semi-transparent color by combining alpha with base color
        val transparentColor = Color.argb(alpha, Color.red(baseColor), Color.green(baseColor), Color.blue(baseColor))
        
        // Apply background color to the root container (entire widget)
        views.setInt(R.id.widget_root_container, "setBackgroundColor", transparentColor)
        
        // Adjust text colors based on background for better visibility
        val textColor = when (backgroundColor) {
            "black" -> Color.WHITE
            "blue" -> Color.WHITE
            "green" -> Color.WHITE
            else -> Color.BLACK // white background
        }
        
        // Update text colors
        views.setInt(R.id.tv_page_title, "setTextColor", textColor)
        views.setInt(R.id.tv_clock_in_time, "setTextColor", textColor)
        views.setInt(R.id.tv_clock_out_time, "setTextColor", textColor)
        views.setInt(R.id.tv_remaining_label, "setTextColor", textColor)
        views.setInt(R.id.tv_remaining_value, "setTextColor", textColor)
        views.setInt(R.id.tv_overtime_label, "setTextColor", textColor)
        views.setInt(R.id.tv_overtime_value, "setTextColor", textColor)
        views.setInt(R.id.tv_today_earnings_label, "setTextColor", textColor)
        views.setInt(R.id.tv_today_earnings_value, "setTextColor", textColor)
        views.setInt(R.id.tv_monthly_earnings_label, "setTextColor", textColor)
        views.setInt(R.id.tv_monthly_earnings_value, "setTextColor", textColor)
        views.setInt(R.id.tv_calendar_header, "setTextColor", textColor)
        
        // Update calendar day text colors
        val dayIds = arrayOf(
            R.id.day_1, R.id.day_2, R.id.day_3, R.id.day_4, R.id.day_5, R.id.day_6, R.id.day_7,
            R.id.day_8, R.id.day_9, R.id.day_10, R.id.day_11, R.id.day_12, R.id.day_13, R.id.day_14,
            R.id.day_15, R.id.day_16, R.id.day_17, R.id.day_18, R.id.day_19, R.id.day_20, R.id.day_21,
            R.id.day_22, R.id.day_23, R.id.day_24, R.id.day_25, R.id.day_26, R.id.day_27, R.id.day_28,
            R.id.day_29, R.id.day_30, R.id.day_31, R.id.day_32, R.id.day_33, R.id.day_34, R.id.day_35,
            R.id.day_36, R.id.day_37, R.id.day_38, R.id.day_39, R.id.day_40, R.id.day_41, R.id.day_42
        )
        
        for (dayId in dayIds) {
            views.setInt(dayId, "setTextColor", textColor)
        }
    }
    
    private fun applyWidgetSettings(context: Context) {
        // Trigger widget update to apply new settings
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, MyHomeWidgetProvider::class.java))
        if (appWidgetIds.isNotEmpty()) {
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }
    
    private fun populateMiniCalendar(context: Context, views: RemoteViews) {
        try {
            val now = Calendar.getInstance()
            val currentMonth = now.get(Calendar.MONTH)
            val currentYear = now.get(Calendar.YEAR)
            
            // Set calendar header
            val monthNames = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
            val headerText = "${monthNames[currentMonth]} $currentYear"
            views.setTextViewText(R.id.tv_calendar_header, headerText)
            
            // Get calendar data from widget
            val prefs = HomeWidgetPlugin.getData(context)
            val calendarData = prefs.getString("_calendarData", "") ?: ""
            
            if (calendarData.isNotEmpty()) {
                // Parse calendar data and populate days
                val days = calendarData.split(",")
                populateCalendarDays(context, views, days)
            } else {
                // Create empty calendar if no data
                createEmptyCalendar(views, now)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "[home_widget] Error populating mini calendar: ${e.message}", e)
            createEmptyCalendar(views, Calendar.getInstance())
        }
    }
    
    private fun populateCalendarDays(context: Context, views: RemoteViews, days: List<String>) {
        val dayIds = arrayOf(
            R.id.day_1, R.id.day_2, R.id.day_3, R.id.day_4, R.id.day_5, R.id.day_6, R.id.day_7,
            R.id.day_8, R.id.day_9, R.id.day_10, R.id.day_11, R.id.day_12, R.id.day_13, R.id.day_14,
            R.id.day_15, R.id.day_16, R.id.day_17, R.id.day_18, R.id.day_19, R.id.day_20, R.id.day_21,
            R.id.day_22, R.id.day_23, R.id.day_24, R.id.day_25, R.id.day_26, R.id.day_27, R.id.day_28,
            R.id.day_29, R.id.day_30, R.id.day_31, R.id.day_32, R.id.day_33, R.id.day_34, R.id.day_35,
            R.id.day_36, R.id.day_37, R.id.day_38, R.id.day_39, R.id.day_40, R.id.day_41, R.id.day_42
        )
        // Get background color from shared preferences
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        val backgroundColor = prefs.getString("backgroundColor", "white") ?: "white"
        val isDarkBg = backgroundColor == "black" || backgroundColor == "blue" || backgroundColor == "green"
        for (i in 0 until minOf(days.size, dayIds.size)) {
            val dayData = days[i]
            val (dayView, status) = createEnhancedDayViewWithStatus(dayData)
            views.setTextViewText(dayIds[i], dayView)
            // Set color based on status and background
            val textColor = when (status) {
                "completed" -> if (isDarkBg) android.graphics.Color.parseColor("#A5D6A7") /* light green */ else android.graphics.Color.parseColor("#388E3C") /* dark green */
                "inprogress" -> if (isDarkBg) android.graphics.Color.parseColor("#FFD180") /* light orange */ else android.graphics.Color.parseColor("#FFA500") /* dark orange */
                "offday" -> if (isDarkBg) android.graphics.Color.parseColor("#90CAF9") /* light blue */ else android.graphics.Color.parseColor("#1976D2") /* dark blue */
                else -> if (isDarkBg) android.graphics.Color.WHITE else android.graphics.Color.BLACK
            }
            views.setInt(dayIds[i], "setTextColor", textColor)
        }
    }

    // Helper to get the default text color (black or white) for empty days
    private fun getDefaultCalendarTextColor(views: RemoteViews): Int {
        // This is a fallback; actual dynamic color is set in applyWidgetSettings
        // Use black as a safe default
        return android.graphics.Color.BLACK
    }

    // Returns Pair<displayText, status>
    private fun createEnhancedDayViewWithStatus(dayData: String): Pair<String, String> {
        val parts = dayData.split(":")
        if (parts.size >= 2) {
            val day = parts[0]
            val status = parts[1]
            val time = if (parts.size >= 3) parts[2] else ""
            val (secondLine, emoji) = when (status) {
                "completed" -> if (time.isNotEmpty()) Pair(time, "✅") else Pair("✓", "✅")
                "inprogress" -> if (time.isNotEmpty()) Pair(time, "🕒") else Pair("○", "🕒")
                "offday" -> Pair("OFF", "💤")
                else -> Pair(" ", "")
            }
            return Pair("$day\n$secondLine $emoji".trimEnd(), status)
        }
        // If data is malformed, still reserve two lines
        return Pair(dayData.split(":")[0] + "\n ", "empty")
    }
    
    private fun createEmptyCalendar(views: RemoteViews, calendar: Calendar) {
        // Create a simple empty calendar structure
        Log.d(TAG, "[home_widget] Creating empty calendar for ${calendar.get(Calendar.MONTH)}/${calendar.get(Calendar.YEAR)}")
        
        // Clear all day views
        val dayIds = arrayOf(
            R.id.day_1, R.id.day_2, R.id.day_3, R.id.day_4, R.id.day_5, R.id.day_6, R.id.day_7,
            R.id.day_8, R.id.day_9, R.id.day_10, R.id.day_11, R.id.day_12, R.id.day_13, R.id.day_14,
            R.id.day_15, R.id.day_16, R.id.day_17, R.id.day_18, R.id.day_19, R.id.day_20, R.id.day_21,
            R.id.day_22, R.id.day_23, R.id.day_24, R.id.day_25, R.id.day_26, R.id.day_27, R.id.day_28,
            R.id.day_29, R.id.day_30, R.id.day_31, R.id.day_32, R.id.day_33, R.id.day_34, R.id.day_35,
            R.id.day_36, R.id.day_37, R.id.day_38, R.id.day_39, R.id.day_40, R.id.day_41, R.id.day_42
        )
        
        for (dayId in dayIds) {
            views.setTextViewText(dayId, "")
        }
    }
} 