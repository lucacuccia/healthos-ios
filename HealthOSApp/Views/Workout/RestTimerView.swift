import SwiftUI

struct RestTimerView: View {
    // Owned here rather than by WorkoutDayView: the timer publishes every 10ms,
    // and observing it higher up re-rendered the whole Workout screen (and any
    // sheet it presents) at that rate, which swallowed taps on segmented pickers.
    @StateObject private var vm = RestTimerViewModel()

    var body: some View {
        HStack(spacing: 16) {
            Button { vm.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .disabled(!vm.isRunning && vm.elapsedTime == 0)

            Text(vm.displayTime)
                .font(.title.bold())
                .monospacedDigit()

            Button { vm.toggle() } label: {
                Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}
