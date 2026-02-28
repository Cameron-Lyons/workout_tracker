import Foundation

struct ExerciseWeightRecommendation: Equatable {
    var recommendedWeight: Double
    var previousWeight: Double
    var shouldIncrease: Bool
    var increment: Double
    var guidance: String
}

final class WorkoutStore: ObservableObject {
    private enum Persistence {
        static let saveDebounceMilliseconds = 300
    }

    private enum Recommendation {
        static let fallbackTopSetRepGoal = 8
        static let weightComparisonTolerance = 0.01
    }

    @Published var routines: [Routine] {
        didSet {
            guard !isHydrating else { return }
            rebuildRoutineIndex()
            scheduleRoutinesSave()
        }
    }

    @Published var workoutHistory: [WorkoutSession] {
        didSet {
            guard !isHydrating else { return }
            scheduleHistorySave()
        }
    }

    @Published var liftHistory: [LiftRecord] {
        didSet {
            guard !isHydrating else { return }
            rebuildLiftHistoryIndex()
            scheduleLiftHistorySave()
        }
    }

    private let routinesKey = "workout_tracker_routines_v1"
    private let historyKey = "workout_tracker_history_v1"
    private let liftHistoryKey = "workout_tracker_lift_history_v1"
    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let persistenceQueue = DispatchQueue(label: "workout_tracker.persistence", qos: .utility)

    private var pendingRoutinesSave: DispatchWorkItem?
    private var pendingHistorySave: DispatchWorkItem?
    private var pendingLiftHistorySave: DispatchWorkItem?

    private var routineIndexByID: [UUID: Int] = [:]
    private var liftHistoryByExerciseName: [String: [LiftRecord]] = [:]
    private var cachedExerciseNamesWithHistory: [String] = []
    private var isHydrating = false

    var exerciseNamesWithLiftHistory: [String] {
        cachedExerciseNamesWithHistory
    }

    init() {
        decoder.dateDecodingStrategy = .iso8601
        routines = []
        workoutHistory = []
        liftHistory = []
        hydrate()
    }

    deinit {
        flushPendingSaves()
    }

    func addRoutine(name: String, exerciseNames: [String]) {
        guard let trimmedName = name.nonEmptyTrimmed else { return }
        let exercises = exerciseNames.compactMap { $0.nonEmptyTrimmed }.map { Exercise(name: $0) }
        guard !exercises.isEmpty else { return }
        routines.append(Routine(name: trimmedName, exercises: exercises))
    }

    func addRoutine(_ routine: Routine) {
        routines.append(routine)
    }

    func addProgramTemplate(_ kind: ProgramKind) {
        addRoutine(
            Routine(
                name: kind.displayName,
                exercises: ProgramTemplate.exerciseNames(for: kind).map { Exercise(name: $0) },
                program: ProgramConfig(kind: kind)
            )
        )
    }

    func addPopularRoutinePack(_ pack: PopularRoutinePack) {
        Self.popularRoutines(for: pack).forEach { addRoutine($0) }
    }

    func updateRoutine(id: UUID, name: String, exercises: [Exercise]) {
        guard let index = routineIndexByID[id] else { return }
        guard let trimmedName = name.nonEmptyTrimmed else { return }

        let cleanedExercises = exercises
            .compactMap { exercise -> Exercise? in
                guard let trimmedExerciseName = exercise.name.nonEmptyTrimmed else {
                    return nil
                }

                return Exercise(
                    id: exercise.id,
                    name: trimmedExerciseName,
                    trainingMax: exercise.trainingMax
                )
            }
        guard !cleanedExercises.isEmpty else { return }

        routines[index] = Routine(
            id: id,
            name: trimmedName,
            exercises: cleanedExercises,
            program: routines[index].program
        )
    }

    func deleteRoutines(at offsets: IndexSet) {
        routines.remove(atOffsets: offsets)
    }

    func moveRoutines(from source: IndexSet, to destination: Int) {
        routines.move(fromOffsets: source, toOffset: destination)
    }

