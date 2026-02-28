import Foundation

final class WorkoutStore: ObservableObject {
    @Published var routines: [Routine] {
        didSet {
            guard !isHydrating else { return }
            saveRoutines()
        }
    }

    @Published var workoutHistory: [WorkoutSession] {
        didSet {
            guard !isHydrating else { return }
            saveHistory()
        }
    }

    @Published var liftHistory: [LiftRecord] {
        didSet {
            guard !isHydrating else { return }
            saveLiftHistory()
        }
    }

    private let routinesKey = "workout_tracker_routines_v1"
    private let historyKey = "workout_tracker_history_v1"
    private let liftHistoryKey = "workout_tracker_lift_history_v1"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isHydrating = false

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        routines = []
        workoutHistory = []
        liftHistory = []
        hydrate()
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
        guard let index = routines.firstIndex(where: { $0.id == id }) else { return }
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
        guard let routineIndex = routines.firstIndex(where: { $0.id == routineID }) else {
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
        routines[routineIndex] = progressedRoutine
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
    }

    private func saveRoutines() {
        guard let data = try? encoder.encode(routines) else { return }
        defaults.set(data, forKey: routinesKey)
    }

    private func saveHistory() {
        guard let data = try? encoder.encode(workoutHistory) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private func saveLiftHistory() {
        guard let data = try? encoder.encode(liftHistory) else { return }
        defaults.set(data, forKey: liftHistoryKey)
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
