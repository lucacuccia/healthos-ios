import SwiftUI

struct ContentView: View {
    @StateObject private var exerciseVM = ExerciseLibraryViewModel()

    var body: some View {
        TabView {
            WorkoutDayView(exerciseVM: exerciseVM)
                .tabItem {
                    Label("Workout", systemImage: "dumbbell")
                }

            ExtrasLogView()
                .tabItem {
                    Label("Wellness", systemImage: "heart.text.square")
                }

            WeightEntryView()
                .tabItem {
                    Label("Weight", systemImage: "scalemass")
                }

            BloodPressureEntryView()
                .tabItem {
                    Label("BP", systemImage: "waveform.path.ecg")
                }
        }
        .task {
            await exerciseVM.load()
        }
    }
}
