import Foundation
import SwiftData

struct ExerciseWeightRecommendation: Equatable {
    var recommendedWeight: Double
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

    private enum LiftHistoryIndexing {
        static let minimumRecordsForParallelIndexing = 800
        static let maximumParallelChunkCount = 8
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

    private struct LiftHistoryIndexPartial {
        var byExerciseName: [String: [LiftRecord]]
        var byExerciseAndSession: [ExerciseSessionKey: [LiftRecord]]
        var latestSessionByExercise: [String: (sessionID: UUID, performedAt: Date)]
        var latestSessionByExerciseAndRoutine: [ExerciseRoutineKey: (sessionID: UUID, performedAt: Date)]
    }

    private struct UnsafeSendableBox<Value>: @unchecked Sendable {
        var value: Value
    }

    private final class WeakStoreBox: @unchecked Sendable {
        weak var store: WorkoutStore?

        init(store: WorkoutStore?) {
            self.store = store
        }
    }

    private final class ParallelHydrationResults: @unchecked Sendable {
        private let lock = NSLock()
        private var routines: [Routine] = []
        private var history: [WorkoutSession] = []
        private var liftHistory: [LiftRecord] = []

        func setRoutines(_ routines: [Routine]) {
            lock.lock()
            self.routines = routines
            lock.unlock()
        }

        func setHistory(_ history: [WorkoutSession]) {
            lock.lock()
            self.history = history
            lock.unlock()
        }

        func setLiftHistory(_ liftHistory: [LiftRecord]) {
            lock.lock()
            self.liftHistory = liftHistory
            lock.unlock()
        }

        func snapshot() -> (
            routines: [Routine],
            history: [WorkoutSession],
            liftHistory: [LiftRecord]
        ) {
            lock.lock()
            defer { lock.unlock() }
            return (
                routines: routines,
                history: history,
                liftHistory: liftHistory
            )
        }
    }

    private final class IndexedPartialStore: @unchecked Sendable {
        private let lock = NSLock()
        private var valuesByIndex: [Int: LiftHistoryIndexPartial] = [:]

        func set(_ partial: LiftHistoryIndexPartial, at index: Int) {
            lock.lock()
            valuesByIndex[index] = partial
            lock.unlock()
        }

        func orderedPartials(count: Int) -> [LiftHistoryIndexPartial] {
            lock.lock()
            defer { lock.unlock() }
            return (0..<count).compactMap { valuesByIndex[$0] }
        }
    }

    private struct PersistedSnapshot {
        var routines: [Routine]
        var history: [WorkoutSession]
        var liftHistory: [LiftRecord]
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

    @Published private(set) var isHydrated = false

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    private var pendingPersistenceSave: DispatchWorkItem?
    private var hasPendingRoutinesSave = false
    private var hasPendingHistorySave = false
    private var hasPendingLiftHistorySave = false

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
    private var hasStartedHydration = false

    var exerciseNamesWithLiftHistory: [String] {
        cachedExerciseNamesWithHistory
    }

    func liftProgress(forExerciseName exerciseName: String) -> [LiftProgressSnapshot] {
        liftProgressByExerciseName[exerciseName] ?? []
    }

    func routine(withID id: UUID) -> Routine? {
        guard let index = routineIndexByID[id], routines.indices.contains(index) else {
            return nil
        }
        return routines[index]
    }

    init(modelContainer: ModelContainer = WorkoutModelContainerFactory.makeContainer()) {
        self.modelContainer = modelContainer
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        routines = []
        workoutHistory = []
        liftHistory = []
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
        workoutHistory.append(session)

        let records = Self.liftRecords(from: session)
        appendLiftHistoryRecords(records)

        var progressedRoutine = routine
        WorkoutProgramEngine.advanceProgramState(in: &progressedRoutine)
        if progressedRoutine != routine {
            routines[routineIndex] = progressedRoutine
        }
    }

    func startHydrationIfNeeded() {
        guard hasStartedHydration == false else {
            return
        }

        hasStartedHydration = true
        let modelContainer = UnsafeSendableBox(value: self.modelContainer)
        let weakStoreBox = WeakStoreBox(store: self)

        DispatchQueue.global(qos: .userInitiated).async {
            let snapshot = Self.loadPersistedSnapshotInParallel(modelContainer: modelContainer.value)
            DispatchQueue.main.async {
                weakStoreBox.store?.hydrate(using: snapshot)
            }
        }
    }

