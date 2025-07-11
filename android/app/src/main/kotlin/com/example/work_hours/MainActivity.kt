package com.example.work_hours

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.content.ComponentName
import android.content.SharedPreferences
import android.appwidget.AppWidgetManager
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.util.ArrayList
import java.util.HashMap

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL_DEVICE_INFO = "device_info"
    private val CHANNEL_EXACT_ALARM = "exact_alarm_check"
    private val CHANNEL_WIDGET_ACTIONS = "widget_actions"
    private val EVENT_CHANNEL_WIDGET = "widget_events"
    private val CHANNEL_SYSTEM_INFO = "work_hours/system_info"
    
    // Widget related constants
    private val WIDGET_CHANNEL = "com.example.work_hours/widget"
    private val WIDGET_ACTIONS_CHANNEL = "com.example.work_hours/actions"
    private val PREFS_NAME = "HomeWidgetPreferences"
    private val KEY_SETTINGS_MODE = "widget_settings_mode"

    private var widgetEventSink: EventChannel.EventSink? = null
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Original Kotlin implementation channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_DEVICE_INFO)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidSdk") {
                    result.success(Build.VERSION.SDK_INT)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SYSTEM_INFO)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidSdkVersion" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_EXACT_ALARM)
            .setMethodCallHandler { call, result ->
                if (call.method == "isExactAlarmAllowed") {
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Widget channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exitSettingsMode" -> {
                        exitWidgetSettingsMode()
                        result.success(null)
                    }
                    "getWidgetInfo" -> {
                        result.success(getWidgetInfo())
                    }
                    else -> result.notImplemented()
                }
            }

        // Widget actions channel
        Log.d(TAG, "[home_widget] 🔍 Setting up widget actions channel: $WIDGET_ACTIONS_CHANNEL")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_ACTIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "[home_widget] 🔍 Widget actions channel received method: ${call.method}")
                when (call.method) {
                    "clockIn" -> {
                        Log.d(TAG, "[home_widget] 🔍 Processing clock in action")
                        try {
                            // This will be handled by the interactiveCallback in Flutter
                            Log.d(TAG, "[home_widget] ✅ Clock in action processed successfully")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "[home_widget] ❌ Error processing clock in action: ${e.message}", e)
                            result.error("CLOCK_IN_ERROR", e.message, null)
                        }
                    }
                    "clockOut" -> {
                        Log.d(TAG, "[home_widget] 🔍 Processing clock out action")
                        try {
                            // This will be handled by the interactiveCallback in Flutter
                            Log.d(TAG, "[home_widget] ✅ Clock out action processed successfully")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "[home_widget] ❌ Error processing clock out action: ${e.message}", e)
                            result.error("CLOCK_OUT_ERROR", e.message, null)
                        }
                    }
                    "clockInOut" -> {
                        Log.d(TAG, "[home_widget] 🔍 Processing clock in/out toggle action")
                        try {
                            // This will be handled by the interactiveCallback in Flutter
                            Log.d(TAG, "[home_widget] ✅ Clock in/out toggle action processed successfully")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "[home_widget] ❌ Error processing clock in/out toggle action: ${e.message}", e)
                            result.error("CLOCK_IN_OUT_ERROR", e.message, null)
                        }
                    }
                    else -> {
                        Log.w(TAG, "[home_widget] ⚠️ Unknown widget action method: ${call.method}")
                        result.notImplemented()
                    }
                }
            }
        Log.d(TAG, "[home_widget] ✅ Widget actions channel set up successfully")

        // Widget events channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_WIDGET)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    widgetEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    widgetEventSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle widget configuration
        if (intent?.action == AppWidgetManager.ACTION_APPWIDGET_CONFIGURE) {
            appWidgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
            
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                finish()
                return
            }
            
            // Set the result to OK
            val resultValue = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_OK, resultValue)
        }
    }

    override fun onResume() {
        super.onResume()
        // If we're in widget configuration mode, finish the activity
        if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        
        if (intent.action == "com.example.work_hours.ACTION_CLOCK_IN_OUT") {
            Log.d(TAG, "[home_widget] 🔍 Widget action received in MainActivity")
            Toast.makeText(this, "Widget action received in MainActivity", Toast.LENGTH_SHORT).show()
            
            try {
                Log.d(TAG, "[home_widget] 🔍 Attempting to send action to Flutter via method channel")
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "com.example.work_hours/actions")
                    .invokeMethod("clockInOut", null)
                Log.d(TAG, "[home_widget] ✅ Action sent to Flutter successfully")
                Toast.makeText(this, "Action sent to Flutter", Toast.LENGTH_SHORT).show()
            } catch (e: Exception) {
                Log.e(TAG, "[home_widget] ❌ Error sending clock in/out action to Flutter: ${e.message}", e)
                Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    // Widget functions from Java implementation
    private fun exitWidgetSettingsMode() {
        try {
            // Call the widget provider's method to exit settings mode
            try {
                val myHomeWidgetProviderClass = Class.forName("com.example.work_hours.MyHomeWidgetProvider")
                val method = myHomeWidgetProviderClass.getMethod("exitSettingsMode", Context::class.java)
                method.invoke(null, applicationContext)
            } catch (e: Exception) {
                Log.e(TAG, "Error calling exitSettingsMode: ${e.message}", e)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error exiting widget settings mode: ${e.message}", e)
        }
    }

    private fun getWidgetInfo(): Map<String, Any> {
        val info = HashMap<String, Any>()
        try {
            // Get widget manager and widget IDs
            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
            val componentName = ComponentName(applicationContext, Class.forName("com.example.work_hours.MyHomeWidgetProvider"))
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // Get settings mode state
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isSettingsMode = prefs.getBoolean(KEY_SETTINGS_MODE, false)
            
            // Put info in map
            info["widgetCount"] = appWidgetIds.size
            info["isSettingsMode"] = isSettingsMode
            
            // Convert widget IDs to List for Dart
            val widgetIdList = ArrayList<Int>()
            for (id in appWidgetIds) {
                widgetIdList.add(id)
            }
            info["widgetIds"] = widgetIdList
        } catch (e: Exception) {
            Log.e(TAG, "Error getting widget info: ${e.message}", e)
            info["error"] = e.message ?: "Unknown error"
        }
        
        return info
    }
}
