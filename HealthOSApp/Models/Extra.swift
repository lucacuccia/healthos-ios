import Foundation
import FirebaseFirestore

enum MeditationStyle: String, Codable, CaseIterable, Identifiable {
    case seated  = "Seated"
    case walking = "Walking"
    var id: String { rawValue }
}

struct MeditationEntry: Codable {
    var style: MeditationStyle
    var duration: Int // minutes
}

struct SaunaEntry: Codable {
    var duration: Int        // minutes
    var temperature: Double? // °F, optional for backward compat
}

struct ColdPlungeEntry: Codable {
    var duration: Int       // minutes
    var temperature: Double // °F
}

struct Extra: Identifiable, Codable {
    @DocumentID var id: String?
    var date: Date
    var sauna: SaunaEntry?
    var meditation: MeditationEntry?
    var coldPlunge: ColdPlungeEntry?
    var createdAt: Date

    init(date: Date = .now, sauna: SaunaEntry? = nil,
         meditation: MeditationEntry? = nil, coldPlunge: ColdPlungeEntry? = nil) {
        self.date = date
        self.sauna = sauna
        self.meditation = meditation
        self.coldPlunge = coldPlunge
        self.createdAt = .now
    }
}