    private func hydrate(using snapshot: PersistedSnapshot) {
        isHydrating = true
        defer {
            isHydrating = false
            isHydrated = true
        }

        let persistedRoutines = snapshot.routines
        let persistedHistory = snapshot.history
        let persistedLiftHistory = snapshot.liftHistory

        let hasPersistedSwiftData = !persistedRoutines.isEmpty
            || !persistedHistory.isEmpty
            || !persistedLiftHistory.isEmpty

        if hasPersistedSwiftData {
            routines = persistedRoutines
            workoutHistory = Self.sortedSessionsByDate(persistedHistory)

            if persistedLiftHistory.isEmpty {
                liftHistory = workoutHistory.flatMap(Self.liftRecords(from:))
                if !liftHistory.isEmpty {
                    replaceStoredLiftHistory(with: liftHistory)
                }
            } else {
                liftHistory = Self.sortedLiftRecordsByDate(persistedLiftHistory)
            }
        } else {
            routines = Self.starterRoutines
            workoutHistory = []
            liftHistory = []
            persistAllToSwiftData()
        }

        rebuildRoutineIndex()
        rebuildLiftHistoryIndex()
    }

    private static func loadPersistedSnapshotInParallel(modelContainer: ModelContainer) -> PersistedSnapshot {
        let results = ParallelHydrationResults()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        group.enter()
        queue.async {
            let readContext = ModelContext(modelContainer)
            readContext.autosaveEnabled = false
            results.setRoutines(Self.loadRoutinesFromStore(using: readContext))
            group.leave()
        }

        group.enter()
        queue.async {
            let readContext = ModelContext(modelContainer)
            readContext.autosaveEnabled = false
            results.setHistory(Self.loadWorkoutHistoryFromStore(using: readContext))
            group.leave()
        }

        group.enter()
        queue.async {
            let readContext = ModelContext(modelContainer)
            readContext.autosaveEnabled = false
            results.setLiftHistory(Self.loadLiftHistoryFromStore(using: readContext))
            group.leave()
        }

        group.wait()
        let snapshot = results.snapshot()
        return PersistedSnapshot(
            routines: snapshot.routines,
            history: snapshot.history,
            liftHistory: snapshot.liftHistory
        )
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
            shouldIncrease: shouldIncrease,
            guidance: guidance
        )
        cacheRecommendation(.value(recommendation), for: cacheKey)
        return recommendation
    }

    func flushPendingSaves() {
        pendingPersistenceSave?.cancel()
        pendingPersistenceSave = nil
        persistDirtyData()
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
        liftHistory.append(contentsOf: records)
    }

