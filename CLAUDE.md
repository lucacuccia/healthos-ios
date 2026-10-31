# HealthOS App: iOS Workout Tracker

> Public snapshot of a private working repo. Releases ship to TestFlight from the private repo via GitHub Actions; that workflow and its secrets are not included here.

Personal iOS app for logging weightlifting workouts, cardio, wellness activities, body weight, and blood pressure. Feeds data into the Health OS reporting pipeline via Firebase/Firestore.

## Rules
- **Every commit on `main` ships to TestFlight** (see TestFlight Pipeline). Merging a PR is a release. Commits that only touch `*.md` or `.gitignore` skip the build
- **Never gate destructive Firestore ops on device-local state.** The old UserDefaults-gated exercise reseed wiped prod on 2026-07-08 when run in a fresh simulator. Migration markers belong in Firestore, and seeding must stay non-destructive (`seedExercisesIfNeeded()` only seeds an empty collection)
- **Commit as** `169097717+lucacuccia@users.noreply.github.com`
- **No Swift toolchain in cloud sessions.** `xcodebuild`/`swift` only exist on Luca's Mac and the macOS CI runner, so changes made elsewhere can't be compiled before they merge. Keep edits small, match existing APIs exactly, and say plainly in the PR that the change is unbuilt
- **Code names differ from UI names:** `Extras*` = Wellness tab, `BodyWeight*` = Weight tab

## Related Projects
- `lucacuccia/healthos-pipeline` (public snapshot of the private `health-os` repo): Python backend that consumes workout/weight data for weekly reports
  - `firestore_client.py`: Firestore reader (primary data source, replaces Sheets)
  - `sheets.py`: Google Sheets reader (fallback data source)
  - `analyze.py`: trend analysis that uses workout/weight data
  - See its `CLAUDE.md` for full architecture
- Firestore field names are a contract with that pipeline: renaming or removing a field in `Models/` breaks the reports

## Tech Stack
- SwiftUI (iOS 17+), Swift 5.9
- Firebase iOS SDK 11+ (Firestore + Anonymous Auth)
- ActivityKit / WidgetKit for the rest timer Live Activity
- XcodeGen for project generation (`.xcodeproj` is gitignored; `project.yml` is the source of truth)

## Setup
```bash
# From the repo root (requires xcodegen: brew install xcodegen)
xcodegen generate
open HealthOSApp.xcodeproj
```

## Firebase
- **Project:** your own Firebase project
- **Bundle ID:** `com.lucacuccia.healthos-app`
- **Firestore:** nam5 (us-central). The app signs in anonymously on launch (`HealthOSApp.swift`), and `firestore.rules` allows read/write only for the anonymous UID on Luca's phone (`request.auth != null` alone let anyone in). **Reinstalling the app, or running it in a simulator, gets a new UID and is denied.** To recover, find the new UID under Firebase console → Authentication (newest anonymous user), update `firestore.rules`, and run `firebase deploy --only firestore:rules`. The health_os pipeline uses a service account and bypasses rules
- **Collections:** `exercises`, `workouts`, `extras`, `bodyweight`, `bloodpressure`. One composite index: `workouts` on `dayType` asc + `date` desc
- **PITR:** enabled (7-day retention) on the `(default)` database for disaster recovery
- **GoogleService-Info.plist:** in `HealthOSApp/` (gitignored)
- Rules and indexes deploy with the Firebase CLI (`firebase.json`, `.firebaserc`)

## Architecture
- `Models/`: Codable structs matching the Firestore schema
- `Services/FirestoreService.swift`: all Firestore CRUD
- `Services/UnsavedWorkoutNotifier.swift`: local notification 5 min after backgrounding with an unsaved workout
- `ViewModels/`: one per domain (Workout, ExerciseLibrary, Extras, BodyWeight, BloodPressure, RestTimer)
- `Views/`: SwiftUI views by feature (Workout, Library, Extras, BodyWeight, BloodPressure, About)
- `Utilities/`: `AppVersion` (date-based version display), `String+TitleCase` (exercise name normalization)
- `LiveActivity/RestTimerAttributes.swift`: shared ActivityKit model, compiled into both the app and widget targets
- `RestTimerWidgetExtension/`: widget extension target with the Dynamic Island + lock screen views

## Features (as of 2026-10-04)
Four tabs: Workout, Wellness, Weight, BP. Library and About open as sheets from the Workout tab.

