# HealthOS App

Personal iOS app for logging weightlifting workouts, cardio, wellness activities, body weight, and blood pressure. Feeds data into the [Health OS](https://github.com/lucacuccia/healthos-pipeline) reporting pipeline via Firebase/Firestore.

The app has four tabs — Workout, Wellness, Weight, and BP — plus an exercise Library that opens as a sheet from the Workout tab.

## Features

- **Workout logging** — Weightlifting sets with weight/reps/sets by day type (Push/Pull/Legs). Exercises are added in the order you pick them, and weight prefills from the last value you logged (zero weights are ignored). Each row shows the previous weight and a progression cue
- **Cardio** — Stairs, run, or stationary bike with duration + distance (runs take `mm:ss`), as a standalone day or warm-up/cool-down on a strength day
- **Abs** — Toggle from the exercise picker, with an optional weight
- **Unsaved-workout reminder** — A notification if a workout is left in progress without being saved
- **Workout history** — Calendar and list views, paginated, with rows that expand to show the full exercise list
- **Rest timer** — Centisecond display, chimes at 1:00/1:15/1:30 with haptics, and a Dynamic Island / lock screen Live Activity that keeps counting while the app is backgrounded
- **Wellness** — Sauna (with temperature), meditation (seated/walking, with duration), cold plunge (duration + temperature)
- **Body weight** — Daily weight tracking with history
- **Blood pressure** — AM/PM sessions with sys/dias/HR readings, live auto-averaging, and a history view with 7-day/30-day/all-time averages
- **Exercise library** — 40 pre-loaded exercises, drag-to-reorder, favorites, per-exercise last/max logged weight, and a logged-history view in the edit sheet. Names are auto-capitalized
- **About screen** — Shows a date-based app version (e.g. `2026-08-09`), accessible from the Workout tab toolbar

History for Wellness, Weight, and BP sits behind the clock icon in each tab's nav bar.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| Backend | Firebase Firestore |
| Auth | Firebase Anonymous Auth |
| Live Activities | ActivityKit / WidgetKit (`RestTimerWidgetExtension`) |
| Project gen | XcodeGen |

## Getting Started

### Prerequisites

- Xcode 26+ (TestFlight only accepts builds made with the iOS 26 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A `GoogleService-Info.plist` from your Firebase project, placed in `HealthOSApp/`

### Setup

```bash
# Generate the Xcode project
xcodegen generate

# Open in Xcode
open HealthOSApp.xcodeproj
```

Build and run on a simulator or device from Xcode. The app signs in with Firebase Anonymous Auth on launch.

### Firestore rules and indexes

Security rules (`firestore.rules`) and composite indexes (`firestore.indexes.json`) are deployed with the Firebase CLI:

```bash
firebase deploy --only firestore
```

### Data safety

- Exercise seeding only runs when the `exercises` collection is empty — it never overwrites existing data
- Point-in-time recovery (7-day retention) is enabled on the `(default)` database

## Project Structure

```
HealthOSApp/
├── Models/              # Codable structs matching Firestore schema
├── Services/            # FirestoreService (all Firestore CRUD), UnsavedWorkoutNotifier
├── ViewModels/          # One per domain (Workout, Exercise, Extras, BodyWeight, BloodPressure, RestTimer)
├── Views/               # SwiftUI views organized by feature (Workout, Extras, Library, BodyWeight, BloodPressure, About)
├── LiveActivity/        # Shared ActivityKit model for the rest timer (compiled into app + widget targets)
├── Utilities/           # Helpers (date-based AppVersion, String+TitleCase)
└── Assets.xcassets/     # App icon and image assets

RestTimerWidgetExtension/ # Widget extension target — Dynamic Island + lock screen views
fastlane/                 # beta lane — builds and uploads to TestFlight
project.yml               # XcodeGen spec (the .xcodeproj is generated, not committed)
firebase.json             # Firebase CLI config → firestore.rules, firestore.indexes.json
```

## TestFlight Pipeline

Every commit pushed to `main` is built and shipped to TestFlight automatically by GitHub Actions (`.github/workflows/testflight.yml`), which runs `fastlane beta`. *(This public copy is a snapshot of a private working repo; the workflow and its secrets live there.)* This covers PRs merged from the web UI or the Claude iPhone app, not just commits made locally.

- The build number is read from App Store Connect (`latest_testflight_build_number`) rather than tracked in the repo, so the lane produces the same result on a fresh CI checkout as it does locally
- App version is date-based (`2026.8.9`, shown in-app as `2026-08-09`) — `fastlane beta` stamps `project.yml`, runs `xcodegen generate`, then restores the file so the working tree stays clean
- CI tags each shipped build (`v2026-08-09`) rather than committing back to `main`
- Code signing uses a cloud-managed distribution certificate plus an App Store Connect API key — no `.p12` needed on the runner

## Related Projects

- **[Health OS](https://github.com/lucacuccia/healthos-pipeline)** — Python backend that consumes workout and weight data for weekly health reports