    private func applyIncrementalLiftHistoryIndexUpdate(with records: [LiftRecord]) {
        var touchedExerciseSessionKeys: Set<ExerciseSessionKey> = []
        touchedExerciseSessionKeys.reserveCapacity(records.count)
        var latestRecordByExerciseName: [String: LiftRecord] = [:]
        latestRecordByExerciseName.reserveCapacity(records.count)
        var latestRecordByExerciseAndRoutine: [ExerciseRoutineKey: LiftRecord] = [:]
        latestRecordByExerciseAndRoutine.reserveCapacity(records.count)
        var addedNewExerciseName = false

        for record in records {
            if liftHistoryByExerciseName[record.exerciseName] == nil {
                addedNewExerciseName = true
            }
            liftHistoryByExerciseName[record.exerciseName, default: []].append(record)

            let exerciseSessionKey = ExerciseSessionKey(
                exerciseName: record.exerciseName,
                sessionID: record.sessionID
            )
            touchedExerciseSessionKeys.insert(exerciseSessionKey)
            liftHistoryByExerciseAndSession[exerciseSessionKey, default: []].append(record)

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

        for exerciseSessionKey in touchedExerciseSessionKeys {
            guard let combinedRecords = liftHistoryByExerciseAndSession[exerciseSessionKey],
                  let snapshot = Self.makeProgressSnapshot(from: combinedRecords) else {
                continue
            }

            upsertProgressSnapshot(snapshot, forExerciseName: exerciseSessionKey.exerciseName)
        }

        updateLatestSessionIDsByExerciseName(with: latestRecordByExerciseName)
        updateLatestSessionIDsByExerciseAndRoutine(with: latestRecordByExerciseAndRoutine)

        if addedNewExerciseName {
            cachedExerciseNamesWithHistory = liftHistoryByExerciseName.keys.sorted()
        }

        recommendationCache.removeAll(keepingCapacity: true)
    }

    private func upsertProgressSnapshot(
        _ snapshot: LiftProgressSnapshot,
        forExerciseName exerciseName: String
    ) {
        var snapshots = liftProgressByExerciseName[exerciseName] ?? []

        if let existingIndex = snapshots.firstIndex(where: { $0.sessionID == snapshot.sessionID }) {
            snapshots[existingIndex] = snapshot

            let hasPrevious = existingIndex > 0
            let hasNext = existingIndex < snapshots.count - 1
            let needsMoveBackward = hasPrevious && snapshots[existingIndex - 1].performedAt > snapshot.performedAt
            let needsMoveForward = hasNext && snapshots[existingIndex + 1].performedAt < snapshot.performedAt

            if needsMoveBackward || needsMoveForward {
                let updatedSnapshot = snapshots.remove(at: existingIndex)
                let insertionIndex = snapshots.firstIndex { $0.performedAt > updatedSnapshot.performedAt } ?? snapshots.endIndex
                snapshots.insert(updatedSnapshot, at: insertionIndex)
            }
        } else if let latestSnapshotDate = snapshots.last?.performedAt,
                  latestSnapshotDate <= snapshot.performedAt {
            snapshots.append(snapshot)
        } else {
            let insertionIndex = snapshots.firstIndex { $0.performedAt > snapshot.performedAt } ?? snapshots.endIndex
            snapshots.insert(snapshot, at: insertionIndex)
        }

        liftProgressByExerciseName[exerciseName] = snapshots
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
        let records = liftHistory
        let preferredChunkCount = min(
            max(ProcessInfo.processInfo.activeProcessorCount, 1),
            LiftHistoryIndexing.maximumParallelChunkCount
        )
        let shouldBuildInParallel = records.count >= LiftHistoryIndexing.minimumRecordsForParallelIndexing
            && preferredChunkCount > 1

        let partials: [LiftHistoryIndexPartial] = shouldBuildInParallel
            ? Self.buildLiftHistoryIndexPartials(records: records, preferredChunkCount: preferredChunkCount)
            : [Self.buildLiftHistoryIndexPartial(from: records[...])]

        var byExerciseName: [String: [LiftRecord]] = [:]
        byExerciseName.reserveCapacity(liftHistoryByExerciseName.count)
        var byExerciseAndSession: [ExerciseSessionKey: [LiftRecord]] = [:]
        byExerciseAndSession.reserveCapacity(liftHistoryByExerciseAndSession.count)
        var latestSessionByExercise: [String: (sessionID: UUID, performedAt: Date)] = [:]
        latestSessionByExercise.reserveCapacity(latestSessionIDByExerciseName.count)
        var latestSessionByExerciseAndRoutine: [ExerciseRoutineKey: (sessionID: UUID, performedAt: Date)] = [:]
        latestSessionByExerciseAndRoutine.reserveCapacity(latestSessionIDByExerciseAndRoutine.count)

        for partial in partials {
            for (exerciseName, partialRecords) in partial.byExerciseName {
                byExerciseName[exerciseName, default: []].append(contentsOf: partialRecords)
            }

            for (exerciseSessionKey, partialRecords) in partial.byExerciseAndSession {
                byExerciseAndSession[exerciseSessionKey, default: []].append(contentsOf: partialRecords)
            }

            for (exerciseName, latestSession) in partial.latestSessionByExercise {
                if let existing = latestSessionByExercise[exerciseName],
                   existing.performedAt >= latestSession.performedAt {
                    continue
                }
                latestSessionByExercise[exerciseName] = latestSession
            }

            for (exerciseRoutineKey, latestSession) in partial.latestSessionByExerciseAndRoutine {
                if let existing = latestSessionByExerciseAndRoutine[exerciseRoutineKey],
                   existing.performedAt >= latestSession.performedAt {
                    continue
                }
                latestSessionByExerciseAndRoutine[exerciseRoutineKey] = latestSession
            }
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

    private static func buildLiftHistoryIndexPartials(
        records: [LiftRecord],
        preferredChunkCount: Int
    ) -> [LiftHistoryIndexPartial] {
        guard !records.isEmpty else {
            return []
        }

        let safeChunkCount = max(1, min(preferredChunkCount, records.count))
        let chunkSize = (records.count + safeChunkCount - 1) / safeChunkCount
        let partialStore = IndexedPartialStore()

        DispatchQueue.concurrentPerform(iterations: safeChunkCount) { chunkIndex in
            let startIndex = chunkIndex * chunkSize
            guard startIndex < records.count else {
                return
            }

            let endIndex = min(startIndex + chunkSize, records.count)
            let partial = buildLiftHistoryIndexPartial(from: records[startIndex..<endIndex])
            partialStore.set(partial, at: chunkIndex)
        }

        return partialStore.orderedPartials(count: safeChunkCount)
    }

    private static func buildLiftHistoryIndexPartial(
        from records: ArraySlice<LiftRecord>
    ) -> LiftHistoryIndexPartial {
        var byExerciseName: [String: [LiftRecord]] = [:]
        byExerciseName.reserveCapacity(records.count)
        var byExerciseAndSession: [ExerciseSessionKey: [LiftRecord]] = [:]
        byExerciseAndSession.reserveCapacity(records.count)
        var latestSessionByExercise: [String: (sessionID: UUID, performedAt: Date)] = [:]
        latestSessionByExercise.reserveCapacity(records.count)
        var latestSessionByExerciseAndRoutine: [ExerciseRoutineKey: (sessionID: UUID, performedAt: Date)] = [:]
        latestSessionByExerciseAndRoutine.reserveCapacity(records.count)

        for record in records {
            byExerciseName[record.exerciseName, default: []].append(record)

            let exerciseSessionKey = ExerciseSessionKey(
                exerciseName: record.exerciseName,
                sessionID: record.sessionID
            )
            byExerciseAndSession[exerciseSessionKey, default: []].append(record)

            updateLatestSession(
                in: &latestSessionByExercise,
                key: record.exerciseName,
                record: record
            )

            let exerciseRoutineKey = ExerciseRoutineKey(
                exerciseName: record.exerciseName,
                routineName: record.routineName
            )
            updateLatestSession(
                in: &latestSessionByExerciseAndRoutine,
                key: exerciseRoutineKey,
                record: record
            )
        }

        return LiftHistoryIndexPartial(
            byExerciseName: byExerciseName,
            byExerciseAndSession: byExerciseAndSession,
            latestSessionByExercise: latestSessionByExercise,
            latestSessionByExerciseAndRoutine: latestSessionByExerciseAndRoutine
        )
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
        hasPendingRoutinesSave = true
        scheduleSave()
    }

    private func scheduleHistorySave() {
        hasPendingHistorySave = true
        scheduleSave()
    }

    private func scheduleLiftHistorySave() {
        hasPendingLiftHistorySave = true
        scheduleSave()
    }

    private func scheduleSave() {
        pendingPersistenceSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistDirtyData()
        }

        pendingPersistenceSave = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(Persistence.saveDebounceMilliseconds),
            execute: work
        )
    }

    private func persistAllToSwiftData() {
        pendingPersistenceSave?.cancel()
        pendingPersistenceSave = nil
        hasPendingRoutinesSave = false
        hasPendingHistorySave = false
        hasPendingLiftHistorySave = false

        replaceStoredRoutines(with: routines)
        replaceStoredWorkoutHistory(with: workoutHistory)
        replaceStoredLiftHistory(with: liftHistory)
    }

    private func persistDirtyData() {
        let shouldSaveRoutines = hasPendingRoutinesSave
        let shouldSaveHistory = hasPendingHistorySave
        let shouldSaveLiftHistory = hasPendingLiftHistorySave

        pendingPersistenceSave = nil
        hasPendingRoutinesSave = false
        hasPendingHistorySave = false
        hasPendingLiftHistorySave = false

        if shouldSaveRoutines {
            replaceStoredRoutines(with: routines)
        }
        if shouldSaveHistory {
            replaceStoredWorkoutHistory(with: workoutHistory)
        }
        if shouldSaveLiftHistory {
            replaceStoredLiftHistory(with: liftHistory)
        }
    }

    private func loadRoutinesFromStore() -> [Routine] {
        Self.loadRoutinesFromStore(using: modelContext)
    }

    private static func loadRoutinesFromStore(using context: ModelContext) -> [Routine] {
        do {
            let descriptor = FetchDescriptor<StoredRoutine>(
                sortBy: [SortDescriptor(\.orderIndex)]
            )
            let storedRoutines = try context.fetch(descriptor)

            return storedRoutines.map { storedRoutine in
                let exercises = storedRoutine.exercises
                    .sorted {
                        Self.orderedByIndexAndID(
                            $0,
                            $1,
                            index: \.orderIndex,
                            id: \.id
                        )
                    }
                    .map { exercise in
                        Exercise(
                            id: exercise.id,
                            name: exercise.name,
                            trainingMax: exercise.trainingMax
                        )
                    }

                return Routine(
                    id: storedRoutine.id,
                    name: storedRoutine.name,
                    exercises: exercises,
                    program: Self.programConfig(
                        kindRaw: storedRoutine.programKindRaw,
                        step: storedRoutine.programStep,
                        cycle: storedRoutine.programCycle
                    )
                )
            }
        } catch {
            print("WorkoutStore: failed to load routines from SwiftData: \(error)")
            return []
        }
    }

    private func loadWorkoutHistoryFromStore() -> [WorkoutSession] {
        Self.loadWorkoutHistoryFromStore(using: modelContext)
    }

    private static func loadWorkoutHistoryFromStore(using context: ModelContext) -> [WorkoutSession] {
        do {
            let descriptor = FetchDescriptor<StoredWorkoutSession>()
            let storedSessions = try context.fetch(descriptor)

            let sessions = storedSessions.map { storedSession in
                let entries = storedSession.entries
                    .sorted {
                        Self.orderedByIndexAndID(
                            $0,
                            $1,
                            index: \.orderIndex,
                            id: \.id
                        )
                    }
                    .map { storedEntry in
                        let sets = storedEntry.sets
                            .sorted {
                                Self.orderedByIndexAndID(
                                    $0,
                                    $1,
                                    index: \.orderIndex,
                                    id: \.id
                                )
                            }
                            .map { storedSet in
                                ExerciseSet(
                                    id: storedSet.id,
                                    weight: storedSet.weight,
                                    reps: storedSet.reps
                                )
                            }

                        return ExerciseEntry(
                            id: storedEntry.id,
                            exerciseName: storedEntry.exerciseName,
                            sets: sets
                        )
                    }

                return WorkoutSession(
                    id: storedSession.id,
                    routineName: storedSession.routineName,
                    performedAt: storedSession.performedAt,
                    entries: entries,
                    programContext: storedSession.programContext
                )
            }

            return Self.sortedSessionsByDate(sessions)
        } catch {
            print("WorkoutStore: failed to load workout history from SwiftData: \(error)")
            return []
        }
    }

    private func loadLiftHistoryFromStore() -> [LiftRecord] {
        Self.loadLiftHistoryFromStore(using: modelContext)
    }

    private static func loadLiftHistoryFromStore(using context: ModelContext) -> [LiftRecord] {
        do {
            let descriptor = FetchDescriptor<StoredLiftRecord>()
            let storedRecords = try context.fetch(descriptor)

            let records = storedRecords.map { record in
                LiftRecord(
                    id: record.id,
                    sessionID: record.sessionID,
                    routineName: record.routineName,
                    exerciseName: record.exerciseName,
                    performedAt: record.performedAt,
                    setIndex: record.setIndex,
                    weight: record.weight,
                    reps: record.reps
                )
            }

            return Self.sortedLiftRecordsByDate(records)
        } catch {
            print("WorkoutStore: failed to load lift history from SwiftData: \(error)")
            return []
        }
    }

    private func replaceStoredRoutines(with routines: [Routine]) {
        do {
            let storedRoutines = try modelContext.fetch(FetchDescriptor<StoredRoutine>())
            var storedRoutineByID: [UUID: StoredRoutine] = [:]
            storedRoutineByID.reserveCapacity(storedRoutines.count)
            for storedRoutine in storedRoutines {
                storedRoutineByID[storedRoutine.id] = storedRoutine
            }

            var seenRoutineIDs: Set<UUID> = []
            seenRoutineIDs.reserveCapacity(routines.count)
            for (routineIndex, routine) in routines.enumerated() {
                seenRoutineIDs.insert(routine.id)

                let storedRoutine = storedRoutineByID[routine.id] ?? {
                    let inserted = StoredRoutine(
                        id: routine.id,
                        name: routine.name,
                        orderIndex: routineIndex,
                        programKindRaw: routine.program?.kind.rawValue,
                        programStep: routine.program?.state.step,
                        programCycle: routine.program?.state.cycle
                    )
                    modelContext.insert(inserted)
                    storedRoutineByID[routine.id] = inserted
                    return inserted
                }()

                storedRoutine.name = routine.name
                storedRoutine.orderIndex = routineIndex
                storedRoutine.programKindRaw = routine.program?.kind.rawValue
                storedRoutine.programStep = routine.program?.state.step
                storedRoutine.programCycle = routine.program?.state.cycle

                syncStoredExercises(for: storedRoutine, with: routine.exercises)
            }

            for storedRoutine in storedRoutines where !seenRoutineIDs.contains(storedRoutine.id) {
                modelContext.delete(storedRoutine)
            }

            try saveContextChanges()
        } catch {
            print("WorkoutStore: failed to persist routines to SwiftData: \(error)")
        }
    }

    private func replaceStoredWorkoutHistory(with sessions: [WorkoutSession]) {
        do {
            let storedSessions = try modelContext.fetch(FetchDescriptor<StoredWorkoutSession>())
            var storedSessionByID: [UUID: StoredWorkoutSession] = [:]
            storedSessionByID.reserveCapacity(storedSessions.count)
            for storedSession in storedSessions {
                storedSessionByID[storedSession.id] = storedSession
            }

            var seenSessionIDs: Set<UUID> = []
            seenSessionIDs.reserveCapacity(sessions.count)
            for session in sessions {
                seenSessionIDs.insert(session.id)

                let storedSession = storedSessionByID[session.id] ?? {
                    let inserted = StoredWorkoutSession(
                        id: session.id,
                        routineName: session.routineName,
                        performedAt: session.performedAt,
                        programContext: session.programContext
                    )
                    modelContext.insert(inserted)
                    storedSessionByID[session.id] = inserted
                    return inserted
                }()

                storedSession.routineName = session.routineName
                storedSession.performedAt = session.performedAt
                storedSession.programContext = session.programContext

                syncStoredEntries(for: storedSession, with: session.entries)
            }

            for storedSession in storedSessions where !seenSessionIDs.contains(storedSession.id) {
                modelContext.delete(storedSession)
            }

            try saveContextChanges()
        } catch {
            print("WorkoutStore: failed to persist workout history to SwiftData: \(error)")
        }
    }

    private func replaceStoredLiftHistory(with records: [LiftRecord]) {
        do {
            let storedRecords = try modelContext.fetch(FetchDescriptor<StoredLiftRecord>())
            var storedRecordByID: [UUID: StoredLiftRecord] = [:]
            storedRecordByID.reserveCapacity(storedRecords.count)
            for storedRecord in storedRecords {
                storedRecordByID[storedRecord.id] = storedRecord
            }

            var seenRecordIDs: Set<UUID> = []
            seenRecordIDs.reserveCapacity(records.count)
            for record in records {
                seenRecordIDs.insert(record.id)

                let storedRecord = storedRecordByID[record.id] ?? {
                    let inserted = StoredLiftRecord(
                        id: record.id,
                        sessionID: record.sessionID,
                        routineName: record.routineName,
                        exerciseName: record.exerciseName,
                        performedAt: record.performedAt,
                        setIndex: record.setIndex,
                        weight: record.weight,
                        reps: record.reps
                    )
                    modelContext.insert(inserted)
                    storedRecordByID[record.id] = inserted
                    return inserted
                }()

                storedRecord.sessionID = record.sessionID
                storedRecord.routineName = record.routineName
                storedRecord.exerciseName = record.exerciseName
                storedRecord.performedAt = record.performedAt
                storedRecord.setIndex = record.setIndex
                storedRecord.weight = record.weight
                storedRecord.reps = record.reps
            }

            for storedRecord in storedRecords where !seenRecordIDs.contains(storedRecord.id) {
                modelContext.delete(storedRecord)
            }

            try saveContextChanges()
        } catch {
            print("WorkoutStore: failed to persist lift history to SwiftData: \(error)")
        }
    }

    private func syncStoredExercises(
        for storedRoutine: StoredRoutine,
        with exercises: [Exercise]
    ) {
        let existingExercises = storedRoutine.exercises
        var storedExerciseByID: [UUID: StoredExercise] = [:]
        storedExerciseByID.reserveCapacity(existingExercises.count)
        for storedExercise in existingExercises {
            storedExerciseByID[storedExercise.id] = storedExercise
        }

        var seenExerciseIDs: Set<UUID> = []
        seenExerciseIDs.reserveCapacity(exercises.count)
        for (exerciseIndex, exercise) in exercises.enumerated() {
            seenExerciseIDs.insert(exercise.id)

            let storedExercise = storedExerciseByID[exercise.id] ?? {
                let inserted = StoredExercise(
                    id: exercise.id,
                    name: exercise.name,
                    trainingMax: exercise.trainingMax,
                    orderIndex: exerciseIndex
                )
                inserted.routine = storedRoutine
                modelContext.insert(inserted)
                storedExerciseByID[exercise.id] = inserted
                return inserted
            }()

            storedExercise.name = exercise.name
            storedExercise.trainingMax = exercise.trainingMax
            storedExercise.orderIndex = exerciseIndex
            if storedExercise.routine?.id != storedRoutine.id {
                storedExercise.routine = storedRoutine
            }
        }

        for storedExercise in existingExercises where !seenExerciseIDs.contains(storedExercise.id) {
            modelContext.delete(storedExercise)
        }
    }

    private func syncStoredEntries(
        for storedSession: StoredWorkoutSession,
        with entries: [ExerciseEntry]
    ) {
        let existingEntries = storedSession.entries
        var storedEntryByID: [UUID: StoredWorkoutEntry] = [:]
        storedEntryByID.reserveCapacity(existingEntries.count)
        for storedEntry in existingEntries {
            storedEntryByID[storedEntry.id] = storedEntry
        }

        var seenEntryIDs: Set<UUID> = []
        seenEntryIDs.reserveCapacity(entries.count)
        for (entryIndex, entry) in entries.enumerated() {
            seenEntryIDs.insert(entry.id)

            let storedEntry = storedEntryByID[entry.id] ?? {
                let inserted = StoredWorkoutEntry(
                    id: entry.id,
                    exerciseName: entry.exerciseName,
                    orderIndex: entryIndex
                )
                inserted.session = storedSession
                modelContext.insert(inserted)
                storedEntryByID[entry.id] = inserted
                return inserted
            }()

            storedEntry.exerciseName = entry.exerciseName
            storedEntry.orderIndex = entryIndex
            if storedEntry.session?.id != storedSession.id {
                storedEntry.session = storedSession
            }

            syncStoredSets(for: storedEntry, with: entry.sets)
        }

        for storedEntry in existingEntries where !seenEntryIDs.contains(storedEntry.id) {
            modelContext.delete(storedEntry)
        }
    }

    private func syncStoredSets(
        for storedEntry: StoredWorkoutEntry,
        with sets: [ExerciseSet]
    ) {
        let existingSets = storedEntry.sets
        var storedSetByID: [UUID: StoredWorkoutSet] = [:]
        storedSetByID.reserveCapacity(existingSets.count)
        for storedSet in existingSets {
            storedSetByID[storedSet.id] = storedSet
        }

        var seenSetIDs: Set<UUID> = []
        seenSetIDs.reserveCapacity(sets.count)
        for (setIndex, set) in sets.enumerated() {
            seenSetIDs.insert(set.id)

            let storedSet = storedSetByID[set.id] ?? {
                let inserted = StoredWorkoutSet(
                    id: set.id,
                    weight: set.weight,
                    reps: set.reps,
                    orderIndex: setIndex
                )
                inserted.entry = storedEntry
                modelContext.insert(inserted)
                storedSetByID[set.id] = inserted
                return inserted
            }()

            storedSet.weight = set.weight
            storedSet.reps = set.reps
            storedSet.orderIndex = setIndex
            if storedSet.entry?.id != storedEntry.id {
                storedSet.entry = storedEntry
            }
        }

        for storedSet in existingSets where !seenSetIDs.contains(storedSet.id) {
            modelContext.delete(storedSet)
        }
    }

    private func saveContextChanges() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    private func updateLatestSessionIDsByExerciseName(with latestRecords: [String: LiftRecord]) {
        updateLatestSessionIDs(
            with: latestRecords,
            target: &latestSessionIDByExerciseName
        ) { exerciseName in
            exerciseName
        }
    }

    private func updateLatestSessionIDsByExerciseAndRoutine(
        with latestRecords: [ExerciseRoutineKey: LiftRecord]
    ) {
        updateLatestSessionIDs(
            with: latestRecords,
            target: &latestSessionIDByExerciseAndRoutine
        ) { exerciseRoutineKey in
            exerciseRoutineKey.exerciseName
        }
    }

    private func currentSessionDate(forExerciseName exerciseName: String, sessionID: UUID) -> Date {
        liftHistoryByExerciseAndSession[
            ExerciseSessionKey(exerciseName: exerciseName, sessionID: sessionID)
        ]?.first?.performedAt ?? .distantPast
    }

    private func updateLatestSessionIDs<Key: Hashable>(
        with latestRecords: [Key: LiftRecord],
        target latestSessionIDsByKey: inout [Key: UUID],
        exerciseNameForKey: (Key) -> String
    ) {
        for (key, latestRecord) in latestRecords {
            let currentDate = latestSessionIDsByKey[key].map {
                currentSessionDate(
                    forExerciseName: exerciseNameForKey(key),
                    sessionID: $0
                )
            } ?? .distantPast

            if latestRecord.performedAt >= currentDate {
                latestSessionIDsByKey[key] = latestRecord.sessionID
            }
        }
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

    private static func orderedByIndexAndID<T>(
        _ lhs: T,
        _ rhs: T,
        index: KeyPath<T, Int>,
        id: KeyPath<T, UUID>
    ) -> Bool {
        let lhsIndex = lhs[keyPath: index]
        let rhsIndex = rhs[keyPath: index]
        if lhsIndex != rhsIndex {
            return lhsIndex < rhsIndex
        }
        return lhs[keyPath: id].uuidString < rhs[keyPath: id].uuidString
    }

    private static func programConfig(kindRaw: String?, step: Int?, cycle: Int?) -> ProgramConfig? {
        guard let kindRaw, let kind = ProgramKind(rawValue: kindRaw) else {
            return nil
        }

        return ProgramConfig(
            kind: kind,
            state: ProgramState(step: max(step ?? 0, 0), cycle: max(cycle ?? 1, 1))
        )
    }

    private static func liftRecords(from session: WorkoutSession) -> [LiftRecord] {
        session.entries.flatMap { entry in
            entry.sets.enumerated().compactMap { index, set in
                guard set.weight != nil || set.reps != nil else {
                    return nil
                }

                return LiftRecord(
                    sessionID: session.id,
                    routineName: session.routineName,
                    exerciseName: entry.exerciseName,
                    performedAt: session.performedAt,
                    setIndex: index + 1,
                    weight: set.weight,
                    reps: set.reps
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

    private static func sortedSessionsByDate(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions.sorted { lhs, rhs in
            if lhs.performedAt != rhs.performedAt {
                return lhs.performedAt < rhs.performedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func sortedLiftRecordsByDate(_ records: [LiftRecord]) -> [LiftRecord] {
        records.sorted { lhs, rhs in
            if lhs.performedAt != rhs.performedAt {
                return lhs.performedAt < rhs.performedAt
            }
            if lhs.sessionID != rhs.sessionID {
                return lhs.sessionID.uuidString < rhs.sessionID.uuidString
            }
            return lhs.setIndex < rhs.setIndex
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
}
