# WorkoutTracker (iPhone)

Native SwiftUI iPhone app for logging workouts with routines and voice entry.

## Features
- Create/delete workout routines
- Edit and reorder routines
- Add, edit, and reorder exercises inside each routine
- Log multiple sets per exercise (manual-first flow)
- One-tap program templates: Starting Strength, 5/3/1, Boring But Big
- Popular online routine packs: Push/Pull/Legs, Upper/Lower, StrongLifts 5x5, Arnold Split, PHUL
- Auto-calculated prescribed sets/weights for template routines (using per-exercise TM/working weight)
- Automatic progression tracking:
  - Starting Strength day rotation (A/B)
  - 5/3/1 and BBB week/cycle progression with TM increases each cycle
- Optional voice tools (toggle in logger) to dictate values like:
  - `135 for 8`
  - `225 pounds 5 reps`
  - `80 x 12`
- Workout history view with timestamped sessions
- Historical lift record storage (per set) for trend analysis
- Progress-over-time chart by exercise (top set per workout)
- Rest timer in the workout logger (presets + pause/resume/reset + optional auto-start)
- Local persistence via `UserDefaults`

## Project Structure
- `WorkoutTracker.xcodeproj` (generated)
- `WorkoutTracker/Models` for data, persistence, speech, and parsing
- `WorkoutTracker/Views` for routines, logging, and history screens

## Run
1. Open `/Users/cam/workout_tracker/WorkoutTracker.xcodeproj` in Xcode.
2. Select an iPhone simulator or connected iPhone.
3. Build and run.

## Notes
- The app requests Microphone + Speech Recognition permissions the first time voice input is used.
- `project.yml` is included for regenerating the Xcode project with `xcodegen generate` if you want to edit project settings.
