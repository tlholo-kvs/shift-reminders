package com.example.shifts_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.util.Log
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity

class AlarmActivity : FlutterActivity() {
    private var mediaPlayer: MediaPlayer? = null
    private var alarmLabel = "Alarm"
    private var toneId = "mixkit_morning_clock_alarm_1003"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        alarmLabel = intent.getStringExtra("label") ?: "Alarm"
        toneId = intent.getStringExtra("toneId")
            ?: "mixkit_morning_clock_alarm_1003"
        Log.d("RemindMeAlarm", "ACTIVITY opened label=$alarmLabel tone=$toneId")

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(64, 64, 64, 64)
            setBackgroundColor(0xFF0B1020.toInt())
        }
        val title = TextView(this).apply {
            text = alarmLabel
            textSize = 30f
            gravity = Gravity.CENTER
            setTextColor(0xFFFFFFFF.toInt())
        }
        val snooze = Button(this).apply {
            text = "SNOOZE 10 MIN"
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0xFF7867F6.toInt())
            setOnClickListener {
                AlarmScheduler.scheduleSnooze(applicationContext, 10, alarmLabel, toneId)
                stopAlarm()
            }
        }
        val stop = Button(this).apply {
            text = "STOP"
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(0xFFB90F2D.toInt())
            setOnClickListener { stopAlarm() }
        }
        layout.addView(title)
        layout.addView(snooze, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            160
        ).apply { topMargin = 80 })
        layout.addView(stop, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            160
        ).apply { topMargin = 32 })
        setContentView(layout)
        startLoopingTone()
    }

    private fun startLoopingTone() {
        val resourceId = resources.getIdentifier(toneId, "raw", packageName)
        if (resourceId == 0) return
        mediaPlayer = MediaPlayer.create(this, resourceId)?.apply {
            isLooping = true
            start()
        }
    }

    private fun stopAlarm() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        finishAndRemoveTask()
    }

    override fun onDestroy() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }
}
