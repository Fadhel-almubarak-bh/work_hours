package com.example.work_hours

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_DEVICE_INFO = "device_info"
    private val CHANNEL_EXACT_ALARM = "exact_alarm_check"
    private val CHANNEL_WIDGET_ACTIONS = "widget_actions"
    private val EVENT_CHANNEL_WIDGET = "widget_events"

    private var widgetEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_DEVICE_INFO)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidSdk") {
                    result.success(Build.VERSION.SDK_INT)
                } else {
                    result.notImplemented()
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
        when (intent.action) {
            "CLOCK_IN" -> {
                widgetEventSink?.success("clock_in")
            }
            "CLOCK_OUT" -> {
                widgetEventSink?.success("clock_out")
            }
        }
    }
}
