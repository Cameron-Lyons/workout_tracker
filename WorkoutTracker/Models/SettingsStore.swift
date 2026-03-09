import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let upperIncrement = "workout_tracker_v2_upper_increment"
        static let lowerIncrement = "workout_tracker_v2_lower_increment"
        static let defaultRestSeconds = "workout_tracker_v2_default_rest"
        static let completedOnboarding = "workout_tracker_v2_completed_onboarding"
        static let warmupRamp = "workout_tracker_v2_warmup_ramp"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()

    var weightUnit: WeightUnit {
        didSet {
            defaults.set(weightUnit.rawValue, forKey: WeightUnit.settingsKey)
        }
    }

    var upperBodyIncrement: Double {
        didSet {
            defaults.set(upperBodyIncrement, forKey: Keys.upperIncrement)
        }
    }

    var lowerBodyIncrement: Double {
        didSet {
            defaults.set(lowerBodyIncrement, forKey: Keys.lowerIncrement)
        }
    }

    var defaultRestSeconds: Int {
        didSet {
            defaults.set(defaultRestSeconds, forKey: Keys.defaultRestSeconds)
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.completedOnboarding)
        }
    }

    var warmupRamp: [WarmupRampStep] {
        didSet {
            if let data = try? encoder.encode(warmupRamp) {
                defaults.set(data, forKey: Keys.warmupRamp)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.weightUnit = WeightUnit(rawValue: defaults.string(forKey: WeightUnit.settingsKey) ?? "") ?? .pounds
        self.upperBodyIncrement = defaults.object(forKey: Keys.upperIncrement) as? Double
            ?? WeightUnit.pounds.defaultUpperBodyIncrement
        self.lowerBodyIncrement = defaults.object(forKey: Keys.lowerIncrement) as? Double
            ?? WeightUnit.pounds.defaultLowerBodyIncrement
        self.defaultRestSeconds = defaults.object(forKey: Keys.defaultRestSeconds) as? Int
            ?? ExerciseBlockDefaults.restSeconds
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.completedOnboarding)
        if let data = defaults.data(forKey: Keys.warmupRamp),
           let decoded = try? decoder.decode([WarmupRampStep].self, from: data),
           !decoded.isEmpty {
            self.warmupRamp = decoded
        } else {
            self.warmupRamp = [
                WarmupRampStep(percentage: 0.40, reps: 5),
                WarmupRampStep(percentage: 0.60, reps: 3)
            ]
        }
    }

    func preferredIncrement(for exerciseName: String) -> Double {
        ExerciseClassification.isLowerBody(exerciseName) ? lowerBodyIncrement : upperBodyIncrement
    }

    nonisolated static func resetPersistedSettings(defaults: UserDefaults = .standard) {
        [
            WeightUnit.settingsKey,
            Keys.upperIncrement,
            Keys.lowerIncrement,
            Keys.defaultRestSeconds,
            Keys.completedOnboarding,
            Keys.warmupRamp
        ].forEach { defaults.removeObject(forKey: $0) }
    }
}
