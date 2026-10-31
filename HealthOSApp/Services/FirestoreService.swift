import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Exercises

    func fetchExercises() async throws -> [Exercise] {
        let snapshot = try await db.collection("exercises")
            .order(by: "sortOrder")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Exercise.self) }
    }

    func saveExercise(_ exercise: Exercise) async throws {
        if let id = exercise.id {
            try db.collection("exercises").document(id).setData(from: exercise)
        } else {
            _ = try db.collection("exercises").addDocument(from: exercise)
        }
    }

    func deleteExercise(_ exercise: Exercise) async throws {
        guard let id = exercise.id else { return }
        try await db.collection("exercises").document(id).delete()
    }

    /// Writes only the `sortOrder` field, in one atomic batch, so a reorder
    /// can't clobber concurrent field updates like `maxWeight`.
    func updateSortOrders(_ sortOrders: [String: Int]) async throws {
        guard !sortOrders.isEmpty else { return }
        let batch = db.batch()
        for (id, sortOrder) in sortOrders where !id.isEmpty {
            batch.updateData(["sortOrder": sortOrder], forDocument: db.collection("exercises").document(id))
        }
        try await batch.commit()
    }

    func setMaxWeight(exerciseId: String, weight: Double) async throws {
        guard !exerciseId.isEmpty else { return }
        try await db.collection("exercises").document(exerciseId)
            .updateData(["maxWeight": weight])
    }

    func updateMaxWeightIfNeeded(exerciseId: String, weight: Double) async throws {
        // An empty id would trap Firestore's .document("") precondition
        // (a crash, not a catchable throw), so guard before touching it.
        guard !exerciseId.isEmpty else { return }
        // A cleared weight field reads back as 0; recording that as a max would
        // stick (the backfill only fills nil) and show "max: 0 lbs" in the Library.
        guard weight > 0 else { return }
        let ref = db.collection("exercises").document(exerciseId)
        let doc = try await ref.getDocument()
        let currentMax = doc.data()?["maxWeight"] as? Double
        if currentMax == nil || weight > currentMax! {
            try await ref.updateData(["maxWeight": weight])
        }
    }

    func seedExercisesIfNeeded() async throws {
        // Seed only when the collection is truly empty. Never gate on
        // UserDefaults: it's per-install, so a reinstall or fresh simulator
        // would re-trigger a wipe of shared Firestore data.
        let snapshot = try await db.collection("exercises").limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for exercise in Exercise.seedData {
            let ref = db.collection("exercises").document()
            try batch.setData(from: exercise, forDocument: ref)
        }
        try await batch.commit()
    }

    // MARK: - Workouts

    func saveWorkout(_ workout: Workout) async throws {
        if let id = workout.id {
            try db.collection("workouts").document(id).setData(from: workout)
        } else {
            _ = try db.collection("workouts").addDocument(from: workout)
        }
    }

    func fetchWorkouts(limit: Int? = 30) async throws -> [Workout] {
        var query: Query = db.collection("workouts").order(by: "date", descending: true)
        if let limit { query = query.limit(to: limit) }
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Workout.self) }
    }

    // Next page of history: workouts strictly older than `date`, newest first.
    func fetchWorkouts(before date: Date, limit: Int) async throws -> [Workout] {
        let snapshot = try await db.collection("workouts")
            .order(by: "date", descending: true)
            .start(after: [date])
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Workout.self) }
    }

    // All workouts in [start, end), newest first. Used by the history calendar.
    func fetchWorkouts(from start: Date, to end: Date) async throws -> [Workout] {
        let snapshot = try await db.collection("workouts")
            .whereField("date", isGreaterThanOrEqualTo: start)
            .whereField("date", isLessThan: end)
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Workout.self) }
    }

    func fetchLastWorkout(dayType: DayType) async throws -> Workout? {
        let snapshot = try await db.collection("workouts")
            .whereField("dayType", isEqualTo: dayType.rawValue)
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.first.flatMap { try? $0.data(as: Workout.self) }
    }

    func deleteWorkout(_ workout: Workout) async throws {
        guard let id = workout.id else { return }
        try await db.collection("workouts").document(id).delete()
    }

    // MARK: - Extras

    func saveExtra(_ extra: Extra) async throws {
        if let id = extra.id {
            try db.collection("extras").document(id).setData(from: extra)
        } else {
            _ = try db.collection("extras").addDocument(from: extra)
        }
    }

    func deleteExtra(_ extra: Extra) async throws {
        guard let id = extra.id else { return }
        try await db.collection("extras").document(id).delete()
    }

    func fetchExtras(limit: Int = 30) async throws -> [Extra] {
        let snapshot = try await db.collection("extras")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Extra.self) }
    }

    // MARK: - Body Weight

    func saveBodyWeight(_ entry: BodyWeightEntry) async throws {
        if let id = entry.id {
            try db.collection("bodyweight").document(id).setData(from: entry)
        } else {
            _ = try db.collection("bodyweight").addDocument(from: entry)
        }
    }

    func fetchBodyWeight(limit: Int = 30) async throws -> [BodyWeightEntry] {
        let snapshot = try await db.collection("bodyweight")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: BodyWeightEntry.self) }
    }

    // MARK: - Blood Pressure

    func saveBloodPressure(_ entry: BloodPressureEntry) async throws {
        if let id = entry.id {
            try db.collection("bloodpressure").document(id).setData(from: entry)
        } else {
            _ = try db.collection("bloodpressure").addDocument(from: entry)
        }
    }

    func deleteBloodPressure(_ entry: BloodPressureEntry) async throws {
        guard let id = entry.id else { return }
        try await db.collection("bloodpressure").document(id).delete()
    }

    func fetchBloodPressure(limit: Int = 30) async throws -> [BloodPressureEntry] {
        let snapshot = try await db.collection("bloodpressure")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: BloodPressureEntry.self) }
    }
}
