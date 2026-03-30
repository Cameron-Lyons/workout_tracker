# WorkoutTracker (iPhone)

[![Quality](https://github.com/Cameron-Lyons/workout_tracker/actions/workflows/quality.yml/badge.svg?branch=main)](https://github.com/Cameron-Lyons/workout_tracker/actions/workflows/quality.yml)

WorkoutTracker is an iPhone-first SwiftUI strength training app for installing programs, starting workouts quickly, logging sessions live, and reviewing progress over time. The main app flow is organized around three tabs: `Today`, `Programs`, and `Progress`.

## What The App Covers

- Onboarding that lets you start blank or install a preset program pack on first launch.
- `Today` surfaces the pinned next workout, quick-start templates, active-session resume, recent sessions, and recent personal records.
- `Programs` groups templates into editable programs with weekday scheduling, notes, supersets, custom exercises, and pin-to-Today behavior.
- `Session` logging supports warmups, working sets, inline notes, add/copy set actions, undo, discard, finish validation, and rest timers.
- `Progress` shows overview stats, recent records, per-exercise trend charts, calendar history, and completed-session history.
- A widget extension powers the rest timer Live Activity / Dynamic Island experience.
- Data stays local-first with SwiftData-backed persistence for plans, exercise profiles, active drafts, and completed sessions.

## Preset Programs

Built-in packs currently include:

- General Gym
- PHUL
- Starting Strength
- StrongLifts 5x5
- Greyskull LP
- 5/3/1
- Boring But Big
- Madcow 5x5
- GZCLP

## Stack

- Swift 6.2
- SwiftUI with Observation
- SwiftData
- Charts
- ActivityKit and WidgetKit for the rest timer Live Activity
- XcodeGen via `project.yml`
- XCTest unit tests, UI tests, and a dedicated benchmark target

## Requirements

- Xcode 26.4 or newer
- iOS 26.2 simulator runtime for the default commands in this repo
- `xcodegen` if you need to regenerate `WorkoutTracker.xcodeproj`
- Optional CLI tooling: `swiftlint` and `swift-format`

## Project Layout

- `WorkoutTracker/App/`: app entry point, root shell, settings, and app-level coordinators
- `WorkoutTracker/Features/`: onboarding, today, programs, session, and progress flows
- `WorkoutTracker/Domain/`: workout, progression, preset, planning, and analytics-selection models
- `WorkoutTracker/Data/`: repositories, persistence controllers, schema, hydration, and analytics access
- `WorkoutTracker/Shared/`: theme tokens, shared components, modifiers, extensions, and utilities
- `WorkoutTracker/Resources/`: assets and localized strings
- `WorkoutTracker/LiveActivities/`: shared activity attributes used by the widget extension
- `WorkoutTrackerWidgets/`: Live Activity widget UI
- `WorkoutTrackerTests/`: unit tests for stores, persistence, hydration, progression, analytics, and weight logic
- `WorkoutTrackerUITests/`: end-to-end UI coverage and layout smoke tests
- `WorkoutTrackerBenchmarks/`: performance guardrails for analytics, persistence, startup, and app flows
- `.github/workflows/quality.yml`: CI pipeline for linting, build, tests, layout smoke checks, and benchmarks
- `.vscode/tasks.json`: workspace tasks for generating, building, testing, and benchmarking
- `scripts/run-benchmarks.sh`: wrapper around the benchmark scheme
- `BENCHMARKS.md`: benchmark thresholds and maintenance notes
- `project.yml`: XcodeGen project definition

## Run Locally

1. Run `xcodegen generate` only if you changed `project.yml`.
2. Open `WorkoutTracker.xcodeproj` in Xcode.
3. Build and run the `WorkoutTracker` scheme on an iPhone simulator or device.

Cursor/VS Code note:
This repo is an Xcode project generated from `project.yml`, not a Swift Package. The Swift extension's package tasks such as `swift package describe` will fail because there is no `Package.swift`. Use the workspace tasks in `.vscode/tasks.json` or open `WorkoutTracker.xcodeproj` in Xcode.

Default CLI build:

```bash
xcodebuild build -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination "platform=iOS Simulator,name=iPhone 17"
```

Default CLI unit tests:

```bash
xcodebuild test -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:WorkoutTrackerTests
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

The default simulator destination used by the repo commands is `iPhone 17`. CI also runs compact-layout smoke coverage on `iPhone 17e` and larger-layout smoke coverage on `iPad Pro 13-inch (M5)`.

## CI

GitHub Actions runs:

- SwiftLint
- `swift-format` linting
- a clean app build
- unit tests
- full UI tests
- compact and iPad layout smoke tests
- the dedicated benchmark target

Benchmark logs and `.xcresult` bundles are uploaded as workflow artifacts.

## Notes

- `WorkoutTracker.xcodeproj` is generated from `project.yml`, but the generated project is committed for normal day-to-day work.
- Program and progress data hydrate in stages so launch stays responsive even with a larger history.
- Benchmark details and threshold guidance live in [`BENCHMARKS.md`](BENCHMARKS.md).
