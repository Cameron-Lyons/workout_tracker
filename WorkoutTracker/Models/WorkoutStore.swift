import Foundation

final class WorkoutStore: ObservableObject {
    private enum Persistence {
        static let saveDebounceMilliseconds = 300
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

        if let data = defaults.data(forKey: routinesKey),
           let decodedRoutines = try? decoder.decode([Routine].self, from: data),
           !decodedRoutines.isEmpty {
            routines = decodedRoutines
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
    }

    func liftRecords(forExerciseName exerciseName: String) -> [LiftRecord] {
        liftHistoryByExerciseName[exerciseName] ?? []
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

    static var starterRoutines: [Routine] {
        [
            Routine(
                name: "Push",
                exercises: [
                    Exercise(name: "Bench Press"),
                    Exercise(name: "Incline Dumbbell Press"),
                    Exercise(name: "Overhead Press")
                ]
            ),
            Routine(
                name: "Pull",
                exercises: [
                    Exercise(name: "Deadlift"),
                    Exercise(name: "Pull Up"),
                    Exercise(name: "Barbell Row")
                ]
            ),
            Routine(
                name: "Legs",
                exercises: [
                    Exercise(name: "Back Squat"),
                    Exercise(name: "Romanian Deadlift"),
                    Exercise(name: "Leg Press")
                ]
            )
        ]
    }
}