    func logWorkout(routineID: UUID, entries: [ExerciseEntry]) {
        guard let routineIndex = routineIndexByID[routineID] else {
            return
        }

        let meaningfulEntries = entries.filter {
            !$0.sets.isEmpty
        }

        guard !meaningfulEntries.isEmpty else { return }

        let routine = routines[routineIndex]
        let session = WorkoutSession(
            routineName: routine.name,
            entries: meaningfulEntries,
            programContext: WorkoutProgramEngine.contextLabel(for: routine)
        )
        workoutHistory.insert(session, at: 0)

        let records = Self.liftRecords(from: session)
        if !records.isEmpty {
            liftHistory.insert(contentsOf: records, at: 0)
        }

        var progressedRoutine = routine
        WorkoutProgramEngine.advanceProgramState(in: &progressedRoutine)
        if progressedRoutine != routine {
            routines[routineIndex] = progressedRoutine
        }
    }

    private func hydrate() {
        isHydrating = true
        defer { isHydrating = false }

        var didMigrateLegacyStarterRoutines = false

        if let data = defaults.data(forKey: routinesKey),
           let decodedRoutines = try? decoder.decode([Routine].self, from: data),
           !decodedRoutines.isEmpty {
            if Self.matchesLegacyStarterRoutines(decodedRoutines) {
                routines = Self.starterRoutines
                didMigrateLegacyStarterRoutines = true
            } else {
                routines = decodedRoutines
            }
        } else {
            routines = Self.starterRoutines
        }

        if let data = defaults.data(forKey: historyKey),
           let decodedHistory = try? decoder.decode([WorkoutSession].self, from: data) {
            workoutHistory = decodedHistory
        } else {
            workoutHistory = []
        }

        if let data = defaults.data(forKey: liftHistoryKey),
           let decodedLiftHistory = try? decoder.decode([LiftRecord].self, from: data) {
            liftHistory = decodedLiftHistory
        } else {
            // Backfill normalized lift records from existing session history.
            liftHistory = workoutHistory.flatMap(Self.liftRecords(from:))
        }

        rebuildRoutineIndex()
        rebuildLiftHistoryIndex()

        if didMigrateLegacyStarterRoutines {
            persist(routines, forKey: routinesKey)
        }
    }

    func liftRecords(forExerciseName exerciseName: String) -> [LiftRecord] {
        liftHistoryByExerciseName[exerciseName] ?? []
    }

    func weightRecommendation(
        routineName: String,
        exerciseName: String,
        targetReps: [Int],
        minimumIncrease: Double,
        unit: WeightUnit
    ) -> ExerciseWeightRecommendation? {
        let latestRecords = latestSessionRecords(
            forExerciseName: exerciseName,
            preferredRoutineName: routineName
        )
        guard !latestRecords.isEmpty else {
            return nil
        }

        guard let previousWeight = latestRecords.compactMap(\.weight).max() else {
            return nil
        }

        let resolvedMinimumIncrease = unit.normalizedDisplayIncrease(minimumIncrease)
        let increment = recommendedIncrement(
            forExerciseName: exerciseName,
            minimumIncrease: resolvedMinimumIncrease,
            unit: unit
        )
        let cleanedTargets = targetReps.filter { $0 > 0 }
        let shouldIncrease: Bool
        let guidance: String

        if cleanedTargets.isEmpty {
            let topSetReps = topSetReps(from: latestRecords, topWeight: previousWeight)
            shouldIncrease = topSetReps.map { $0 >= Recommendation.fallbackTopSetRepGoal } ?? false

            if let topSetReps {
                if shouldIncrease {
                    guidance = "Top set reached \(topSetReps) reps last time. Add \(WeightFormatter.displayString(displayValue: increment, unit: unit)) \(unit.symbol)."
                } else {
                    guidance = "Top set reached \(topSetReps) reps last time. Stay at this weight."
                }
            } else {
                guidance = "No rep data from last workout. Stay at this weight."
            }
        } else {
            shouldIncrease = didMeetAllRepTargets(cleanedTargets, records: latestRecords)
            let targetSummary = cleanedTargets.map(String.init).joined(separator: "/")
            if shouldIncrease {
                guidance = "Hit all target reps (\(targetSummary)) last time. Add \(WeightFormatter.displayString(displayValue: increment, unit: unit)) \(unit.symbol)."
            } else {
                guidance = "Missed target reps (\(targetSummary)) last time. Stay at this weight."
            }
        }

        let previousDisplayWeight = unit.displayValue(fromStoredPounds: previousWeight, snapToGymIncrement: false)
        let recommendedDisplayWeight = roundToNearestIncrement(
            previousDisplayWeight + (shouldIncrease ? increment : 0),
            increment: resolvedMinimumIncrease
        )
        let recommendedWeight = unit.storedPounds(
            fromDisplayValue: unit.roundedForGymDisplay(recommendedDisplayWeight)
        )
        let incrementInStoredPounds = unit.storedPounds(fromDisplayValue: increment)

        return ExerciseWeightRecommendation(
            recommendedWeight: recommendedWeight,
            previousWeight: previousWeight,
            shouldIncrease: shouldIncrease,
            increment: shouldIncrease ? incrementInStoredPounds : 0,
            guidance: guidance
        )
    }

