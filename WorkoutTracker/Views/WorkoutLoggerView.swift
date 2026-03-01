import Foundation
import SwiftUI

private struct SetDraft: Identifiable, Equatable {
    var id = UUID()
    var weight = ""
    var reps = ""
    var transcript = ""
    var prescriptionNote: String?
}

private struct ActiveVoiceTarget: Equatable {
    var exerciseID: UUID
    var setID: UUID
}

struct WorkoutLoggerView: View {
    private enum Constants {
        static let weightInputCharacters = "0123456789."
        static let savedToastDuration = 1.4
        static let defaultRestSeconds = 90
        static let minimumRestSeconds = 1
        static let quickAddRestSeconds = 30
        static let defaultMinimumWeightIncreaseInPounds = 10.0
        static let restPresets = [60, 90, 120, 180]
        static let restTickerInterval = 1.0
        static let animationDuration = 0.2
    }

    private enum Layout {
        static let rootSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let compactSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 10
        static let unitPickerWidth: CGFloat = 210
        static let minimumIncreaseInputWidth: CGFloat = 66
        static let cardCornerRadius: CGFloat = 16
        static let setCardCornerRadius: CGFloat = 12
        static let setCardPadding: CGFloat = 10
        static let listBottomPadding: CGFloat = 6
        static let toastHorizontalPadding: CGFloat = 14
        static let toastVerticalPadding: CGFloat = 10
        static let toastBottomPadding: CGFloat = 24
    }

    @EnvironmentObject private var store: WorkoutStore
    @StateObject private var speechInput = SpeechInputManager()
    @AppStorage("workout_tracker_rest_timer_auto_start_v1") private var autoStartRestTimer = false
    @AppStorage(WeightUnit.preferenceKey) private var weightUnitRawValue = WeightUnit.pounds.rawValue
    @AppStorage("workout_tracker_min_weight_increase_v1")
    private var minimumWeightIncreaseInPounds = Constants.defaultMinimumWeightIncreaseInPounds

    @State private var selectedRoutineID: UUID?
    @State private var drafts: [UUID: [SetDraft]] = [:]
    @State private var activeVoiceTarget: ActiveVoiceTarget?
    @State private var minimumWeightIncreaseInput = ""
    @State private var previousWeightUnit: WeightUnit = .pounds

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @State private var showSavedToast = false
    @State private var showVoiceTools = false

    @State private var restTimerDuration = Constants.defaultRestSeconds
    @State private var restTimerRemaining = 0
    @State private var isRestTimerRunning = false

    private let restTicker = Timer.publish(
        every: Constants.restTickerInterval,
        on: .main,
        in: .common
    ).autoconnect()

