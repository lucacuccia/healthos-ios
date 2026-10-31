import SwiftUI

struct ExercisePickerView: View {
    let allExercises: [Exercise]
    let defaultDayType: DayType
    let selectedIds: Set<String>
    let currentlyIncludesAbs: Bool
    let onAdd: ([Exercise], Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    // Order matters: exercises are added to the workout in the order they were
    // tapped here, not in library order.
    @State private var picked: [String] = []
    @State private var absSelected: Bool
    @State private var filterDayType: DayType
    @State private var showAllFavorites = false

    init(allExercises: [Exercise], defaultDayType: DayType, selectedIds: Set<String>,
         currentlyIncludesAbs: Bool, onAdd: @escaping ([Exercise], Bool) -> Void) {
        self.allExercises = allExercises
        self.defaultDayType = defaultDayType
        self.selectedIds = selectedIds
        self.currentlyIncludesAbs = currentlyIncludesAbs
        self.onAdd = onAdd
        self._filterDayType = State(initialValue: defaultDayType)
        self._absSelected = State(initialValue: currentlyIncludesAbs)
    }

    private var filteredExercises: [Exercise] {
        allExercises
            .filter { $0.dayType == filterDayType }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var canConfirm: Bool {
        picked.count > 0 || absSelected != currentlyIncludesAbs
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Category", selection: $filterDayType) {
                        ForEach([DayType.push, .pull, .legs]) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                let favorites = filteredExercises.filter(\.isFavorite)
                let others = filteredExercises.filter { !$0.isFavorite }

                if !favorites.isEmpty {
                    Section("Favorites") {
                        let visible = showAllFavorites ? favorites : Array(favorites.prefix(5))
                        ForEach(visible) { exercise in
                            exerciseRow(exercise)
                        }
                        if favorites.count > 5 && !showAllFavorites {
                            Button("Show more (\(favorites.count - 5) more)") {
                                showAllFavorites = true
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }

                if !others.isEmpty {
                    Section("All") {
                        ForEach(others) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }

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
            .onChange(of: filterDayType) { showAllFavorites = false }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(picked.count + (absSelected && !currentlyIncludesAbs ? 1 : 0)))") {
                        let byId = Dictionary(
                            allExercises.compactMap { ex in ex.id.map { ($0, ex) } },
                            uniquingKeysWith: { first, _ in first }
                        )
                        let selected = picked.compactMap { byId[$0] }
                        onAdd(selected, absSelected)
                        dismiss()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let id = exercise.id ?? ""
        let alreadyAdded = selectedIds.contains(id)

        return Button {
            if let index = picked.firstIndex(of: id) {
                picked.remove(at: index)
            } else {
                picked.append(id)
            }
        } label: {
            HStack {
                Text(exercise.name)
                    .foregroundStyle(alreadyAdded ? .secondary : .primary)
                Spacer()
                if alreadyAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let position = picked.firstIndex(of: id) {
                    // SF Symbols only ship numbered circles up to 50.
                    Image(systemName: position < 50 ? "\(position + 1).circle.fill" : "checkmark.circle.fill")
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
