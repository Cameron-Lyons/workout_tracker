# WorkoutTracker (iPhone)

[![Quality](https://github.com/Cameron-Lyons/workout_tracker/actions/workflows/quality.yml/badge.svg?branch=main)](https://github.com/Cameron-Lyons/workout_tracker/actions/workflows/quality.yml)

Native SwiftUI iPhone app for logging workouts with routines.

## Features
- Create, edit, and delete workout routines
- Add, edit, and remove exercises inside each routine
- Log multiple sets per exercise (manual-first flow)
- One-tap program templates: Starting Strength, 5/3/1, Boring But Big
- Popular online routine packs: Push/Pull/Legs, Upper/Lower, StrongLifts 5x5, Arnold Split, PHUL
- Auto-calculated prescribed sets/weights for template routines (using per-exercise TM/working weight)
- Automatic progression tracking:
  - Starting Strength day rotation (A/B)
  - 5/3/1 and BBB week/cycle progression with TM increases each cycle
- Workout history view with timestamped sessions
- Historical lift record storage (per set) for trend analysis
- Progress-over-time chart by exercise (top set per workout)
- Rest timer in the workout logger (optional auto-start + clear)
- Local persistence via SwiftData (v2 fast storage path)

## Project Structure
- `WorkoutTracker.xcodeproj` (generated)
- `WorkoutTracker/Models` for data and persistence
- `WorkoutTracker/Views` for routines, logging, and history screens

## Run
1. Open `/Users/cam/workout_tracker/WorkoutTracker.xcodeproj` in Xcode.
2. Select an iPhone simulator or connected iPhone.
3. Build and run.

## Notes
- `project.yml` is included for regenerating the Xcode project with `xcodegen generate` if you want to edit project settings.

## Quality Checks
- `swiftlint lint --config .swiftlint.yml`
- `swift-format lint --recursive --configuration .swift-format WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`
- `swift-format format --in-place --recursive --configuration .swift-format WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`
- `xcodebuild build -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination "platform=iOS Simulator,name=iPhone 17"`
- The same checks run automatically in GitHub Actions on pushes to `main` and on pull requests.
