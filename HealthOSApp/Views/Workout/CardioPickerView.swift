import SwiftUI

struct CardioPickerView: View {
    let selectedTypes: Set<CardioType>
    // Abs is offered here only on Cardio days; strength days toggle it in the
    // exercise picker instead.
    let showsAbs: Bool
    let currentlyIncludesAbs: Bool
    let onAdd: ([CardioType], Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<CardioType> = []
    @State private var absSelected: Bool

    init(selectedTypes: Set<CardioType>, showsAbs: Bool, currentlyIncludesAbs: Bool,
         onAdd: @escaping ([CardioType], Bool) -> Void) {
        self.selectedTypes = selectedTypes
        self.showsAbs = showsAbs
        self.currentlyIncludesAbs = currentlyIncludesAbs
        self.onAdd = onAdd
        self._absSelected = State(initialValue: currentlyIncludesAbs)
    }

    private var canConfirm: Bool {
        picked.count > 0 || absSelected != currentlyIncludesAbs
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CardioType.allCases) { type in
                        cardioTypeRow(type)
                    }
                }

                if showsAbs {
                    Section("Other") {
                        Button {
                            absSelected.toggle()
                        } label: {
                            HStack {
                                Text("Abs")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if absSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(picked.count + (absSelected && !currentlyIncludesAbs ? 1 : 0)))") {
                        onAdd(Array(picked), absSelected)
                        dismiss()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func cardioTypeRow(_ type: CardioType) -> some View {
        let alreadyAdded = selectedTypes.contains(type)

        return Button {
            if picked.contains(type) {
                picked.remove(type)
            } else {
                picked.insert(type)
            }
        } label: {
            HStack {
                Text(type.rawValue)
                    .foregroundStyle(alreadyAdded ? .secondary : .primary)
                Spacer()
                if alreadyAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if picked.contains(type) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(alreadyAdded)
    }
}
