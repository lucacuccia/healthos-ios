import SwiftUI

struct ExtrasLogView: View {
    @StateObject private var vm = ExtrasViewModel()
    @State private var showSavedAlert = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)
                }

                // Sauna
                Section {
                    Toggle("Sauna", isOn: $vm.saunaEnabled)
                    if vm.saunaEnabled {
                        Picker("Duration", selection: $vm.saunaDuration) {
                            ForEach(1...120, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        HStack {
                            Text("Temperature")
                            Spacer()
                            TextField("°F", value: $vm.saunaTemperature, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("°F")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Meditation
                Section {
                    Toggle("Meditation", isOn: $vm.meditationEnabled)
                    if vm.meditationEnabled {
                        Picker("Style", selection: $vm.meditationStyle) {
                            ForEach(MeditationStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        Picker("Duration", selection: $vm.meditationDuration) {
                            ForEach(1...120, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }

                // Cold Plunge
                Section {
                    Toggle("Cold Plunge", isOn: $vm.coldPlungeEnabled)
                    if vm.coldPlungeEnabled {
                        Picker("Duration", selection: $vm.coldPlungeDuration) {
                            ForEach(1...30, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        HStack {
                            Text("Temperature")
                            Spacer()
                            TextField("°F", value: $vm.coldPlungeTemperature, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("°F")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Save
                Section {
                    Button(action: {
                        Task {
                            if await vm.save() {
                                showSavedAlert = true
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if vm.isSaving {
                                ProgressView()
                            } else {
                                Text("Save")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(vm.isSaving || !vm.hasSelection)
                }

            }
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Wellness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("History", systemImage: "clock") {
                        showHistory = true
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    List {
                        ForEach(wellnessHistory) { extra in
                            extraRow(extra)
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { wellnessHistory[$0] }
                            for extra in toDelete {
                                Task { await vm.deleteExtra(extra) }
                            }
                        }
                    }
                    .navigationTitle("Wellness History")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .alert("Saved", isPresented: $showSavedAlert) {
                Button("OK") {}
            }
            .task {
                await vm.load()
            }
        }
    }

    private var wellnessHistory: [Extra] {
        vm.recentExtras.filter { $0.sauna != nil || $0.meditation != nil || $0.coldPlunge != nil }
    }

    private func extraSummary(_ extra: Extra) -> String {
        var parts: [String] = []
        if let sauna = extra.sauna {
            var s = "Sauna \(sauna.duration)min"
            if let temp = sauna.temperature { s += " \(Int(temp))°F" }
            parts.append(s)
        }
        if let med = extra.meditation {
            parts.append("Meditation \(med.style.rawValue) \(med.duration)min")
        }
        if let cp = extra.coldPlunge {
            parts.append("Cold Plunge \(cp.duration)min \(Int(cp.temperature))°F")
        }
        return parts.joined(separator: " | ")
    }

    private func extraRow(_ extra: Extra) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(extra.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(extraSummary(extra))
                .font(.subheadline)
        }
    }
}
