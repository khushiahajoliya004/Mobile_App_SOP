package com.callrecorder.call_recorder_app

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
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
        private const val UPLOAD_URL_PATH = "/calls/upload-url"

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
            val notesText = "Auto-recorded $callType call | Duration: ${durationMs / 1000}s"
            val phoneOrNull = if (phoneNumber != "unknown") phoneNumber else null

            // Direct-to-S3: the file goes straight to S3 instead of being
            // relayed through this server. There is no server-relay fallback —
            // the backend no longer accepts a multipart file on POST /calls,
            // so any failure here (presign, S3 PUT, or the final metadata
            // call) throws and this whole attempt is retried by WorkManager.
            val (uploadUrl, audioUrl) = getUploadUrl(token, "audio/mp4", "m4a")
                ?: throw Exception("Failed to get S3 upload URL")
            if (!putFileToS3(uploadUrl, audioFile, "audio/mp4")) {
                throw Exception("Direct S3 upload failed")
            }
            val success = uploadCallDirect(
                token = token,
                audioUrl = audioUrl,
                phoneNumber = phoneOrNull,
                customerName = customerName,
                userId = userId,
                companyId = companyId,
                notes = notesText,
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

    /** Asks the backend for a short-lived S3 upload URL. Returns (uploadUrl, audioUrl) or null on failure. */
    private fun getUploadUrl(token: String, contentType: String, extension: String): Pair<String, String>? {
        val url = URL("$BASE_URL$UPLOAD_URL_PATH")
        val connection = url.openConnection() as HttpURLConnection
        connection.apply {
            requestMethod = "POST"
            doOutput = true
            doInput = true
            connectTimeout = 30_000
            readTimeout = 30_000
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "application/json")
        }

        val body = JSONObject().apply {
            put("contentType", contentType)
            put("extension", extension)
            put("fileType", "audio")
        }
        connection.outputStream.use { it.write(body.toString().toByteArray()) }

        val responseCode = connection.responseCode
        if (responseCode !in 200..299) {
            Log.w(TAG, "getUploadUrl response code: $responseCode")
            connection.disconnect()
            return null
        }

        val responseText = connection.inputStream.bufferedReader().use { it.readText() }
        connection.disconnect()
        val data = JSONObject(responseText).getJSONObject("data")
        return Pair(data.getString("uploadUrl"), data.getString("audioUrl"))
    }

    /** PUTs the raw audio bytes directly to S3 via the presigned URL. */
    private fun putFileToS3(uploadUrl: String, audioFile: File, contentType: String): Boolean {
        val connection = URL(uploadUrl).openConnection() as HttpURLConnection
        connection.apply {
            requestMethod = "PUT"
            doOutput = true
            connectTimeout = 30_000
            readTimeout = 300_000
            setRequestProperty("Content-Type", contentType)
        }
        connection.outputStream.use { out ->
            FileInputStream(audioFile).use { it.copyTo(out) }
        }
        val responseCode = connection.responseCode
        Log.i(TAG, "S3 PUT response code: $responseCode")
        connection.disconnect()
        return responseCode in 200..299
    }

    /** Sends call metadata + an already-uploaded S3 audioUrl (no file in this request). */
    private fun uploadCallDirect(
        token: String,
        audioUrl: String,
        phoneNumber: String?,
        customerName: String,
        userId: String,
        companyId: String,
        notes: String,
    ): Boolean {
        val url = URL("$BASE_URL$UPLOAD_PATH")
        val connection = url.openConnection() as HttpURLConnection
        connection.apply {
            requestMethod = "POST"
            doOutput = true
            doInput = true
            connectTimeout = 30_000
            readTimeout = 30_000
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "application/json")
        }

        val body = JSONObject().apply {
            put("customerName", customerName)
            if (!phoneNumber.isNullOrEmpty()) put("phoneNumber", phoneNumber)
            put("userId", userId)
            put("companyId", companyId)
            put("notes", notes)
            put("audioUrl", audioUrl)
            put("audioFileType", "audio")
        }
        connection.outputStream.use { it.write(body.toString().toByteArray()) }

        val responseCode = connection.responseCode
        Log.i(TAG, "Direct upload response code: $responseCode")
        connection.disconnect()
        return responseCode in 200..299
    }
}
