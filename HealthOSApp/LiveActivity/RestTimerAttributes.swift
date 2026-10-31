import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
    /// An activity goes stale this long after its last update, so one orphaned
    /// by a force-quit stops counting instead of running to the 8-hour limit.
    static let staleInterval: TimeInterval = 30 * 60

    public struct ContentState: Codable, Hashable {
        /// Wall-clock start of the current running segment.
        var startDate: Date
        /// True when the timer is paused; widget shows a static frozen time.
        var isPaused: Bool
        /// Seconds accumulated in all previous segments (before the current start).
        var accumulatedSeconds: Double
    }
}
