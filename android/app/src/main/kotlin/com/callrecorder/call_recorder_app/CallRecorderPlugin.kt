package com.callrecorder.call_recorder_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.net.Uri
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

/**
 * CallRecorderPlugin: Registers all Platform Channels as a proper FlutterPlugin.
 *
 * This ensures channels are available regardless of Activity lifecycle,
 * and avoids MissingPluginException when the engine is reused or
 * when the overlay engine tries to call methods.
 *
 * Channels:
 * - com.callrecorder/native_recorder (MethodChannel) — recording control
 * - com.callrecorder/call_state (EventChannel) — phone state stream
 * - com.callrecorder/overlay (MethodChannel) — floating button control
 */
class CallRecorderPlugin : FlutterPlugin, ActivityAware {

    companion object {
        private const val TAG = "CallRecorderPlugin"
        private const val RECORDER_CHANNEL = "com.callrecorder/native_recorder"
        private const val CALL_STATE_CHANNEL = "com.callrecorder/call_state"
        private const val OVERLAY_CHANNEL = "com.callrecorder/overlay"
    }

    private var recorderChannel: MethodChannel? = null
    private var overlayChannel: MethodChannel? = null
    private var callStateEventChannel: EventChannel? = null
    private var callStateStreamHandler: CallStateStreamHandler? = null

    private var applicationContext: Context? = null
    private var activity: Activity? = null

    // ── FlutterPlugin ──

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        val messenger = binding.binaryMessenger

        // Recording channel
        recorderChannel = MethodChannel(messenger, RECORDER_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                val ctx = applicationContext
                if (ctx == null) {
                    result.error("NO_CONTEXT", "Application context not available", null)
                    return@setMethodCallHandler
                }
                handleRecorderMethod(call.method, call, result, ctx)
            }
        }

        // Call state event channel
        callStateStreamHandler = CallStateStreamHandler(binding.applicationContext)
        callStateEventChannel = EventChannel(messenger, CALL_STATE_CHANNEL).also { channel ->
            channel.setStreamHandler(callStateStreamHandler)
        }

        // Overlay channel
        overlayChannel = MethodChannel(messenger, OVERLAY_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                handleOverlayMethod(call.method, call, result)
            }
        }

        Log.i(TAG, "Plugin attached to engine, all channels registered")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        recorderChannel?.setMethodCallHandler(null)
        recorderChannel = null
        overlayChannel?.setMethodCallHandler(null)
        overlayChannel = null
        callStateEventChannel?.setStreamHandler(null)
        callStateEventChannel = null
        callStateStreamHandler?.dispose()
        callStateStreamHandler = null
        applicationContext = null
        Log.i(TAG, "Plugin detached from engine")
    }

    // ── ActivityAware ──

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        Log.d(TAG, "Attached to activity")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ── Recorder Method Handler ──

    private fun handleRecorderMethod(
        method: String,
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
        ctx: Context
    ) {
        when (method) {
            "startRecording" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARG", "path is required", null)
                    return
                }
                val audioSource = call.argument<String>("audioSource") ?: "voice_communication"
                val success = CallRecorderEngine.startRecording(path, audioSource, ctx)
                if (success) {
                    result.success(mapOf(
                        "path" to path,
                        "source" to CallRecorderEngine.activeSource,
                        "message" to "Recording started"
                    ))
                } else {
                    result.error("RECORD_FAILED", "Could not start recording. Check permissions.", null)
                }
            }
            "stopRecording" -> {
                result.success(CallRecorderEngine.stopRecording())
            }
            "isRecording" -> {
                result.success(CallRecorderEngine.isRecording)
            }
            "getRecordingInfo" -> {
                result.success(mapOf(
                    "isRecording" to CallRecorderEngine.isRecording,
                    "path" to CallRecorderEngine.currentPath,
                    "source" to CallRecorderEngine.activeSource,
                    "durationMs" to CallRecorderEngine.getElapsedMs()
                ))
            }
            "getDeviceCapabilities" -> {
                result.success(mapOf(
                    "androidVersion" to Build.VERSION.SDK_INT,
                    "supportsVoiceCommunication" to (Build.VERSION.SDK_INT < 30),
                    "supportsCallCapture" to false,
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL
                ))
            }
            else -> result.notImplemented()
        }
    }

    // ── Overlay Method Handler ──

    private fun handleOverlayMethod(
        method: String,
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        val ctx = applicationContext
        val act = activity

        when (method) {
            "hasOverlayPermission" -> {
                val hasPermission = if (ctx != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(ctx)
                } else {
                    true
                }
                result.success(hasPermission)
            }
            "requestOverlayPermission" -> {
                if (act != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(act)) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${act.packageName}")
                        )
                        act.startActivity(intent)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to open overlay settings: ${e.message}")
                    }
                }
                result.success(true)
            }
            "showOverlay" -> {
                if (ctx != null) {
                    try {
                        val intent = Intent(ctx, FloatingButtonService::class.java)
                        intent.action = FloatingButtonService.ACTION_SHOW
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ctx.startForegroundService(intent)
                        } else {
                            ctx.startService(intent)
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to show overlay: ${e.message}")
                    }
                }
                result.success(true)
            }
            "hideOverlay" -> {
                if (ctx != null) {
                    try {
                        val intent = Intent(ctx, FloatingButtonService::class.java)
                        intent.action = FloatingButtonService.ACTION_HIDE
                        ctx.startService(intent)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to hide overlay: ${e.message}")
                    }
                }
                result.success(true)
            }
            "updateOverlayState" -> {
                val recording = call.argument<Boolean>("recording") ?: false
                val seconds = call.argument<Int>("seconds") ?: 0
                FloatingButtonService.updateState(recording, seconds)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
