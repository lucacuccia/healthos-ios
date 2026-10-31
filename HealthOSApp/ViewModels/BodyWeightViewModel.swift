import Foundation

@MainActor
class BodyWeightViewModel: ObservableObject {
    @Published var entries: [BodyWeightEntry] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    // Form state
    @Published var weightText = ""
    @Published var notes = ""
    @Published var date = Date()

    private let service = FirestoreService.shared

    var latestWeight: Double? {
        entries.first?.weight
    }

    func load() async {
        isLoading = true
        do {
            entries = try await service.fetchBodyWeight(limit: 30)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func save() async -> Bool {
        guard let weight = Double(weightText), weight > 0 else {
            error = "Enter a valid weight"
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let entry = BodyWeightEntry(date: date, weight: weight, notes: notes)
        do {
            try await service.saveBodyWeight(entry)
            weightText = ""
            notes = ""
            date = .now
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
