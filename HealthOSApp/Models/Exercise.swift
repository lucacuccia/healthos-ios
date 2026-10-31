import Foundation
import FirebaseFirestore

enum DayType: String, Codable, CaseIterable, Identifiable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case cardio = "Cardio"

    var id: String { rawValue }
}

struct Exercise: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var dayType: DayType
    var defaultSets: Int
    var targetRepMin: Int
    var targetRepMax: Int
    var isFavorite: Bool
    var sortOrder: Int
    var startingWeight: Double = 0
    var maxWeight: Double?

    var targetRepRange: String {
        targetRepMin == targetRepMax ? "\(targetRepMin)" : "\(targetRepMin)-\(targetRepMax)"
    }

    static let seedData: [Exercise] = [
        // Push
        Exercise(name: "Bench Press", dayType: .push, defaultSets: 3, targetRepMin: 10, targetRepMax: 10, isFavorite: true, sortOrder: 0, startingWeight: 90),
        Exercise(name: "Bench Press (5x5)", dayType: .push, defaultSets: 5, targetRepMin: 5, targetRepMax: 5, isFavorite: true, sortOrder: 1, startingWeight: 140),
        Exercise(name: "DB Bench Press", dayType: .push, defaultSets: 3, targetRepMin: 10, targetRepMax: 10, isFavorite: true, sortOrder: 2, startingWeight: 60),
        Exercise(name: "DB Shoulder Press", dayType: .push, defaultSets: 3, targetRepMin: 10, targetRepMax: 12, isFavorite: true, sortOrder: 3, startingWeight: 32.5),
        Exercise(name: "Pec Deck", dayType: .push, defaultSets: 3, targetRepMin: 15, targetRepMax: 20, isFavorite: true, sortOrder: 4, startingWeight: 90),
        Exercise(name: "High Cable Lateral Raises", dayType: .push, defaultSets: 3, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 5, startingWeight: 24),
        Exercise(name: "Overhead Tricep Extension", dayType: .push, defaultSets: 3, targetRepMin: 5, targetRepMax: 10, isFavorite: true, sortOrder: 6, startingWeight: 102),
        Exercise(name: "Cable Kickback", dayType: .push, defaultSets: 3, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 7, startingWeight: 24),
        Exercise(name: "Dips", dayType: .push, defaultSets: 3, targetRepMin: 10, targetRepMax: 10, isFavorite: true, sortOrder: 8, startingWeight: 0),

        // Pull
        Exercise(name: "Close Grip Lat Pulldown", dayType: .pull, defaultSets: 3, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 0, startingWeight: 92),
        Exercise(name: "Machine Rows", dayType: .pull, defaultSets: 3, targetRepMin: 8, targetRepMax: 10, isFavorite: true, sortOrder: 1, startingWeight: 180),
        Exercise(name: "Close Grip Cable Row", dayType: .pull, defaultSets: 2, targetRepMin: 15, targetRepMax: 20, isFavorite: true, sortOrder: 2, startingWeight: 72),
        Exercise(name: "Reverse Cable Flys", dayType: .pull, defaultSets: 3, targetRepMin: 15, targetRepMax: 20, isFavorite: true, sortOrder: 3, startingWeight: 10),
        Exercise(name: "Shrugs", dayType: .pull, defaultSets: 3, targetRepMin: 15, targetRepMax: 20, isFavorite: true, sortOrder: 4, startingWeight: 180),
        Exercise(name: "Decline Seated Bicep Curls", dayType: .pull, defaultSets: 3, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 5, startingWeight: 17.5),
        Exercise(name: "Hammer Curls", dayType: .pull, defaultSets: 3, targetRepMin: 10, targetRepMax: 10, isFavorite: true, sortOrder: 6, startingWeight: 20),
        Exercise(name: "Preacher Curls", dayType: .pull, defaultSets: 3, targetRepMin: 15, targetRepMax: 20, isFavorite: true, sortOrder: 7, startingWeight: 60),

        // Legs
        Exercise(name: "Hamstring Curls", dayType: .legs, defaultSets: 3, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 0, startingWeight: 62.5),
        Exercise(name: "SL Hamstring Curls", dayType: .legs, defaultSets: 3, targetRepMin: 12, targetRepMax: 12, isFavorite: true, sortOrder: 1, startingWeight: 35),
        Exercise(name: "Leg Press", dayType: .legs, defaultSets: 3, targetRepMin: 10, targetRepMax: 10, isFavorite: true, sortOrder: 2, startingWeight: 100),
        Exercise(name: "Barbell RDL", dayType: .legs, defaultSets: 3, targetRepMin: 5, targetRepMax: 10, isFavorite: true, sortOrder: 3, startingWeight: 55),
        Exercise(name: "Decline Quad Extensions", dayType: .legs, defaultSets: 3, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 4, startingWeight: 120),
        Exercise(name: "SL Quad Extensions", dayType: .legs, defaultSets: 3, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 5, startingWeight: 60),
        Exercise(name: "Adductor Machine", dayType: .legs, defaultSets: 2, targetRepMin: 15, targetRepMax: 20, isFavorite: true, sortOrder: 6, startingWeight: 120),
        Exercise(name: "Abductor Machine", dayType: .legs, defaultSets: 2, targetRepMin: 15, targetRepMax: 20, isFavorite: true, sortOrder: 7, startingWeight: 135),
        Exercise(name: "Calf Raises", dayType: .legs, defaultSets: 4, targetRepMin: 10, targetRepMax: 15, isFavorite: true, sortOrder: 8, startingWeight: 100),
        Exercise(name: "Bulgarian Split Squats", dayType: .legs, defaultSets: 3, targetRepMin: 10, targetRepMax: 10, isFavorite: true, sortOrder: 9, startingWeight: 24),
    ]
}
