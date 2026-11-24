package com.example.shifts_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.app.KeyguardManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.WindowManager
import android.util.Log
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity

class AlarmActivity : FlutterActivity() {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var vibrator: Vibrator? = null
    private var alarmLabel = "Alarm"
    private var toneId = "mixkit_morning_clock_alarm_1003"

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 700, 400, 700, 400)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(
                VibrationEffect.createWaveform(pattern, 0),
                null,
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
        Log.d("RemindMeAlarm", "VIBRATION loop started")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
            "RemindMe:AlarmScreen",
        )
        wakeLock?.acquire(10 * 60 * 1000L)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager =
                getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
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
        startVibration()
    }

    private fun startLoopingTone() {
        val resourceId = resources.getIdentifier(toneId, "raw", packageName)
        val player = if (resourceId != 0) {
            MediaPlayer.create(this, resourceId)
        } else {
            null
        }
        mediaPlayer = player?.apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            isLooping = true
            setVolume(1f, 1f)
            start()
        }
        Log.d(
            "RemindMeAlarm",
            "TONE playback started=$resourceId volumeStream=${AudioManager.STREAM_ALARM}",
        )
    }

    private fun stopAlarm() {
        vibrator?.cancel()
        vibrator = null
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        wakeLock?.release()
        wakeLock = null
        finishAndRemoveTask()
    }

    override fun onDestroy() {
        vibrator?.cancel()
        vibrator = null
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }
}
