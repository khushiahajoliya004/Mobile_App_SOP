package com.callrecorder.call_recorder_app

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL

class CallUploadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "CallUploadWorker"
        const val KEY_FILE_PATH = "filePath"
        const val KEY_META_PATH = "metaPath"

        // Must match api_service.dart baseUrl
        private const val BASE_URL = "https://api.mysterymentor.in"
        private const val UPLOAD_PATH = "/calls"

        // SharedPreferences keys — must match Flutter's auth_service.dart
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TOKEN = "flutter.auth_token"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val filePath = inputData.getString(KEY_FILE_PATH)
        val metaPath = inputData.getString(KEY_META_PATH)

        if (filePath == null) {
            Log.e(TAG, "No file path provided")
            return@withContext Result.failure()
        }

        val audioFile = File(filePath)
        if (!audioFile.exists()) {
            Log.e(TAG, "Audio file not found: $filePath")
            return@withContext Result.failure()
        }

        // Read auth token and user info from SharedPreferences (written by Flutter)
        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)
        val userId = prefs.getString("flutter.native_user_id", null)
        val companyId = prefs.getString("flutter.native_company_id", null)

        if (token == null || userId.isNullOrEmpty() || companyId.isNullOrEmpty()) {
            Log.e(TAG, "Missing auth token, userId or companyId — user not logged in")
            return@withContext Result.failure()
        }

        // Read metadata (phone number, call type, duration)
        var phoneNumber = "unknown"
        var callType = "unknown"
        var durationMs = 0L

        if (metaPath != null) {
            val metaFile = File(metaPath)
            if (metaFile.exists()) {
                try {
                    val meta = JSONObject(metaFile.readText())
                    phoneNumber = meta.optString("phoneNumber", "unknown")
                    callType = meta.optString("callType", "unknown")
                    durationMs = meta.optLong("durationMs", 0L)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to read metadata: ${e.message}")
                }
            }
        }

        Log.i(TAG, "Uploading call: $filePath | phone: $phoneNumber | type: $callType")

        // Use phone number as customerName so it appears in the UI;
        // the backend will normalize it to the phoneNumber field automatically.
        val customerName = if (phoneNumber != "unknown") phoneNumber else "Auto-recorded call"

        return@withContext try {
            val success = uploadCall(
                token = token,
                audioFile = audioFile,
                phoneNumber = if (phoneNumber != "unknown") phoneNumber else null,
                customerName = customerName,
                userId = userId,
                companyId = companyId,
                notes = "Auto-recorded $callType call | Duration: ${durationMs / 1000}s"
            )

            if (success) {
                Log.i(TAG, "Upload successful, deleting local files")
                audioFile.delete()
                metaPath?.let { File(it).delete() }
                Result.success()
            } else {
                Log.w(TAG, "Upload failed, will retry")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Upload error: ${e.message}", e)
            Result.retry()
        }
    }

    private fun uploadCall(
        token: String,
        audioFile: File,
        phoneNumber: String?,
        customerName: String,
        userId: String,
        companyId: String,
        notes: String
    ): Boolean {
        val boundary = "------Boundary${System.currentTimeMillis()}"
        val url = URL("$BASE_URL$UPLOAD_PATH")
        val connection = url.openConnection() as HttpURLConnection

        connection.apply {
            requestMethod = "POST"
            doOutput = true
            doInput = true
            connectTimeout = 30_000
            readTimeout = 300_000
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
        }

        val out = DataOutputStream(connection.outputStream)

        fun writeField(name: String, value: String) {
            out.writeBytes("--$boundary\r\n")
            out.writeBytes("Content-Disposition: form-data; name=\"$name\"\r\n\r\n")
            out.writeBytes("$value\r\n")
        }

        writeField("customerName", customerName)
        if (!phoneNumber.isNullOrEmpty()) writeField("phoneNumber", phoneNumber)
        writeField("userId", userId)
        writeField("companyId", companyId)
        writeField("notes", notes)

        // Write audio file
        out.writeBytes("--$boundary\r\n")
        out.writeBytes("Content-Disposition: form-data; name=\"audio\"; filename=\"${audioFile.name}\"\r\n")
        out.writeBytes("Content-Type: audio/mp4\r\n\r\n")
        FileInputStream(audioFile).use { it.copyTo(out) }
        out.writeBytes("\r\n")

        out.writeBytes("--$boundary--\r\n")
        out.flush()
        out.close()

        val responseCode = connection.responseCode
        Log.i(TAG, "Upload response code: $responseCode")
        connection.disconnect()

        return responseCode in 200..299
    }
}
