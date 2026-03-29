import Foundation
import SwiftData

@testable import WorkoutTracker

@MainActor
extension BenchmarkTestCase {
    func makeBenchmarkAppStore(
        container: ModelContainer = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true),
        launchArguments: Set<String> = []
    ) -> AppStore {
        let suiteName = "WorkoutTrackerBenchmarks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

        return AppStore(
            modelContainer: container,
            launchArguments: launchArguments,
            settingsStore: SettingsStore(defaults: defaults)
        )
    }
}
