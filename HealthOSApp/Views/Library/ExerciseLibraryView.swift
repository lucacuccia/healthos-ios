import SwiftUI

struct ExerciseLibraryView: View {
    @ObservedObject var viewModel: ExerciseLibraryViewModel
    @State private var showAddSheet = false
    @State private var exerciseToEdit: Exercise?

    var body: some View {
        NavigationStack {
            List {
                ForEach([DayType.push, .pull, .legs], id: \.self) { dayType in
                    Section {
                        Text(dayType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))

                        let exercises = viewModel.libraryExercises(for: dayType)
                        ForEach(exercises) { exercise in
                            exerciseRow(exercise)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    exerciseToEdit = exercise
                                }
                        }
                        .onDelete { offsets in
                            let exercises = viewModel.libraryExercises(for: dayType)
                            for offset in offsets {
                                Task { await viewModel.deleteExercise(exercises[offset]) }
                            }
                        }
                        .onMove { from, to in
                            Task { await viewModel.moveExercises(in: dayType, from: from, to: to) }
                        }
                    }
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        showAddSheet = true
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExerciseView(viewModel: viewModel)
            }
            .sheet(item: $exerciseToEdit) { exercise in
                AddExerciseView(viewModel: viewModel, exercise: exercise)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(exercise.name)
                    .font(.body)
                Text("\(exercise.defaultSets) sets × \(exercise.targetRepRange) reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let latest = viewModel.currentWeight(for: exercise)
            let max = viewModel.maxWeight(for: exercise)
            if latest != nil || max != nil {
                VStack(alignment: .trailing, spacing: 2) {
                    if let latest {
                        Text("last: \(latest, specifier: "%g") lbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let max {
                        Text("max: \(max, specifier: "%g") lbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                Task { await viewModel.toggleFavorite(exercise) }
            } label: {
                Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(exercise.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
