import SwiftUI

struct BloodPressureEntryView: View {
    @StateObject private var vm = BloodPressureViewModel()
    @State private var showSavedAlert = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)

                    Picker("Session", selection: $vm.session) {
                        Text("AM").tag("am")
                        Text("PM").tag("pm")
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Sit quietly for 5 minutes first. Arm supported at heart level. Take 2–3 readings one minute apart.")
                }

                Section {
                    ForEach(0..<3, id: \.self) { i in
                        readingRow(index: i)
                    }
                } header: {
                    Text("Readings")
                } footer: {
                    if let summary = vm.summary {
                        Text("Summary: \(summary.systolic)/\(summary.diastolic) · \(summary.heartRate) bpm")
                            .font(.callout.bold())
                            .foregroundStyle(.primary)
                    } else {
                        Text("Summary averages the last two readings.")
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $vm.notes, axis: .vertical)
                        .lineLimit(2...4)
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
                    .disabled(vm.isSaving || !vm.canSave)
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Blood Pressure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("History", systemImage: "clock") {
                        showHistory = true
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                BloodPressureHistoryView(vm: vm)
            }
            .alert("Saved", isPresented: $showSavedAlert) {
                Button("OK") {}
            }
            .task {
                await vm.load()
            }
        }
    }

    private func readingRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 16)

            numberField("Sys", text: $vm.systolicTexts[index])
            Text("/")
                .foregroundStyle(.secondary)
            numberField("Dias", text: $vm.diastolicTexts[index])
            numberField("HR", text: $vm.heartRateTexts[index])
        }
    }

    private func numberField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .onChange(of: text.wrappedValue) { _, new in
                let filtered = new.filter(\.isNumber)
                if filtered != new { text.wrappedValue = filtered }
            }
    }
}

struct BloodPressureHistoryView: View {
    @ObservedObject var vm: BloodPressureViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Averages") {
                    averageRow(label: "Last 7 Days", since: Calendar.current.date(byAdding: .day, value: -7, to: .now))
                    averageRow(label: "Last 30 Days", since: Calendar.current.date(byAdding: .day, value: -30, to: .now))
                    averageRow(label: "All Time", since: nil)
                }

                Section("Entries") {
                    ForEach(vm.entries) { entry in
                        entryRow(entry)
                    }
                    .onDelete { offsets in
                        Task { await vm.delete(at: offsets) }
                    }
                }
            }
            .navigationTitle("BP History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func entryRow(_ entry: BloodPressureEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.session.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(entry.session == "am" ? Color.orange : Color.indigo, in: Capsule())
                Spacer()
                Text(entry.summaryText)
                    .font(.body.monospacedDigit())
            }
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }

    private func averageRow(label: String, since: Date?) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let am = vm.average(session: "am", since: since) {
                sessionAverage("AM", am)
            }
            if let pm = vm.average(session: "pm", since: since) {
                Divider()
                    .padding(.horizontal, 10)
                sessionAverage("PM", pm)
            }
        }
    }

    private func sessionAverage(_ label: String, _ avg: BloodPressureViewModel.SessionAverage) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text("\(avg.systolic)/\(avg.diastolic)")
                .font(.caption.monospacedDigit())
        }
    }
}
