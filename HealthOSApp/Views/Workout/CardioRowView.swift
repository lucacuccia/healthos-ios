import SwiftUI

struct CardioRowView: View {
    @Binding var entry: CardioEntry

    @State private var durationStr = ""
    @State private var secondsStr = ""
    @State private var distanceStr = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.type.rawValue)
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("0", text: $durationStr)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .onChange(of: durationStr) { _, new in
                                let filtered = new.filter(\.isNumber)
                                if filtered != new { durationStr = filtered }
                                entry.duration = Int(filtered) ?? 0
                            }
                        Text("min")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("0", text: $secondsStr)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .onChange(of: secondsStr) { _, new in
                                var filtered = new.filter(\.isNumber)
                                if let value = Int(filtered), value > 59 {
                                    filtered = "59"
                                }
                                if filtered != new { secondsStr = filtered }
                                entry.durationSeconds = Int(filtered) ?? 0
                            }
                        Text("sec")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.type.distanceLabel.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("0", text: $distanceStr)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onChange(of: distanceStr) { _, new in
                                let filtered = new.filter { $0.isNumber || $0 == "." }
                                if filtered != new { distanceStr = filtered }
                                entry.distance = Double(filtered) ?? 0.0
                            }
                        Text(entry.type.distanceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            durationStr = entry.duration > 0 ? "\(entry.duration)" : ""
            secondsStr = entry.durationSeconds > 0 ? "\(entry.durationSeconds)" : ""
            distanceStr = entry.distance > 0 ? String(format: "%g", entry.distance) : ""
        }
    }
}
