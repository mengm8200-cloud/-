import AVFoundation
import SwiftUI

/// Records one voice clip at a time.
@MainActor
final class VoiceRecorder: ObservableObject {
    static let maxDuration: TimeInterval = 60
    private static let minDurationMs = 500

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var ticker: Task<Void, Never>?

    /// Asks for microphone access if needed, then starts recording.
    /// Returns a message for the user when recording could not start.
    func start() async -> String? {
        guard !isRecording else { return nil }
        guard await AVAudioApplication.requestRecordPermission() else {
            return "没有麦克风权限，请在系统设置里允许使用麦克风。"
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().lower).m4a")
            // Speech-quality mono AAC keeps a one-minute clip around 250 KB.
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22050,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32000,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.record(forDuration: VoiceRecorder.maxDuration) else {
                return "无法开始录音，请稍后再试。"
            }
            self.recorder = recorder
            fileURL = url
            elapsed = 0
            isRecording = true
            startTicking()
            return nil
        } catch {
            return "无法开始录音，请稍后再试。"
        }
    }

    /// Stops recording and hands back the clip, or nil when it is too short to send.
    func finish() -> (url: URL, durationMs: Int)? {
        guard let recorder, let fileURL else { return nil }
        // Once the time limit stops the recorder, its own clock reads zero again.
        let seconds = recorder.isRecording ? recorder.currentTime : elapsed
        recorder.stop()
        reset()
        let durationMs = min(Int((seconds * 1000).rounded()), Int(VoiceRecorder.maxDuration * 1000))
        guard durationMs >= VoiceRecorder.minDurationMs else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return (fileURL, durationMs)
    }

    func cancel() {
        recorder?.stop()
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        reset()
    }

    private func reset() {
        ticker?.cancel()
        ticker = nil
        recorder = nil
        fileURL = nil
        isRecording = false
        elapsed = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let recorder = self.recorder else { return }
                if recorder.isRecording {
                    self.elapsed = recorder.currentTime
                } else {
                    // The time limit was reached; keep the clip until the user sends or cancels.
                    self.elapsed = VoiceRecorder.maxDuration
                    return
                }
            }
        }
    }
}

/// Keeps downloaded voice clips on disk so replaying does not download again.
enum VoiceCache {
    private static let directory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches.appendingPathComponent("voice", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private static func file(for path: String) -> URL {
        directory.appendingPathComponent(path.replacingOccurrences(of: "/", with: "_"))
    }

    static func store(_ data: Data, for path: String) {
        try? data.write(to: file(for: path), options: .atomic)
    }

    static func data(for path: String) async throws -> Data {
        if let cached = try? Data(contentsOf: file(for: path)) {
            return cached
        }
        let data = try await Backend.shared.download(bucket: "chat-media", path: path)
        store(data, for: path)
        return data
    }
}

/// Plays one voice message at a time.
@MainActor
final class VoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = VoicePlayer()

    @Published private(set) var playingId: UUID?
    @Published private(set) var loadingId: UUID?

    private var player: AVAudioPlayer?

    private override init() {
        super.init()
    }

    /// Starts the clip, or stops it when it is the one already playing.
    func toggle(messageId: UUID, path: String) {
        if playingId == messageId || loadingId == messageId {
            stop()
            return
        }
        stop()
        loadingId = messageId
        Task {
            do {
                let data = try await VoiceCache.data(for: path)
                // The user may have tapped another clip while this one was downloading.
                guard loadingId == messageId else { return }
                loadingId = nil
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                let player = try AVAudioPlayer(data: data)
                player.delegate = self
                self.player = player
                playingId = messageId
                player.play()
            } catch {
                if loadingId == messageId {
                    loadingId = nil
                }
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingId = nil
        loadingId = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            // Ignore the callback of a clip that was already replaced by another one.
            guard self.player === player else { return }
            self.player = nil
            self.playingId = nil
        }
    }
}

/// Chat bubble for a voice message: tap to play, tap again to stop.
struct VoiceBubble: View {
    let message: Message
    let isMine: Bool

    @ObservedObject private var player = VoicePlayer.shared

    init(message: Message, isMine: Bool) {
        self.message = message
        self.isMine = isMine
    }

    private var seconds: Int {
        max(1, Int((Double(message.durationMs ?? 0) / 1000).rounded()))
    }

    /// Longer clips get wider bubbles, as a quick visual cue of their length.
    private var width: CGFloat {
        84 + CGFloat(min(seconds, 60)) * 2.2
    }

    var body: some View {
        Button {
            if let path = message.mediaPath {
                player.toggle(messageId: message.id, path: path)
            }
        } label: {
            HStack(spacing: 8) {
                if player.loadingId == message.id {
                    ProgressView()
                        .tint(isMine ? Color.white : Color.accentColor)
                } else {
                    Image(systemName: player.playingId == message.id ? "stop.fill" : "play.fill")
                }
                Text("\(seconds)″")
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(width: width, alignment: .leading)
            .foregroundStyle(isMine ? Color.white : Color.primary)
            .background(isMine ? Color.accentColor : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("语音消息，\(seconds) 秒")
        .accessibilityHint(player.playingId == message.id ? "轻点停止播放" : "轻点播放")
    }
}
