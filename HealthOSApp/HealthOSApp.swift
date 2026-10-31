import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications

@main
struct HealthOSApp: App {
    @State private var isAuthenticated = false
    @State private var authError: String?

    init() {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                ContentView()
            } else if let authError {
                VStack(spacing: 12) {
                    Text("Couldn't sign in")
                        .font(.headline)
                    Text(authError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        self.authError = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView("Loading...")
                    .task {
                        await signInAnonymously()
                    }
            }
        }
    }

    private func signInAnonymously() async {
        if Auth.auth().currentUser != nil {
            isAuthenticated = true
            return
        }
        do {
            try await Auth.auth().signInAnonymously()
            isAuthenticated = true
        } catch {
            print("Anonymous auth failed: \(error.localizedDescription)")
            authError = error.localizedDescription
        }
    }
}

// Suppress rest-timer chime banners when app is in foreground so in-app playTone() handles it.
// Other notifications (e.g. the unsaved-workout reminder) still present normally.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier.hasPrefix("chime_") {
            completionHandler([])   // no banner, no sound — in-app chime already fired
        } else {
            completionHandler([.banner, .sound])
        }
    }
}
