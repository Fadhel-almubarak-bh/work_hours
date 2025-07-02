package com.example.work_hours

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

object HomeWidgetPlugin {
    private const val TAG = "HomeWidgetPlugin"
    private const val PREFS_NAME = "home_widget_prefs"

    fun getData(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun saveData(context: Context, key: String, value: String) {
        try {
            getData(context).edit().putString(key, value).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving widget data: ${e.message}", e)
        }
    }

    fun saveData(context: Context, key: String, value: Boolean) {
        try {
            getData(context).edit().putBoolean(key, value).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving widget data: ${e.message}", e)
        }
    }

    fun saveData(context: Context, key: String, value: Int) {
        try {
            getData(context).edit().putInt(key, value).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving widget data: ${e.message}", e)
        }
    }

    fun saveData(context: Context, key: String, value: Long) {
        try {
            getData(context).edit().putLong(key, value).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving widget data: ${e.message}", e)
        }
    }

    fun saveData(context: Context, key: String, value: Float) {
        try {
            getData(context).edit().putFloat(key, value).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving widget data: ${e.message}", e)
        }
    }
} 