    func flushPendingSaves() {
        pendingRoutinesSave?.cancel()
        pendingHistorySave?.cancel()
        pendingLiftHistorySave?.cancel()
        pendingRoutinesSave = nil
        pendingHistorySave = nil
        pendingLiftHistorySave = nil

        // Ensure any already-started background writes finish before this immediate flush.
        persistenceQueue.sync { }

        persist(routines, forKey: routinesKey)
        persist(workoutHistory, forKey: historyKey)
        persist(liftHistory, forKey: liftHistoryKey)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = Self.makeEncoder()
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func latestSessionRecords(
        forExerciseName exerciseName: String,
        preferredRoutineName: String
    ) -> [LiftRecord] {
        let records = liftHistoryByExerciseName[exerciseName] ?? []
        guard !records.isEmpty else {
            return []
        }

        let groupedBySession = Dictionary(grouping: records, by: \.sessionID)
        let preferredRoutineRecords = groupedBySession.values.filter { grouped in
            grouped.first?.routineName == preferredRoutineName
        }
        let candidateGroups = preferredRoutineRecords.isEmpty ? Array(groupedBySession.values) : preferredRoutineRecords

        return candidateGroups.max { lhs, rhs in
            let lhsDate = lhs.map(\.performedAt).max() ?? .distantPast
            let rhsDate = rhs.map(\.performedAt).max() ?? .distantPast
            return lhsDate < rhsDate
        } ?? []
    }

    private func didMeetAllRepTargets(_ targets: [Int], records: [LiftRecord]) -> Bool {
        guard !targets.isEmpty else {
            return false
        }

        var repsBySetIndex: [Int: Int] = [:]
        for record in records {
            guard let reps = record.reps else { continue }
            repsBySetIndex[record.setIndex] = reps
        }

        return targets.enumerated().allSatisfy { index, target in
            guard let performedReps = repsBySetIndex[index + 1] else {
                return false
            }
            return performedReps >= target
        }
    }

    private func topSetReps(from records: [LiftRecord], topWeight: Double) -> Int? {
        records
            .filter { record in
                guard let weight = record.weight else { return false }
                return abs(weight - topWeight) < Recommendation.weightComparisonTolerance
            }
            .compactMap(\.reps)
            .max()
    }

    private func recommendedIncrement(
        forExerciseName exerciseName: String,
        minimumIncrease: Double,
        unit: WeightUnit
    ) -> Double {
        isLowerBodyLift(exerciseName)
            ? max(minimumIncrease, unit.lowerBodyDefaultIncrease)
            : max(minimumIncrease, unit.upperBodyDefaultIncrease)
    }

    private func isLowerBodyLift(_ exerciseName: String) -> Bool {
        let normalized = exerciseName.lowercased()
        return normalized.contains("squat")
            || normalized.contains("deadlift")
            || normalized.contains("clean")
            || normalized.contains("lunge")
            || normalized.contains("leg")
            || normalized.contains("calf")
            || normalized.contains("hip thrust")
    }

    private func roundToNearestIncrement(_ value: Double, increment: Double) -> Double {
        guard increment > 0 else { return value }
        return (value / increment).rounded() * increment
    }

    private func rebuildRoutineIndex() {
        routineIndexByID = Dictionary(
            uniqueKeysWithValues: routines.enumerated().map { index, routine in
                (routine.id, index)
            }
        )
    }

    private func rebuildLiftHistoryIndex() {
        var byExerciseName: [String: [LiftRecord]] = [:]
        byExerciseName.reserveCapacity(liftHistoryByExerciseName.count)

        for record in liftHistory {
            byExerciseName[record.exerciseName, default: []].append(record)
        }

        liftHistoryByExerciseName = byExerciseName
        cachedExerciseNamesWithHistory = byExerciseName.keys.sorted()
    }

    private func scheduleRoutinesSave() {
        let snapshot = routines
        pendingRoutinesSave?.cancel()

        let key = routinesKey
        let defaults = self.defaults

        let work = DispatchWorkItem {
            let encoder = Self.makeEncoder()
            guard let data = try? encoder.encode(snapshot) else { return }
            defaults.set(data, forKey: key)
        }

        pendingRoutinesSave = work
        persistenceQueue.asyncAfter(
            deadline: .now() + .milliseconds(Persistence.saveDebounceMilliseconds),
            execute: work
        )
    }

    private func scheduleHistorySave() {
        let snapshot = workoutHistory
        pendingHistorySave?.cancel()

        let key = historyKey
        let defaults = self.defaults

        let work = DispatchWorkItem {
            let encoder = Self.makeEncoder()
            guard let data = try? encoder.encode(snapshot) else { return }
            defaults.set(data, forKey: key)
        }

        pendingHistorySave = work
        persistenceQueue.asyncAfter(
            deadline: .now() + .milliseconds(Persistence.saveDebounceMilliseconds),
            execute: work
        )
    }

    private func scheduleLiftHistorySave() {
        let snapshot = liftHistory
        pendingLiftHistorySave?.cancel()

        let key = liftHistoryKey
        let defaults = self.defaults

        let work = DispatchWorkItem {
            let encoder = Self.makeEncoder()
            guard let data = try? encoder.encode(snapshot) else { return }
            defaults.set(data, forKey: key)
        }

        pendingLiftHistorySave = work
        persistenceQueue.asyncAfter(
            deadline: .now() + .milliseconds(Persistence.saveDebounceMilliseconds),
            execute: work
        )
    }

    private static func liftRecords(from session: WorkoutSession) -> [LiftRecord] {
        session.entries.flatMap { entry in
            entry.sets.enumerated().compactMap { index, set in
                let transcript = set.transcript?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard set.weight != nil || set.reps != nil || ((transcript ?? "").isEmpty == false) else {
                    return nil
                }

                return LiftRecord(
                    sessionID: session.id,
                    routineName: session.routineName,
                    exerciseName: entry.exerciseName,
                    performedAt: session.performedAt,
                    setIndex: index + 1,
                    weight: set.weight,
                    reps: set.reps,
                    transcript: transcript?.isEmpty == true ? nil : transcript
                )
            }
        }
    }

#if DEBUG
    func runHistoryQueryBenchmark(iterations: Int = 25) -> String {
        let exerciseNames = cachedExerciseNamesWithHistory
        guard !exerciseNames.isEmpty else {
            return "No lift history available for benchmarking."
        }

        let loops = max(1, iterations)
        let totalRecords = liftHistory.count

        let indexedMs = measureMilliseconds {
            for _ in 0..<loops {
                for exerciseName in exerciseNames {
                    _ = liftHistoryByExerciseName[exerciseName]?.count ?? 0
                }
            }
        }

        let naiveMs = measureMilliseconds {
            for _ in 0..<loops {
                for exerciseName in exerciseNames {
                    _ = liftHistory.filter { $0.exerciseName == exerciseName }.count
                }
            }
        }

        let delta = naiveMs - indexedMs
        let speedup = indexedMs > 0 ? naiveMs / indexedMs : 0

        return """
        Records: \(totalRecords)
        Exercises: \(exerciseNames.count)
        Iterations: \(loops)
        Indexed lookup: \(String(format: "%.2f", indexedMs)) ms
        Naive filter: \(String(format: "%.2f", naiveMs)) ms
        Delta: \(String(format: "%.2f", delta)) ms
        Speedup: \(String(format: "%.2fx", speedup))
        """
    }

    private func measureMilliseconds(_ work: () -> Void) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        work()
        return (CFAbsoluteTimeGetCurrent() - start) * 1000
    }
#endif
}

