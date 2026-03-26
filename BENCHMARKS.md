# Benchmarks

This repo keeps lightweight performance guardrails in `WorkoutTrackerTests/WorkoutBenchmarkTests.swift`.

## Run

```bash
xcodebuild test -project "WorkoutTracker.xcodeproj" -scheme "WorkoutTracker" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:WorkoutTrackerTests/WorkoutBenchmarkTests
```

## What is covered

| Benchmark | Fixture | Thresholds |
| --- | --- | --- |
| `testBenchmarkSessionAnalyticsSnapshotLargeHistory` | 500 sessions, 4 blocks/session, 6 sets/block | avg `<= 0.040s`, max `<= 0.055s` |
| `testBenchmarkProgressStorePrepareStateLargeHistory` | same 500-session history | avg `<= 0.010s`, max `<= 0.020s` |
| `testBenchmarkPlanRepositoryLoadPlansLargeLibrary` | 120 plans, 4 templates/plan, 5 blocks/template, 6 targets/block | avg `<= 2.350s`, max `<= 2.700s` |
| `testBenchmarkSessionRepositoryLoadCompletedSessionsLargeHistory` | 240 completed sessions, 4 blocks/session, 6 sets/block | avg `<= 1.100s`, max `<= 1.200s` |

The thresholds are code-level guardrails, not Xcode `.xcbaseline` files. Each benchmark:

- warms up once
- records several timed samples
- asserts both average and worst-case sample bounds
- attaches a short timing report to the XCTest activity log
- prints a machine-greppable summary into the test log for CI artifacts

## Updating thresholds

Only update thresholds when the workload changes intentionally or you have confirmed a stable performance shift.

Recommended process:

1. Run the benchmark suite a few times on the same simulator/device configuration.
2. Compare the new steady-state averages and max samples with the existing bounds.
3. Keep thresholds tight enough to catch regressions, but loose enough to tolerate normal simulator noise.
4. Update both `WorkoutTrackerTests/WorkoutBenchmarkTests.swift` and this file in the same change.

## Notes

- Simulator timing is noisy; the thresholds are intentionally a bit looser than the latest local averages.
- These benchmarks are meant to catch meaningful regressions in analytics, derived-state preparation, and persistence loading hot paths.
- GitHub Actions uploads both `benchmark-results.log` and `BenchmarkResults.xcresult`, so timing history survives outside the raw console log.
