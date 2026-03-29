# Benchmarks

This repo keeps lightweight performance guardrails in the dedicated `WorkoutTrackerBenchmarks` test bundle.

## Run

```bash
./scripts/run-benchmarks.sh
```

## What is covered

| Area | Benchmark | Fixture | Thresholds |
| --- | --- | --- | --- |
| Analytics | `AnalyticsBenchmarks.testSessionAnalyticsSnapshotLargeHistory` | 500 sessions, 4 blocks/session, 6 sets/block | avg `<= 0.030s`, max `<= 0.040s` |
| Analytics | `AnalyticsBenchmarks.testProgressStorePrepareStateLargeHistory` | same 500-session history | avg `<= 0.005s`, max `<= 0.008s` |
| Persistence | `PersistenceBenchmarks.testPlanRepositorySavePlansLargeLibrary` | 120 plans, 4 templates/plan, 5 blocks/template, 6 targets/block | avg `<= 2.050s`, max `<= 2.250s` |
| Persistence | `PersistenceBenchmarks.testPlanRepositoryLoadPlansLargeLibrary` | same large plan library | avg `<= 2.200s`, max `<= 2.400s` |
| Persistence | `PersistenceBenchmarks.testSessionRepositorySaveActiveDraftLargeSession` | 18-block progression session draft, 6 targets/block | avg `<= 0.035s`, max `<= 0.045s` |
| Persistence | `PersistenceBenchmarks.testSessionRepositoryLoadActiveDraftLargeSession` | same large active draft | avg `<= 0.030s`, max `<= 0.040s` |
| Persistence | `PersistenceBenchmarks.testSessionRepositoryPersistCompletedSessionLargeSession` | completed 18-block progression session | avg `<= 0.035s`, max `<= 0.045s` |
| Persistence | `PersistenceBenchmarks.testSessionRepositoryLoadCompletedSessionsLargeHistory` | 240 completed sessions, 4 blocks/session, 6 sets/block | avg `<= 0.950s`, max `<= 1.050s` |
| App Flow | `AppFlowBenchmarks.testSessionEngineStartSessionLargeTemplate` | 18-block mixed-progression template | avg `<= 0.001s`, max `<= 0.002s` |
| App Flow | `AppFlowBenchmarks.testAppStoreFinishActiveSessionLargeProgressionSession` | finish + persist a 12-block progression session | avg `<= 0.080s`, max `<= 0.100s` |
| App Flow | `AppFlowBenchmarks.testPersistenceHydrationLoaderLoadStartupSnapshotLargeLibrary` | startup summary snapshot with 121 plans, profiles, and active draft | avg `<= 0.450s`, max `<= 0.500s` |
| App Flow | `AppFlowBenchmarks.testPersistenceHydrationLoaderLoadCompletedSessionHistoryLargeHistory` | lazy history load for 240 completed sessions | avg `<= 0.950s`, max `<= 1.050s` |
| App Flow | `AppFlowBenchmarks.testAppDerivedStateControllerRefreshDerivedStoresLargeLibraryAndHistory` | refresh derived stores for 120 plans + 500 sessions | avg `<= 0.035s`, max `<= 0.045s` |

The thresholds are code-level guardrails, not Xcode `.xcbaseline` files. The suite is split into:

- `WorkoutTrackerBenchmarks/BenchmarkHarness.swift` for warmup, timing, threshold assertions, and benchmark reports
- `WorkoutTrackerBenchmarks/BenchmarkFixtures.swift` for shared synthetic plans, sessions, and catalog data
- `WorkoutTrackerBenchmarks/AnalyticsBenchmarks.swift` for derived-state and analytics hot paths
- `WorkoutTrackerBenchmarks/PersistenceBenchmarks.swift` for SwiftData persistence loading hot paths
- `WorkoutTrackerBenchmarks/AppFlowBenchmarks.swift` for startup, derived refresh, and session lifecycle flows
- `WorkoutTrackerBenchmarks/BenchmarkSupport.swift` for ephemeral benchmark-local app store setup

Each benchmark:

- warms up once
- records several timed samples
- reports average, median, p90, max, RSD, and raw samples
- asserts both average and worst-case sample bounds
- attaches a short timing report to the XCTest activity log
- prints a machine-greppable summary into the test log for CI artifacts

The benchmark scheme is `WorkoutTrackerBenchmarks`, separate from the main `WorkoutTracker` scheme, so benchmark runs do not inherit coverage instrumentation from the normal test suite.

## Updating thresholds

Only update thresholds when the workload changes intentionally or you have confirmed a stable performance shift.

Recommended process:

1. Run the benchmark suite a few times on the same simulator/device configuration.
2. Compare the new steady-state averages and max samples with the existing bounds.
3. Keep thresholds tight enough to catch regressions, but loose enough to tolerate normal simulator noise.
4. Update the relevant file under `WorkoutTrackerBenchmarks/` and this file in the same change.

## Notes

- Simulator timing is noisy; the thresholds are intentionally a bit looser than the latest local averages.
- These benchmarks are meant to catch meaningful regressions in analytics, derived-state preparation, startup hydration, session lifecycle flows, and persistence read/write paths.
- GitHub Actions uploads both `benchmark-results.log` and `BenchmarkResults.xcresult`, so timing history survives outside the raw console log.