private extension WorkoutStore {
    enum ProgramTemplate {
        static let bigFourExerciseNames = [
            "Back Squat",
            "Bench Press",
            "Deadlift",
            "Overhead Press"
        ]

        static func exerciseNames(for kind: ProgramKind) -> [String] {
            switch kind {
            case .startingStrength:
                return bigFourExerciseNames + ["Power Clean"]
            case .fiveThreeOne, .boringButBig:
                return bigFourExerciseNames
            }
        }
    }

    static func popularRoutines(for pack: PopularRoutinePack) -> [Routine] {
        switch pack {
        case .pushPullLegs:
            return [
                Routine(
                    name: "PPL Push",
                    exercises: [
                        Exercise(name: "Bench Press"),
                        Exercise(name: "Overhead Press"),
                        Exercise(name: "Incline Dumbbell Press"),
                        Exercise(name: "Dips"),
                        Exercise(name: "Lateral Raise"),
                        Exercise(name: "Triceps Pushdown")
                    ]
                ),
                Routine(
                    name: "PPL Pull",
                    exercises: [
                        Exercise(name: "Deadlift"),
                        Exercise(name: "Pull Up"),
                        Exercise(name: "Barbell Row"),
                        Exercise(name: "Seated Cable Row"),
                        Exercise(name: "Face Pull"),
                        Exercise(name: "Barbell Curl")
                    ]
                ),
                Routine(
                    name: "PPL Legs",
                    exercises: [
                        Exercise(name: "Back Squat"),
                        Exercise(name: "Romanian Deadlift"),
                        Exercise(name: "Leg Press"),
                        Exercise(name: "Leg Curl"),
                        Exercise(name: "Walking Lunge"),
                        Exercise(name: "Standing Calf Raise")
                    ]
                )
            ]
        case .upperLower:
            return [
                Routine(
                    name: "Upper/Lower Upper",
                    exercises: [
                        Exercise(name: "Bench Press"),
                        Exercise(name: "Barbell Row"),
                        Exercise(name: "Overhead Press"),
                        Exercise(name: "Pull Up"),
                        Exercise(name: "Incline Dumbbell Press"),
                        Exercise(name: "Barbell Curl")
                    ]
                ),
                Routine(
                    name: "Upper/Lower Lower",
                    exercises: [
                        Exercise(name: "Back Squat"),
                        Exercise(name: "Deadlift"),
                        Exercise(name: "Bulgarian Split Squat"),
                        Exercise(name: "Leg Curl"),
                        Exercise(name: "Hip Thrust"),
                        Exercise(name: "Seated Calf Raise")
                    ]
                )
            ]
        case .strongLiftsFiveByFive:
            return [
                Routine(
                    name: "StrongLifts 5x5 A",
                    exercises: [
                        Exercise(name: "Back Squat"),
                        Exercise(name: "Bench Press"),
                        Exercise(name: "Barbell Row")
                    ]
                ),
                Routine(
                    name: "StrongLifts 5x5 B",
                    exercises: [
                        Exercise(name: "Back Squat"),
                        Exercise(name: "Overhead Press"),
                        Exercise(name: "Deadlift")
                    ]
                )
            ]
        case .arnoldSplit:
            return [
                Routine(
                    name: "Arnold Chest/Back",
                    exercises: [
                        Exercise(name: "Bench Press"),
                        Exercise(name: "Incline Bench Press"),
                        Exercise(name: "Dumbbell Fly"),
                        Exercise(name: "Pull Up"),
                        Exercise(name: "Barbell Row"),
                        Exercise(name: "Lat Pulldown")
                    ]
                ),
                Routine(
                    name: "Arnold Shoulders/Arms",
                    exercises: [
                        Exercise(name: "Overhead Press"),
                        Exercise(name: "Lateral Raise"),
                        Exercise(name: "Rear Delt Fly"),
                        Exercise(name: "Barbell Curl"),
                        Exercise(name: "Incline Dumbbell Curl"),
                        Exercise(name: "Skull Crusher")
                    ]
                ),
                Routine(
                    name: "Arnold Legs",
                    exercises: [
                        Exercise(name: "Back Squat"),
                        Exercise(name: "Romanian Deadlift"),
                        Exercise(name: "Leg Press"),
                        Exercise(name: "Leg Extension"),
                        Exercise(name: "Leg Curl"),
                        Exercise(name: "Standing Calf Raise")
                    ]
                )
            ]
        case .phul:
            return [
                Routine(
                    name: "PHUL Upper Power",
                    exercises: [
                        Exercise(name: "Bench Press"),
                        Exercise(name: "Barbell Row"),
                        Exercise(name: "Overhead Press"),
                        Exercise(name: "Weighted Pull Up"),
                        Exercise(name: "Barbell Curl"),
                        Exercise(name: "Skull Crusher")
                    ]
                ),
                Routine(
                    name: "PHUL Lower Power",
                    exercises: [
                        Exercise(name: "Back Squat"),
                        Exercise(name: "Deadlift"),
                        Exercise(name: "Front Squat"),
                        Exercise(name: "Leg Press"),
                        Exercise(name: "Standing Calf Raise")
                    ]
                ),
                Routine(
                    name: "PHUL Upper Hypertrophy",
                    exercises: [
                        Exercise(name: "Incline Dumbbell Press"),
                        Exercise(name: "Seated Cable Row"),
                        Exercise(name: "Dumbbell Shoulder Press"),
                        Exercise(name: "Lat Pulldown"),
                        Exercise(name: "Lateral Raise"),
                        Exercise(name: "Triceps Pushdown"),
                        Exercise(name: "Hammer Curl")
                    ]
                ),
                Routine(
                    name: "PHUL Lower Hypertrophy",
                    exercises: [
                        Exercise(name: "Front Squat"),
                        Exercise(name: "Romanian Deadlift"),
                        Exercise(name: "Bulgarian Split Squat"),
                        Exercise(name: "Leg Extension"),
                        Exercise(name: "Leg Curl"),
                        Exercise(name: "Seated Calf Raise")
                    ]
                )
            ]
        }
    }

