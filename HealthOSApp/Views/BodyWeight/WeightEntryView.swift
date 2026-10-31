import SwiftUI

struct WeightEntryView: View {
    @StateObject private var vm = BodyWeightViewModel()
    @State private var showSavedAlert = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)

                    HStack {
                        Text("Weight (lbs)")
                        Spacer()
                        TextField("0", text: $vm.weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    TextField("Notes (optional)", text: $vm.notes)
                } footer: {
                    if let latest = vm.latestWeight {
                        Text("Last: \(String(format: "%.1f", latest)) lbs")
                    }
                }

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
                    .disabled(vm.isSaving || vm.weightText.isEmpty)
                }

            }
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Body Weight")
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
                    List(vm.entries) { entry in
                        HStack {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", entry.weight)) lbs")
                                .font(.body.monospacedDigit())
                            if !entry.notes.isEmpty {
                                Text(entry.notes)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .navigationTitle("Weight History")
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
}
