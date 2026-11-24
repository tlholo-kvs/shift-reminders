package com.example.shifts_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import java.util.Calendar
import kotlin.math.abs

object AlarmScheduler {
    private const val PREFS = "remindme_native_alarms"

    fun scheduleMockAlarm(context: Context, delaySeconds: Int, label: String, toneId: String) {
        val millis = System.currentTimeMillis() + delaySeconds * 1000L
        val exactPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            manager.canScheduleExactAlarms()
        } else {
            true
        }
        Log.d(
            "RemindMeAlarm",
            "Scheduling mock alarm millis=$millis delay=${delaySeconds}s " +
                "tone=$toneId exactPermission=$exactPermission",
        )
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("lastAlarm", "Mock: $label, $delaySeconds seconds")
            .apply()
        scheduleOnce(context, millis, label, toneId, "mock_${System.currentTimeMillis()}")
    }

    fun scheduleManualAlarms(context: Context, json: String) {
        cancelAll(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("manual", json).apply()
        val alarms = JSONArray(json)
        for (i in 0 until alarms.length()) {
            val alarm = alarms.getJSONObject(i)
            if (!alarm.optBoolean("enabled", true)) continue
            val weekdays = alarm.getJSONArray("weekdays")
            val time = alarm.getJSONObject("time")
            val label = alarm.optString("label", "Alarm")
            val toneId = alarm.optString("toneId", "mixkit_morning_clock_alarm_1003")
            val id = alarm.optString("id", "alarm")
            if (weekdays.length() == 0) {
                val dateParts = alarm.optString("scheduledDate", "")
                    .split("-")
                    .mapNotNull { it.toIntOrNull() }
                val now = Calendar.getInstance()
                val year = dateParts.getOrNull(0) ?: now.get(Calendar.YEAR)
                val month = dateParts.getOrNull(1) ?: now.get(Calendar.MONTH) + 1
                val day = dateParts.getOrNull(2) ?: now.get(Calendar.DAY_OF_MONTH)
                val target = Calendar.getInstance().apply {
                    set(year, month - 1, day, time.getInt("hour"), time.getInt("minute"), 0)
                    set(Calendar.MILLISECOND, 0)
                }
                scheduleOnce(
                    context,
                    target.timeInMillis,
                    label,
                    toneId,
                    "${id}_once",
                )
                continue
            }
            for (d in 0 until weekdays.length()) {
                scheduleWeekly(
                    context,
                    weekdays.getInt(d),
                    time.getInt("hour"),
                    time.getInt("minute"),
                    label,
                    toneId,
                    id,
                )
            }
        }
    }

    fun scheduleShiftAlarms(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("shifts", json).apply()
        val alarms = JSONArray(json)
        for (i in 0 until alarms.length()) {
            val alarm = alarms.getJSONObject(i)
            scheduleOnce(
                context,
                alarm.getLong("millis"),
                alarm.optString("label", "Shift alarm"),
                alarm.optString("toneId", "mixkit_morning_clock_alarm_1003"),
                alarm.optString("id", "shift"),
            )
        }
    }

    fun rescheduleStored(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString("manual", null)?.let {
            scheduleManualAlarms(context, it)
        }
        prefs.getString("shifts", null)?.let {
            scheduleShiftAlarms(context, it)
        }
    }

    fun scheduleSnooze(context: Context, minutes: Int, label: String, toneId: String) {
        scheduleOnce(
            context,
            System.currentTimeMillis() + minutes * 60_000L,
            label,
            toneId,
            "snooze_${System.currentTimeMillis()}",
        )
    }

    fun scheduleWeekly(
        context: Context,
        weekday: Int,
        hour: Int,
        minute: Int,
        label: String,
        toneId: String,
        idText: String,
    ) {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val javaDay = if (weekday == 7) Calendar.SUNDAY else weekday + 1
        target.set(Calendar.DAY_OF_WEEK, javaDay)
        if (target.timeInMillis <= now.timeInMillis) {
            target.add(Calendar.DAY_OF_YEAR, 7)
        }
        scheduleWeeklyOnce(
            context,
            target.timeInMillis,
            label,
            toneId,
            "${idText}_$weekday",
            weekday,
            hour,
            minute,
        )
    }

    private fun scheduleWeeklyOnce(
        context: Context,
        millis: Long,
        label: String,
        toneId: String,
        idText: String,
        weekday: Int,
        hour: Int,
        minute: Int,
    ) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("label", label)
            putExtra("toneId", toneId)
            putExtra("hour", hour)
            putExtra("minute", minute)
            putExtra("weekday", weekday)
            putExtra("idText", idText)
        }
        val requestCode = abs(idText.hashCode())
        rememberRequestCode(context, requestCode)
        val pending = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !manager.canScheduleExactAlarms()
        ) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, pending)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val showIntent = Intent(context, AlarmActivity::class.java).apply {
                putExtra("label", label)
                putExtra("toneId", toneId)
            }
            val showPending = PendingIntent.getActivity(
                context,
                requestCode,
                showIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            manager.setAlarmClock(
                AlarmManager.AlarmClockInfo(millis, showPending),
                pending,
            )
        } else {
            manager.setExact(AlarmManager.RTC_WAKEUP, millis, pending)
        }
    }

    fun scheduleOnce(
        context: Context,
        millis: Long,
        label: String,
        toneId: String,
        idText: String,
    ) {
        if (millis <= System.currentTimeMillis()) return
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("label", label)
            putExtra("toneId", toneId)
        }
        val requestCode = abs(idText.hashCode())
        rememberRequestCode(context, requestCode)
        val pending = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !manager.canScheduleExactAlarms()
        ) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, pending)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val showIntent = Intent(context, AlarmActivity::class.java).apply {
                putExtra("label", label)
                putExtra("toneId", toneId)
            }
            val showPending = PendingIntent.getActivity(
                context,
                requestCode,
                showIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val clock = AlarmManager.AlarmClockInfo(millis, showPending)
            manager.setAlarmClock(clock, pending)
        } else {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, pending)
        }
    }

    fun cancelAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().remove("manual").remove("shifts").apply()
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val storedCodes = prefs.getStringSet("requestCodes", emptySet()) ?: emptySet()
        for (codeText in storedCodes) {
            val code = codeText.toIntOrNull() ?: continue
            val intent = Intent(context, AlarmReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                code,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pending != null) manager.cancel(pending)
        }
        prefs.edit().remove("requestCodes").apply()
    }

    private fun rememberRequestCode(context: Context, code: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val codes = prefs.getStringSet("requestCodes", emptySet())?.toMutableSet()
            ?: mutableSetOf()
        codes.add(code.toString())
        prefs.edit().putStringSet("requestCodes", codes).apply()
    }
}
