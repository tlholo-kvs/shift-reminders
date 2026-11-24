package com.example.shifts_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.util.Log
import android.app.AlarmManager
import android.provider.Settings
import android.net.Uri
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
                "scheduleManualAlarms" -> {
                    val alarms = call.argument<String>("alarms") ?: "[]"
                    AlarmScheduler.scheduleManualAlarms(applicationContext, alarms)
                    result.success(null)
                }
                "scheduleShiftAlarms" -> {
                    val alarms = call.argument<String>("alarms") ?: "[]"
                    AlarmScheduler.scheduleShiftAlarms(applicationContext, alarms)
                    result.success(null)
                }
                "cancelAllAppAlarms" -> {
                    AlarmScheduler.cancelAll(applicationContext)
                    result.success(null)
                }
                "scheduleMockAlarm" -> {
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 10
                    val toneId = call.argument<String>("toneId")
                        ?: "mixkit_morning_clock_alarm_1003"
                    val label = call.argument<String>("label") ?: "Mock Alarm"
                    Log.d("RemindMeAlarm", "DART scheduleMockAlarm delay=${delaySeconds}s tone=$toneId")
                    AlarmScheduler.scheduleMockAlarm(applicationContext, delaySeconds, label, toneId)
                    result.success(null)
                }
                "canDrawOverOtherApps" -> {
                    result.success(Settings.canDrawOverlays(applicationContext))
                }
                "openOverlaySettings" -> {
                    val intent = android.content.Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName"),
                    ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    applicationContext.startActivity(intent)
                    result.success(null)
                }
                "getAlarmDebugInfo" -> {
                    val prefs = getSharedPreferences("remindme_native_alarms", Context.MODE_PRIVATE)
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val exactPermission = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                        alarmManager.canScheduleExactAlarms()
                    } else {
                        true
                    }
                    val info = mapOf(
                        "manual" to (prefs.getString("manual", null) ?: ""),
                        "shifts" to (prefs.getString("shifts", null) ?: ""),
                        "requestCodes" to (prefs.getStringSet("requestCodes", emptySet())?.size ?: 0),
                        "lastAlarm" to (prefs.getString("lastAlarm", "None") ?: "None"),
                        "exactAlarmPermission" to exactPermission,
                    )
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }
    }
}
