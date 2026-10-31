import Foundation
import FirebaseFirestore

enum CardioType: String, Codable, CaseIterable, Identifiable {
    case stairs = "Stairs"
    case run    = "Run"
    case bike   = "Stationary Bike"

    var id: String { rawValue }

    var distanceLabel: String {
        switch self {
        case .stairs: return "steps"
        case .run, .bike: return "mi"
        }
    }
}

struct ExerciseEntry: Codable, Identifiable {
    var id = UUID().uuidString
    var exerciseId: String
    var exerciseName: String
    var weight: Double
    var reps: Int
    var sets: Int
    var readyToIncrease: Bool?   // nil on old docs → treated as false

    var wantsIncrease: Bool { readyToIncrease ?? false }

    enum CodingKeys: String, CodingKey {
        case id, exerciseId, exerciseName, weight, reps, sets, readyToIncrease
    }
}

struct CardioEntry: Codable, Identifiable {
    var id: String
    var type: CardioType
    var duration: Int    // whole minutes
    var durationSeconds: Int // 0-59, extra seconds beyond `duration` minutes
    var distance: Double // miles (or floors for stairs)

    enum CodingKeys: String, CodingKey { case id, type, duration, durationSeconds, distance }

    // Handles old docs that lack `id`, `type`, or `durationSeconds`
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = (try? c.decode(String.self,     forKey: .id))              ?? UUID().uuidString
        type            = (try? c.decode(CardioType.self, forKey: .type))            ?? .run
        duration        = (try? c.decode(Int.self,        forKey: .duration))        ?? 0
        durationSeconds = (try? c.decode(Int.self,        forKey: .durationSeconds)) ?? 0
        distance        = (try? c.decode(Double.self,     forKey: .distance))        ?? 0.0
    }

    init(type: CardioType = .run, duration: Int = 0, durationSeconds: Int = 0, distance: Double = 0.0) {
        self.id = UUID().uuidString
        self.type = type
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.distance = distance
    }

    /// "30 min" when there are no extra seconds, otherwise "30:05".
    var durationText: String {
        durationSeconds > 0
            ? "\(duration):\(String(format: "%02d", durationSeconds))"
            : "\(duration) min"
    }
}

struct Workout: Identifiable, Codable {
    @DocumentID var id: String?
    var date: Date
    var dayType: DayType
    var notes: String
    var exercises: [ExerciseEntry]
    var cardio: CardioEntry?          // legacy — backward compat reads only
    var cardioEntries: [CardioEntry]? // new multi-entry format
    var includesAbs: Bool?            // nil on old docs → treated as false
    var absWeight: Double?            // nil = bodyweight / no weight used
    var createdAt: Date

    var resolvedCardioEntries: [CardioEntry] {
        if let entries = cardioEntries, !entries.isEmpty { return entries }
        if let single = cardio { return [single] }
        return []
    }

    var didAbs: Bool { includesAbs ?? false }

    init(dayType: DayType, date: Date = .now, notes: String = "",
         exercises: [ExerciseEntry] = [], cardioEntries: [CardioEntry] = [],
         includesAbs: Bool = false, absWeight: Double? = nil) {
        self.date = date
        self.dayType = dayType
        self.notes = notes
        self.exercises = exercises
        self.cardio = nil
        self.cardioEntries = cardioEntries.isEmpty ? nil : cardioEntries
        self.includesAbs = includesAbs
        self.absWeight = absWeight
        self.createdAt = .now
    }
}
