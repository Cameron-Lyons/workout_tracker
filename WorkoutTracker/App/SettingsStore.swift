import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let upperIncrement = "workout_tracker_upper_increment"
        static let lowerIncrement = "workout_tracker_lower_increment"
        static let defaultRestSeconds = "workout_tracker_default_rest"
        static let completedOnboarding = "workout_tracker_completed_onboarding"
        static let warmupRamp = "workout_tracker_warmup_ramp"
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
            do {
                let data = try encoder.encode(warmupRamp)
                defaults.set(data, forKey: Keys.warmupRamp)
            } catch {
                PersistenceDiagnostics.record("Failed to encode warmup ramp settings", error: error)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let weightUnit = WeightUnit(rawValue: defaults.string(forKey: WeightUnit.settingsKey) ?? "") ?? .pounds
        self.weightUnit = weightUnit
        self.upperBodyIncrement =
            defaults.object(forKey: Keys.upperIncrement) as? Double
            ?? weightUnit.defaultUpperBodyIncrement
        self.lowerBodyIncrement =
            defaults.object(forKey: Keys.lowerIncrement) as? Double
            ?? weightUnit.defaultLowerBodyIncrement
        self.defaultRestSeconds =
            defaults.object(forKey: Keys.defaultRestSeconds) as? Int
            ?? ExerciseBlockDefaults.restSeconds
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.completedOnboarding)
        if let data = defaults.data(forKey: Keys.warmupRamp) {
            do {
                let decoded = try decoder.decode([WarmupRampStep].self, from: data)
                if decoded.isEmpty {
                    self.warmupRamp = WarmupDefaults.ramp
                } else {
                    self.warmupRamp = decoded
                }
            } catch {
                PersistenceDiagnostics.record("Failed to decode warmup ramp settings", error: error)
                self.warmupRamp = WarmupDefaults.ramp
            }
        } else {
            self.warmupRamp = WarmupDefaults.ramp
        }
    }

    nonisolated static func preferredIncrement(
        for exerciseName: String,
        upperBodyIncrement: Double,
        lowerBodyIncrement: Double
    ) -> Double {
        ExerciseClassification.isLowerBody(exerciseName) ? lowerBodyIncrement : upperBodyIncrement
    }

    func preferredIncrement(for exerciseName: String) -> Double {
        Self.preferredIncrement(
            for: exerciseName,
            upperBodyIncrement: upperBodyIncrement,
            lowerBodyIncrement: lowerBodyIncrement
        )
    }
}