**Workout**
- Exercise picker has its own Push/Pull/Legs filter, so browsing another category doesn't change the workout title. It mirrors library order: a "Favorites" section capped at 5, then non-favorites in an "All" section
- Adding an exercise prefills the weight from the most recent logged value across any day type, falling back to `startingWeight` only if never logged
- Weight/reps/sets fields use string-based bindings so values can be deleted and retyped without reverting
- Weight lookups are keyed by `exerciseId`, not name, so renames don't break history
- Cardio section on every day type (Stairs/Run/Stationary Bike, duration with minutes + seconds, distance): works as a standalone cardio day or warm-up/cool-down
- Abs is a toggle in the picker (under "Other") and shows as a checkmark row. On Cardio days, where there is no exercise picker, the same toggle sits in the cardio picker and the row shows in the Cardio section
- History sheet behind the clock icon; rows expand/collapse to show the full exercise list
- Unsaved-workout reminder notification if the app is backgrounded mid-workout

**Rest timer**
- Centisecond display in a full-width bottom bar; runs on the `.common` RunLoop mode so it doesn't freeze while scrolling
- Chimes at 1:00 (1×), 1:15 (2×), 1:30 (3×) with haptics and an 880Hz tone. Background chimes are scheduled as local notifications with a `chime_` ID prefix, which `NotificationDelegate` silences in the foreground
- Live Activity on the Dynamic Island + lock screen: counts up while backgrounded, frozen with a "Paused" badge when paused, dismissed on reset. The compact pill sits trailing (so it doesn't cover the clock) and uses `Text(date, style: .timer)` in a fixed 44pt frame, with an empty leading region to keep it narrow

**Library** (books icon, Workout tab top-left)
- 40 exercises. Seeding is non-destructive (see Rules); after the 2026-07-08 wipe, all 40 were restored to their original doc IDs from workout logs
- Shows "last: X lbs / max: Y lbs" per exercise (max only if different from last)
- Drag-to-reorder via the Edit button; custom `sortOrder` persisted to Firestore
- Edit sheet has a read-only Logged History section. "Default Weight" (the `startingWeight` field) has a footer explaining it

**Wellness** (`Extras*` in code): Sauna (+ temperature), Meditation (Seated/Walking + duration), Cold Plunge (duration + temperature). History behind the clock icon

**Weight** (`BodyWeight*` in code): daily entries, history behind the clock icon

**BP:** AM/PM session picker, three sys/dias/HR reading rows with a live auto-summary (average of the last two readings), optional notes. One `bloodpressure` doc per session, ID `YYYY-MM-DD-am`/`-pm` (103 historical sessions migrated from the old BP Google Sheet). The history sheet shows 7-day / 30-day / all-time AM+PM averages and an entry list with notes and swipe-to-delete

**About** (info icon, Workout tab top-left): app version and build. `AppVersion.display` renders the date-based version as `2026-08-09` / `2026-08-09.2`

## TestFlight Pipeline
- **GitHub Actions ships every commit on `main`** (`.github/workflows/testflight.yml`), including PRs merged from the web UI or the Claude iPhone app. This replaced the old local `post-commit` hook, which never saw commits merged on GitHub
- Versions are date-based: `fastlane beta` stamps `MARKETING_VERSION` with the build date (`2026.8.9`, since App Store Connect only accepts dotted integers) and sets `CURRENT_PROJECT_VERSION` to the next same-day revision
- The build number comes from `latest_testflight_build_number` (TestFlight is the source of truth), not from `project.yml`. That keeps the lane stateless: same result on a fresh CI checkout as locally, and nothing is committed back. The lane stamps `project.yml`, runs `xcodegen generate`, then restores the file. Don't hand-edit the version fields in `project.yml`; they're placeholders
- CI records what shipped by pushing a `v2026-08-11` / `v2026-08-11.2` **git tag** rather than amending the commit (pushing to `main` would retrigger the workflow)
- The runner sets `TZ=America/New_York`; on UTC the date-based version would roll over five hours early
- The workflow uses the newest Xcode on the `macos-26` image and fails fast if its iOS SDK is older than 26 (App Store Connect rejects older SDKs)
- Signing needs no `.p12` because the distribution certificate is **cloud-managed** (Apple holds the private key; it doesn't appear in the local keychain or in `/v1/certificates`). `-allowProvisioningUpdates` plus the ASC API key is enough
- The archive step still needs an Apple Development cert, and a fresh runner has none, so Xcode creates a "Created via API" dev cert on every run. Ten of those hit Apple's certificate limit on 2026-10-03 and broke signing. `fastlane beta` now revokes dev certs with that exact name before and after each build (never the Mac's own dev cert or the managed distribution cert)
- Two gitignored files are injected from repo secrets, base64-encoded: `ASC_API_KEY_P8` → `fastlane/AuthKey_<KEY_ID>.p8`, `GOOGLE_SERVICE_INFO_PLIST` → `HealthOSApp/GoogleService-Info.plist`. Rotating either means updating the secret with `gh secret set`
- `delete_branch_on_merge` is enabled on the repo, so merged PR branches prune themselves

## Pending
Nothing at the moment.
