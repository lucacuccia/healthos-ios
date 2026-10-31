import SwiftUI

struct WorkoutHistoryView: View {
    @ObservedObject var vm: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewMode: ViewMode = .calendar
    @State private var expandedWorkoutIds: Set<String> = []
    @State private var visibleCount = 5
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate: Date?

    private let pageSize = 5
    private let calendar = Calendar.current

    private enum ViewMode: String, CaseIterable, Identifiable {
        case calendar = "Calendar"
        case list = "List"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.historyWorkouts.isEmpty {
                    ContentUnavailableView("No Workouts", systemImage: "dumbbell", description: Text("Your workout history will appear here"))
                        .frame(maxHeight: .infinity)
                } else {
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    switch viewMode {
                    case .calendar: calendarView
                    case .list: listView
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Calendar

    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                weekdayHeader
                monthGrid
                legend
                Divider()
                selectedDayDetails
            }
            .padding()
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentMonthOrLater)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let types = workoutTypes(on: date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        return Button {
            selectedDate = types.isEmpty ? nil : date
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.white : .primary)
                HStack(spacing: 3) {
                    ForEach(types, id: \.self) { type in
                        Circle()
                            .fill(type.color)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: AppStyle.inputCornerRadius)
                    .fill(isSelected ? Color.accentColor : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.inputCornerRadius)
                    .stroke(isToday && !isSelected ? Color.accentColor : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(types.isEmpty)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(DayType.allCases) { type in
                HStack(spacing: 4) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 8, height: 8)
                    Text(type.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedDayDetails: some View {
        if let selectedDate {
            let workouts = workouts(on: selectedDate)
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                ForEach(workouts) { workout in
                    workoutRow(workout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Tap a marked day to see its workout")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(Array(vm.historyWorkouts.prefix(visibleCount))) { workout in
                workoutRow(workout)
            }
            .onDelete { offsets in
                let toDelete = offsets.map { vm.historyWorkouts[$0] }
                for workout in toDelete {
                    Task { await vm.deleteWorkout(workout) }
                }
            }

            if vm.isLoadingMoreHistory {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if vm.historyWorkouts.count > visibleCount || vm.hasMoreHistory {
                Button("Show More") {
                    visibleCount += pageSize
                    // Past the loaded buffer: fetch the next page from Firestore.
                    if visibleCount > vm.historyWorkouts.count {
                        Task { await vm.loadMoreHistory() }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Calendar helpers

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Days of the displayed month, padded with leading nils to align the first weekday.
    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }
        return days
    }

    private var isCurrentMonthOrLater: Bool {
        calendar.compare(displayedMonth, to: .now, toGranularity: .month) != .orderedAscending
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
            selectedDate = nil
            Task { await vm.loadHistoryMonth(containing: newMonth) }
        }
    }

    private func workouts(on date: Date) -> [Workout] {
        vm.historyWorkouts
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    /// Distinct workout types logged on a day, in a stable order, for the dots.
    private func workoutTypes(on date: Date) -> [DayType] {
        let types = Set(workouts(on: date).map(\.dayType))
        return DayType.allCases.filter { types.contains($0) }
    }

    // MARK: - Shared row

    private func exerciseSummary(_ workout: Workout) -> String {
        var parts = workout.exercises.map { "\($0.exerciseName) \(String(format: "%.0f", $0.weight))lbs" }
        if workout.didAbs {
            if let w = workout.absWeight, w > 0 {
                parts.append("Abs \(String(format: "%.0f", w))lbs")
            } else {
                parts.append("Abs")
            }
        }
        return parts.joined(separator: " | ")
    }

    private func workoutRow(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(workout.dayType.color)
                    .frame(width: 8, height: 8)
                Text(workout.dayType.rawValue)
                    .font(.headline)
                Spacer()
                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Cardio summary (shown for any workout that has cardio entries)
            let cardioEntries = workout.resolvedCardioEntries
            if !cardioEntries.isEmpty {
                Text(cardioEntries.map {
                    "\($0.type.rawValue): \($0.durationText), \(String(format: "%g", $0.distance)) \($0.type.distanceLabel)"
                }.joined(separator: " | "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Exercise summary (strength days, plus Abs on cardio days)
            let summary = exerciseSummary(workout)
            let id = workout.id ?? ""
            let isExpanded = expandedWorkoutIds.contains(id)
            if !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .onTapGesture {
                        if isExpanded {
                            expandedWorkoutIds.remove(id)
                        } else {
                            expandedWorkoutIds.insert(id)
                        }
                    }
            }

            if !workout.notes.isEmpty {
                Text(workout.notes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
