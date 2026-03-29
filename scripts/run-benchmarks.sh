#!/usr/bin/env bash
set -euo pipefail

PROJECT="${XCODE_PROJECT:-WorkoutTracker.xcodeproj}"
SCHEME="${XCODE_BENCHMARK_SCHEME:-WorkoutTrackerBenchmarks}"
DESTINATION="${XCODE_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-BenchmarkResults.xcresult}"
LOG_PATH="${LOG_PATH:-benchmark-results.log}"

EXTRA_ARGS=("$@")

XCODEBUILD_ARGS=(
  test
  -project "$PROJECT"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -parallel-testing-enabled NO
  -resultBundlePath "$RESULT_BUNDLE_PATH"
)

if ((${#EXTRA_ARGS[@]} > 0)); then
  XCODEBUILD_ARGS+=("${EXTRA_ARGS[@]}")
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" | tee "$LOG_PATH"
