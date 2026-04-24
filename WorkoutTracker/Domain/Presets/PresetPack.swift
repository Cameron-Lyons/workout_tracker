import Foundation

enum PresetPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case generalGym
    case phul
    case startingStrength
    case strongLiftsFiveByFive
    case greyskullLP
    case fiveThreeOne
    case boringButBig
    case madcowFiveByFive
    case gzclp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generalGym:
            return "General Gym"
        case .phul:
            return "PHUL"
        case .startingStrength:
            return "Starting Strength"
        case .strongLiftsFiveByFive:
            return "StrongLifts 5x5"
        case .greyskullLP:
            return "Greyskull LP"
        case .fiveThreeOne:
            return "5/3/1"
        case .boringButBig:
            return "Boring But Big"
        case .madcowFiveByFive:
            return "Madcow 5x5"
        case .gzclp:
            return "GZCLP"
        }
    }

    var description: String {
        switch self {
        case .generalGym:
            return "Balanced upper/lower templates with flexible progression for mixed gym training."
        case .phul:
            return "Four-day power and hypertrophy upper/lower split built around simple compound progression."
        case .startingStrength:
            return "Simple barbell-focused A/B sessions using double progression."
        case .strongLiftsFiveByFive:
            return "Classic A/B novice barbell split using 5x5 targets and automatic workout rotation."
        case .greyskullLP:
            return "A/B linear progression with 3x5 main work and AMRAP cues on the final set."
        case .fiveThreeOne:
            return "Four main-lift days powered by generic percentage-wave progression."
        case .boringButBig:
            return "5/3/1 main work plus 5x10 supplemental volume."
        case .madcowFiveByFive:
            return "Intermediate three-day 5x5 templates with weekly ramp and top-set guidance."
        case .gzclp:
            return "Tiered T1/T2/T3 strength templates mapped onto the app's existing progression system."
        }
    }

    var systemImage: String {
        switch self {
        case .generalGym:
            return "square.grid.2x2"
        case .phul:
            return "dumbbell.fill"
        case .startingStrength:
            return "figure.strengthtraining.traditional"
        case .strongLiftsFiveByFive:
            return "dumbbell"
        case .greyskullLP:
            return "bolt.fill"
        case .fiveThreeOne:
            return "number"
        case .boringButBig:
            return "chart.bar.doc.horizontal"
        case .madcowFiveByFive:
            return "chart.line.uptrend.xyaxis"
        case .gzclp:
            return "square.stack.3d.up.fill"
        }
    }
}
