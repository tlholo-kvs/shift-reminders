package com.example.shifts_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.media.AudioAttributes
import android.content.pm.PackageManager
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val wakeLock = (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "RemindMe:AlarmWake",
            )
        wakeLock.acquire(30_000L)

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
        try {
            context.startActivity(alarmActivity)
        } catch (error: Exception) {
            Log.e("RemindMeAlarm", "ACTIVITY launch failed: ${error.message}")
        }

        try {
            if (wakeLock.isHeld) wakeLock.release()
        } catch (_: Exception) {
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "remindme_full_alarm",
                "RemindMe Alarms",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Full-screen looping alarms"
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }
        val activityPending = PendingIntent.getActivity(
            context,
            intent.getIntExtra("requestCode", System.identityHashCode(alarmActivity)),
            alarmActivity,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, "remindme_full_alarm")
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(label)
            .setContentText("Alarm ringing")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(false)
            .setFullScreenIntent(activityPending, true)
            .setContentIntent(activityPending)
            .build()
        manager.notify(System.identityHashCode(label), notification)
    }
}

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmScheduler.rescheduleStored(context)
    }
}
