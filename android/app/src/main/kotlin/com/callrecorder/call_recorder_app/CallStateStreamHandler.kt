package com.callrecorder.call_recorder_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * CallStateStreamHandler: Detects phone call state changes using TelephonyManager
 * and BroadcastReceiver, then streams events to Flutter via EventChannel.
 *
 * Emits events:
 *   { "state": "ringing"|"offhook"|"idle", "number": "...", "callType": "incoming"|"outgoing"|"unknown" }
 *
 * Call type detection logic:
 * - RINGING -> OFFHOOK = incoming call answered
 * - OFFHOOK (without prior RINGING) = outgoing call
 * - IDLE = call ended
 */
class CallStateStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        private const val TAG = "CallStateStream"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var receiver: PhoneStateReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        receiver = PhoneStateReceiver { state, number, callType ->
            events?.success(mapOf(
                "state" to state,
                "number" to (number ?: ""),
                "callType" to callType
            ))
        }

        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        // Also listen for outgoing calls
        @Suppress("DEPRECATION")
        filter.addAction(Intent.ACTION_NEW_OUTGOING_CALL)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        Log.i(TAG, "Call state listener registered")
    }

    override fun onCancel(arguments: Any?) {
        dispose()
    }

    fun dispose() {
        try {
            receiver?.let { context.unregisterReceiver(it) }
        } catch (_: Exception) {}
        receiver = null
        eventSink = null
        Log.i(TAG, "Call state listener unregistered")
    }
}

/**
 * BroadcastReceiver that tracks phone state transitions to determine
 * call direction (incoming vs outgoing).
 */
class PhoneStateReceiver(
    private val onStateChanged: (state: String, number: String?, callType: String) -> Unit
) : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneStateReceiver"
    }

    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var isIncoming = false
    private var savedNumber: String? = null

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) return

        // Capture outgoing call number
        if (intent.action == Intent.ACTION_NEW_OUTGOING_CALL) {
            savedNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
            Log.d(TAG, "Outgoing call to: $savedNumber")
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

        // Avoid duplicate events
        if (state == lastState) return

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                // Incoming call ringing
                isIncoming = true
                savedNumber = number
                Log.d(TAG, "RINGING - incoming from: $number")
                onStateChanged("ringing", number, "incoming")
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                val callType = if (isIncoming) "incoming" else "outgoing"
                Log.d(TAG, "OFFHOOK - $callType, number: $savedNumber")
                onStateChanged("offhook", savedNumber, callType)
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                val callType = if (isIncoming) "incoming" else if (savedNumber != null) "outgoing" else "unknown"
                Log.d(TAG, "IDLE - call ended ($callType)")
                onStateChanged("idle", savedNumber, callType)
                // Reset state
                isIncoming = false
                savedNumber = null
            }
        }

        lastState = state
    }
}
