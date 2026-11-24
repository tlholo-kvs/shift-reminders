package com.example.shifts_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val label = intent.getStringExtra("label") ?: "Alarm"
        val toneId = intent.getStringExtra("toneId")
            ?: "mixkit_morning_clock_alarm_1003"
        Log.d("RemindMeAlarm", "RECEIVER fired label=$label tone=$toneId")
        context.getSharedPreferences("remindme_native_alarms", Context.MODE_PRIVATE)
            .edit()
            .putString("lastAlarm", "Receiver fired: $label")
            .apply()
        val weekday = intent.getIntExtra("weekday", -1)
        val hour = intent.getIntExtra("hour", -1)
        val minute = intent.getIntExtra("minute", -1)
        val idText = intent.getStringExtra("idText")
        if (weekday >= 1 && hour >= 0 && minute >= 0) {
            AlarmScheduler.scheduleWeekly(
                context,
                weekday,
                hour,
                minute,
                label,
                toneId,
                idText ?: "alarm",
            )
        }

        val alarmActivity = Intent(context, AlarmActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra("label", label)
            putExtra("toneId", toneId)
        }
        context.startActivity(alarmActivity)
    }
}

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmScheduler.rescheduleStored(context)
    }
}
