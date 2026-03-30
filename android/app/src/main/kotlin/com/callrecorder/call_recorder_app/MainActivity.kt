package com.callrecorder.call_recorder_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity: Entry point for the Flutter app.
 *
 * Channel registration is handled by CallRecorderPlugin.
 * CallMonitorService is NOT auto-started here — it is started
 * from Flutter only after the user grants all required permissions
 * and taps "Start" on the recorder screen.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(CallRecorderPlugin())
    }
}