    static var starterRoutines: [Routine] {
        [
            .startingStrength,
            .fiveThreeOne,
            .boringButBig
        ].map { kind in
            Routine(
                name: kind.displayName,
                exercises: ProgramTemplate.exerciseNames(for: kind).map { Exercise(name: $0) },
                program: ProgramConfig(kind: kind)
            )
        }
    }

    static func matchesLegacyStarterRoutines(_ routines: [Routine]) -> Bool {
        let legacyRoutines: [(name: String, exerciseNames: [String])] = [
            (
                name: "Push",
                exerciseNames: [
                    "Bench Press",
                    "Incline Dumbbell Press",
                    "Overhead Press"
                ]
            ),
            (
                name: "Pull",
                exerciseNames: [
                    "Deadlift",
                    "Pull Up",
                    "Barbell Row"
                ]
            ),
            (
                name: "Legs",
                exerciseNames: [
                    "Back Squat",
                    "Romanian Deadlift",
                    "Leg Press"
                ]
            )
        ]

        guard routines.count == legacyRoutines.count else { return false }

        return zip(routines, legacyRoutines).allSatisfy { routine, legacy in
            routine.name == legacy.name &&
            routine.program == nil &&
            routine.exercises.map(\.name) == legacy.exerciseNames
        }
    }
}
