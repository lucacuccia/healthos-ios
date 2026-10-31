import Foundation

@MainActor
class ExtrasViewModel: ObservableObject {
    @Published var recentExtras: [Extra] = []
    @Published var isSaving = false
    @Published var error: String?

    // Form state
    @Published var date = Date()
    @Published var saunaEnabled = false
    @Published var saunaDuration = 15
    @Published var saunaTemperature: Double = 170
    @Published var meditationEnabled = false
    @Published var meditationStyle: MeditationStyle = .seated
    @Published var meditationDuration = 10
    @Published var coldPlungeEnabled = false
    @Published var coldPlungeDuration = 3
    @Published var coldPlungeTemperature: Double = 55

    private let service = FirestoreService.shared

    var hasSelection: Bool {
        saunaEnabled || meditationEnabled || coldPlungeEnabled
    }

    func load() async {
        do {
            recentExtras = try await service.fetchExtras(limit: 20)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        let extra = Extra(
            date: date,
            sauna: saunaEnabled ? SaunaEntry(duration: saunaDuration, temperature: saunaTemperature) : nil,
            meditation: meditationEnabled ? MeditationEntry(style: meditationStyle, duration: meditationDuration) : nil,
            coldPlunge: coldPlungeEnabled ? ColdPlungeEntry(duration: coldPlungeDuration, temperature: coldPlungeTemperature) : nil
        )

        do {
            try await service.saveExtra(extra)
            resetForm()
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteExtra(_ extra: Extra) async {
        do {
            try await service.deleteExtra(extra)
            recentExtras.removeAll { $0.id == extra.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func resetForm() {
        date = .now
        saunaEnabled = false
        saunaDuration = 15
        saunaTemperature = 170
        meditationEnabled = false
        meditationStyle = .seated
        meditationDuration = 10
        coldPlungeEnabled = false
        coldPlungeDuration = 3
        coldPlungeTemperature = 55
    }
}
