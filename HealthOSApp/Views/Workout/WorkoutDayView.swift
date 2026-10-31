import SwiftUI

struct WorkoutDayView: View {
    @ObservedObject var exerciseVM: ExerciseLibraryViewModel
    @StateObject private var vm = WorkoutViewModel()
    @State private var showExercisePicker = false
    @State private var showCardioPicker = false
    @State private var showHistory = false
    @State private var showLibrary = false
    @State private var showAbout = false
    @State private var showSavedAlert = false
    @State private var showDatePicker = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                // Day type picker
                Section {
                    Picker("Day Type", selection: $vm.selectedDayType) {
                        ForEach(DayType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        showDatePicker = true
                    } label: {
                        HStack {
                            Text("Date")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(vm.workoutDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if vm.selectedDayType == .cardio {
                    cardioSection
                } else {
                    exercisesSection
                    cardioSection
                }

                // Save
                Section {
                    Button(action: {
                        Task {
                            if await vm.save() {
                                withAnimation {
                                    showSavedAlert = true
                                }
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if vm.isSaving {
                                ProgressView()
                            } else {
                                Text("Save Workout")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(vm.isSaving || !canSave)
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .bottom) {
                RestTimerView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.bar)
                    .contentShape(Rectangle())
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Library", systemImage: "books.vertical") {
                        showLibrary = true
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("About", systemImage: "info.circle") {
                        showAbout = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("History", systemImage: "clock") {
                        showHistory = true
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                VStack(spacing: 0) {
                    DatePicker("", selection: $vm.workoutDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .onChange(of: vm.workoutDate) {
                            showDatePicker = false
                        }
                }
                .padding(.horizontal)
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(
                    allExercises: exerciseVM.exercises,
                    defaultDayType: vm.selectedDayType,
                    selectedIds: Set(vm.selectedExercises.map(\.exerciseId)),
                    currentlyIncludesAbs: vm.includesAbs
                ) { selected, includesAbs in
                    vm.addExercises(from: selected)
                    vm.includesAbs = includesAbs
                }
            }
            .sheet(isPresented: $showCardioPicker) {
                CardioPickerView(
                    selectedTypes: Set(vm.cardioEntries.map(\.type)),
                    showsAbs: vm.selectedDayType == .cardio,
                    currentlyIncludesAbs: vm.includesAbs
                ) { picked, includesAbs in
                    vm.addCardioEntries(from: picked)
                    if vm.selectedDayType == .cardio {
                        vm.includesAbs = includesAbs
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                WorkoutHistoryView(vm: vm)
            }
            .sheet(isPresented: $showLibrary) {
                ExerciseLibraryView(viewModel: exerciseVM)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .overlay {
                if showSavedAlert {
                    WorkoutSavedOverlay(isPresented: $showSavedAlert)
                }
            }
            .onChange(of: vm.selectedDayType) {
                Task { await vm.loadPreviousWorkout() }
            }
            .task {
                await vm.loadPreviousWorkout()
                await vm.loadHistory()
                UnsavedWorkoutNotifier.requestPermissionIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if vm.hasUnsavedWorkout {
                        UnsavedWorkoutNotifier.schedule()
                    }
                case .active:
                    UnsavedWorkoutNotifier.cancel()
                default:
                    break
                }
            }
        }
    }

    private var canSave: Bool {
        if vm.selectedDayType == .cardio {
            return vm.cardioEntries.contains { $0.duration > 0 || $0.durationSeconds > 0 }
        }
        return !vm.selectedExercises.isEmpty || vm.cardioEntries.contains { $0.duration > 0 || $0.durationSeconds > 0 }
    }

    private var cardioSection: some View {
        Section {
            if vm.cardioEntries.isEmpty && !(vm.selectedDayType == .cardio && vm.includesAbs) {
                if vm.selectedDayType != .cardio {
                    // On strength days: compact empty state (just the Add button is enough)
                    EmptyView()
                } else {
                    ContentUnavailableView(
                        "No Cardio",
                        systemImage: "figure.run",
                        description: Text("Add a cardio type to start logging")
                    )
                }
            } else {
                ForEach($vm.cardioEntries) { $entry in
                    CardioRowView(entry: $entry)
                }
                .onDelete(perform: vm.removeCardioEntry)
            }

            // On strength days Abs lives in the Exercises section instead.
            if vm.selectedDayType == .cardio && vm.includesAbs {
                absRow
            }

            Button("Add Cardio", systemImage: "plus") {
                showCardioPicker = true
            }
        } header: {
            HStack {
                Text("Cardio")
                if !vm.cardioEntries.isEmpty {
                    Text("\(vm.cardioEntries.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
            }
        } footer: {
            if vm.selectedDayType == .cardio, let prev = vm.previousWorkout {
                Text("Previous Cardio: \(prev.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
            }
        }
    }

    private var exercisesSection: some View {
        Section {
            if vm.selectedExercises.isEmpty && !vm.includesAbs {
                ContentUnavailableView("No Exercises", systemImage: "plus.circle", description: Text("Add exercises to start logging"))
            } else {
                ForEach($vm.selectedExercises) { $entry in
                    ExerciseRowView(
                        entry: $entry,
                        previousWeight: vm.latestWeightByExercise[entry.exerciseId],
                        targetReps: exerciseVM.exercises.first(where: { $0.id == entry.exerciseId })?.targetRepRange,
                        pendingIncrease: vm.pendingIncreaseByExercise[entry.exerciseId] ?? false
                    )
                }
                .onDelete(perform: vm.removeExercise)

                if vm.includesAbs {
                    absRow
                }
            }

            Button("Add Exercises", systemImage: "plus") {
                showExercisePicker = true
            }
        } header: {
            HStack {
                Text("Exercises")
                let count = vm.selectedExercises.count + (vm.includesAbs ? 1 : 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
            }
        } footer: {
            if let prev = vm.previousWorkout {
                Text("Previous \(vm.selectedDayType.rawValue): \(prev.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
            }
        }
    }

    private var absRow: some View {
        HStack {
            Text("Abs")
            Spacer()
            TextField("lbs", text: $vm.absWeightStr)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .onChange(of: vm.absWeightStr) { _, new in
                    let filtered = new.filter { $0.isNumber || $0 == "." }
                    if filtered != new { vm.absWeightStr = filtered }
                }
            Text("lbs")
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .swipeActions {
            Button(role: .destructive) {
                vm.includesAbs = false
                vm.absWeightStr = ""
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}
