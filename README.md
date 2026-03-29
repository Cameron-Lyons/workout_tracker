# WorkoutTracker (iPhone)

[![Quality](https://github.com/Cameron-Lyons/workout_tracker/actions/workflows/quality.yml/badge.svg?branch=main)](https://github.com/Cameron-Lyons/workout_tracker/actions/workflows/quality.yml)

WorkoutTracker is an iPhone-first SwiftUI strength training app for building plans, running live workout sessions, and reviewing progress over time. The app is organized around three primary tabs: `Today`, `Plans`, and `Progress`.

## Highlights

- Session-first flow with pinned templates, quick start actions, and autosaved active workouts.
- Editable plans and templates with scheduled weekdays, notes, supersets, custom exercises, and pin-to-Today behavior.
- Built-in preset packs: General Gym, PHUL, Starting Strength, StrongLifts 5x5, Greyskull LP, 5/3/1, Boring But Big, Madcow 5x5, and GZCLP.
- Workout logger with warmups, working sets, add/copy set actions, inline notes, rest timers, undo, discard, and finish validation.
- Progress dashboard with recent PRs, per-exercise trend charts, calendar history, recent sessions, and rolling weekly and 30-day metrics.
- Local-first persistence for plans, exercise profiles, active session drafts, and completed sessions using SwiftData.

## Stack

- Swift 6.2
- SwiftUI with Observation
- SwiftData
- Charts
- XcodeGen via `project.yml`
- XCTest unit tests, UI tests, and a dedicated benchmark bundle

## Requirements

- Xcode 26.3 or newer
- iOS 26.2 simulator runtime for the default commands in this repo
- Optional CLI tooling: `xcodegen`, `swiftlint`, and `swift-format`

## Project Layout

- `WorkoutTracker/`: app source, models, views, persistence, and resources
- `WorkoutTrackerTests/`: unit tests for stores, progression logic, and weight handling
- `WorkoutTrackerUITests/`: UI coverage and layout smoke tests
- `WorkoutTrackerBenchmarks/`: performance guardrails for analytics, persistence, startup, and session flows
- `scripts/run-benchmarks.sh`: wrapper for the benchmark scheme
- `BENCHMARKS.md`: benchmark thresholds and maintenance notes
- `project.yml`: XcodeGen project definition

## Run Locally

1. Run `xcodegen generate` if you changed `project.yml`.
2. Open `WorkoutTracker.xcodeproj` in Xcode.
3. Build and run the `WorkoutTracker` scheme on an iPhone simulator or device.

Optional CLI build:

```bash
xcodebuild build -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination "platform=iOS Simulator,name=iPhone 17"
```

## Quality Checks

```bash
swiftlint lint --config .swiftlint.yml
swift-format lint --recursive --configuration .swift-format WorkoutTracker WorkoutTrackerTests WorkoutTrackerBenchmarks WorkoutTrackerUITests
swift-format format --in-place --recursive --configuration .swift-format WorkoutTracker WorkoutTrackerTests WorkoutTrackerBenchmarks WorkoutTrackerUITests
xcodebuild build -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination "platform=iOS Simulator,name=iPhone 17"
xcodebuild test -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:WorkoutTrackerTests
xcodebuild test -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination "platform=iOS Simulator,name=iPhone 17" -parallel-testing-enabled NO -only-testing:WorkoutTrackerUITests
./scripts/run-benchmarks.sh
```

## CI

GitHub Actions runs SwiftLint, `swift-format`, a clean app build, unit tests, UI tests, compact-phone and iPad layout smoke tests, and the dedicated benchmark scheme. Benchmark logs and UI result bundles are uploaded as workflow artifacts.

## Notes

- `WorkoutTracker.xcodeproj` is generated from `project.yml`, but the generated project is committed for normal day-to-day work.
- Benchmark details and threshold guidance live in [`BENCHMARKS.md`](BENCHMARKS.md).
