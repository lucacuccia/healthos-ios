import ActivityKit
import WidgetKit
import SwiftUI

struct RestTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context: context)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Rest Timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if context.state.isPaused {
                            Text("Paused")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                compactTimerText(context: context)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(width: 44, alignment: .center)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }

    // Compact pill: uses Text(date, style: .timer) which sizes predictably at "M:SS"
    @ViewBuilder
    private func compactTimerText(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        let state = context.state
        if context.isStale {
            Text(formatSeconds(frozenSeconds(context)))
                .opacity(0.5)
        } else if state.isPaused {
            Text(formatSeconds(state.accumulatedSeconds))
        } else {
            let effectiveStart = state.startDate.addingTimeInterval(-state.accumulatedSeconds)
            Text(effectiveStart, style: .timer)
        }
    }

    @ViewBuilder
    private func timerText(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        let state = context.state
        if context.isStale {
            Text(formatSeconds(frozenSeconds(context)))
                .opacity(0.5)
        } else if state.isPaused {
            Text(formatSeconds(state.accumulatedSeconds))
        } else {
            // Bake accumulated time into the start date so the widget renders
            // total elapsed time without any app-side updates.
            let effectiveStart = state.startDate.addingTimeInterval(-state.accumulatedSeconds)
            // Cap at 99:59 so SwiftUI sizes the view for M:SS format, not H:MM:SS
            let cappedEnd = effectiveStart.addingTimeInterval(5999)
            Text(timerInterval: effectiveStart...cappedEnd, countsDown: false)
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest Timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if context.isStale {
                    Text(formatSeconds(frozenSeconds(context)))
                        .font(.title3.bold().monospacedDigit())
                        .opacity(0.5)
                } else if context.state.isPaused {
                    Text(formatSeconds(context.state.accumulatedSeconds))
                        .font(.title3.bold().monospacedDigit())
                } else {
                    let effectiveStart = context.state.startDate
                        .addingTimeInterval(-context.state.accumulatedSeconds)
                    Text(timerInterval: effectiveStart...Date.distantFuture, countsDown: false)
                        .font(.title3.bold().monospacedDigit())
                }
            }

            Spacer()

            if context.state.isPaused {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Time to show once the activity is stale (the app stopped updating it, e.g.
/// after a force-quit). A running timer goes stale `staleInterval` after its
/// segment started, so that's where it freezes.
private func frozenSeconds(_ context: ActivityViewContext<RestTimerAttributes>) -> Double {
    let state = context.state
    return state.isPaused
        ? state.accumulatedSeconds
        : state.accumulatedSeconds + RestTimerAttributes.staleInterval
}
