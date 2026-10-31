import Foundation

@MainActor
class ExerciseLibraryViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var latestWeights: [String: Double] = [:]

    private let service = FirestoreService.shared

    func load() async {
        isLoading = true
        error = nil
        do {
            try await service.seedExercisesIfNeeded()
            exercises = try await service.fetchExercises()
            await loadLatestWeights()
            await backfillMaxWeightsIfNeeded()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func currentWeight(for exercise: Exercise) -> Double? {
        let weight = latestWeights[exercise.id ?? ""] ?? (exercise.startingWeight > 0 ? exercise.startingWeight : nil)
        return weight
    }

    func maxWeight(for exercise: Exercise) -> Double? {
        exercise.maxWeight
    }

    private func loadLatestWeights() async {
        var latest: [String: Double] = [:]
        let workouts = (try? await service.fetchWorkouts(limit: 50)) ?? []
        for workout in workouts.sorted(by: { $0.date > $1.date }) {
            for entry in workout.exercises where latest[entry.exerciseId] == nil {
                latest[entry.exerciseId] = entry.weight
            }
        }
        latestWeights = latest
    }

    private func backfillMaxWeightsIfNeeded() async {
        let missing = exercises.filter { $0.maxWeight == nil && $0.id != nil }
        guard !missing.isEmpty else { return }

        let allWorkouts = (try? await service.fetchWorkouts(limit: nil)) ?? []
        var maxesByExercise: [String: Double] = [:]
        for workout in allWorkouts {
            for entry in workout.exercises {
                maxesByExercise[entry.exerciseId] = Swift.max(maxesByExercise[entry.exerciseId] ?? 0, entry.weight)
            }
        }

        for exercise in missing {
            guard let id = exercise.id, let computedMax = maxesByExercise[id] else { continue }
            try? await service.setMaxWeight(exerciseId: id, weight: computedMax)
            if let idx = exercises.firstIndex(where: { $0.id == id }) {
                exercises[idx].maxWeight = computedMax
            }
        }
    }

    func libraryExercises(for dayType: DayType) -> [Exercise] {
        exercises.filter { $0.dayType == dayType }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func moveExercises(in dayType: DayType, from source: IndexSet, to destination: Int) async {
        var items = libraryExercises(for: dayType)
        items.move(fromOffsets: source, toOffset: destination)
        let previous = exercises
        var changed: [String: Int] = [:]
        for (index, exercise) in items.enumerated() where exercise.sortOrder != index {
            guard let id = exercise.id,
                  let idx = exercises.firstIndex(where: { $0.id == id }) else { continue }
            exercises[idx].sortOrder = index
            changed[id] = index
        }
        do {
            try await service.updateSortOrders(changed)
        } catch {
            // The batch is atomic, so nothing was written: roll back the local order too.
            exercises = previous
            self.error = error.localizedDescription
        }
    }

    func toggleFavorite(_ exercise: Exercise) async {
        var updated = exercise
        updated.isFavorite.toggle()
        do {
            try await service.saveExercise(updated)
            if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercises[idx] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addExercise(name: String, dayType: DayType, sets: Int, repMin: Int, repMax: Int, startingWeight: Double = 0) async {
        let maxOrder = exercises.filter { $0.dayType == dayType }.map(\.sortOrder).max() ?? -1
        let exercise = Exercise(
            name: name.titleCasedName,
            dayType: dayType,
            defaultSets: sets,
            targetRepMin: repMin,
            targetRepMax: repMax,
            isFavorite: false,
            sortOrder: maxOrder + 1,
            startingWeight: startingWeight
        )
        do {
            try await service.saveExercise(exercise)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateExercise(_ exercise: Exercise, name: String, dayType: DayType, sets: Int, repMin: Int, repMax: Int, startingWeight: Double) async {
        var updated = exercise
        updated.name = name.titleCasedName
        updated.dayType = dayType
        updated.defaultSets = sets
        updated.targetRepMin = repMin
        updated.targetRepMax = repMax
        updated.startingWeight = startingWeight
        if dayType != exercise.dayType {
            let maxOrder = exercises.filter { $0.dayType == dayType }.map(\.sortOrder).max() ?? -1
            updated.sortOrder = maxOrder + 1
        }
        do {
            try await service.saveExercise(updated)
            if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercises[idx] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteExercise(_ exercise: Exercise) async {
        do {
            try await service.deleteExercise(exercise)
            exercises.removeAll { $0.id == exercise.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
