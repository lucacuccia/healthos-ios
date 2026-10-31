import Foundation
import UIKit
import AVFoundation
import ActivityKit
import UserNotifications

@MainActor
class RestTimerViewModel: ObservableObject {
    @Published private var accumulatedTime: TimeInterval = 0
    @Published private var startDate: Date?

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var chimesFired = Set<Int>()
    private var pendingChimes: Int = 0
    private var nextChimeAt: Date = .distantPast
    private var liveActivity: Activity<RestTimerAttributes>?

    // Milestones: elapsed seconds → number of chimes
    private let chimeMilestones: [(seconds: Int, count: Int)] = [(60, 1), (75, 2), (90, 3)]

    var isRunning: Bool { startDate != nil }

    var elapsedTime: TimeInterval {
        accumulatedTime + (startDate.map { Date().timeIntervalSince($0) } ?? 0)
    }

    var displayTime: String {
        let total = elapsedTime
        let totalSeconds = Int(total)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centiseconds = Int((total - Double(totalSeconds)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
    }

    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        accumulatedTime = 0
        chimesFired.removeAll()
        pendingChimes = 0
        nextChimeAt = .distantPast
        cancelChimeNotifications()
        endLiveActivity()
    }

    private func start() {
        startDate = Date()
        let t = Timer(timeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                self.checkChimes()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        requestNotificationPermissionIfNeeded()
        scheduleChimeNotifications()
        startOrUpdateLiveActivity()
    }

    private func pause() {
        if let start = startDate {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        startDate = nil
        timer?.invalidate()
        timer = nil
        cancelChimeNotifications()
        pauseLiveActivity()
    }

    private func checkChimes() {
        // Enqueue chimes when a milestone is crossed
        let elapsed = Int(elapsedTime)
        for milestone in chimeMilestones {
            if elapsed >= milestone.seconds && !chimesFired.contains(milestone.seconds) {
                chimesFired.insert(milestone.seconds)
                pendingChimes = milestone.count
                nextChimeAt = .distantPast
            }
        }

        // Play one chime per tick when due (0.4s spacing between chimes)
        let now = Date()
        if pendingChimes > 0 && now >= nextChimeAt {
            playTone()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            pendingChimes -= 1
            nextChimeAt = now.addingTimeInterval(0.4)
        }
    }

    private func playTone() {
        let sampleRate: Double = 44100
        let duration: Double = 0.35
        let frequency: Double = 880
        let amplitude: Double = 0.9
        let numSamples = Int(sampleRate * duration)

        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1 - t / duration)
            samples[i] = Int16(envelope * amplitude * Double(Int16.max) * sin(2 * .pi * frequency * t))
        }

        let dataSize = numSamples * 2
        var wav = Data()
        // RIFF header
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Array($0) })
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })   // chunk size
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })    // PCM
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })    // mono
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) }) // sample rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) }) // byte rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })    // block align
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })   // bits per sample
        wav.append(contentsOf: Array("data".utf8))
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        samples.withUnsafeBytes { wav.append(contentsOf: $0) }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: wav)
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        } catch {}
    }

    // MARK: - Background chime notifications

    private static let chimeNotificationCategory = "REST_TIMER_CHIME"

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { _, _ in }
    }

    private func scheduleChimeNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: chimeNotificationIds())

        for milestone in chimeMilestones {
            guard !chimesFired.contains(milestone.seconds) else { continue }
            let fireDelay = Double(milestone.seconds) - accumulatedTime
            guard fireDelay > 0 else { continue }

            for chimeIndex in 0..<milestone.count {
                let delay = fireDelay + Double(chimeIndex) * 0.4
                let content = UNMutableNotificationContent()
                content.sound = .default
                // No title/body — the sound is all we need
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let id = "chime_\(milestone.seconds)_\(chimeIndex)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    private func cancelChimeNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: chimeNotificationIds())
    }

    private func chimeNotificationIds() -> [String] {
        chimeMilestones.flatMap { m in (0..<m.count).map { "chime_\(m.seconds)_\($0)" } }
    }

    // MARK: - Live Activity

    private func startOrUpdateLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let sd = startDate else { return }

        // Bake accumulated time into the start date so the widget can use
        // Text(timerInterval:) to show total elapsed time without app-side updates.
        let state = RestTimerAttributes.ContentState(
            startDate: sd,
            isPaused: false,
            accumulatedSeconds: accumulatedTime
        )
        let content = ActivityContent(
            state: state,
            staleDate: sd.addingTimeInterval(RestTimerAttributes.staleInterval)
        )

        if let activity = liveActivity {
            Task { await activity.update(content) }
        } else {
            do {
                liveActivity = try Activity<RestTimerAttributes>.request(
                    attributes: RestTimerAttributes(),
                    content: content,
                    pushType: nil
                )
            } catch {
                // Live Activities unavailable on this device/simulator — silently ignore.
                print("Live Activity request failed: \(error)")
            }
        }
    }

    private func pauseLiveActivity() {
        guard let activity = liveActivity else { return }
        let state = RestTimerAttributes.ContentState(
            startDate: Date(),   // sentinel; widget ignores this when isPaused = true
            isPaused: true,
            accumulatedSeconds: accumulatedTime
        )
        let staleDate = Date().addingTimeInterval(RestTimerAttributes.staleInterval)
        Task { await activity.update(ActivityContent(state: state, staleDate: staleDate)) }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        liveActivity = nil
        Task { await activity.end(ActivityContent(state: activity.content.state, staleDate: nil),
                                  dismissalPolicy: .immediate) }
    }

    deinit {
        timer?.invalidate()
    }
}
