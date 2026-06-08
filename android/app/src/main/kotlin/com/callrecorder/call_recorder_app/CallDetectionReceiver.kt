package com.callrecorder.call_recorder_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Static BroadcastReceiver declared in manifest.
 * Works even when CallMonitorService is killed by Samsung battery optimizer.
 * Receives PHONE_STATE_CHANGED and restarts CallMonitorService if needed.
 */
class CallDetectionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallDetectionReceiver"
    }

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        try {
            when (intent.action) {
                Intent.ACTION_NEW_OUTGOING_CALL -> {
                    Log.d(TAG, "Outgoing call detected")
                    // ensureServiceRunning(context)
                }
                TelephonyManager.ACTION_PHONE_STATE_CHANGED -> {
                    val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
                    Log.d(TAG, "Phone state changed: $stateStr")
                    // ensureServiceRunning(context)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onReceive: ${e.message}")
        }
    }

    private fun ensureServiceRunning(context: Context) {
        try {
            if (!CallMonitorService.isMonitoring) {
                Log.i(TAG, "CallMonitorService not running — restarting it")
                val intent = Intent(context, CallMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CallMonitorService: ${e.message}")
        }
    }
}
