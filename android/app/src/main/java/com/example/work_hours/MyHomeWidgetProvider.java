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
    private static final String DEBUG_TAG = "WIDGET_DEBUG";
    private static final String PREFS_NAME = "HomeWidgetPreferences";
    private static final String KEY_TRANSPARENCY = "widget_transparency";
    private static final String KEY_WIDGET_PAGE = "_widgetPage";
    private static final String KEY_SETTINGS_MODE = "widget_settings_mode";
    
    // Define transparency levels
    private static final int[] TRANSPARENCY_LEVELS = {50, 100, 150, 200, 255};

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(DEBUG_TAG, "Native onUpdate called without SharedPreferences");
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        onUpdate(context, appWidgetManager, appWidgetIds, prefs);
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds, SharedPreferences prefs) {
        try {
            Log.d(DEBUG_TAG, "Native onUpdate called with appWidgetIds: " + java.util.Arrays.toString(appWidgetIds));
            
            // Check if the settings mode is stuck for too long (over 30 minutes)
            long lastSettingsTime = prefs.getLong("last_settings_time", 0);
            long currentTime = System.currentTimeMillis();
            
            // If no timestamp was saved, set it now to prevent false stuck detection
            if (prefs.getBoolean(KEY_SETTINGS_MODE, false) && lastSettingsTime == 0) {
                SharedPreferences.Editor editor = prefs.edit();
                editor.putLong("last_settings_time", currentTime);
                editor.apply();
                Log.d(DEBUG_TAG, "Initialized settings mode timestamp");
            }
            
            // Now check if it's stuck (only if we have a valid timestamp)
            boolean isSettingsModeStuck = lastSettingsTime > 0 && 
                                         (currentTime - lastSettingsTime > 30 * 60 * 1000); // 30 minutes
            
            if (prefs.getBoolean(KEY_SETTINGS_MODE, false) && isSettingsModeStuck) {
                Log.d(DEBUG_TAG, "Settings mode appears to be stuck (inactive for 30+ minutes), resetting it");
                SharedPreferences.Editor editor = prefs.edit();
                editor.putBoolean(KEY_SETTINGS_MODE, false);
                editor.apply();
            } else if (prefs.getBoolean(KEY_SETTINGS_MODE, false)) {
                // Log current settings mode status but don't update the timestamp here
                // (it should be updated when entering settings mode or changing settings)
                Log.d(DEBUG_TAG, "Widget in settings mode, last activity: " + 
                      (currentTime - lastSettingsTime)/1000 + " seconds ago");
            }
            
            for (int appWidgetId : appWidgetIds) {
                // Check if we're in settings mode
                boolean isSettingsMode = prefs.getBoolean(KEY_SETTINGS_MODE, false);
                
                RemoteViews views;
                if (isSettingsMode) {
                    Log.d(DEBUG_TAG, "Widget in settings mode for id: " + appWidgetId);
                    // Show transparency settings view
                    views = createTransparencySettingsView(context, prefs, appWidgetId);
                } else {
                    // Get current page (0 = main, 1 = overtime)
                    // First check the HomeWidget data (flutter data)
                    int currentPage = 0; // Default to main page
                    
                    // Try to get the value from SharedPreferences
                    try {
                        currentPage = prefs.getInt(KEY_WIDGET_PAGE, 0);
                        Log.d(DEBUG_TAG, "Read widget page from SharedPreferences: " + currentPage);
                    } catch (ClassCastException e) {
                        // Handle case where data was stored as a different type
                        Log.e(DEBUG_TAG, "Error reading widget page, defaulting to 0. Error: " + e.getMessage());
                        
                        // Fix the type by storing a correct int value
                        SharedPreferences.Editor editor = prefs.edit();
                        editor.putInt(KEY_WIDGET_PAGE, 0);
                        editor.apply();
                        Log.d(DEBUG_TAG, "Fixed widget page type by storing correct int value");
                    }
                    
                    // Ensure page is within valid range
                    if (currentPage < 0 || currentPage > 1) {
                        Log.d(DEBUG_TAG, "Widget page out of range: " + currentPage + ", resetting to 0");
                        currentPage = 0;
                        
                        // Fix the value in SharedPreferences
                        SharedPreferences.Editor editor = prefs.edit();
                        editor.putInt(KEY_WIDGET_PAGE, 0);
                        editor.apply();
                        Log.d(DEBUG_TAG, "Stored corrected page value in SharedPreferences");
                    }
                    
                    Log.d(DEBUG_TAG, "Widget page for id " + appWidgetId + ": " + currentPage);
                    
                    // Create views based on the current page
                    if (currentPage == 1) {
                        // Overtime page
                        Log.d(DEBUG_TAG, "Creating overtime page for widget id: " + appWidgetId);
                        views = createOvertimePage(context, prefs, appWidgetId);
                    } else {
                        // Main page (default)
                        Log.d(DEBUG_TAG, "Creating main page for widget id: " + appWidgetId);
                        views = createMainPage(context, prefs, appWidgetId);
                    }
                    
                    // Set navigation button click listeners
                    setupNavigationButtons(context, views, appWidgetId, currentPage);
                }
                
                // Update the widget
                Log.d(DEBUG_TAG, "Updating widget with AppWidgetManager for id: " + appWidgetId);
                appWidgetManager.updateAppWidget(appWidgetId, views);
                Log.d(DEBUG_TAG, "✅ Widget updated successfully for appWidgetId: " + appWidgetId);
            }
        } catch (Exception e) {
            Log.e(DEBUG_TAG, "❌ Error updating widget: " + e.getMessage(), e);
        }
    }
    
    /**
     * Create a view for transparency settings
     */
    private RemoteViews createTransparencySettingsView(Context context, SharedPreferences prefs, int appWidgetId) {
        Log.d(DEBUG_TAG, "Creating transparency settings view for widget id: " + appWidgetId);
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_transparency_controls);
        
        int currentTransparency = prefs.getInt(KEY_TRANSPARENCY, 255);
        int transparency = prefs.getInt(KEY_TRANSPARENCY, 255); // Default fully opaque
        Log.d(DEBUG_TAG, "Current transparency setting: " + currentTransparency);
        
        // Apply transparent background to root
        int backgroundColor = Color.argb(transparency, 0, 0, 0); // black with alpha
        views.setInt(R.id.widget_transparency_root, "setBackgroundColor", backgroundColor);
        
        // Highlight the appropriate transparency button
        int selectedLevel = -1;
        for (int i = 0; i < TRANSPARENCY_LEVELS.length; i++) {
            if (currentTransparency <= TRANSPARENCY_LEVELS[i]) {
                selectedLevel = i;
                break;
            }
        }
        if (selectedLevel == -1) selectedLevel = TRANSPARENCY_LEVELS.length - 1;
        Log.d(DEBUG_TAG, "Selected transparency level: " + selectedLevel + " (value: " + 
              (selectedLevel >= 0 && selectedLevel < TRANSPARENCY_LEVELS.length ? TRANSPARENCY_LEVELS[selectedLevel] : "unknown") + ")");
        
        // Set click handlers for transparency level buttons
        for (int i = 0; i < TRANSPARENCY_LEVELS.length; i++) {
            int level = TRANSPARENCY_LEVELS[i];
            int buttonId = getTransparencyButtonId(i);
            
            // Highlight the selected button using background color instead of alpha
            if (i == selectedLevel) {
                // Selected button gets a green background
                views.setInt(buttonId, "setBackgroundColor", Color.parseColor("#4CAF50"));
                views.setTextColor(buttonId, Color.WHITE);
            } else {
                // Non-selected buttons get a light gray background
                views.setInt(buttonId, "setBackgroundColor", Color.parseColor("#DDDDDD"));
                views.setTextColor(buttonId, Color.BLACK);
            }
            
            // Set up click handler
            Intent intent = new Intent(context, MyHomeWidgetProvider.class);
            intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
            intent.putExtra("SET_TRANSPARENCY", level);
            intent.setData(Uri.parse("homewidget://transparency_" + i + "_" + System.currentTimeMillis()));
            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                context, 200 + i, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(buttonId, pendingIntent);
        }
        
        // Set up close button
        Intent closeIntent = new Intent(context, MyHomeWidgetProvider.class);
        closeIntent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        closeIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
        closeIntent.putExtra("EXIT_SETTINGS", true);
        closeIntent.setData(Uri.parse("homewidget://close_settings_" + System.currentTimeMillis()));
        PendingIntent closePendingIntent = PendingIntent.getBroadcast(
            context, 300, closeIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_button_close_settings, closePendingIntent);
        
        // Set up save button (same as close)
        views.setOnClickPendingIntent(R.id.widget_button_save_settings, closePendingIntent);
        
        return views;
    }
    
    private int getTransparencyButtonId(int index) {
        switch (index) {
            case 0: return R.id.transparency_level_0;
            case 1: return R.id.transparency_level_1;
            case 2: return R.id.transparency_level_2;
            case 3: return R.id.transparency_level_3;
            case 4: return R.id.transparency_level_4;
            default: return R.id.transparency_level_2; // Middle by default
        }
    }
    
    private RemoteViews createMainPage(Context context, SharedPreferences prefs, int appWidgetId) {
        Log.d(DEBUG_TAG, "Creating main page for widget id: " + appWidgetId);
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.home_widget_layout);
        
        String clockInText = prefs.getString("_clockInText", "In: --:--");
        String clockOutText = prefs.getString("_clockOutText", "Out: --:--");
        String overtimeText = prefs.getString("_overtimeText", "Overtime: 0h 0m");
        int transparency = prefs.getInt(KEY_TRANSPARENCY, 255); // Default fully opaque

        // Determine login state from clock in/out text
        boolean hasClockIn = !clockInText.equals("In: --:--");
        boolean hasClockOut = !clockOutText.equals("Out: --:--") && !clockOutText.equals("Out: Pending");
        boolean isLoggedIn = hasClockIn && !hasClockOut;

        Log.d(DEBUG_TAG, "Main page data - Clock In: " + clockInText);
        Log.d(DEBUG_TAG, "Main page data - Clock Out: " + clockOutText);
        Log.d(DEBUG_TAG, "Main page data - Overtime: " + overtimeText);
        Log.d(DEBUG_TAG, "Login state - Has Clock In: " + hasClockIn + ", Has Clock Out: " + hasClockOut + ", Is Logged In: " + isLoggedIn);

        views.setTextViewText(R.id.widget_clock_in, clockInText);
        views.setTextViewText(R.id.widget_clock_out, clockOutText);
        views.setTextViewText(R.id.widget_overtime, overtimeText);

        // Set button visibility based on login state
        views.setViewVisibility(R.id.widget_button_clock_in, isLoggedIn ? View.GONE : View.VISIBLE);
        views.setViewVisibility(R.id.widget_button_clock_out, isLoggedIn ? View.VISIBLE : View.GONE);

        // Apply transparent background using argb (safe for RemoteViews)
        int backgroundColor = Color.argb(transparency, 0, 0, 0); // black with alpha
        views.setInt(R.id.widget_root, "setBackgroundColor", backgroundColor);

        // Set click listeners for clock in/out buttons
        try {
            Log.d(DEBUG_TAG, "Setting up clock in/out button click listeners");
            
            // Create explicit intent for Clock In action
            Intent clockInIntent = new Intent(context, com.example.work_hours.MainActivity.class);
            clockInIntent.setAction("CLOCK_IN");
            // Add flags to create a new task for the activity
            clockInIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            // Use unique data URI to prevent intent reuse
            clockInIntent.setData(Uri.parse("workhours://clock_in/" + System.currentTimeMillis()));
            
            PendingIntent clockInPendingIntent = PendingIntent.getActivity(
                context, 0, clockInIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(R.id.widget_button_clock_in, clockInPendingIntent);
            Log.d(DEBUG_TAG, "Clock IN button set up with action: " + clockInIntent.getAction());

            // Create explicit intent for Clock Out action 
            Intent clockOutIntent = new Intent(context, com.example.work_hours.MainActivity.class);
            clockOutIntent.setAction("CLOCK_OUT");
            // Add flags to create a new task for the activity
            clockOutIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            // Use unique data URI to prevent intent reuse
            clockOutIntent.setData(Uri.parse("workhours://clock_out/" + System.currentTimeMillis()));
            
            PendingIntent clockOutPendingIntent = PendingIntent.getActivity(
                context, 1, clockOutIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(R.id.widget_button_clock_out, clockOutPendingIntent);
            Log.d(DEBUG_TAG, "Clock OUT button set up with action: " + clockOutIntent.getAction());
        } catch (Exception e) {
            Log.e(DEBUG_TAG, "Error setting up clock in/out buttons: " + e.getMessage(), e);
        }
        
        return views;
    }
    
    private RemoteViews createOvertimePage(Context context, SharedPreferences prefs, int appWidgetId) {
        Log.d(DEBUG_TAG, "Creating overtime page for widget id: " + appWidgetId);
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.home_widget_layout_overtime);
        
        // Get overtime data
        String currentMonthName = prefs.getString("_currentMonthName", "Current Month");
        String overtimeText = prefs.getString("_overtimeText", "Overtime: 0h 0m");
        String expectedVsActual = prefs.getString("_expectedVsActual", "Expected: 0h / Actual: 0h");
        String workDaysText = prefs.getString("_workDaysText", "Work Days: 0");
        String offDaysText = prefs.getString("_offDaysText", "Off Days: 0");
        String statusMessage = prefs.getString("_statusMessage", "");
        int overtimeColor = prefs.getInt("_overtimeColor", 1); // Default to green (1)
        int transparency = prefs.getInt(KEY_TRANSPARENCY, 255); // Default fully opaque
        
        Log.d(DEBUG_TAG, "Overtime page data - Month: " + currentMonthName);
        Log.d(DEBUG_TAG, "Overtime page data - Overtime: " + overtimeText);
        Log.d(DEBUG_TAG, "Overtime page data - Expected vs Actual: " + expectedVsActual);
        Log.d(DEBUG_TAG, "Overtime page data - Status Message: " + statusMessage);
        Log.d(DEBUG_TAG, "Overtime page data - Color: " + (overtimeColor == 1 ? "green" : "red"));
        
        // Set the text values
        views.setTextViewText(R.id.widget_current_month, currentMonthName);
        views.setTextViewText(R.id.widget_overtime, overtimeText);
        views.setTextViewText(R.id.widget_expected_vs_actual, expectedVsActual);
        views.setTextViewText(R.id.widget_work_days, workDaysText);
        views.setTextViewText(R.id.widget_off_days, offDaysText);
        views.setTextViewText(R.id.widget_status_message, statusMessage);
        
        // Set status message color based on overtime
        int textColor = overtimeColor == 1 ? Color.parseColor("#4CAF50") : Color.parseColor("#F44336");
        views.setTextColor(R.id.widget_status_message, textColor);
        
        // Apply transparent background using argb (safe for RemoteViews)
        int backgroundColor = Color.argb(transparency, 0, 0, 0); // black with alpha
        views.setInt(R.id.widget_root, "setBackgroundColor", backgroundColor);
        
        // Set up click listener for view summary button
        try {
            Log.d(DEBUG_TAG, "Setting up summary button click listener");
            Intent summaryIntent = new Intent(context, com.example.work_hours.MainActivity.class);
            summaryIntent.putExtra("initialTab", 2); // Assuming 2 is the index for the Summary tab
            PendingIntent summaryPendingIntent = PendingIntent.getActivity(
                context, 3, summaryIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(R.id.widget_button_view_summary, summaryPendingIntent);
        } catch (Exception e) {
            Log.e(DEBUG_TAG, "Error setting up summary button: " + e.getMessage(), e);
        }
        
        return views;
    }
    
    private void setupNavigationButtons(Context context, RemoteViews views, int appWidgetId, int currentPage) {
        Log.d(DEBUG_TAG, "Setting up navigation buttons for widget id: " + appWidgetId + ", current page: " + currentPage);
        
        // Set Settings button click handler - now opens transparency settings directly in widget
        Intent settingsIntent = new Intent(context, MyHomeWidgetProvider.class);
        settingsIntent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        settingsIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
        settingsIntent.putExtra("ENTER_SETTINGS", true);
        settingsIntent.setData(Uri.parse("homewidget://enter_settings_" + System.currentTimeMillis()));
        PendingIntent settingsPendingIntent = PendingIntent.getBroadcast(
            context, 100, settingsIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_button_settings, settingsPendingIntent);
        
        // Set Previous button click handler
        Intent prevIntent = new Intent(context, MyHomeWidgetProvider.class);
        prevIntent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        prevIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
        prevIntent.putExtra("PAGE_DIRECTION", "prev");
        prevIntent.setData(Uri.parse("homewidget://prev_page_" + System.currentTimeMillis()));
        PendingIntent prevPendingIntent = PendingIntent.getBroadcast(
            context, 10, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_button_previous, prevPendingIntent);
        
        // Set Next button click handler
        Intent nextIntent = new Intent(context, MyHomeWidgetProvider.class);
        nextIntent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        nextIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, new int[]{appWidgetId});
        nextIntent.putExtra("PAGE_DIRECTION", "next");
        nextIntent.setData(Uri.parse("homewidget://next_page_" + System.currentTimeMillis()));
        PendingIntent nextPendingIntent = PendingIntent.getBroadcast(
            context, 11, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_button_next, nextPendingIntent);
        
        Log.d(DEBUG_TAG, "Navigation buttons set up successfully");
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(DEBUG_TAG, "onReceive called with action: " + intent.getAction());
        super.onReceive(context, intent);
        
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            boolean needsUpdate = false;
            
            // Handle entering settings mode
            if (intent.hasExtra("ENTER_SETTINGS")) {
                Log.d(DEBUG_TAG, "Entering settings mode");
                
                // Set settings mode flag and save the current time to prevent auto-exit
                editor.putBoolean(KEY_SETTINGS_MODE, true);
                editor.putLong("last_settings_time", System.currentTimeMillis());
                editor.apply();
                
                needsUpdate = true;
            }
            
            // Handle exiting settings mode
            else if (intent.hasExtra("EXIT_SETTINGS")) {
                Log.d(DEBUG_TAG, "Exiting settings mode");
                editor.putBoolean(KEY_SETTINGS_MODE, false);
                editor.apply();
                needsUpdate = true;
            }
            
            // Handle transparency level change
            else if (intent.hasExtra("SET_TRANSPARENCY")) {
                int level = intent.getIntExtra("SET_TRANSPARENCY", 255);
                Log.d(DEBUG_TAG, "Setting transparency to " + level);
                editor.putInt(KEY_TRANSPARENCY, level);
                
                // Update the last settings time to prevent auto-exit
                editor.putLong("last_settings_time", System.currentTimeMillis());
                editor.apply();
                
                needsUpdate = true;
            }
            
            // Handle page navigation
            else if (intent.hasExtra("PAGE_DIRECTION")) {
                String direction = intent.getStringExtra("PAGE_DIRECTION");
                Log.d(DEBUG_TAG, "Received page navigation: " + direction);
                
                // Safely get current page with default value
                int currentPage = 0;
                try {
                    currentPage = prefs.getInt(KEY_WIDGET_PAGE, 0);
                    Log.d(DEBUG_TAG, "Current page before navigation: " + currentPage);
                } catch (ClassCastException e) {
                    // Handle case where data was stored as a different type
                    Log.e(DEBUG_TAG, "Error reading widget page, defaulting to 0: " + e.getMessage());
                }
                
                int totalPages = 2; // We have 2 pages: main and overtime
                
                // Calculate the new page based on direction
                int newPage;
                if ("next".equals(direction)) {
                    newPage = (currentPage + 1) % totalPages;
                } else {
                    newPage = (currentPage - 1 + totalPages) % totalPages;
                }
                
                Log.d(DEBUG_TAG, "Changing page from " + currentPage + " to " + newPage);
                
                // Save the new page
                editor.putInt(KEY_WIDGET_PAGE, newPage);
                editor.apply();
                needsUpdate = true;
            }
            
            // Update the widget if needed
            if (needsUpdate) {
                Log.d(DEBUG_TAG, "Widget needs update, triggering updateAppWidget");
                AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
                ComponentName componentName = new ComponentName(context, MyHomeWidgetProvider.class);
                int[] appWidgetIds = appWidgetManager.getAppWidgetIds(componentName);
                Log.d(DEBUG_TAG, "Found widget IDs: " + java.util.Arrays.toString(appWidgetIds));
                this.onUpdate(context, appWidgetManager, appWidgetIds, prefs);
            }
        } catch (Exception e) {
            Log.e(DEBUG_TAG, "❌ Error in onReceive: " + e.getMessage(), e);
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

    public static void updateWidget(Context context) {
        Log.d(DEBUG_TAG, "🔄 updateWidget() static method called");
        try {
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            ComponentName componentName = new ComponentName(context, MyHomeWidgetProvider.class);
            int[] appWidgetIds = appWidgetManager.getAppWidgetIds(componentName);
            Log.d(DEBUG_TAG, "Found " + appWidgetIds.length + " widget IDs: " + java.util.Arrays.toString(appWidgetIds));

            if (appWidgetIds.length > 0) {
                SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                MyHomeWidgetProvider provider = new MyHomeWidgetProvider();
                provider.onUpdate(context, appWidgetManager, appWidgetIds, prefs);
                Log.d(DEBUG_TAG, "Widget update triggered successfully");
            } else {
                Log.d(DEBUG_TAG, "No widgets found to update");
            }
        } catch (Exception e) {
            Log.e(DEBUG_TAG, "Error in static updateWidget method: " + e.getMessage(), e);
        }
    }
    
    /**
     * Exit settings mode for all widgets
     */
    public static void exitSettingsMode(Context context) {
        Log.d(DEBUG_TAG, "Exiting settings mode for all widgets");
        try {
            // Set settings mode to false in SharedPreferences
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            editor.putBoolean(KEY_SETTINGS_MODE, false);
            editor.apply();
            Log.d(DEBUG_TAG, "Settings mode set to false in SharedPreferences");
            
            // Force widget update
            updateWidget(context);
        } catch (Exception e) {
            Log.e(DEBUG_TAG, "Error exiting settings mode: " + e.getMessage(), e);
        }
    }
}
