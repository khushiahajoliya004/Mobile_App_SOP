package com.callrecorder.call_recorder_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * CallMonitorService: Foreground service that monitors phone call state
 * and automatically starts/stops recording.
 *
 * This service runs independently of the Flutter UI, ensuring recordings
 * happen even when the app is in the background.
 *
 * Recording behavior:
 * - Incoming call answered (RINGING -> OFFHOOK): auto-start recording
 * - Outgoing call connected (OFFHOOK without RINGING): auto-start recording
 * - Call ended (IDLE): auto-stop recording, save metadata
 *
 * The service also handles the legacy file-polling mechanism for backward
 * compatibility with the overlay button.
 */
class CallMonitorService : Service() {

    companion object {
        private const val TAG = "CallMonitorService"
        private const val CHANNEL_ID = "call_monitor_channel"
        private const val NOTIFICATION_ID = 2001
        const val ACTION_START_MONITORING = "start_monitoring"
        const val ACTION_STOP_MONITORING = "stop_monitoring"

        var autoRecordEnabled = true
        var isMonitoring = false
            private set
    }

    private var phoneStateReceiver: BroadcastReceiver? = null
    private var isIncoming = false
    private var savedNumber: String? = null
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var autoRecordedPath: String? = null

    // File polling for overlay button commands (backward compat)
    private val handler = Handler(Looper.getMainLooper())
    private var polling = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!polling) return
            checkCommandFile()
            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification("Ready"))
            registerPhoneStateReceiver()
            startPolling()
            isMonitoring = true
            Log.i(TAG, "CallMonitorService created and monitoring")
        } catch (e: Exception) {
            Log.e(TAG, "Error in onCreate: ${e.message}", e)
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_MONITORING -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopPolling()
        unregisterPhoneStateReceiver()
        // Stop any active recording
        if (CallRecorderEngine.isRecording) {
            CallRecorderEngine.stopRecording()
        }
        isMonitoring = false
        Log.i(TAG, "CallMonitorService destroyed")
        super.onDestroy()
    }

    // ── Phone State Detection ──

    private fun registerPhoneStateReceiver() {
        phoneStateReceiver = object : BroadcastReceiver() {
            @Suppress("DEPRECATION")
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return

                if (intent.action == Intent.ACTION_NEW_OUTGOING_CALL) {
                    savedNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
                    Log.d(TAG, "Outgoing call detected: $savedNumber")
                    return
                }

                val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

                val state = when (stateStr) {
                    TelephonyManager.EXTRA_STATE_RINGING -> TelephonyManager.CALL_STATE_RINGING
                    TelephonyManager.EXTRA_STATE_OFFHOOK -> TelephonyManager.CALL_STATE_OFFHOOK
                    TelephonyManager.EXTRA_STATE_IDLE -> TelephonyManager.CALL_STATE_IDLE
                    else -> return
                }

                if (state == lastState) return
                handleCallStateChange(state, number)
                lastState = state
            }
        }

        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        @Suppress("DEPRECATION")
        filter.addAction(Intent.ACTION_NEW_OUTGOING_CALL)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(phoneStateReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(phoneStateReceiver, filter)
        }
    }

    private fun unregisterPhoneStateReceiver() {
        try {
            phoneStateReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        phoneStateReceiver = null
    }

    private fun handleCallStateChange(state: Int, number: String?) {
        try {
            when (state) {
                TelephonyManager.CALL_STATE_RINGING -> {
                    isIncoming = true
                    savedNumber = number
                    Log.i(TAG, "Call ringing - incoming from: $number")
                    updateNotification("Incoming call...")
                }
                TelephonyManager.CALL_STATE_OFFHOOK -> {
                    val callType = if (isIncoming) "incoming" else "outgoing"
                    Log.i(TAG, "Call active - $callType, number: $savedNumber")
                    updateNotification("Recording...")

                    // Auto-record if enabled and not already recording from overlay
                    if (autoRecordEnabled && !CallRecorderEngine.isRecording) {
                        autoStartRecording(callType)
                    }
                }
                TelephonyManager.CALL_STATE_IDLE -> {
                    val callType = if (isIncoming) "incoming" else if (savedNumber != null) "outgoing" else "unknown"
                    Log.i(TAG, "Call ended - $callType")

                    // Auto-stop recording if we auto-started it
                    if (autoRecordedPath != null && CallRecorderEngine.isRecording) {
                        try {
                            val info = CallRecorderEngine.stopRecording()
                            saveCallMetadata(callType, savedNumber, info)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error stopping recording: ${e.message}")
                        }
                        autoRecordedPath = null
                    }

                    updateNotification("Ready")
                    isIncoming = false
                    savedNumber = null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling call state change: ${e.message}", e)
        }
    }

    private fun autoStartRecording(callType: String) {
        try {
            val dir = File(filesDir.parentFile, "app_flutter")
            if (!dir.exists()) {
                val created = dir.mkdirs()
                Log.d(TAG, "Output directory created: $created")
            }

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val path = "${dir.absolutePath}/${callType}_call_$timestamp.m4a"

            val success = CallRecorderEngine.startRecording(path, "voice_communication", applicationContext)
            if (success) {
                autoRecordedPath = path
                Log.i(TAG, "Auto-recording started: $path (source: ${CallRecorderEngine.activeSource})")
                updateNotification("Recording...")
            } else {
                Log.w(TAG, "Auto-recording failed to start - all audio sources failed")
                updateNotification("Failed to record")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Auto-recording error: ${e.message}", e)
            updateNotification("Recording error")
        }
    }

    /**
     * Save call metadata as a JSON sidecar file next to the recording.
     */
    private fun saveCallMetadata(callType: String, number: String?, recordingInfo: Map<String, Any?>) {
        try {
            val path = recordingInfo["path"] as? String ?: return
            val durationMs = recordingInfo["durationMs"] as? Long ?: 0L
            val source = recordingInfo["source"] as? String ?: "unknown"

            val metaFile = File("$path.meta.json")
            val json = """
            {
                "callType": "$callType",
                "phoneNumber": "${number ?: "unknown"}",
                "durationMs": $durationMs,
                "audioSource": "$source",
                "timestamp": "${SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).format(Date())}",
                "filePath": "$path",
                "androidVersion": ${Build.VERSION.SDK_INT},
                "device": "${Build.MANUFACTURER} ${Build.MODEL}"
            }
            """.trimIndent()
            metaFile.writeText(json)
            Log.i(TAG, "Call metadata saved: ${metaFile.absolutePath}")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to save call metadata: ${e.message}")
        }
    }

    // ── File Polling for Overlay Button ──

    private fun startPolling() {
        polling = true
        handler.post(pollRunnable)
    }

    private fun stopPolling() {
        polling = false
        handler.removeCallbacks(pollRunnable)
    }

    private fun checkCommandFile() {
        try {
            val appFlutterDir = File(filesDir.parentFile, "app_flutter")
            val cmdFile = File(appFlutterDir, ".recorder_command")
            if (!cmdFile.exists()) return

            val content = cmdFile.readText().trim()
            if (content.isEmpty()) return

            val parts = content.split("|", limit = 2)
            val command = parts[0]
            val path = if (parts.size > 1) parts[1] else ""

            when {
                command == "start" && !CallRecorderEngine.isRecording && path.isNotEmpty() -> {
                    Log.d(TAG, "Overlay command: start recording -> $path")
                    val success = CallRecorderEngine.startRecording(path, "voice_communication", applicationContext)
                    cmdFile.writeText(if (success) "recording|$path" else "error|")
                }
                command == "stop" && CallRecorderEngine.isRecording -> {
                    Log.d(TAG, "Overlay command: stop recording")
                    CallRecorderEngine.stopRecording()
                    cmdFile.writeText("idle|")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Poll error: ${e.message}")
        }
    }

    // ── Notification ──

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors phone calls for recording"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val mainActivityClass = try {
            Class.forName("com.mysterymentor.app.MainActivity")
        } catch (e: ClassNotFoundException) {
            Class.forName("com.callrecorder.call_recorder_app.MainActivity")
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, mainActivityClass),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Recording")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }
}
