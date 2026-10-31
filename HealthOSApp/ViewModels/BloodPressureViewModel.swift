import Foundation

@MainActor
class BloodPressureViewModel: ObservableObject {
    @Published var entries: [BloodPressureEntry] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    // Form state — three reading rows as strings
    @Published var date = Date()
    @Published var session = Calendar.current.component(.hour, from: .now) < 15 ? "am" : "pm"
    @Published var systolicTexts = ["", "", ""]
    @Published var diastolicTexts = ["", "", ""]
    @Published var heartRateTexts = ["", "", ""]
    @Published var notes = ""

    private let service = FirestoreService.shared

    /// Complete readings entered so far, in row order.
    var completedReadings: [BPReading] {
        (0..<3).compactMap { i in
            guard let sys = Int(systolicTexts[i]), sys > 0,
                  let dia = Int(diastolicTexts[i]), dia > 0,
                  let hr = Int(heartRateTexts[i]), hr > 0 else { return nil }
            return BPReading(systolic: sys, diastolic: dia, heartRate: hr)
        }
    }

    /// Summary = average of 2nd + 3rd readings; falls back to the last two,
    /// or the single reading on rushed days.
    var summary: BPReading? {
        let readings = completedReadings
        guard !readings.isEmpty else { return nil }
        let averaged = Array(readings.suffix(2))
        func avg(_ values: [Int]) -> Int {
            Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
        }
        return BPReading(
            systolic: avg(averaged.map(\.systolic)),
            diastolic: avg(averaged.map(\.diastolic)),
            heartRate: avg(averaged.map(\.heartRate))
        )
    }

    var canSave: Bool { summary != nil }

    func load() async {
        isLoading = true
        do {
            entries = try await service.fetchBloodPressure(limit: 400)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func save() async -> Bool {
        guard let summary else {
            error = "Enter at least one complete reading"
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let entry = BloodPressureEntry(
            date: date,
            session: session,
            readings: completedReadings,
            systolic: summary.systolic,
            diastolic: summary.diastolic,
            heartRate: summary.heartRate,
            notes: notes
        )
        do {
            try await service.saveBloodPressure(entry)
            systolicTexts = ["", "", ""]
            diastolicTexts = ["", "", ""]
            heartRateTexts = ["", "", ""]
            notes = ""
            date = .now
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func delete(at offsets: IndexSet) async {
        let toDelete = offsets.map { entries[$0] }
        entries.remove(atOffsets: offsets)
        for entry in toDelete {
            do {
                try await service.deleteBloodPressure(entry)
            } catch {
                self.error = error.localizedDescription
                await load()
                return
            }
        }
    }

    // MARK: - Averages for the history sheet

    struct SessionAverage {
        var systolic: Int
        var diastolic: Int
        var heartRate: Int
        var count: Int
    }

    func average(session: String, since: Date? = nil) -> SessionAverage? {
        var matching = entries.filter { $0.session == session }
        if let since {
            matching = matching.filter { $0.date >= since }
        }
        guard !matching.isEmpty else { return nil }
        func avg(_ values: [Int]) -> Int {
            Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
        }
        return SessionAverage(
            systolic: avg(matching.map(\.systolic)),
            diastolic: avg(matching.map(\.diastolic)),
            heartRate: avg(matching.map(\.heartRate)),
            count: matching.count
        )
    }
}
