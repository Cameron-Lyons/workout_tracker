import Foundation

struct ExerciseWeightRecommendation: Equatable {
    var recommendedWeight: Double
    var previousWeight: Double
    var shouldIncrease: Bool
    var guidance: String
}

struct LiftProgressSnapshot: Equatable {
    var sessionID: UUID
    var performedAt: Date
    var topWeightInStoredPounds: Double
}

final class WorkoutStore: ObservableObject {
    private enum Persistence {
        static let saveDebounceMilliseconds = 300
    }

    private enum Recommendation {
        static let fallbackTopSetRepGoal = 8
        static let weightComparisonTolerance = 0.01
        static let cacheEntryLimit = 512
    }

    private struct RecommendationCacheKey: Hashable {
        var routineName: String
        var exerciseName: String
        var targetReps: [Int]
        var minimumIncrease: Double
        var unit: WeightUnit
    }

    private enum CachedRecommendationResult {
        case value(ExerciseWeightRecommendation)
        case noResult
    }

    private struct ExerciseSessionKey: Hashable {
        var exerciseName: String
        var sessionID: UUID
    }

    private struct ExerciseRoutineKey: Hashable {
        var exerciseName: String
        var routineName: String
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
            if isApplyingIncrementalLiftHistoryUpdate {
                scheduleLiftHistorySave()
                return
            }
            rebuildLiftHistoryIndex()
            scheduleLiftHistorySave()
        }
    }

    private let routinesKey = "workout_tracker_routines_v1"
    private let historyKey = "workout_tracker_history_v1"
    private let liftHistoryKey = "workout_tracker_lift_history_v1"
    private let legacyPushPullLegsCleanupKey = "workout_tracker_legacy_push_pull_legs_cleanup_v1"
    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let persistenceQueue = DispatchQueue(label: "workout_tracker.persistence", qos: .utility)

    private var pendingRoutinesSave: DispatchWorkItem?
    private var pendingHistorySave: DispatchWorkItem?
    private var pendingLiftHistorySave: DispatchWorkItem?

    private var routineIndexByID: [UUID: Int] = [:]
    private var liftHistoryByExerciseName: [String: [LiftRecord]] = [:]
    private var liftHistoryByExerciseAndSession: [ExerciseSessionKey: [LiftRecord]] = [:]
    private var latestSessionIDByExerciseName: [String: UUID] = [:]
    private var latestSessionIDByExerciseAndRoutine: [ExerciseRoutineKey: UUID] = [:]
    private var liftProgressByExerciseName: [String: [LiftProgressSnapshot]] = [:]
    private var cachedExerciseNamesWithHistory: [String] = []
    private var recommendationCache: [RecommendationCacheKey: CachedRecommendationResult] = [:]
    private var isHydrating = false
    private var isApplyingIncrementalLiftHistoryUpdate = false

    var exerciseNamesWithLiftHistory: [String] {
        cachedExerciseNamesWithHistory
    }

    func liftProgress(forExerciseName exerciseName: String) -> [LiftProgressSnapshot] {
        liftProgressByExerciseName[exerciseName] ?? []
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
        addRoutine(Self.makeProgramRoutine(kind))
    }

    func addPopularRoutinePack(_ pack: PopularRoutinePack) {
        let routinesToAdd = Self.popularRoutines(for: pack)
        guard !routinesToAdd.isEmpty else { return }
        routines.append(contentsOf: routinesToAdd)
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
        appendLiftHistoryRecords(records)

        var progressedRoutine = routine
        WorkoutProgramEngine.advanceProgramState(in: &progressedRoutine)
        if progressedRoutine != routine {
            routines[routineIndex] = progressedRoutine
        }
    }

    private func hydrate() {
        isHydrating = true
        defer { isHydrating = false }

        var didMigrateStoredRoutines = false
        let hasAppliedLegacyPushPullLegsCleanup = defaults.bool(forKey: legacyPushPullLegsCleanupKey)

        if let data = defaults.data(forKey: routinesKey),
           let decodedRoutines = try? decoder.decode([Routine].self, from: data),
           !decodedRoutines.isEmpty {
            var hydratedRoutines = decodedRoutines

            if Self.matchesLegacyStarterRoutines(hydratedRoutines) {
                hydratedRoutines = Self.starterRoutines
                didMigrateStoredRoutines = true
            }

            if !hasAppliedLegacyPushPullLegsCleanup {
                let cleanedRoutines = Self.removingLegacyPushPullLegsRoutines(from: hydratedRoutines)
                if cleanedRoutines.count != hydratedRoutines.count {
                    hydratedRoutines = cleanedRoutines.isEmpty ? Self.starterRoutines : cleanedRoutines
                    didMigrateStoredRoutines = true
                }
                defaults.set(true, forKey: legacyPushPullLegsCleanupKey)
            }

            routines = hydratedRoutines
        } else {
            routines = Self.starterRoutines
            if !hasAppliedLegacyPushPullLegsCleanup {
                defaults.set(true, forKey: legacyPushPullLegsCleanupKey)
            }
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

        if didMigrateStoredRoutines {
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
        let cleanedTargets = targetReps.filter { $0 > 0 }
        let resolvedMinimumIncrease = unit.normalizedDisplayIncrease(minimumIncrease)
        let cacheKey = RecommendationCacheKey(
            routineName: routineName,
            exerciseName: exerciseName,
            targetReps: cleanedTargets,
            minimumIncrease: resolvedMinimumIncrease,
            unit: unit
        )

        if let cached = recommendationCache[cacheKey] {
            switch cached {
            case .value(let recommendation):
                return recommendation
            case .noResult:
                return nil
            }
        }

        let latestRecords = latestSessionRecords(
            forExerciseName: exerciseName,
            preferredRoutineName: routineName
        )
        guard !latestRecords.isEmpty else {
            cacheRecommendation(.noResult, for: cacheKey)
            return nil
        }

        guard let previousWeight = latestRecords.compactMap(\.weight).max() else {
            cacheRecommendation(.noResult, for: cacheKey)
            return nil
        }

        let increment = recommendedIncrement(
            forExerciseName: exerciseName,
            minimumIncrease: resolvedMinimumIncrease,
            unit: unit
        )
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

        let recommendation = ExerciseWeightRecommendation(
            recommendedWeight: recommendedWeight,
            previousWeight: previousWeight,
            shouldIncrease: shouldIncrease,
            guidance: guidance
        )
        cacheRecommendation(.value(recommendation), for: cacheKey)
        return recommendation
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
        let preferredSessionKey = ExerciseRoutineKey(
            exerciseName: exerciseName,
            routineName: preferredRoutineName
        )
        let resolvedSessionID = latestSessionIDByExerciseAndRoutine[preferredSessionKey]
            ?? latestSessionIDByExerciseName[exerciseName]

        guard let targetSessionID = resolvedSessionID else {
            return []
        }

        let exerciseSessionKey = ExerciseSessionKey(
            exerciseName: exerciseName,
            sessionID: targetSessionID
        )
        return liftHistoryByExerciseAndSession[exerciseSessionKey] ?? []
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
        LiftClassifier.isLowerBodyLift(exerciseName)
            ? max(minimumIncrease, unit.lowerBodyDefaultIncrease)
            : max(minimumIncrease, unit.upperBodyDefaultIncrease)
    }

    private func roundToNearestIncrement(_ value: Double, increment: Double) -> Double {
        guard increment > 0 else { return value }
        return (value / increment).rounded() * increment
    }

    private func appendLiftHistoryRecords(_ records: [LiftRecord]) {
        guard !records.isEmpty else {
            return
        }

        applyIncrementalLiftHistoryIndexUpdate(with: records)

        isApplyingIncrementalLiftHistoryUpdate = true
        defer { isApplyingIncrementalLiftHistoryUpdate = false }
        liftHistory.insert(contentsOf: records, at: 0)
    }

    private func applyIncrementalLiftHistoryIndexUpdate(with records: [LiftRecord]) {
        var recordsByExerciseName: [String: [LiftRecord]] = [:]
        recordsByExerciseName.reserveCapacity(records.count)
        var recordsByExerciseSession: [ExerciseSessionKey: [LiftRecord]] = [:]
        recordsByExerciseSession.reserveCapacity(records.count)
        var latestRecordByExerciseName: [String: LiftRecord] = [:]
        latestRecordByExerciseName.reserveCapacity(records.count)
        var latestRecordByExerciseAndRoutine: [ExerciseRoutineKey: LiftRecord] = [:]
        latestRecordByExerciseAndRoutine.reserveCapacity(records.count)

        for record in records {
            recordsByExerciseName[record.exerciseName, default: []].append(record)

            let exerciseSessionKey = ExerciseSessionKey(
                exerciseName: record.exerciseName,
                sessionID: record.sessionID
            )
            recordsByExerciseSession[exerciseSessionKey, default: []].append(record)

            Self.updateLatestRecord(
                in: &latestRecordByExerciseName,
                key: record.exerciseName,
                candidate: record
            )

            let exerciseRoutineKey = ExerciseRoutineKey(
                exerciseName: record.exerciseName,
                routineName: record.routineName
            )
            Self.updateLatestRecord(
                in: &latestRecordByExerciseAndRoutine,
                key: exerciseRoutineKey,
                candidate: record
            )
        }

        var addedNewExerciseName = false
        for (exerciseName, newRecords) in recordsByExerciseName {
            if liftHistoryByExerciseName[exerciseName] == nil {
                addedNewExerciseName = true
            }
            liftHistoryByExerciseName[exerciseName, default: []].insert(contentsOf: newRecords, at: 0)
        }

        for (exerciseSessionKey, newRecords) in recordsByExerciseSession {
            if var existingRecords = liftHistoryByExerciseAndSession[exerciseSessionKey] {
                existingRecords.insert(contentsOf: newRecords, at: 0)
                liftHistoryByExerciseAndSession[exerciseSessionKey] = existingRecords
            } else {
                liftHistoryByExerciseAndSession[exerciseSessionKey] = newRecords
            }

            guard let combinedRecords = liftHistoryByExerciseAndSession[exerciseSessionKey],
                  let snapshot = Self.makeProgressSnapshot(from: combinedRecords) else {
                continue
            }

            var snapshots = liftProgressByExerciseName[exerciseSessionKey.exerciseName] ?? []
            if let existingIndex = snapshots.firstIndex(where: { $0.sessionID == snapshot.sessionID }) {
                snapshots[existingIndex] = snapshot
            } else {
                snapshots.append(snapshot)
            }
            snapshots.sort { lhs, rhs in
                lhs.performedAt < rhs.performedAt
            }
            liftProgressByExerciseName[exerciseSessionKey.exerciseName] = snapshots
        }

        updateLatestSessionIDsByExerciseName(with: latestRecordByExerciseName)
        updateLatestSessionIDsByExerciseAndRoutine(with: latestRecordByExerciseAndRoutine)

        if addedNewExerciseName {
            cachedExerciseNamesWithHistory = liftHistoryByExerciseName.keys.sorted()
        }

        recommendationCache.removeAll(keepingCapacity: true)
    }

    private func rebuildRoutineIndex() {
        var indexByID: [UUID: Int] = [:]
        indexByID.reserveCapacity(routines.count)

        for (index, routine) in routines.enumerated() {
            indexByID[routine.id] = index
        }

        routineIndexByID = indexByID
    }

    private func rebuildLiftHistoryIndex() {
        var byExerciseName: [String: [LiftRecord]] = [:]
        byExerciseName.reserveCapacity(liftHistoryByExerciseName.count)
        var byExerciseAndSession: [ExerciseSessionKey: [LiftRecord]] = [:]
        byExerciseAndSession.reserveCapacity(liftHistoryByExerciseAndSession.count)
        var latestSessionByExercise: [String: (sessionID: UUID, performedAt: Date)] = [:]
        latestSessionByExercise.reserveCapacity(latestSessionIDByExerciseName.count)
        var latestSessionByExerciseAndRoutine: [ExerciseRoutineKey: (sessionID: UUID, performedAt: Date)] = [:]
        latestSessionByExerciseAndRoutine.reserveCapacity(latestSessionIDByExerciseAndRoutine.count)

        for record in liftHistory {
            byExerciseName[record.exerciseName, default: []].append(record)

            let exerciseSessionKey = ExerciseSessionKey(
                exerciseName: record.exerciseName,
                sessionID: record.sessionID
            )
            byExerciseAndSession[exerciseSessionKey, default: []].append(record)

            Self.updateLatestSession(
                in: &latestSessionByExercise,
                key: record.exerciseName,
                record: record
            )

            let exerciseRoutineKey = ExerciseRoutineKey(
                exerciseName: record.exerciseName,
                routineName: record.routineName
            )
            Self.updateLatestSession(
                in: &latestSessionByExerciseAndRoutine,
                key: exerciseRoutineKey,
                record: record
            )
        }

        var progressByExerciseName: [String: [LiftProgressSnapshot]] = [:]
        progressByExerciseName.reserveCapacity(byExerciseName.count)

        for (key, records) in byExerciseAndSession {
            guard let summary = Self.makeProgressSnapshot(from: records) else {
                continue
            }
            progressByExerciseName[key.exerciseName, default: []].append(summary)
        }

        for exerciseName in progressByExerciseName.keys {
            progressByExerciseName[exerciseName]?.sort { lhs, rhs in
                lhs.performedAt < rhs.performedAt
            }
        }

        liftHistoryByExerciseAndSession = byExerciseAndSession
        latestSessionIDByExerciseName = latestSessionByExercise.mapValues(\.sessionID)
        latestSessionIDByExerciseAndRoutine = latestSessionByExerciseAndRoutine.mapValues(\.sessionID)
        liftProgressByExerciseName = progressByExerciseName
        liftHistoryByExerciseName = byExerciseName
        cachedExerciseNamesWithHistory = byExerciseName.keys.sorted()
        recommendationCache.removeAll(keepingCapacity: true)
    }

    private func cacheRecommendation(
        _ result: CachedRecommendationResult,
        for key: RecommendationCacheKey
    ) {
        if recommendationCache.count >= Recommendation.cacheEntryLimit {
            recommendationCache.removeAll(keepingCapacity: true)
        }
        recommendationCache[key] = result
    }

    private func scheduleRoutinesSave() {
        scheduleSave(snapshot: routines, key: routinesKey, pendingWorkItem: &pendingRoutinesSave)
    }

    private func scheduleHistorySave() {
        scheduleSave(snapshot: workoutHistory, key: historyKey, pendingWorkItem: &pendingHistorySave)
    }

    private func scheduleLiftHistorySave() {
        scheduleSave(snapshot: liftHistory, key: liftHistoryKey, pendingWorkItem: &pendingLiftHistorySave)
    }

    private func scheduleSave<T: Encodable>(
        snapshot: T,
        key: String,
        pendingWorkItem: inout DispatchWorkItem?
    ) {
        pendingWorkItem?.cancel()

        let defaults = self.defaults
        let work = DispatchWorkItem {
            let encoder = Self.makeEncoder()
            guard let data = try? encoder.encode(snapshot) else { return }
            defaults.set(data, forKey: key)
        }

        pendingWorkItem = work
        persistenceQueue.asyncAfter(
            deadline: .now() + .milliseconds(Persistence.saveDebounceMilliseconds),
            execute: work
        )
    }

    private func updateLatestSessionIDsByExerciseName(with latestRecords: [String: LiftRecord]) {
        for (exerciseName, latestRecord) in latestRecords {
            let currentDate = latestSessionIDByExerciseName[exerciseName].map {
                currentSessionDate(forExerciseName: exerciseName, sessionID: $0)
            } ?? .distantPast

            if latestRecord.performedAt >= currentDate {
                latestSessionIDByExerciseName[exerciseName] = latestRecord.sessionID
            }
        }
    }

    private func updateLatestSessionIDsByExerciseAndRoutine(
        with latestRecords: [ExerciseRoutineKey: LiftRecord]
    ) {
        for (exerciseRoutineKey, latestRecord) in latestRecords {
            let currentDate = latestSessionIDByExerciseAndRoutine[exerciseRoutineKey].map {
                currentSessionDate(forExerciseName: exerciseRoutineKey.exerciseName, sessionID: $0)
            } ?? .distantPast

            if latestRecord.performedAt >= currentDate {
                latestSessionIDByExerciseAndRoutine[exerciseRoutineKey] = latestRecord.sessionID
            }
        }
    }

    private func currentSessionDate(forExerciseName exerciseName: String, sessionID: UUID) -> Date {
        liftHistoryByExerciseAndSession[
            ExerciseSessionKey(exerciseName: exerciseName, sessionID: sessionID)
        ]?.first?.performedAt ?? .distantPast
    }

    private static func updateLatestRecord<Key: Hashable>(
        in recordsByKey: inout [Key: LiftRecord],
        key: Key,
        candidate: LiftRecord
    ) {
        if let existing = recordsByKey[key], existing.performedAt >= candidate.performedAt {
            return
        }
        recordsByKey[key] = candidate
    }

    private static func updateLatestSession<Key: Hashable>(
        in sessionsByKey: inout [Key: (sessionID: UUID, performedAt: Date)],
        key: Key,
        record: LiftRecord
    ) {
        if let existing = sessionsByKey[key], existing.performedAt >= record.performedAt {
            return
        }
        sessionsByKey[key] = (sessionID: record.sessionID, performedAt: record.performedAt)
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

    private static func makeProgressSnapshot(from records: [LiftRecord]) -> LiftProgressSnapshot? {
        guard let firstRecord = records.first else {
            return nil
        }

        var latestDate = firstRecord.performedAt
        var topWeightInStoredPounds: Double?

        for record in records {
            if record.performedAt > latestDate {
                latestDate = record.performedAt
            }

            guard let weight = record.weight else {
                continue
            }

            if let existingTopWeight = topWeightInStoredPounds {
                if weight > existingTopWeight {
                    topWeightInStoredPounds = weight
                }
            } else {
                topWeightInStoredPounds = weight
            }
        }

        guard let topWeightInStoredPounds else {
            return nil
        }

        return LiftProgressSnapshot(
            sessionID: firstRecord.sessionID,
            performedAt: latestDate,
            topWeightInStoredPounds: topWeightInStoredPounds
        )
    }

    private static func makeProgramRoutine(_ kind: ProgramKind) -> Routine {
        Routine(
            name: kind.displayName,
            exercises: ProgramTemplate.exerciseNames(for: kind).map { Exercise(name: $0) },
            program: ProgramConfig(kind: kind)
        )
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

    func runProgressQueryBenchmark(iterations: Int = 25, unit: WeightUnit = .pounds) -> String {
        let exerciseNames = cachedExerciseNamesWithHistory
        guard !exerciseNames.isEmpty else {
            return "No lift history available for progress benchmarking."
        }

        let loops = max(1, iterations)

        let indexedMs = measureMilliseconds {
            for _ in 0..<loops {
                for exerciseName in exerciseNames {
                    _ = (liftProgressByExerciseName[exerciseName] ?? []).map {
                        unit.displayValue(fromStoredPounds: $0.topWeightInStoredPounds)
                    }
                }
            }
        }

        let naiveMs = measureMilliseconds {
            for _ in 0..<loops {
                for exerciseName in exerciseNames {
                    let records = liftHistory.filter { $0.exerciseName == exerciseName }
                    var summaryBySessionID: [UUID: (date: Date, topWeightInStoredPounds: Double)] = [:]

                    for record in records {
                        guard let weight = record.weight else {
                            continue
                        }

                        if var existing = summaryBySessionID[record.sessionID] {
                            if record.performedAt > existing.date {
                                existing.date = record.performedAt
                            }

                            if weight > existing.topWeightInStoredPounds {
                                existing.topWeightInStoredPounds = weight
                            }

                            summaryBySessionID[record.sessionID] = existing
                        } else {
                            summaryBySessionID[record.sessionID] = (
                                date: record.performedAt,
                                topWeightInStoredPounds: weight
                            )
                        }
                    }

                    _ = summaryBySessionID.values.map {
                        unit.displayValue(fromStoredPounds: $0.topWeightInStoredPounds)
                    }
                }
            }
        }

        let delta = naiveMs - indexedMs
        let speedup = indexedMs > 0 ? naiveMs / indexedMs : 0

        return """
        Exercises: \(exerciseNames.count)
        Iterations: \(loops)
        Indexed progress lookup: \(String(format: "%.2f", indexedMs)) ms
        Naive progress rebuild: \(String(format: "%.2f", naiveMs)) ms
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
    static let legacyPushPullLegsExerciseNamesByRoutineName: [String: [String]] = [
        "Push": [
            "Bench Press",
            "Incline Dumbbell Press",
            "Overhead Press"
        ],
        "Pull": [
            "Deadlift",
            "Pull Up",
            "Barbell Row"
        ],
        "Legs": [
            "Back Squat",
            "Romanian Deadlift",
            "Leg Press"
        ]
    ]

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
        ].map(makeProgramRoutine)
    }

    static func matchesLegacyStarterRoutines(_ routines: [Routine]) -> Bool {
        let expectedRoutineCount = legacyPushPullLegsExerciseNamesByRoutineName.count
        guard routines.count == expectedRoutineCount else { return false }

        let migratedRoutineNames = Set(routines.map(\.name))
        guard migratedRoutineNames.count == expectedRoutineCount else { return false }

        return routines.allSatisfy(isLegacyPushPullLegsRoutine)
    }

    static func removingLegacyPushPullLegsRoutines(from routines: [Routine]) -> [Routine] {
        routines.filter { !isLegacyPushPullLegsRoutine($0) }
    }

    static func isLegacyPushPullLegsRoutine(_ routine: Routine) -> Bool {
        guard routine.program == nil else { return false }
        guard let expectedExerciseNames = legacyPushPullLegsExerciseNamesByRoutineName[routine.name] else {
            return false
        }

        return routine.exercises.map(\.name) == expectedExerciseNames
    }
}
