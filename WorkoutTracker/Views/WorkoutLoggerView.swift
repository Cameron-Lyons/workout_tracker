import Foundation
import SwiftUI

private struct SetDraft: Identifiable, Equatable {
    var id = UUID()
    var weight = ""
    var reps = ""
    var prescriptionNote: String?
}

private struct RestTimerCardView: View {
    private enum Constants {
        static let defaultRestSeconds = 90
        static let minimumRestSeconds = 1
        static let quickAddRestSeconds = 30
        static let restPresets = [60, 90, 120, 180]
        static let restTickerInterval = 1.0
        static let restPresetTintOpacity = 0.88
    }

    private enum Layout {
        static let sectionSpacing: CGFloat = 12
        static let compactSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 10
        static let cardCornerRadius: CGFloat = 16
    }

    @Binding var autoStartRestTimer: Bool
    let autoStartTrigger: Int

    @State private var restTimerDuration = Constants.defaultRestSeconds
    @State private var restTimerRemaining = 0
    @State private var isRestTimerRunning = false

    private let restTicker = Timer.publish(
        every: Constants.restTickerInterval,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack {
                Label("Rest Timer", systemImage: "timer")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(restTimerDisplay)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
                    .foregroundStyle(restTimerRemaining == 0 && !isRestTimerRunning ? AppColors.textSecondary : AppColors.textPrimary)
            }

            ProgressView(value: restProgress)
                .tint(AppColors.accent)

            HStack(spacing: Layout.compactSpacing) {
                ForEach(Constants.restPresets, id: \.self) { seconds in
                    Button(presetLabel(for: seconds)) {
                        startRestTimer(seconds: seconds)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.accent.opacity(Constants.restPresetTintOpacity))
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
                .tint(AppColors.accent)

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
                .tint(AppColors.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
        .onReceive(restTicker) { _ in
            handleRestTimerTick()
        }
        .onChange(of: autoStartTrigger) { _, _ in
            guard autoStartRestTimer else {
                return
            }
            startRestTimer(seconds: restTimerDuration)
        }
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
}

struct WorkoutLoggerView: View {
    private enum Constants {
        static let weightInputCharacters = "0123456789."
        static let savedToastDuration = 1.4
        static let scrollFadeOpacity = 0.84
        static let scrollScale = 0.985
        static let destructiveControlOpacity = 0.9
        static let animationDuration = 0.2
        static let setAnimation = Animation.spring(response: 0.40, dampingFraction: 0.84)
    }

    private enum Layout {
        static let rootSpacing: CGFloat = 18
        static let sectionSpacing: CGFloat = 12
        static let selectorSectionSpacing: CGFloat = 10
        static let compactSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 10
        static let unitPickerWidth: CGFloat = 210
        static let minimumIncreaseInputWidth: CGFloat = 66
        static let cardCornerRadius: CGFloat = 16
        static let setCardCornerRadius: CGFloat = 12
        static let setCardPadding: CGFloat = 10
        static let routineSelectorPadding: CGFloat = 14
        static let listBottomPadding: CGFloat = 6
        static let emptyStateSpacing: CGFloat = 12
        static let emptyStateIconSize: CGFloat = 38
        static let emptyStatePadding: CGFloat = 22
        static let recommendationSpacing: CGFloat = 4
        static let recommendationRowSpacing: CGFloat = 6
        static let recommendationHorizontalPadding: CGFloat = 10
        static let recommendationVerticalPadding: CGFloat = 8
        static let recommendationBorderOpacity = 0.75
        static let toastHorizontalPadding: CGFloat = 14
        static let toastVerticalPadding: CGFloat = 10
        static let toastBottomPadding: CGFloat = 24
        static let heroHorizontalPadding: CGFloat = 14
    }

    @EnvironmentObject private var store: WorkoutStore
    @AppStorage("workout_tracker_rest_timer_auto_start_v1") private var autoStartRestTimer = false
    @AppStorage(WeightUnit.preferenceKey) private var weightUnitRawValue = WeightUnit.pounds.rawValue
    @AppStorage("workout_tracker_min_weight_increase_v1")
    private var minimumWeightIncreaseInPounds = StrengthProgressionDefaults.recommendedMinimumIncreaseInPounds

    @State private var selectedRoutineID: UUID?
    @State private var drafts: [UUID: [SetDraft]] = [:]
    @State private var minimumWeightIncreaseInput = ""
    @State private var previousWeightUnit: WeightUnit = .pounds

    @State private var showSavedToast = false

    @State private var restTimerAutoStartTrigger = 0

    private var selectedRoutine: Routine? {
        guard let selectedRoutineID else { return nil }
        return store.routine(withID: selectedRoutineID)
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
                        let setDraftsByExerciseID = buildSetDraftCache(
                            for: visibleExercises,
                            plan: plan
                        )
                        let recommendationsByExerciseID = buildRecommendationCache(
                            routineName: routine.name,
                            exercises: visibleExercises,
                            setDraftsByExerciseID: setDraftsByExerciseID
                        )
                        return (
                            routine: routine,
                            plan: plan,
                            visibleExercises: visibleExercises,
                            setDraftsByExerciseID: setDraftsByExerciseID,
                            recommendationsByExerciseID: recommendationsByExerciseID
                        )
                    }

                    loggerHeroCard(
                        selectedRoutineName: selectedRoutineWithPlan?.routine.name,
                        visibleExerciseCount: selectedRoutineWithPlan?.visibleExercises.count ?? 0
                    )
                    .padding(.horizontal, Layout.heroHorizontalPadding)
                    .appReveal(delay: 0.01)

                    routineSelector
                        .appReveal(delay: 0.02)

                    if let contextLabel = selectedRoutineWithPlan?.plan.contextLabel {
                        Text(contextLabel)
                            .font(.caption.weight(.semibold))
                            .tracking(0.7)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    RestTimerCardView(
                        autoStartRestTimer: $autoStartRestTimer,
                        autoStartTrigger: restTimerAutoStartTrigger
                    )
                        .padding(.horizontal)
                        .appReveal(delay: 0.08)

                    if let selectedRoutineWithPlan {
                        let routine = selectedRoutineWithPlan.routine
                        let visibleExercises = selectedRoutineWithPlan.visibleExercises
                        let setDraftsByExerciseID = selectedRoutineWithPlan.setDraftsByExerciseID
                        let recommendationsByExerciseID = selectedRoutineWithPlan.recommendationsByExerciseID

                        ScrollView {
                            LazyVStack(spacing: Layout.sectionSpacing) {
                                ForEach(visibleExercises) { exercise in
                                    exerciseCard(
                                        exercise,
                                        sets: setDraftsByExerciseID[exercise.id] ?? [],
                                        recommendation: recommendationsByExerciseID[exercise.id]
                                    )
                                        .scrollTransition(axis: .vertical) { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1 : Constants.scrollFadeOpacity)
                                                .scaleEffect(phase.isIdentity ? 1 : Constants.scrollScale)
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, Layout.listBottomPadding)
                        }
                        .scrollIndicators(.hidden)

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
                        .accessibilityIdentifier("logger.saveWorkoutButton")
                        .appReveal(delay: 0.12)
                    } else {
                        Spacer()
                        VStack(spacing: Layout.emptyStateSpacing) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: Layout.emptyStateIconSize, weight: .semibold))
                                .foregroundStyle(AppColors.accent)

                            Text("No routine selected")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Create a routine first, then pick it here to start logging.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(Layout.emptyStatePadding)
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
                        .accessibilityIdentifier("logger.savedToast")
                }
            }
            .animation(.easeInOut(duration: Constants.animationDuration), value: showSavedToast)
        }
    }

    private func loggerHeroCard(
        selectedRoutineName: String?,
        visibleExerciseCount: Int
    ) -> some View {
        let hasSelection = selectedRoutineName != nil

        return AppHeroCard(
            eyebrow: "Current Session",
            title: selectedRoutineName ?? "Choose a routine",
            subtitle: hasSelection
                ? "Log \(visibleExerciseCount) exercise\(visibleExerciseCount == 1 ? "" : "s"), then save to update your progress history."
                : "Pick a routine to unlock set logging, recommendations, and auto rest timing.",
            systemImage: "figure.strengthtraining.traditional",
            metrics: [
                AppHeroMetric(
                    id: "logger-exercises",
                    label: "Exercises",
                    value: "\(visibleExerciseCount)",
                    systemImage: "dumbbell"
                ),
                AppHeroMetric(
                    id: "logger-unit",
                    label: "Unit",
                    value: weightUnit.symbol.uppercased(),
                    systemImage: "scalemass"
                ),
                AppHeroMetric(
                    id: "logger-rest",
                    label: "Auto Rest",
                    value: autoStartRestTimer ? "On" : "Off",
                    systemImage: "timer"
                )
            ]
        )
    }

    private var routineSelector: some View {
        VStack(alignment: .leading, spacing: Layout.selectorSectionSpacing) {
            Label("Session setup", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            selectorRowLabel("Routine", systemImage: "list.bullet")

            Picker("Routine", selection: $selectedRoutineID) {
                Text("Choose a routine").tag(Optional<UUID>.none)
                ForEach(store.routines) { routine in
                    Text(routine.name).tag(Optional(routine.id))
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.textPrimary)
            .accessibilityIdentifier("logger.routinePicker")

            HStack(spacing: Layout.compactSpacing) {
                selectorRowLabel("Units", systemImage: "scalemass")

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
                selectorRowLabel("Min Weight Increase", systemImage: "arrow.up.right")

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
        .padding(Layout.routineSelectorPadding)
        .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
        .padding(.horizontal)
    }

    private func selectorRowLabel(_ label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.textSecondary)
            .tracking(0.4)
    }

    private func exerciseCard(
        _ exercise: Exercise,
        sets: [SetDraft],
        recommendation: ExerciseWeightRecommendation?
    ) -> some View {
        return VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(exercise.name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            if let recommendation {
                recommendationCallout(recommendation)
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                VStack(alignment: .leading, spacing: Layout.compactSpacing) {
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.caption.weight(.semibold))
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
                            .foregroundStyle(Color.red.opacity(Constants.destructiveControlOpacity))
                        }
                    }

                    HStack(spacing: Layout.rowSpacing) {
                        TextField("Weight (\(weightUnit.symbol))", text: weightBinding(for: exercise.id, setIndex: index))
                            .keyboardType(.decimalPad)
                            .appInputField()
                            .accessibilityIdentifier("logger.weightField.\(exercise.id.uuidString).\(index)")

                        TextField("Reps", text: repsBinding(for: exercise.id, setIndex: index))
                            .keyboardType(.numberPad)
                            .appInputField()
                            .accessibilityIdentifier("logger.repsField.\(exercise.id.uuidString).\(index)")
                    }

                    if let note = set.prescriptionNote, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(Layout.setCardPadding)
                .appSurface(cornerRadius: Layout.setCardCornerRadius, shadow: false)
            }
            .animation(Constants.setAnimation, value: sets.count)

            Button {
                addSet(to: exercise.id)
            } label: {
                Label("Add Set", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .tint(AppColors.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
    }

    private func recommendationCallout(_ recommendation: ExerciseWeightRecommendation) -> some View {
        VStack(alignment: .leading, spacing: Layout.recommendationSpacing) {
            HStack(spacing: Layout.recommendationRowSpacing) {
                Image(systemName: recommendation.shouldIncrease ? "arrow.up.right.circle.fill" : "equal.circle.fill")
                    .foregroundStyle(recommendation.shouldIncrease ? AppColors.accent : AppColors.textSecondary)

                Text("Suggested next weight: \(WeightFormatter.displayString(recommendation.recommendedWeight, unit: weightUnit)) \(weightUnit.symbol)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text(recommendation.guidance)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, Layout.recommendationHorizontalPadding)
        .padding(.vertical, Layout.recommendationVerticalPadding)
        .appInsetCard(borderOpacity: Layout.recommendationBorderOpacity)
    }

    private func activeExercises(in routine: Routine, plan: ProgramWorkoutPlan) -> [Exercise] {
        if let activeIDs = plan.activeExerciseIDs {
            return routine.exercises.filter { activeIDs.contains($0.id) }
        }

        return routine.exercises
    }

    private func buildSetDraftCache(
        for exercises: [Exercise],
        plan: ProgramWorkoutPlan
    ) -> [UUID: [SetDraft]] {
        var setDraftsByExerciseID: [UUID: [SetDraft]] = [:]
        setDraftsByExerciseID.reserveCapacity(exercises.count)

        for exercise in exercises {
            setDraftsByExerciseID[exercise.id] = setDrafts(for: exercise, plan: plan)
        }

        return setDraftsByExerciseID
    }

    private func buildRecommendationCache(
        routineName: String,
        exercises: [Exercise],
        setDraftsByExerciseID: [UUID: [SetDraft]]
    ) -> [UUID: ExerciseWeightRecommendation] {
        let minimumIncrease = minimumWeightIncreaseDisplayValue()
        var recommendationsByExerciseID: [UUID: ExerciseWeightRecommendation] = [:]
        recommendationsByExerciseID.reserveCapacity(exercises.count)

        for exercise in exercises {
            let setDrafts = setDraftsByExerciseID[exercise.id] ?? []
            let targetReps = setDrafts.compactMap { Int($0.reps) }
            if let recommendation = store.weightRecommendation(
                routineName: routineName,
                exerciseName: exercise.name,
                targetReps: targetReps,
                minimumIncrease: minimumIncrease,
                unit: weightUnit
            ) {
                recommendationsByExerciseID[exercise.id] = recommendation
            }
        }

        return recommendationsByExerciseID
    }

    private var minimumWeightIncreaseBinding: Binding<String> {
        Binding(
            get: {
                minimumWeightIncreaseInput
            },
            set: { value in
                let sanitized = value.filter { Constants.weightInputCharacters.contains($0) }
                minimumWeightIncreaseInput = sanitized

                guard let parsed = WeightInputParser.parseDisplayValue(sanitized) else {
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
        guard let transition = WeightUnitTransition.changedUnits(
            previous: &previousWeightUnit,
            next: weightUnit
        ) else {
            syncMinimumWeightIncreaseInput()
            return
        }

        convertDraftWeights(from: transition.old, to: transition.new)
        normalizeStoredMinimumIncrease()
        syncMinimumWeightIncreaseInput()
    }

    private func convertDraftWeights(from oldUnit: WeightUnit, to newUnit: WeightUnit) {
        drafts = drafts.mapValues { sets in
            sets.map { set in
                guard let convertedWeight = WeightInputConversion.convertedDisplayString(
                    from: set.weight,
                    oldUnit: oldUnit,
                    newUnit: newUnit
                ) else {
                    return set
                }

                var converted = set
                converted.weight = convertedWeight
                return converted
            }
        }
    }

    private func parseStoredWeight(from text: String) -> Double? {
        WeightInputConversion.parseStoredPounds(from: text, unit: weightUnit, allowsZero: true)
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
                prescriptionNote: template.note
            )
        }
    }

    private func syncSelection() {
        if selectedRoutineID == nil {
            selectedRoutineID = store.routines.first?.id
        }

        if let selectedRoutineID,
           store.routine(withID: selectedRoutineID) == nil {
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
        if drafts[exerciseID]?.isEmpty != false {
            drafts[exerciseID] = [SetDraft(), SetDraft()]
            return
        }

        drafts[exerciseID, default: []].append(SetDraft())
    }

    private func removeSet(from exerciseID: UUID, setID: UUID) {
        guard let index = drafts[exerciseID]?.firstIndex(where: { $0.id == setID }) else {
            return
        }

        drafts[exerciseID]!.remove(at: index)
        if drafts[exerciseID]?.isEmpty == true {
            drafts[exerciseID] = [SetDraft()]
        }
    }

    private func updateSet(
        for exerciseID: UUID,
        setIndex: Int,
        update: (inout SetDraft) -> Void
    ) {
        guard let setCount = drafts[exerciseID]?.count,
              setIndex >= 0,
              setIndex < setCount else {
            return
        }

        var updatedSet = drafts[exerciseID]![setIndex]
        update(&updatedSet)
        drafts[exerciseID]![setIndex] = updatedSet
    }

    private func setFieldBinding(
        for exerciseID: UUID,
        setIndex: Int,
        value: @escaping (SetDraft) -> String,
        assign: @escaping (inout SetDraft, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: {
                guard let sets = drafts[exerciseID],
                      sets.indices.contains(setIndex) else {
                    return ""
                }
                return value(sets[setIndex])
            },
            set: { input in
                updateSet(for: exerciseID, setIndex: setIndex) { set in
                    assign(&set, input)
                }
            }
        )
    }

    private func weightBinding(for exerciseID: UUID, setIndex: Int) -> Binding<String> {
        setFieldBinding(
            for: exerciseID,
            setIndex: setIndex,
            value: { $0.weight },
            assign: { set, input in
                set.weight = input.filter { Constants.weightInputCharacters.contains($0) }
            }
        )
    }

    private func repsBinding(for exerciseID: UUID, setIndex: Int) -> Binding<String> {
        setFieldBinding(
            for: exerciseID,
            setIndex: setIndex,
            value: { $0.reps },
            assign: { set, input in
                set.reps = input.filter(\.isNumber)
            }
        )
    }

    private func hasAnyLoggedValues(in exercises: [Exercise]) -> Bool {
        exercises.contains { exercise in
            let sets = drafts[exercise.id] ?? []
            return sets.contains { set in
                !set.weight.isEmpty || !set.reps.isEmpty
            }
        }
    }

    private func saveWorkout(routine: Routine, activeExercises: [Exercise]) {
        let entries: [ExerciseEntry] = activeExercises.map { exercise in
            let sets = (drafts[exercise.id] ?? []).compactMap { set -> ExerciseSet? in
                let weight = parseStoredWeight(from: set.weight)
                let reps = Int(set.reps)

                if weight == nil, reps == nil {
                    return nil
                }

                return ExerciseSet(
                    weight: weight,
                    reps: reps
                )
            }

            return ExerciseEntry(exerciseName: exercise.name, sets: sets)
        }

        store.logWorkout(routineID: routine.id, entries: entries)

        if autoStartRestTimer {
            restTimerAutoStartTrigger += 1
        }

        drafts = [:]
        syncSelection()

        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.savedToastDuration) {
            showSavedToast = false
        }
    }
}
