import SwiftUI

struct AddExerciseView: View {
    @ObservedObject var viewModel: ExerciseLibraryViewModel
    @Environment(\.dismiss) private var dismiss

    let editingExercise: Exercise?

    @State private var name = ""
    @State private var dayType: DayType = .push
    @State private var sets = 3
    @State private var repMin = 8
    @State private var repMax = 12
    @State private var startingWeight = ""

    private var isEditing: Bool { editingExercise != nil }

    init(viewModel: ExerciseLibraryViewModel, exercise: Exercise? = nil) {
        self.viewModel = viewModel
        self.editingExercise = exercise
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    Picker("Day Type", selection: $dayType) {
                        Text("Push").tag(DayType.push)
                        Text("Pull").tag(DayType.pull)
                        Text("Legs").tag(DayType.legs)
                    }
                }

                Section {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    Stepper("Min Reps: \(repMin)", value: $repMin, in: 1...30)
                    Stepper("Max Reps: \(repMax)", value: $repMax, in: 1...30)
                    HStack {
                        TextField("Default Weight", text: $startingWeight)
                            .keyboardType(.decimalPad)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Defaults")
                } footer: {
                    Text("Default weight is a fallback used only if you have no logged history for this exercise.")
                }

                if let exercise = editingExercise {
                    Section("Logged History") {
                        let last = viewModel.latestWeights[exercise.id ?? ""]
                        let max = exercise.maxWeight
                        if let last {
                            LabeledContent("Last logged", value: String(format: "%g lbs", last))
                        }
                        if let max, max != last {
                            LabeledContent("Max logged", value: String(format: "%g lbs", max))
                        }
                        if last == nil && max == nil {
                            Text("No workout history yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task {
                            if let exercise = editingExercise {
                                await viewModel.updateExercise(
                                    exercise,
                                    name: name,
                                    dayType: dayType,
                                    sets: sets,
                                    repMin: repMin,
                                    repMax: max(repMin, repMax),
                                    startingWeight: Double(startingWeight) ?? 0
                                )
                            } else {
                                await viewModel.addExercise(
                                    name: name,
                                    dayType: dayType,
                                    sets: sets,
                                    repMin: repMin,
                                    repMax: max(repMin, repMax),
                                    startingWeight: Double(startingWeight) ?? 0
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let exercise = editingExercise {
                    name = exercise.name
                    dayType = exercise.dayType
                    sets = exercise.defaultSets
                    repMin = exercise.targetRepMin
                    repMax = exercise.targetRepMax
                    startingWeight = exercise.startingWeight > 0 ? String(format: "%.10g", exercise.startingWeight) : ""
                }
            }
        }
    }
}
