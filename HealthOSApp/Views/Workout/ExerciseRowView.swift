import SwiftUI

struct ExerciseRowView: View {
    @Binding var entry: ExerciseEntry
    let previousWeight: Double?
    let targetReps: String?
    let pendingIncrease: Bool

    @State private var setsStr = ""
    @State private var repsStr = ""
    @State private var weightStr = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise name + progression cue + previous weight
            HStack {
                Text(entry.exerciseName)
                    .font(.headline)
                if pendingIncrease {
                    Label("ready to go up", systemImage: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                }
                Spacer()
                if let prev = previousWeight, prev > 0 {
                    Text("prev: \(prev, specifier: "%g") lbs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                // Sets
                VStack(alignment: .leading) {
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("3", text: $setsStr)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .onChange(of: setsStr) { _, new in
                            let filtered = new.filter(\.isNumber)
                            if filtered != new { setsStr = filtered }
                            entry.sets = Int(filtered) ?? 0
                        }
                }

                // Reps
                VStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let target = targetReps {
                            Text("(\(target))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .fixedSize()
                    TextField("10", text: $repsStr)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .onChange(of: repsStr) { _, new in
                            let filtered = new.filter(\.isNumber)
                            if filtered != new { repsStr = filtered }
                            entry.reps = Int(filtered) ?? 0
                        }
                }

                // Weight
                VStack(alignment: .leading) {
                    Text("lbs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("135", text: $weightStr)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: weightStr) { _, new in
                            let filtered = new.filter { $0.isNumber || $0 == "." }
                            if filtered != new { weightStr = filtered }
                            entry.weight = Double(filtered) ?? 0
                        }
                }

                Spacer()

                // Flag this session as "ready to go up next time"
                VStack(alignment: .trailing) {
                    Text("Go up?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        entry.readyToIncrease = !entry.wantsIncrease
                    } label: {
                        Image(systemName: entry.wantsIncrease ? "arrow.up.circle.fill" : "arrow.up.circle")
                            .font(.title2)
                            .foregroundStyle(entry.wantsIncrease ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            setsStr   = entry.sets    > 0 ? "\(entry.sets)"                       : ""
            repsStr   = entry.reps    > 0 ? "\(entry.reps)"                       : ""
            weightStr = entry.weight  > 0 ? String(format: "%.10g", entry.weight) : ""
        }
    }
}
