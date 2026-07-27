package com.callrecorder.call_recorder_app

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * FloatingButtonService: Native Android floating overlay button (PiP-style).
 *
 * Features:
 * - Draggable across entire screen with boundary constraints
 * - Snaps to nearest screen edge on release
 * - Smooth animations with overshoot interpolator
 * - Visual recording state (blue idle, red pulsing when recording)
 * - Timer display during recording
 * - Tap to start/stop recording
 * - Runs as foreground service with SYSTEM_ALERT_WINDOW permission
 * - Does NOT disappear on swipe (always visible)
 */
class FloatingButtonService : Service() {

    companion object {
        private const val TAG = "FloatingButton"
        private const val CHANNEL_ID = "floating_button_channel"
        private const val NOTIFICATION_ID = 3001
        const val ACTION_SHOW = "show_overlay"
        const val ACTION_HIDE = "hide_overlay"

        private var instance: FloatingButtonService? = null

        fun updateState(recording: Boolean, seconds: Int) {
            instance?.floatingView?.let {
                if (it is FloatingButtonView) {
                    it.setRecordingState(recording, seconds)
                }
            }
        }
    }

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var screenWidth = 0
    private var screenHeight = 0

    // Recording state
    private var isRecording = false
    private var recordingSeconds = 0
    private val timerHandler = Handler(Looper.getMainLooper())
    private val timerRunnable = object : Runnable {
        override fun run() {
            if (isRecording) {
                recordingSeconds++
                (floatingView as? FloatingButtonView)?.setRecordingState(true, recordingSeconds)
                timerHandler.postDelayed(this, 1000)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        getScreenDimensions()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> showButton()
            ACTION_HIDE -> hideButton()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        hideButton()
        timerHandler.removeCallbacks(timerRunnable)
        instance = null
        super.onDestroy()
    }

    private fun getScreenDimensions() {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager?.defaultDisplay?.getMetrics(metrics)
        screenWidth = metrics.widthPixels
        screenHeight = metrics.heightPixels
    }

    private fun showButton() {
        if (floatingView != null) return

        val buttonSize = dpToPx(64)
        val view = FloatingButtonView(this, buttonSize)
        view.setOnClickListener { onButtonTap() }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            buttonSize, buttonSize,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = screenWidth - buttonSize - dpToPx(8)
            y = screenHeight / 3
        }

        layoutParams = params
        floatingView = view

        setupDragListener(view, params)

        try {
            windowManager?.addView(view, params)
            Log.i(TAG, "Floating button shown")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show floating button: ${e.message}")
        }
    }

    private fun hideButton() {
        try {
            floatingView?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {}
        floatingView = null
        layoutParams = null

        if (isRecording) {
            stopRecordingAction()
        }
        Log.i(TAG, "Floating button hidden")
    }

    /**
     * Setup drag listener with edge snapping and boundary constraints.
     */
    private fun setupDragListener(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        val touchSlop = dpToPx(8)

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY

                    if (!isDragging && (Math.abs(dx) > touchSlop || Math.abs(dy) > touchSlop)) {
                        isDragging = true
                    }

                    if (isDragging) {
                        // Constrain to screen bounds
                        val newX = (initialX + dx.toInt()).coerceIn(0, screenWidth - view.width)
                        val newY = (initialY + dy.toInt()).coerceIn(0, screenHeight - view.height - dpToPx(48))
                        params.x = newX
                        params.y = newY
                        try { windowManager?.updateViewLayout(view, params) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (isDragging) {
                        // Snap to nearest edge
                        snapToEdge(view, params)
                    } else {
                        // It was a tap
                        v.performClick()
                    }
                    true
                }
                else -> false
            }
        }
    }

    /**
     * Animate the button to snap to the nearest horizontal edge.
     */
    private fun snapToEdge(view: View, params: WindowManager.LayoutParams) {
        val centerX = params.x + view.width / 2
        val targetX = if (centerX < screenWidth / 2) {
            dpToPx(4) // Snap to left
        } else {
            screenWidth - view.width - dpToPx(4) // Snap to right
        }

        val animator = ValueAnimator.ofInt(params.x, targetX)
        animator.duration = 300
        animator.interpolator = OvershootInterpolator(1.2f)
        animator.addUpdateListener { anim ->
            params.x = anim.animatedValue as Int
            try { windowManager?.updateViewLayout(view, params) } catch (_: Exception) {}
        }
        animator.start()
    }

    // ── Recording Actions ──

    private fun onButtonTap() {
        if (isRecording) {
            stopRecordingAction()
        } else {
            startRecordingAction()
        }
    }

    private fun startRecordingAction() {
        val dir = File(filesDir.parentFile, "app_flutter")
        if (!dir.exists()) dir.mkdirs()

        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val path = "${dir.absolutePath}/manual_call_$timestamp.m4a"

        // Also write command file for Flutter compatibility
        try {
            val cmdFile = File(dir, ".recorder_command")
            cmdFile.writeText("start|$path")
        } catch (_: Exception) {}

        val success = CallRecorderEngine.startRecording(path, "voice_communication", applicationContext)
        if (success) {
            isRecording = true
            recordingSeconds = 0
            (floatingView as? FloatingButtonView)?.setRecordingState(true, 0)
            timerHandler.postDelayed(timerRunnable, 1000)
            Log.i(TAG, "Recording started via floating button: $path")
        } else {
            Log.w(TAG, "Failed to start recording via floating button")
        }
    }

    private fun stopRecordingAction() {
        timerHandler.removeCallbacks(timerRunnable)
        val info = CallRecorderEngine.stopRecording()
        isRecording = false
        recordingSeconds = 0
        (floatingView as? FloatingButtonView)?.setRecordingState(false, 0)

        // Write command file for Flutter compatibility
        try {
            val dir = File(filesDir.parentFile, "app_flutter")
            val cmdFile = File(dir, ".recorder_command")
            cmdFile.writeText("idle|")
        } catch (_: Exception) {}

        Log.i(TAG, "Recording stopped via floating button: ${info["path"]}")
    }

    // ── Notification ──

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Floating Button",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Floating record button overlay"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val mainActivityClass = try {
            Class.forName("com.mysterymentor.app.MainActivity")
        } catch (e: ClassNotFoundException) {
            Class.forName("com.callrecorder.call_recorder_app.MainActivity")
        }
        
        val intent = PendingIntent.getActivity(
            this, 0,
            Intent(this, mainActivityClass),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Recorder")
            .setContentText("Floating button active")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(intent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}

/**
 * Custom View for the floating button with gradient, shadow, and recording animation.
 */
class FloatingButtonView(context: Context, private val size: Int) : View(context) {

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 6f
        color = Color.WHITE
    }
    private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
    }
    private val timerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 20f
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }
    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        setShadowLayer(16f, 0f, 4f, Color.argb(80, 0, 0, 0))
    }

    private var recording = false
    private var seconds = 0
    private var pulseScale = 1f
    private val pulseHandler = Handler(Looper.getMainLooper())
    private var pulseGrowing = true

    private val pulseRunnable = object : Runnable {
        override fun run() {
            if (!recording) {
                pulseScale = 1f
                invalidate()
                return
            }
            pulseScale = if (pulseGrowing) {
                (pulseScale + 0.008f).also { if (it >= 1.08f) pulseGrowing = false }
            } else {
                (pulseScale - 0.008f).also { if (it <= 0.95f) pulseGrowing = true }
            }
            invalidate()
            pulseHandler.postDelayed(this, 16) // ~60fps
        }
    }

    fun setRecordingState(isRecording: Boolean, secs: Int) {
        val wasRecording = recording
        recording = isRecording
        seconds = secs
        if (isRecording && !wasRecording) {
            pulseGrowing = true
            pulseScale = 1f
            pulseHandler.post(pulseRunnable)
        } else if (!isRecording) {
            pulseHandler.removeCallbacks(pulseRunnable)
            pulseScale = 1f
        }
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val radius = (size / 2f - 8f) * pulseScale

        // Shadow
        canvas.drawCircle(cx, cy + 2f, radius, shadowPaint)

        // Gradient background
        bgPaint.shader = if (recording) {
            LinearGradient(0f, 0f, width.toFloat(), height.toFloat(),
                Color.parseColor("#EF4444"), Color.parseColor("#DC2626"),
                Shader.TileMode.CLAMP)
        } else {
            LinearGradient(0f, 0f, width.toFloat(), height.toFloat(),
                Color.parseColor("#1A73E8"), Color.parseColor("#0D47A1"),
                Shader.TileMode.CLAMP)
        }
        canvas.drawCircle(cx, cy, radius, bgPaint)

        // White border
        canvas.drawCircle(cx, cy, radius - 3f, borderPaint)

        // Icon (mic or stop)
        iconPaint.textSize = if (recording) size * 0.28f else size * 0.35f
        val iconY = if (recording) cy - 2f else cy + iconPaint.textSize / 3f
        canvas.drawText(if (recording) "■" else "🎙", cx, iconY, iconPaint)

        // Timer text when recording
        if (recording) {
            val min = (seconds / 60).toString().padStart(2, '0')
            val sec = (seconds % 60).toString().padStart(2, '0')
            canvas.drawText("$min:$sec", cx, cy + radius * 0.55f, timerPaint)
        }
    }
}
