import Flutter
import UIKit
import AVFoundation

/// Flutter Method Channel plugin for native iOS audio recording with background support.
class AudioRecorderPlugin: NSObject, FlutterPlugin {
    
    private let recorder = AudioRecorderManager.shared
    private var channel: FlutterMethodChannel?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.callrecorder/native_recorder", binaryMessenger: registrar.messenger())
        let instance = AudioRecorderPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.setupCallbacks()
    }
    
    private func setupCallbacks() {
        recorder.onRecordingStateChanged = { [weak self] isRecording in
            self?.channel?.invokeMethod("onRecordingStateChanged", arguments: isRecording)
        }
        recorder.onDurationUpdate = { [weak self] duration in
            self?.channel?.invokeMethod("onDurationUpdate", arguments: Int(duration))
        }
        recorder.onError = { [weak self] error in
            self?.channel?.invokeMethod("onError", arguments: error)
        }
        recorder.onRecordingFinished = { [weak self] url, duration in
            self?.channel?.invokeMethod("onRecordingFinished", arguments: ["path": url.path, "duration": Int(duration)])
        }
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkPermission":
            result(recorder.checkPermissionStatus().rawValue)
            
        case "requestPermission":
            recorder.requestPermission { granted in result(granted) }
            
        case "openSettings":
            recorder.openAppSettings()
            result(nil)
            
        case "startRecording":
            result(recorder.startRecording())
            
        case "stopRecording":
            let (url, duration) = recorder.stopRecording()
            result(["path": url?.path ?? "", "duration": Int(duration)])
            
        case "pauseRecording":
            recorder.pauseRecording()
            result(nil)
            
        case "resumeRecording":
            recorder.resumeRecording()
            result(nil)
            
        case "isRecording":
            result(recorder.isRecording)
            
        case "getDuration":
            result(Int(recorder.getCurrentDuration()))
            
        case "getFilePath":
            result(recorder.recordingFileURL?.path)
            
        case "queryAudioFiles":
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                let audioFiles: [[String: Any]] = files
                    .filter { ["m4a", "wav", "mp3", "aac"].contains($0.pathExtension.lowercased()) }
                    .sorted { (a, b) in
                        let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                        let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                        return dateA > dateB
                    }
                    .compactMap { url -> [String: Any]? in
                        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                        let size = (attrs?[.size] as? Int) ?? 0
                        let date = (attrs?[.modificationDate] as? Date) ?? Date()
                        var durationMs = 0
                        if let audioFile = try? AVAudioFile(forReading: url) {
                            let frames = audioFile.length
                            let sampleRate = audioFile.processingFormat.sampleRate
                            if sampleRate > 0 { durationMs = Int((Double(frames) / sampleRate) * 1000) }
                        }
                        return [
                            "name": url.lastPathComponent,
                            "path": url.path,
                            "size": size,
                            "duration": durationMs,
                            "dateModified": Int(date.timeIntervalSince1970)
                        ]
                    }
                result(audioFiles)
            } catch {
                result([])
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
