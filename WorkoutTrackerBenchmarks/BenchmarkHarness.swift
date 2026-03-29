import Foundation
import XCTest

struct BenchmarkThreshold {
    let warmupIterationCount: Int
    let measuredIterationCount: Int
    let averageSecondsUpperBound: TimeInterval
    let maxSecondsUpperBound: TimeInterval

    init(
        warmupIterationCount: Int = 1,
        measuredIterationCount: Int,
        averageSecondsUpperBound: TimeInterval,
        maxSecondsUpperBound: TimeInterval
    ) {
        self.warmupIterationCount = warmupIterationCount
        self.measuredIterationCount = measuredIterationCount
        self.averageSecondsUpperBound = averageSecondsUpperBound
        self.maxSecondsUpperBound = maxSecondsUpperBound
    }

    var formattedAverageUpperBound: String {
        Self.format(averageSecondsUpperBound)
    }

    var formattedMaxUpperBound: String {
        Self.format(maxSecondsUpperBound)
    }

    private static func format(_ seconds: TimeInterval) -> String {
        String(format: "%.3fs", seconds)
    }
}

struct BenchmarkResult {
    let samples: [TimeInterval]

    var averageSeconds: TimeInterval {
        guard !samples.isEmpty else {
            return 0
        }

        return samples.reduce(0, +) / Double(samples.count)
    }

    var minSeconds: TimeInterval {
        samples.min() ?? 0
    }

    var medianSeconds: TimeInterval {
        percentile(0.5)
    }

    var p90Seconds: TimeInterval {
        percentile(0.9)
    }

    var maxSeconds: TimeInterval {
        samples.max() ?? 0
    }

    var relativeStandardDeviation: Double {
        guard samples.count > 1, averageSeconds > 0 else {
            return 0
        }

        let variance =
            samples.reduce(0) { partialResult, sample in
                partialResult + ((sample - averageSeconds) * (sample - averageSeconds))
            } / Double(samples.count)
        return variance.squareRoot() / averageSeconds
    }

    var formattedAverage: String {
        Self.format(averageSeconds)
    }

    var formattedMin: String {
        Self.format(minSeconds)
    }

    var formattedMedian: String {
        Self.format(medianSeconds)
    }

    var formattedP90: String {
        Self.format(p90Seconds)
    }

    var formattedMax: String {
        Self.format(maxSeconds)
    }

    func report(named name: String, threshold: BenchmarkThreshold) -> String {
        let formattedSamples =
            samples
            .map { String(format: "%.4f", $0) }
            .joined(separator: ", ")

        return """
            BENCHMARK: \(name)
            benchmark.warmup_iterations: \(threshold.warmupIterationCount)
            benchmark.iterations: \(samples.count)
            benchmark.min: \(formattedMin)
            benchmark.average: \(formattedAverage) (threshold: \(threshold.formattedAverageUpperBound))
            benchmark.median: \(formattedMedian)
            benchmark.p90: \(formattedP90)
            benchmark.max: \(formattedMax) (threshold: \(threshold.formattedMaxUpperBound))
            benchmark.rsd: \(String(format: "%.2f%%", relativeStandardDeviation * 100))
            benchmark.samples: [\(formattedSamples)]

            """
    }

    private func percentile(_ fraction: Double) -> TimeInterval {
        guard !samples.isEmpty else {
            return 0
        }

        let sortedSamples = samples.sorted()
        let index = Int((Double(sortedSamples.count - 1) * fraction).rounded())
        return sortedSamples[index]
    }

    private static func format(_ seconds: TimeInterval) -> String {
        String(format: "%.3fs", seconds)
    }
}

@MainActor
class BenchmarkTestCase: XCTestCase {
    @discardableResult
    func benchmark(
        named name: String,
        threshold: BenchmarkThreshold,
        operation: () -> Void
    ) -> BenchmarkResult {
        runWarmupIterations(count: threshold.warmupIterationCount, operation: operation)

        var samples: [TimeInterval] = []
        samples.reserveCapacity(threshold.measuredIterationCount)

        for _ in 0..<threshold.measuredIterationCount {
            let start = DispatchTime.now().uptimeNanoseconds
            operation()
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsedNanoseconds) / 1_000_000_000)
        }

        return finalizeBenchmark(named: name, threshold: threshold, samples: samples)
    }

    @discardableResult
    func benchmark<Fixture>(
        named name: String,
        threshold: BenchmarkThreshold,
        setup: () -> Fixture,
        operation: (Fixture) -> Void
    ) -> BenchmarkResult {
        runWarmupIterations(count: threshold.warmupIterationCount) {
            operation(setup())
        }

        var samples: [TimeInterval] = []
        samples.reserveCapacity(threshold.measuredIterationCount)

        for _ in 0..<threshold.measuredIterationCount {
            let fixture = setup()
            let start = DispatchTime.now().uptimeNanoseconds
            operation(fixture)
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsedNanoseconds) / 1_000_000_000)
        }

        return finalizeBenchmark(named: name, threshold: threshold, samples: samples)
    }

    @discardableResult
    func benchmark(
        named name: String,
        threshold: BenchmarkThreshold,
        operation: () async -> Void
    ) async -> BenchmarkResult {
        await runWarmupIterations(count: threshold.warmupIterationCount, operation: operation)

        var samples: [TimeInterval] = []
        samples.reserveCapacity(threshold.measuredIterationCount)

        for _ in 0..<threshold.measuredIterationCount {
            let start = DispatchTime.now().uptimeNanoseconds
            await operation()
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsedNanoseconds) / 1_000_000_000)
        }

        return finalizeBenchmark(named: name, threshold: threshold, samples: samples)
    }

    @discardableResult
    func benchmark<Fixture>(
        named name: String,
        threshold: BenchmarkThreshold,
        setup: () async -> Fixture,
        operation: (Fixture) async -> Void
    ) async -> BenchmarkResult {
        await runWarmupIterations(count: threshold.warmupIterationCount) {
            let fixture = await setup()
            await operation(fixture)
        }

        var samples: [TimeInterval] = []
        samples.reserveCapacity(threshold.measuredIterationCount)

        for _ in 0..<threshold.measuredIterationCount {
            let fixture = await setup()
            let start = DispatchTime.now().uptimeNanoseconds
            await operation(fixture)
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsedNanoseconds) / 1_000_000_000)
        }

        return finalizeBenchmark(named: name, threshold: threshold, samples: samples)
    }

    private func runWarmupIterations(count: Int, operation: () -> Void) {
        for _ in 0..<count {
            operation()
        }
    }

    private func runWarmupIterations(count: Int, operation: () async -> Void) async {
        for _ in 0..<count {
            await operation()
        }
    }

    private func finalizeBenchmark(
        named name: String,
        threshold: BenchmarkThreshold,
        samples: [TimeInterval]
    ) -> BenchmarkResult {
        let result = BenchmarkResult(samples: samples)
        let report = result.report(named: name, threshold: threshold)
        XCTContext.runActivity(named: "Benchmark: \(name)") { activity in
            let attachment = XCTAttachment(string: report)
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
        print(report)

        XCTAssertLessThanOrEqual(
            result.averageSeconds,
            threshold.averageSecondsUpperBound,
            "\(name) average \(result.formattedAverage) exceeded threshold \(threshold.formattedAverageUpperBound)"
        )
        XCTAssertLessThanOrEqual(
            result.maxSeconds,
            threshold.maxSecondsUpperBound,
            "\(name) max sample \(result.formattedMax) exceeded threshold \(threshold.formattedMaxUpperBound)"
        )

        return result
    }
}
