import Foundation
import FirebaseFirestore

struct BPReading: Codable, Equatable {
    var systolic: Int
    var diastolic: Int
    var heartRate: Int
}

struct BloodPressureEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var date: Date
    var session: String // "am" | "pm"
    var readings: [BPReading] // raw readings (empty for migrated sheet rows)
    var systolic: Int // summary: avg of 2nd + 3rd readings
    var diastolic: Int
    var heartRate: Int
    var notes: String
    var createdAt: Date

    init(
        date: Date = .now,
        session: String,
        readings: [BPReading] = [],
        systolic: Int,
        diastolic: Int,
        heartRate: Int,
        notes: String = ""
    ) {
        self.date = date
        self.session = session
        self.readings = readings
        self.systolic = systolic
        self.diastolic = diastolic
        self.heartRate = heartRate
        self.notes = notes
        self.createdAt = .now
    }

    var summaryText: String {
        "\(systolic)/\(diastolic) · \(heartRate) bpm"
    }
}
