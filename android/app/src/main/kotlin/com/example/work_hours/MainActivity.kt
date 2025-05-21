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
    
    // Widget related constants from Java implementation
    private val WIDGET_CHANNEL = "com.example.work_hours/widget"
    private val WIDGET_ACTIONS_CHANNEL = "com.example.work_hours/actions"
    private val PREFS_NAME = "HomeWidgetPreferences"
    private val KEY_SETTINGS_MODE = "widget_settings_mode"

    private var widgetEventSink: EventChannel.EventSink? = null

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_WIDGET)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    widgetEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    widgetEventSink = null
                }
            })
            
        // Widget functionality from Java implementation
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exitSettingsMode" -> {
                        exitWidgetSettingsMode()
                        result.success(true)
                    }
                    "getWidgetInfo" -> {
                        try {
                            result.success(getWidgetInfo())
                        } catch (e: Exception) {
                            result.error("ERROR", "Error getting widget info", e.message)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == null) {
            return
        }
        
        Log.d(TAG, "Handling intent with action: ${intent.action}")
        
        when (intent.action) {
            "CLOCK_IN" -> {
                Log.d(TAG, "Received CLOCK_IN action")
                // Send event to Flutter via event channel
                widgetEventSink?.success("clock_in")
                
                // Alternative approach using method channel
                try {
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, WIDGET_ACTIONS_CHANNEL)
                        .invokeMethod("clockIn", null)
                    Log.d(TAG, "Successfully sent CLOCK_IN action to Flutter")
                    
                    // Show a toast notification
                    Toast.makeText(this, "Clocking in...", Toast.LENGTH_SHORT).show()
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending CLOCK_IN to Flutter: ${e.message}", e)
                }
            }
            "CLOCK_OUT" -> {
                Log.d(TAG, "Received CLOCK_OUT action")
                // Send event to Flutter via event channel
                widgetEventSink?.success("clock_out")
                
                // Alternative approach using method channel
                try {
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, WIDGET_ACTIONS_CHANNEL)
                        .invokeMethod("clockOut", null)
                    Log.d(TAG, "Successfully sent CLOCK_OUT action to Flutter")
                    
                    // Show a toast notification
                    Toast.makeText(this, "Clocking out...", Toast.LENGTH_SHORT).show()
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending CLOCK_OUT to Flutter: ${e.message}", e)
                }
            }
        }
    }
    
    // Widget functions from Java implementation
    private fun exitWidgetSettingsMode() {
        try {
            Log.d(TAG, "Exiting widget settings mode")
            
            // Call the widget provider's method to exit settings mode
            try {
                val myHomeWidgetProviderClass = Class.forName("com.example.work_hours.MyHomeWidgetProvider")
                val method = myHomeWidgetProviderClass.getMethod("exitSettingsMode", Context::class.java)
                method.invoke(null, applicationContext)
                
                Log.d(TAG, "Widget settings mode exited successfully")
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
            Log.d(TAG, "Getting widget information")
            
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
            
            Log.d(TAG, "Widget info collected: $info")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting widget info: ${e.message}", e)
            info["error"] = e.message ?: "Unknown error"
        }
        
        return info
    }
}
