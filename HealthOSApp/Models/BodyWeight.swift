import Foundation
import FirebaseFirestore

struct BodyWeightEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var date: Date
    var weight: Double // lbs
    var notes: String
    var createdAt: Date

    init(date: Date = .now, weight: Double, notes: String = "") {
        self.date = date
        self.weight = weight
        self.notes = notes
        self.createdAt = .now
    }
}
