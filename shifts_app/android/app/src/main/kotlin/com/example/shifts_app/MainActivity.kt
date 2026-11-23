package com.example.shifts_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.shifts_app/timezone",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTimezone" -> result.success(TimeZone.getDefault().id)
                "clearScheduledNotifications" -> {
                    getSharedPreferences(
                        "scheduled_notifications",
                        Context.MODE_PRIVATE,
                    ).edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