    private var selectedRoutine: Routine? {
        guard let selectedRoutineID else { return nil }
        return store.routines.first { $0.id == selectedRoutineID }
    }

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRawValue) ?? .pounds
    }

    private var weightUnitBinding: Binding<WeightUnit> {
        Binding(
            get: { weightUnit },
            set: { newValue in
                weightUnitRawValue = newValue.rawValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: Layout.rootSpacing) {
                    let selectedRoutineWithPlan = selectedRoutine.map { routine in
                        let plan = WorkoutProgramEngine.plan(for: routine)
                        let visibleExercises = activeExercises(in: routine, plan: plan)
                        return (routine: routine, plan: plan, visibleExercises: visibleExercises)
                    }

                    routineSelector

                    if let contextLabel = selectedRoutineWithPlan?.plan.contextLabel {
                        Text(contextLabel)
                            .font(.caption.weight(.heavy))
                            .tracking(0.7)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Use manual entry by default. Voice input is optional for quick logging.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    restTimerCard
                        .padding(.horizontal)

                    if let selectedRoutineWithPlan {
                        let routine = selectedRoutineWithPlan.routine
                        let plan = selectedRoutineWithPlan.plan
                        let visibleExercises = selectedRoutineWithPlan.visibleExercises

                        ScrollView {
                            LazyVStack(spacing: Layout.sectionSpacing) {
                                ForEach(visibleExercises) { exercise in
                                    exerciseCard(exercise, plan: plan)
                                        .scrollTransition(axis: .vertical) { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1 : 0.84)
                                                .scaleEffect(phase.isIdentity ? 1 : 0.985)
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, Layout.listBottomPadding)
                        }

                        Button {
                            saveWorkout(routine: routine, activeExercises: visibleExercises)
                        } label: {
                            Text("Save Workout")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.accent)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .disabled(!hasAnyLoggedValues(in: visibleExercises))
                    } else {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(AppColors.accent)

                            Text("No routine selected")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Create a routine first, then pick it here to start logging.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(22)
                        .appSurface()
                        .padding(.horizontal)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Log Workout")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                normalizeStoredMinimumIncrease()
                previousWeightUnit = weightUnit
                syncSelection()
                syncMinimumWeightIncreaseInput()
            }
            .onChange(of: store.routines) { _, _ in
                syncSelection()
            }
            .onChange(of: weightUnitRawValue) { _, _ in
                handleWeightUnitChange()
            }
            .onChange(of: selectedRoutineID) { _, _ in
                rebuildDrafts()
            }
            .onChange(of: showVoiceTools) { _, isEnabled in
                if !isEnabled {
                    speechInput.stopRecording()
                    activeVoiceTarget = nil
                }
            }
            .onReceive(restTicker) { _ in
                handleRestTimerTick()
            }
            .alert("Voice Input", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showVoiceTools.toggle()
                    } label: {
                        Label(showVoiceTools ? "Voice tools on" : "Voice tools off", systemImage: showVoiceTools ? "mic.fill" : "mic.slash")
                    }
                }
            }
            .tint(AppColors.accent)
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Workout saved")
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, Layout.toastHorizontalPadding)
                        .padding(.vertical, Layout.toastVerticalPadding)
                        .background(
                            Capsule()
                                .fill(AppColors.surfaceStrong.opacity(0.98))
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppColors.stroke, lineWidth: 1)
                        )
                        .padding(.bottom, Layout.toastBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: Constants.animationDuration), value: showSavedToast)
        }
    }

    private var routineSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Routine")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Picker("Routine", selection: $selectedRoutineID) {
                Text("Choose a routine").tag(Optional<UUID>.none)
                ForEach(store.routines) { routine in
                    Text(routine.name).tag(Optional(routine.id))
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.textPrimary)

            HStack(spacing: Layout.compactSpacing) {
                Text("Units")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Picker("Units", selection: weightUnitBinding) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.shortLabel).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: Layout.unitPickerWidth)
            }

            HStack(spacing: Layout.compactSpacing) {
                Text("Min Weight Increase")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                HStack(spacing: Layout.compactSpacing) {
                    TextField(
                        WeightFormatter.displayString(
                            displayValue: weightUnit.recommendedMinimumIncreaseDefault,
                            unit: weightUnit
                        ),
                        text: minimumWeightIncreaseBinding
                    )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: Layout.minimumIncreaseInputWidth)
                        .appInputField()

                    Text(weightUnit.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Text("Used by auto-suggestions when recommending your next weight.")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(14)
        .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
        .padding(.horizontal)
    }

    private var restTimerCard: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack {
                Label("Rest Timer", systemImage: "timer")
                    .font(.system(.body, design: .rounded).weight(.black))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(restTimerDisplay)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(restTimerRemaining == 0 && !isRestTimerRunning ? AppColors.textSecondary : AppColors.textPrimary)
            }

            ProgressView(value: restProgress)
                .tint(restTimerRemaining == 0 ? AppColors.accentAlt : AppColors.accent)

            HStack(spacing: Layout.compactSpacing) {
                ForEach(Constants.restPresets, id: \.self) { seconds in
                    Button(presetLabel(for: seconds)) {
                        startRestTimer(seconds: seconds)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.accentAlt.opacity(0.85))
                    .font(.caption)
                }
            }

            HStack(spacing: Layout.rowSpacing) {
                Button {
                    if isRestTimerRunning {
                        pauseRestTimer()
                    } else if restTimerRemaining > 0 {
                        resumeRestTimer()
                    } else {
                        startRestTimer(seconds: restTimerDuration)
                    }
                } label: {
                    Label(restControlLabel, systemImage: restControlIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                Button("+30s") {
                    addRestTime(seconds: Constants.quickAddRestSeconds)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.accentAlt)

                Button("Reset", role: .destructive) {
                    resetRestTimer()
                }
                .buttonStyle(.bordered)
                .disabled(restTimerRemaining == 0 && !isRestTimerRunning)
            }

            if restTimerRemaining == 0 && !isRestTimerRunning {
                Text("Ready for your next set.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Toggle("Auto-start rest timer after saving workout", isOn: $autoStartRestTimer)
                .font(.caption)
                .tint(AppColors.accentAlt)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
    }

    private func exerciseCard(
        _ exercise: Exercise,
        plan: ProgramWorkoutPlan
    ) -> some View {
        let sets = setDrafts(for: exercise, plan: plan)
        let recommendation = weightRecommendation(for: exercise, targetSets: sets)

        return VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(exercise.name)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            if let recommendation {
                recommendationCallout(recommendation)
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                VStack(alignment: .leading, spacing: Layout.compactSpacing) {
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.caption.weight(.heavy))
                            .tracking(0.4)
                            .foregroundStyle(AppColors.textSecondary)

                        Spacer()

                        if sets.count > 1 {
                            Button(role: .destructive) {
                                removeSet(from: exercise.id, setID: set.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.red.opacity(0.9))
                        }
                    }

                    HStack(spacing: Layout.rowSpacing) {
                        TextField("Weight (\(weightUnit.symbol))", text: weightBinding(for: exercise.id, setIndex: index))
                            .keyboardType(.decimalPad)
                            .appInputField()

                        TextField("Reps", text: repsBinding(for: exercise.id, setIndex: index))
                            .keyboardType(.numberPad)
                            .appInputField()
                    }

                    if let note = set.prescriptionNote, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if showVoiceTools {
                        HStack(spacing: Layout.rowSpacing) {
                            Button {
                                toggleVoiceInput(for: exercise.id, setID: set.id)
                            } label: {
                                Label(
                                    isVoiceActive(for: exercise.id, setID: set.id) && speechInput.isRecording ? "Stop" : "Speak",
                                    systemImage: isVoiceActive(for: exercise.id, setID: set.id) && speechInput.isRecording ? "stop.circle.fill" : "mic.fill"
                                )
                            }
                            .buttonStyle(.bordered)
                            .tint(isVoiceActive(for: exercise.id, setID: set.id) && speechInput.isRecording ? .red : AppColors.accentAlt)

                            if !set.transcript.isEmpty {
                                Text("Heard: \(set.transcript)")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(Layout.setCardPadding)
                .appSurface(cornerRadius: Layout.setCardCornerRadius, shadow: false)
            }

            Button {
                addSet(to: exercise.id)
            } label: {
                Label("Add Set", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .tint(AppColors.accentAlt)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
    }

    private func recommendationCallout(_ recommendation: ExerciseWeightRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: recommendation.shouldIncrease ? "arrow.up.right.circle.fill" : "equal.circle.fill")
                    .foregroundStyle(recommendation.shouldIncrease ? AppColors.accent : AppColors.accentAlt)

                Text("Suggested next weight: \(WeightFormatter.displayString(recommendation.recommendedWeight, unit: weightUnit)) \(weightUnit.symbol)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text(recommendation.guidance)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.input.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.75), lineWidth: 1)
        )
    }

    private func activeExercises(in routine: Routine, plan: ProgramWorkoutPlan) -> [Exercise] {
        if let activeIDs = plan.activeExerciseIDs {
            return routine.exercises.filter { activeIDs.contains($0.id) }
        }

        return routine.exercises
    }

    private var restControlLabel: String {
        if isRestTimerRunning {
            return "Pause"
        }

        if restTimerRemaining > 0 {
            return "Resume"
        }

        return "Start"
    }

    private var restControlIcon: String {
        isRestTimerRunning ? "pause.fill" : "play.fill"
    }

    private var restProgress: Double {
        guard restTimerDuration > 0 else { return 0 }
        let elapsed = Double(restTimerDuration - restTimerRemaining)
        return max(0, min(1, elapsed / Double(restTimerDuration)))
    }

    private var restTimerDisplay: String {
        durationText(from: restTimerRemaining)
    }

    private func presetLabel(for seconds: Int) -> String {
        durationText(from: seconds)
    }

    private func durationText(from totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }

    private var minimumWeightIncreaseBinding: Binding<String> {
        Binding(
            get: {
                minimumWeightIncreaseInput
            },
            set: { value in
                let sanitized = value.filter { Constants.weightInputCharacters.contains($0) }
                minimumWeightIncreaseInput = sanitized

                guard let parsed = Double(sanitized), parsed > 0 else {
                    return
                }

                let normalizedDisplayValue = weightUnit.normalizedDisplayIncrease(parsed)
                minimumWeightIncreaseInPounds = weightUnit.storedPounds(fromDisplayValue: normalizedDisplayValue)
                minimumWeightIncreaseInput = WeightFormatter.displayString(
                    displayValue: normalizedDisplayValue,
                    unit: weightUnit
                )
            }
        )
    }

    private func syncMinimumWeightIncreaseInput() {
        let displayValue = weightUnit.displayValue(
            fromStoredPounds: minimumWeightIncreaseInPounds,
            snapToGymIncrement: false
        )
        minimumWeightIncreaseInput = WeightFormatter.displayString(displayValue: displayValue, unit: weightUnit)
    }

    private func minimumWeightIncreaseDisplayValue() -> Double {
        let displayValue = weightUnit.displayValue(
            fromStoredPounds: minimumWeightIncreaseInPounds,
            snapToGymIncrement: false
        )
        return weightUnit.normalizedDisplayIncrease(displayValue)
    }

    private func normalizeStoredMinimumIncrease() {
        let displayValue = minimumWeightIncreaseDisplayValue()
        minimumWeightIncreaseInPounds = weightUnit.storedPounds(fromDisplayValue: displayValue)
    }

    private func handleWeightUnitChange() {
        let newUnit = weightUnit
        let oldUnit = previousWeightUnit
        previousWeightUnit = newUnit

        guard newUnit != oldUnit else {
            syncMinimumWeightIncreaseInput()
            return
        }

        convertDraftWeights(from: oldUnit, to: newUnit)
        normalizeStoredMinimumIncrease()
        syncMinimumWeightIncreaseInput()
    }

    private func convertDraftWeights(from oldUnit: WeightUnit, to newUnit: WeightUnit) {
        drafts = drafts.mapValues { sets in
            sets.map { set in
                guard let convertedWeight = newUnit.convertedDisplayString(from: oldUnit, text: set.weight) else {
                    return set
                }

                var converted = set
                converted.weight = convertedWeight
                return converted
            }
        }
    }

    private func parseStoredWeight(from text: String) -> Double? {
        guard let displayWeight = Double(text), displayWeight >= 0 else {
            return nil
        }

        return weightUnit.storedPounds(fromDisplayValue: displayWeight)
    }

    private func startRestTimer(seconds: Int) {
        let safeSeconds = max(seconds, Constants.minimumRestSeconds)
        restTimerDuration = safeSeconds
        restTimerRemaining = safeSeconds
        isRestTimerRunning = true
    }

    private func pauseRestTimer() {
        isRestTimerRunning = false
    }

    private func resumeRestTimer() {
        if restTimerRemaining == 0 {
            restTimerRemaining = restTimerDuration
        }
        isRestTimerRunning = true
    }

    private func resetRestTimer() {
        isRestTimerRunning = false
        restTimerRemaining = 0
    }

    private func addRestTime(seconds: Int) {
        guard seconds > 0 else { return }

        if restTimerRemaining == 0 {
            startRestTimer(seconds: seconds)
            return
        }

        restTimerRemaining += seconds
        restTimerDuration = max(restTimerDuration, restTimerRemaining)
    }

    private func handleRestTimerTick() {
        guard isRestTimerRunning, restTimerRemaining > 0 else { return }

        restTimerRemaining -= 1
        if restTimerRemaining <= 0 {
            restTimerRemaining = 0
            isRestTimerRunning = false
        }
    }

    private func defaultDrafts(
        for exercise: Exercise,
        plan: ProgramWorkoutPlan
    ) -> [SetDraft] {
        let templates = plan.setTemplatesByExerciseID[exercise.id] ?? []
        let recommendation = weightRecommendation(for: exercise, targetReps: templates.map(\.reps))
        let recommendedWeight = recommendation?.recommendedWeight

        if templates.isEmpty {
            return [
                SetDraft(
                    weight: recommendedWeight.map { WeightFormatter.displayString($0, unit: weightUnit) } ?? ""
                )
            ]
        }

        return templates.map { template in
            SetDraft(
                weight: (template.weight ?? recommendedWeight).map {
                    WeightFormatter.displayString($0, unit: weightUnit)
                } ?? "",
                reps: String(template.reps),
                transcript: "",
                prescriptionNote: template.note
            )
        }
    }

    private func syncSelection() {
        if selectedRoutineID == nil {
            selectedRoutineID = store.routines.first?.id
        }

        if let selectedRoutineID,
           store.routines.contains(where: { $0.id == selectedRoutineID }) == false {
            self.selectedRoutineID = store.routines.first?.id
        }

        rebuildDrafts()
    }

    private func rebuildDrafts() {
        guard let routine = selectedRoutine else {
            drafts = [:]
            return
        }

        let plan = WorkoutProgramEngine.plan(for: routine)
        let exercises = activeExercises(in: routine, plan: plan)
        var refreshed: [UUID: [SetDraft]] = [:]

        for exercise in exercises {
            let existingSets = drafts[exercise.id] ?? []
            refreshed[exercise.id] = existingSets.isEmpty
                ? defaultDrafts(for: exercise, plan: plan)
                : existingSets
        }

        drafts = refreshed

        if let activeVoiceTarget,
           refreshed[activeVoiceTarget.exerciseID]?.contains(where: { $0.id == activeVoiceTarget.setID }) != true {
            speechInput.stopRecording()
            self.activeVoiceTarget = nil
        }
    }

    private func setDrafts(
        for exercise: Exercise,
        plan: ProgramWorkoutPlan
    ) -> [SetDraft] {
        let sets = drafts[exercise.id] ?? []
        return sets.isEmpty ? defaultDrafts(for: exercise, plan: plan) : sets
    }

    private func weightRecommendation(
        for exercise: Exercise,
        targetSets: [SetDraft]
    ) -> ExerciseWeightRecommendation? {
        let targetReps = targetSets.compactMap { Int($0.reps) }
        return weightRecommendation(for: exercise, targetReps: targetReps)
    }

    private func weightRecommendation(
        for exercise: Exercise,
        targetReps: [Int]
    ) -> ExerciseWeightRecommendation? {
        guard let selectedRoutine else {
            return nil
        }

        return store.weightRecommendation(
            routineName: selectedRoutine.name,
            exerciseName: exercise.name,
            targetReps: targetReps,
            minimumIncrease: minimumWeightIncreaseDisplayValue(),
            unit: weightUnit
        )
    }

    private func addSet(to exerciseID: UUID) {
        var sets = drafts[exerciseID] ?? []
        if sets.isEmpty {
            sets = [SetDraft()]
        }

        sets.append(SetDraft())
        drafts[exerciseID] = sets
    }

    private func removeSet(from exerciseID: UUID, setID: UUID) {
        guard var sets = drafts[exerciseID],
              let index = sets.firstIndex(where: { $0.id == setID }) else {
            return
        }

        if isVoiceActive(for: exerciseID, setID: setID) {
            speechInput.stopRecording()
            activeVoiceTarget = nil
        }

        sets.remove(at: index)
        drafts[exerciseID] = sets.isEmpty ? [SetDraft()] : sets
    }

    private func updateSet(
        for exerciseID: UUID,
        setID: UUID,
        update: (inout SetDraft) -> Void
    ) {
        guard var sets = drafts[exerciseID],
              let index = sets.firstIndex(where: { $0.id == setID }) else {
            return
        }

        update(&sets[index])
        drafts[exerciseID] = sets
    }

    private func updateSet(
        for exerciseID: UUID,
        setIndex: Int,
        update: (inout SetDraft) -> Void
    ) {
        guard var sets = drafts[exerciseID],
              sets.indices.contains(setIndex) else {
            return
        }

        update(&sets[setIndex])
        drafts[exerciseID] = sets
    }

    private func weightBinding(for exerciseID: UUID, setIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let sets = drafts[exerciseID],
                      sets.indices.contains(setIndex) else {
                    return ""
                }
                return sets[setIndex].weight
            },
            set: { value in
                updateSet(for: exerciseID, setIndex: setIndex) { set in
                    set.weight = value.filter { Constants.weightInputCharacters.contains($0) }
                }
            }
        )
    }

    private func repsBinding(for exerciseID: UUID, setIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let sets = drafts[exerciseID],
                      sets.indices.contains(setIndex) else {
                    return ""
                }
                return sets[setIndex].reps
            },
            set: { value in
                updateSet(for: exerciseID, setIndex: setIndex) { set in
                    set.reps = value.filter(\.isNumber)
                }
            }
        )
    }

    private func isVoiceActive(for exerciseID: UUID, setID: UUID) -> Bool {
        activeVoiceTarget == ActiveVoiceTarget(exerciseID: exerciseID, setID: setID)
    }

    private func toggleVoiceInput(for exerciseID: UUID, setID: UUID) {
        let target = ActiveVoiceTarget(exerciseID: exerciseID, setID: setID)

        if activeVoiceTarget == target && speechInput.isRecording {
            speechInput.stopRecording()
            activeVoiceTarget = nil
            return
        }

        speechInput.requestPermissions { granted in
            guard granted else {
                errorMessage = SpeechInputError.permissionsDenied.localizedDescription
                showErrorAlert = true
                return
            }

            do {
                activeVoiceTarget = target

                try speechInput.startRecording { transcript, isFinal in
                    updateSet(for: exerciseID, setID: setID) { set in
                        set.transcript = transcript

                        let parsed = VoiceParser.parseWeightAndReps(from: transcript)
                        if let weight = parsed.weight {
                            let spokenUnit = weight.unit ?? weightUnit
                            let storedWeight = spokenUnit.storedPounds(fromDisplayValue: weight.value)
                            set.weight = WeightFormatter.displayString(storedWeight, unit: weightUnit)
                        }
                        if let reps = parsed.reps {
                            set.reps = String(reps)
                        }
                    }

                    if isFinal {
                        activeVoiceTarget = nil
                    }
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to start voice input."
                showErrorAlert = true
                activeVoiceTarget = nil
            }
        }
    }

    private func hasAnyLoggedValues(in exercises: [Exercise]) -> Bool {
        exercises.contains { exercise in
            let sets = drafts[exercise.id] ?? []
            return sets.contains { set in
                !set.weight.isEmpty || !set.reps.isEmpty || !set.transcript.isEmpty
            }
        }
    }

    private func saveWorkout(routine: Routine, activeExercises: [Exercise]) {
        let entries: [ExerciseEntry] = activeExercises.map { exercise in
            let sets = (drafts[exercise.id] ?? []).compactMap { set -> ExerciseSet? in
                let transcript = set.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                let weight = parseStoredWeight(from: set.weight)
                let reps = Int(set.reps)

                if weight == nil, reps == nil, transcript.isEmpty {
                    return nil
                }

                return ExerciseSet(
                    weight: weight,
                    reps: reps,
                    transcript: transcript.isEmpty ? nil : transcript
                )
            }

            return ExerciseEntry(exerciseName: exercise.name, sets: sets)
        }

        store.logWorkout(routineID: routine.id, entries: entries)

        if autoStartRestTimer {
            startRestTimer(seconds: restTimerDuration)
        }

        speechInput.stopRecording()
        activeVoiceTarget = nil

        drafts = [:]
        syncSelection()

        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.savedToastDuration) {
            showSavedToast = false
        }
    }
}
