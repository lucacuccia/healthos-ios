import Foundation

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var recentWorkouts: [Workout] = []
    @Published var previousWorkout: Workout?
    @Published var selectedDayType: DayType = .push
    @Published var selectedExercises: [ExerciseEntry] = []
    @Published var cardioEntries: [CardioEntry] = []
    @Published var includesAbs: Bool = false {
        didSet {
            if !includesAbs {
                absWeightStr = ""
            } else if absWeightStr.isEmpty, let w = latestAbsWeight, w > 0 {
                absWeightStr = String(format: "%.10g", w)
            }
        }
    }
    @Published var absWeightStr: String = ""
    @Published var workoutDate = Date()
    @Published var isSaving = false
    @Published var isLoading = false
    @Published var error: String?

    // Full history for WorkoutHistoryView: recentWorkouts plus older workouts fetched
    // on demand, deduped by id, newest first. Kept apart from recentWorkouts so the
    // derived weight/reps/increase dictionaries stay on the recent window only.
    @Published private(set) var historyWorkouts: [Workout] = []
    @Published private(set) var hasMoreHistory = false
    @Published private(set) var isLoadingMoreHistory = false

    private let service = FirestoreService.shared
    private let recentLimit = 100
    private let historyPageSize = 50
    private var olderWorkouts: [Workout] = []
    // Everything on or after this date is loaded; list pages continue from here.
    // A calendar month fetch moves it only when the month is contiguous with it.
    private var historyCursor: Date?
    private var fetchedMonths: Set<Date> = []

    // True when the user has entered workout data that isn't in Firestore yet.
    var hasUnsavedWorkout: Bool {
        !selectedExercises.isEmpty
            || !cardioEntries.isEmpty
            || includesAbs
    }

    var latestAbsWeight: Double? {
        recentWorkouts.sorted { $0.date > $1.date }.first { $0.didAbs }?.absWeight
    }

    // Most recent non-zero weight per exerciseId, across all recent workouts (any
    // day type). Zeros are skipped so a cleared weight field doesn't become the
    // prefill; callers fall back to the exercise's default weight instead.
    var latestWeightByExercise: [String: Double] {
        var map: [String: Double] = [:]
        let sorted = recentWorkouts.sorted { $0.date > $1.date }
        for workout in sorted {
            for entry in workout.exercises where map[entry.exerciseId] == nil && entry.weight > 0 {
                map[entry.exerciseId] = entry.weight
            }
        }
        return map
    }

    var latestRepsByExercise: [String: Int] {
        var map: [String: Int] = [:]
        let sorted = recentWorkouts.sorted { $0.date > $1.date }
        for workout in sorted {
            for entry in workout.exercises where map[entry.exerciseId] == nil && entry.reps > 0 {
                map[entry.exerciseId] = entry.reps
            }
        }
        return map
    }

    // Per exerciseId: true if it was flagged "ready to increase" in some session and
    // the weight hasn't actually gone up since. The reminder persists across sessions
    // — even unflagged ones — until a later session logs a heavier weight.
    var pendingIncreaseByExercise: [String: Bool] {
        // Group entries per exercise, most-recent-first.
        var entriesByExercise: [String: [ExerciseEntry]] = [:]
        let sorted = recentWorkouts.sorted { $0.date > $1.date }
        for workout in sorted {
            for entry in workout.exercises {
                entriesByExercise[entry.exerciseId, default: []].append(entry)
            }
        }

        var result: [String: Bool] = [:]
        for (id, entries) in entriesByExercise {
            guard let flagIdx = entries.firstIndex(where: { $0.wantsIncrease }) else {
                result[id] = false
                continue
            }
            let flagWeight = entries[flagIdx].weight
            // Entries before flagIdx were logged more recently than the flag.
            let increased = entries[0..<flagIdx].contains { $0.weight > flagWeight }
            result[id] = !increased
        }
        return result
    }

    func loadHistory() async {
        isLoading = true
        do {
            recentWorkouts = try await service.fetchWorkouts(limit: recentLimit)
            // The recent window just moved, so restart paging from its new edge.
            olderWorkouts = []
            fetchedMonths = []
            historyCursor = recentWorkouts.map(\.date).min()
            hasMoreHistory = recentWorkouts.count == recentLimit
            rebuildHistory()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // Appends the next page of workouts older than everything loaded so far.
    func loadMoreHistory() async {
        guard hasMoreHistory, !isLoadingMoreHistory, let cursor = historyCursor else { return }
        isLoadingMoreHistory = true
        defer { isLoadingMoreHistory = false }
        do {
            let page = try await service.fetchWorkouts(before: cursor, limit: historyPageSize)
            olderWorkouts += page
            historyCursor = page.map(\.date).min() ?? cursor
            hasMoreHistory = page.count == historyPageSize
            rebuildHistory()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Fetches one calendar month when it falls before the loaded history.
    func loadHistoryMonth(containing date: Date) async {
        guard hasMoreHistory, let cursor = historyCursor,
              let month = Calendar.current.dateInterval(of: .month, for: date),
              month.start < cursor, !fetchedMonths.contains(month.start) else { return }
        fetchedMonths.insert(month.start)
        do {
            olderWorkouts += try await service.fetchWorkouts(from: month.start, to: month.end)
            if let current = historyCursor, month.end >= current, month.start < current {
                historyCursor = month.start
            }
            rebuildHistory()
        } catch {
            fetchedMonths.remove(month.start)
            self.error = error.localizedDescription
        }
    }

    private func rebuildHistory() {
        var seen = Set<String>()
        historyWorkouts = (recentWorkouts + olderWorkouts)
            .filter { workout in
                guard let id = workout.id else { return true }
                return seen.insert(id).inserted
            }
            .sorted { $0.date > $1.date }
    }

    func loadPreviousWorkout() async {
        do {
            previousWorkout = try await service.fetchLastWorkout(dayType: selectedDayType)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addExercises(from exercises: [Exercise]) {
        for exercise in exercises {
            // An entry with an empty exerciseId breaks all id-keyed lookups and
            // can reach Firestore's .document(""); skip rather than substitute "".
            guard let id = exercise.id else { continue }
            guard !selectedExercises.contains(where: { $0.exerciseId == id }) else { continue }
            selectedExercises.append(ExerciseEntry(
                exerciseId: id,
                exerciseName: exercise.name,
                weight: latestWeightByExercise[id] ?? exercise.startingWeight,
                reps: latestRepsByExercise[id] ?? exercise.targetRepMin,
                sets: exercise.defaultSets
            ))
        }
    }

    func removeExercise(at offsets: IndexSet) {
        selectedExercises.remove(atOffsets: offsets)
    }

    func addCardioEntries(from types: [CardioType]) {
        for type in types {
            guard !cardioEntries.contains(where: { $0.type == type }) else { continue }
            cardioEntries.append(CardioEntry(type: type))
        }
    }

    func removeCardioEntry(at offsets: IndexSet) {
        cardioEntries.remove(atOffsets: offsets)
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        let workout = Workout(
            dayType: selectedDayType,
            date: workoutDate,
            exercises: selectedExercises,
            cardioEntries: cardioEntries,
            includesAbs: includesAbs,
            absWeight: includesAbs ? Double(absWeightStr) : nil
        )

        do {
            try await service.saveWorkout(workout)
            for entry in selectedExercises {
                try? await service.updateMaxWeightIfNeeded(exerciseId: entry.exerciseId, weight: entry.weight)
            }
            reset()
            await loadHistory()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteWorkout(_ workout: Workout) async {
        do {
            try await service.deleteWorkout(workout)
            recentWorkouts.removeAll { $0.id == workout.id }
            olderWorkouts.removeAll { $0.id == workout.id }
            rebuildHistory()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reset() {
        selectedExercises = []
        cardioEntries = []
        includesAbs = false
        absWeightStr = ""
        workoutDate = .now
        previousWorkout = nil
    }
}
