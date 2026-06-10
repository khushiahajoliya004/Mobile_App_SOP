import Foundation
import AVFoundation
import UIKit

/// Production-level Audio Recorder Manager for iOS 13+
/// Supports background recording, interruption handling, and app lifecycle management.
class AudioRecorderManager: NSObject, AVAudioRecorderDelegate {
    
    static let shared = AudioRecorderManager()
    
    // MARK: - Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    private var recordingTimer: Timer?
    private var currentFileURL: URL?
    private var recordingStartTime: Date?
    private var accumulatedDuration: TimeInterval = 0
    private var isPaused = false
    
    // Callbacks
    var onRecordingStateChanged: ((Bool) -> Void)?
    var onDurationUpdate: ((TimeInterval) -> Void)?
    var onError: ((String) -> Void)?
    var onRecordingFinished: ((URL, TimeInterval) -> Void)?
    
    // MARK: - Permission
    
    enum PermissionStatus: String {
        case granted
        case denied
        case undetermined
    }
    
    func checkPermissionStatus() -> PermissionStatus {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            default: return .undetermined
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            default: return .undetermined
            }
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        recordingSession = session
        
        // playAndRecord keeps audio session alive in background
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Register for interruption notifications
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // MARK: - Recording Control
    
    func startRecording() -> Bool {
        guard checkPermissionStatus() == .granted else {
            onError?("Microphone permission not granted")
            return false
        }
        
        do {
            try configureAudioSession()
        } catch {
            onError?("Failed to configure audio session: \(error.localizedDescription)")
            return false
        }
        
        // Generate file URL
        let fileName = "recording_\(Int(Date().timeIntervalSince1970 * 1000)).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileURL = documentsPath.appendingPathComponent(fileName)
        currentFileURL = audioFileURL
        
        // Recording settings (AAC, high quality)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000,
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            let started = audioRecorder?.record() ?? false
            if started {
                recordingStartTime = Date()
                accumulatedDuration = 0
                isPaused = false
                startTimer()
                onRecordingStateChanged?(true)
                return true
            } else {
                onError?("Failed to start recording")
                return false
            }
        } catch {
            onError?("Failed to create recorder: \(error.localizedDescription)")
            return false
        }
    }
    
    func stopRecording() -> (URL?, TimeInterval) {
        guard let recorder = audioRecorder, recorder.isRecording || isPaused else {
            return (nil, 0)
        }
        
        let duration = getCurrentDuration()
        recorder.stop()
        stopTimer()
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch { }
        
        isPaused = false
        onRecordingStateChanged?(false)
        
        if let url = currentFileURL {
            onRecordingFinished?(url, duration)
            return (url, duration)
        }
        return (nil, duration)
    }
    
    func pauseRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        accumulatedDuration += Date().timeIntervalSince(recordingStartTime ?? Date())
        recorder.pause()
        isPaused = true
        stopTimer()
    }
    
    func resumeRecording() {
        guard let recorder = audioRecorder, isPaused else { return }
        recordingStartTime = Date()
        recorder.record()
        isPaused = false
        startTimer()
    }
    
    func getCurrentDuration() -> TimeInterval {
        if isPaused { return accumulatedDuration }
        guard let start = recordingStartTime else { return accumulatedDuration }
        return accumulatedDuration + Date().timeIntervalSince(start)
    }
    
    var isRecording: Bool { return audioRecorder?.isRecording ?? false }
    var recordingFileURL: URL? { return currentFileURL }
    
    // MARK: - Timer
    
    private func startTimer() {
        stopTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.onDurationUpdate?(self.getCurrentDuration())
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Interruption Handling (incoming calls, Siri, etc.)
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            if isRecording { pauseRecording() }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    resumeRecording()
                } catch {
                    onError?("Failed to resume after interruption: \(error.localizedDescription)")
                }
            }
        @unknown default: break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        // Recording continues regardless of route change
    }
    
    // MARK: - App Lifecycle (background recording continues via audio background mode)
    
    @objc private func appDidEnterBackground() {
        // No action needed — AVAudioRecorder continues in background with audio mode
    }
    
    @objc private func appWillEnterForeground() {
        if isRecording { startTimer() }
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { onError?("Recording finished with error") }
        stopTimer()
        onRecordingStateChanged?(false)
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        onError?("Encoding error: \(error?.localizedDescription ?? "Unknown")")
        stopTimer()
        onRecordingStateChanged?(false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopTimer()
    }
}
