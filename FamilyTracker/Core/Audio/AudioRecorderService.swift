import AVFoundation
import Foundation

enum AudioRecorderEvent {
    case elapsed(TimeInterval)
    case reachedLimit(VoiceAttachmentInput)
    case interrupted
}

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case couldNotStart
    case invalidRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Vui lòng cấp quyền micro trong Cài đặt để gửi tin nhắn thoại."
        case .couldNotStart: return "Không thể bắt đầu ghi âm."
        case .invalidRecording: return "Bản ghi âm không hợp lệ."
        }
    }
}

@MainActor
final class AudioRecorderService: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var timerTask: Task<Void, Never>?
    private var continuation: AsyncStream<AudioRecorderEvent>.Continuation?

    lazy var events: AsyncStream<AudioRecorderEvent> = AsyncStream { [weak self] continuation in
        self?.continuation = continuation
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(interrupted(_:)),
            name: AVAudioSession.interruptionNotification, object: nil
        )
    }

    deinit {
        timerTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func start() async throws {
        guard await microphoneAllowed() else { throw AudioRecorderError.permissionDenied }
        cancel()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString)")
            .appendingPathExtension(MediaUploadPolicy.voiceExtension)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record(forDuration: MediaUploadPolicy.maxVoiceDuration) else {
            throw AudioRecorderError.couldNotStart
        }
        self.recorder = recorder
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self, let recorder = self.recorder else { return }
                self.continuation?.yield(.elapsed(recorder.currentTime))
                if recorder.currentTime >= MediaUploadPolicy.maxVoiceDuration - 0.1 {
                    do { self.continuation?.yield(.reachedLimit(try self.stop())) }
                    catch { self.cancel() }
                    return
                }
            }
        }
    }

    func stop() throws -> VoiceAttachmentInput {
        guard let recorder else { throw AudioRecorderError.invalidRecording }
        let duration = recorder.currentTime
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        timerTask?.cancel()
        timerTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let size = ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        guard duration > 0, duration <= MediaUploadPolicy.maxVoiceDuration,
              size > 0, size <= MediaUploadPolicy.maxVoiceBytes else {
            try? FileManager.default.removeItem(at: url)
            throw MediaUploadError.invalidMedia("Bản ghi phải dưới 15 phút và 25 MB.")
        }
        return VoiceAttachmentInput(fileURL: url, duration: duration, fileSize: size,
                                    mimeType: MediaUploadPolicy.voiceMimeType)
    }

    func cancel() {
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        timerTask?.cancel()
        timerTask = nil
        if let url { try? FileManager.default.removeItem(at: url) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func microphoneAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    @objc private func interrupted(_ notification: Notification) {
        guard recorder != nil else { return }
        cancel()
        continuation?.yield(.interrupted)
    }
}
