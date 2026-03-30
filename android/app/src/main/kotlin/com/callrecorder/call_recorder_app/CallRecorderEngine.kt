package com.callrecorder.call_recorder_app

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import android.util.Log

/**
 * CallRecorderEngine: Core native recording engine.
 *
 * Attempts audio sources in priority order:
 * 1. VOICE_COMMUNICATION - captures both sides on supported devices (pre-Android 10)
 * 2. VOICE_RECOGNITION - good quality mic input, some devices capture call audio
 * 3. MIC - universal fallback, captures microphone only
 *
 * On Android 10+ (API 29+), Google restricted VOICE_CALL and CAPTURE_AUDIO_OUTPUT
 * to system/privileged apps. VOICE_COMMUNICATION may still work on some OEMs.
 *
 * For VoIP calls (WhatsApp, etc.), only MIC source works as a fallback since
 * VoIP apps use their own audio routing. The recording captures the user's
 * microphone audio and whatever leaks through the speaker.
 */
object CallRecorderEngine {

    private const val TAG = "CallRecorderEngine"

    private var mediaRecorder: MediaRecorder? = null
    var isRecording: Boolean = false
        private set
    var currentPath: String? = null
        private set
    var activeSource: String = "none"
        private set
    private var startTimeMs: Long = 0L

    /**
     * Start recording to the given file path.
     * @param path Output file path (.m4a)
     * @param preferredSource Hint: "voice_communication", "voice_recognition", or "mic"
     * @param context Android context
     * @return true if recording started successfully
     */
    fun startRecording(path: String, preferredSource: String, context: Context): Boolean {
        if (isRecording) {
            Log.w(TAG, "Already recording, stopping previous session")
            stopRecording()
        }

        // Build ordered list of audio sources to try
        val sources = buildSourceList(preferredSource)

        for ((sourceName, sourceId) in sources) {
            try {
                val recorder = createRecorder(context)
                recorder.apply {
                    setAudioSource(sourceId)
                    setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    setAudioEncodingBitRate(128000)
                    setAudioSamplingRate(44100)
                    setOutputFile(path)
                    prepare()
                    start()
                }
                mediaRecorder = recorder
                currentPath = path
                activeSource = sourceName
                isRecording = true
                startTimeMs = SystemClock.elapsedRealtime()
                Log.i(TAG, "Recording started with source: $sourceName -> $path")
                return true
            } catch (e: Exception) {
                Log.w(TAG, "Source $sourceName failed: ${e.message}")
                try { mediaRecorder?.release() } catch (_: Exception) {}
                mediaRecorder = null
            }
        }

        Log.e(TAG, "All audio sources failed for path: $path")
        isRecording = false
        return false
    }

    /**
     * Stop recording and return info about the completed recording.
     * @return Map with path, duration, source info; or null values if not recording
     */
    fun stopRecording(): Map<String, Any?> {
        val path = currentPath
        val source = activeSource
        val durationMs = getElapsedMs()

        try {
            if (isRecording) {
                mediaRecorder?.stop()
                Log.i(TAG, "Recording stopped: $path (${durationMs}ms, source: $source)")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping recorder: ${e.message}")
        }

        try {
            mediaRecorder?.release()
        } catch (_: Exception) {}

        mediaRecorder = null
        isRecording = false
        currentPath = null
        activeSource = "none"
        startTimeMs = 0L

        return mapOf(
            "path" to path,
            "durationMs" to durationMs,
            "source" to source
        )
    }

    /**
     * Get elapsed recording time in milliseconds.
     */
    fun getElapsedMs(): Long {
        return if (isRecording && startTimeMs > 0) {
            SystemClock.elapsedRealtime() - startTimeMs
        } else 0L
    }

    /**
     * Build prioritized list of audio sources based on preference and device capabilities.
     */
    private fun buildSourceList(preferred: String): List<Pair<String, Int>> {
        val all = mutableListOf<Pair<String, Int>>()

        // On Android 10+ (API 29), VOICE_COMMUNICATION is restricted on many devices
        // but still works on some OEMs (Samsung, Xiaomi, etc.)
        when (preferred) {
            "voice_communication" -> {
                all.add("voice_communication" to MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                all.add("voice_recognition" to MediaRecorder.AudioSource.VOICE_RECOGNITION)
                all.add("mic" to MediaRecorder.AudioSource.MIC)
            }
            "voice_recognition" -> {
                all.add("voice_recognition" to MediaRecorder.AudioSource.VOICE_RECOGNITION)
                all.add("voice_communication" to MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                all.add("mic" to MediaRecorder.AudioSource.MIC)
            }
            else -> {
                all.add("mic" to MediaRecorder.AudioSource.MIC)
                all.add("voice_communication" to MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                all.add("voice_recognition" to MediaRecorder.AudioSource.VOICE_RECOGNITION)
            }
        }

        return all
    }

    /**
     * Create MediaRecorder instance compatible with current API level.
     */
    private fun createRecorder(context: Context): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
    }
}
