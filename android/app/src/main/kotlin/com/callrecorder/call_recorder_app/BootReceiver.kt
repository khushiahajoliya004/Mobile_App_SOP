package com.callrecorder.call_recorder_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * BootReceiver: Restarts CallMonitorService after reboot,
 * but only if RECORD_AUDIO permission is already granted.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED ||
            intent?.action == "android.intent.action.QUICKBOOT_POWERON") {

            context?.let { ctx ->
                val hasAudio = ContextCompat.checkSelfPermission(
                    ctx, Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED

                if (!hasAudio) {
                    Log.w("BootReceiver", "RECORD_AUDIO not granted, skipping service start")
                    return
                }

                Log.i("BootReceiver", "Device booted, starting CallMonitorService")
                try {
                    val serviceIntent = Intent(ctx, CallMonitorService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ctx.startForegroundService(serviceIntent)
                    } else {
                        ctx.startService(serviceIntent)
                    }
                } catch (e: Exception) {
                    Log.e("BootReceiver", "Failed to start service: ${e.message}")
                }
            }
        }
    }
}
